import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// La interfaz forma parte de la plataforma del paquete que se está simulando.
// ignore: depend_on_referenced_packages
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/data/services/registro_busqueda_lector.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _uuidLector = Guid('6b1a0001-5c1e-4f7a-9d2e-47796d416473');

LectorBleService _servicio() => LectorBleService(
      registro: RegistroBusquedaLector(obtenerMetadatos: () async => {}),
    );

/// Se simula la plataforma, no el servicio: las respuestas recorren el
/// startScan, el buffer y los streams reales de FlutterBluePlus.
final class _PlataformaBleFalsa extends FlutterBluePlusPlatform {
  final adaptador = StreamController<BmBluetoothAdapterState>.broadcast();
  final respuestas = StreamController<BmScanResponse>.broadcast();
  final inicios = <BmScanSettings>[];
  int detenciones = 0;
  Object? errorAlIniciar;
  Completer<void>? permitirInicio;
  Completer<void> inicioRecibido = Completer<void>();
  Completer<void>? permitirDetencion;
  Completer<void> detencionRecibida = Completer<void>();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged => adaptador.stream;

  @override
  Stream<BmScanResponse> get onScanResponse => respuestas.stream;

  @override
  Future<bool> isSupported(BmIsSupportedRequest request) async => true;

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async =>
      BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);

  @override
  Future<bool> startScan(BmScanSettings request) async {
    inicios.add(request);
    if (!inicioRecibido.isCompleted) inicioRecibido.complete();
    await permitirInicio?.future;
    if (errorAlIniciar case final error?) throw error;
    return true;
  }

  @override
  Future<bool> stopScan(BmStopScanRequest request) async {
    detenciones++;
    if (!detencionRecibida.isCompleted) detencionRecibida.complete();
    await permitirDetencion?.future;
    return true;
  }

  void cambiarAdaptador(BmAdapterStateEnum estado) {
    adaptador.add(BmBluetoothAdapterState(adapterState: estado));
  }

  void errorDelEscaneo(int codigo, String descripcion) {
    respuestas.add(BmScanResponse(
      advertisements: const [],
      success: false,
      errorCode: codigo,
      errorString: descripcion,
    ));
  }

  void anunciarLector({String? nombre = 'GymOne-4455', bool ocupado = false}) {
    respuestas.add(BmScanResponse(
      advertisements: [
        BmScanAdvertisement(
          remoteId: const DeviceIdentifier('00:11:22:33:44:55'),
          platformName: null,
          advName: nombre,
          connectable: true,
          txPowerLevel: null,
          appearance: null,
          manufacturerData: {
            0xffff: [0x47, 0x4f, 1, ocupado ? 1 : 0],
          },
          serviceData: const {},
          serviceUuids: [_uuidLector],
          rssi: -50,
        ),
      ],
      success: true,
      errorCode: 0,
      errorString: '',
    ));
  }

  void reiniciarContadores() {
    inicios.clear();
    detenciones = 0;
    errorAlIniciar = null;
    permitirInicio = null;
    inicioRecibido = Completer<void>();
    permitirDetencion = null;
    detencionRecibida = Completer<void>();
  }
}

class _Busqueda {
  _Busqueda(LectorBleService servicio,
      {Duration duracion = const Duration(seconds: 15)}) {
    suscripcion = servicio.buscar(duracion: duracion).listen(
          listas.add,
          onError: (Object error, StackTrace _) => errores.add(error),
          onDone: () {
            terminada = true;
            finalizada.complete();
          },
        );
  }

  final listas = <List<LectorCercano>>[];
  final errores = <Object>[];
  bool terminada = false;
  final finalizada = Completer<void>();
  late final StreamSubscription<List<LectorCercano>> suscripcion;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final plataforma = _PlataformaBleFalsa();

  // FBP conserva listeners globales: se usa una sola plataforma por archivo.
  setUpAll(() async {
    FlutterBluePlusPlatform.instance = plataforma;
    await FlutterBluePlus.isSupported;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await FlutterBluePlus.stopScan();
    plataforma.reiniciarContadores();
    plataforma.cambiarAdaptador(BmAdapterStateEnum.on);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    if (plataforma.permitirInicio?.isCompleted == false) {
      plataforma.permitirInicio!.complete();
    }
    plataforma.permitirInicio = null;
    if (plataforma.permitirDetencion?.isCompleted == false) {
      plataforma.permitirDetencion!.complete();
    }
    plataforma.permitirDetencion = null;
    await FlutterBluePlus.stopScan();
    await Future<void>.delayed(Duration.zero);
  });

  tearDownAll(() async {
    await plataforma.respuestas.close();
    await plataforma.adaptador.close();
  });

  Future<void> avanzarEventos() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> esperarInicio() async {
    await plataforma.inicioRecibido.future.timeout(const Duration(seconds: 1));
    await avanzarEventos();
    expect(plataforma.inicios, isNotEmpty,
        reason:
            'La plataforma debe recibir startScan antes de emitir eventos.');
  }

  test('propaga el fallo nativo asíncrono del escaneo', () async {
    final servicio = _servicio();
    final busqueda = _Busqueda(servicio);
    await esperarInicio();

    plataforma.errorDelEscaneo(3, 'SCAN_FAILED_INTERNAL_ERROR');
    await avanzarEventos();

    expect(busqueda.errores, hasLength(1));
    expect(busqueda.errores.single, isA<LectorBleException>());
    expect((busqueda.errores.single as LectorBleException).mensaje,
        contains('Bluetooth'));
    expect(busqueda.terminada, isTrue);
    expect(FlutterBluePlus.isScanningNow, isFalse);
  });

  test('explica que se debe encender Ubicación en Android antiguo', () async {
    plataforma.errorAlIniciar = PlatformException(
      code: 'startScan',
      message: 'Location services are required to scan for BLE devices',
    );
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();
    await avanzarEventos();

    expect(busqueda.errores, hasLength(1));
    expect(busqueda.errores.single, isA<LectorBleException>());
    expect(
        (busqueda.errores.single as LectorBleException).mensaje.toLowerCase(),
        contains('ubicación'));
    expect(busqueda.terminada, isTrue);
    expect(FlutterBluePlus.isScanningNow, isFalse);
  });

  test('explica que falta el permiso de ubicación', () async {
    plataforma.errorAlIniciar = PlatformException(
      code: 'startScan',
      message: 'Permission android.permission.ACCESS_FINE_LOCATION is denied',
    );
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();
    await avanzarEventos();

    expect(busqueda.errores, hasLength(1));
    expect(busqueda.errores.single, isA<LectorBleException>());
    expect(
        (busqueda.errores.single as LectorBleException).mensaje.toLowerCase(),
        contains('ubicación'));
    expect(busqueda.terminada, isTrue);
    expect(FlutterBluePlus.isScanningNow, isFalse);
  });

  test('explica que falta el permiso de Bluetooth', () async {
    plataforma.errorAlIniciar = PlatformException(
      code: 'startScan',
      message: 'Permission android.permission.BLUETOOTH_SCAN is denied',
    );
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();
    await avanzarEventos();

    expect(busqueda.errores, hasLength(1));
    expect(busqueda.errores.single, isA<LectorBleException>());
    expect(
        (busqueda.errores.single as LectorBleException).mensaje.toLowerCase(),
        contains('permiso'));
    expect(busqueda.terminada, isTrue);
    expect(FlutterBluePlus.isScanningNow, isFalse);
  });

  test('si Bluetooth se apaga durante la búsqueda, explica el fallo', () async {
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();

    plataforma.cambiarAdaptador(BmAdapterStateEnum.off);
    await avanzarEventos();

    expect(busqueda.errores, hasLength(1));
    expect(busqueda.errores.single, isA<LectorBleException>());
    expect((busqueda.errores.single as LectorBleException).mensaje,
        contains('Bluetooth'));
    expect(busqueda.terminada, isTrue);
    expect(FlutterBluePlus.isScanningNow, isFalse);
  });

  test('cancelar la suscripción detiene la búsqueda sin eventos tardíos',
      () async {
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();

    await busqueda.suscripcion.cancel();
    await avanzarEventos();
    final listasAntes = busqueda.listas.length;
    plataforma.anunciarLector();
    await avanzarEventos();

    expect(plataforma.detenciones, 1);
    expect(FlutterBluePlus.isScanningNow, isFalse);
    expect(busqueda.listas.length, listasAntes);
    expect(busqueda.errores, isEmpty);
    expect(busqueda.terminada, isFalse);
  });

  test('cancelar mientras startScan responde también deja todo detenido',
      () async {
    final permitir = Completer<void>();
    plataforma.permitirInicio = permitir;
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();

    final cancelando = busqueda.suscripcion.cancel();
    await avanzarEventos();
    permitir.complete();
    plataforma.permitirInicio = null;
    await avanzarEventos();
    await cancelando;
    plataforma.anunciarLector();
    await avanzarEventos();

    expect(plataforma.detenciones, 1);
    expect(FlutterBluePlus.isScanningNow, isFalse);
    expect(busqueda.errores, isEmpty);
    expect(busqueda.terminada, isFalse);
  });

  test('reemplaza un escaneo previo y conserva los resultados del nuevo',
      () async {
    await FlutterBluePlus.startScan(withServices: [_uuidLector]);
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();

    expect(plataforma.inicios, hasLength(2));
    expect(plataforma.detenciones, 1);
    plataforma.anunciarLector();
    await avanzarEventos();

    expect(busqueda.errores, isEmpty);
    expect(busqueda.terminada, isFalse);
    expect(busqueda.listas.last.single.nombre, 'GymOne-4455');
    expect(busqueda.listas.last.single.dispositivo.remoteId.str,
        '00:11:22:33:44:55');
    await busqueda.suscripcion.cancel();
  });

  test(
      'dos reemplazos simultáneos entregan resultados solo a la última búsqueda',
      () async {
    final primera = _Busqueda(_servicio());
    await esperarInicio();
    final permitir = Completer<void>();
    plataforma.permitirDetencion = permitir;
    final segunda = _Busqueda(_servicio());
    await plataforma.detencionRecibida.future
        .timeout(const Duration(seconds: 1));
    final ultima = _Busqueda(_servicio());

    try {
      // B espera a que A se detenga; C entra mientras esa misma detención
      // está pendiente. Ninguno debe reclamar el escáner saltándose la cola.
      await avanzarEventos();
      permitir.complete();
      plataforma.permitirDetencion = null;
      await Future.wait([primera.finalizada.future, segunda.finalizada.future])
          .timeout(const Duration(seconds: 1));
      await avanzarEventos();

      expect(primera.errores, isEmpty);
      expect(segunda.errores, isEmpty);
      expect(ultima.terminada, isFalse);
      expect(FlutterBluePlus.isScanningNow, isTrue);

      plataforma.anunciarLector();
      await avanzarEventos();

      expect(primera.listas, isEmpty);
      expect(segunda.listas, isEmpty);
      expect(ultima.listas.last.single.nombre, 'GymOne-4455');
      expect(ultima.errores, isEmpty);
    } finally {
      if (!permitir.isCompleted) permitir.complete();
      plataforma.permitirDetencion = null;
      await Future.wait([
        primera.suscripcion.cancel(),
        segunda.suscripcion.cancel(),
        ultima.suscripcion.cancel(),
      ]);
      await avanzarEventos();
    }
    expect(FlutterBluePlus.isScanningNow, isFalse);
  });

  test('detenerBusqueda termina el escaneo sin informar un fallo vacío',
      () async {
    final servicio = _servicio();
    final busqueda = _Busqueda(servicio);
    await esperarInicio();

    await servicio.detenerBusqueda();
    await busqueda.finalizada.future.timeout(const Duration(seconds: 1));
    plataforma.anunciarLector();
    await avanzarEventos();

    expect(busqueda.terminada, isTrue);
    expect(busqueda.errores, isEmpty);
    expect(busqueda.listas, isEmpty);
    expect(plataforma.detenciones, 1);
    expect(FlutterBluePlus.isScanningNow, isFalse);
  });

  test('pide BLE clásico de 1 Mbps y filtra por el servicio del lector',
      () async {
    final busqueda =
        _Busqueda(_servicio(), duracion: const Duration(seconds: 2));
    await esperarInicio();

    final pedido = plataforma.inicios.single;
    expect(pedido.androidLegacy, isTrue);
    expect(pedido.withServices, [_uuidLector]);
    expect(pedido.androidCheckLocationServices, isTrue);
    await busqueda.suscripcion.cancel();
  });

  test('el anuncio sin nombre todavía permite detectar que está ocupado',
      () async {
    final busqueda = _Busqueda(_servicio());
    await esperarInicio();

    plataforma.anunciarLector(nombre: null, ocupado: true);
    await avanzarEventos();

    expect(busqueda.listas.last.single.nombre, 'Lector GymOne');
    expect(busqueda.listas.last.single.ocupado, isTrue);
    expect(busqueda.errores, isEmpty);
    await busqueda.suscripcion.cancel();
  });

  test('un timeout vacío finaliza normalmente sin inventar un error', () async {
    final busqueda =
        _Busqueda(_servicio(), duracion: const Duration(milliseconds: 20));
    await esperarInicio();

    await busqueda.finalizada.future.timeout(const Duration(seconds: 1));

    expect(busqueda.terminada, isTrue);
    expect(busqueda.errores, isEmpty);
    expect(busqueda.listas.expand((lista) => lista), isEmpty);
    expect(FlutterBluePlus.isScanningNow, isFalse);
    expect(plataforma.detenciones, 1);
  });
}

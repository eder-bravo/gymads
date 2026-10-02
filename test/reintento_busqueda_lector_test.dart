import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/data/services/registro_busqueda_lector.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:gymads/app/modules/configuracion/views/agregar_lector_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ble extends LectorBleService {
  _Ble({this.fallos = 1, this.error, this.vacio = false})
      : super(
          registro: RegistroBusquedaLector(
            obtenerMetadatos: () async => {'plataforma': 'otro'},
          ),
        );
  final int fallos;
  final Object? error;
  final bool vacio;
  int busquedas = 0;
  int conexiones = 0;
  int liberaciones = 0;
  final preparado = Completer<void>();
  Completer<void>? liberarPendiente;

  @override
  Stream<List<LectorCercano>> buscar({
    Duration duracion = const Duration(seconds: 15),
  }) {
    busquedas++;
    late final StreamController<List<LectorCercano>> respuesta;
    respuesta = StreamController<List<LectorCercano>>(
      onListen: () {
        if (busquedas <= fallos) {
          respuesta.addError(error ??
              const FalloBusquedaBle('Apaga Bluetooth y vuelve a intentar.',
                  TipoFalloBusquedaBle.interno,
                  codigo: 3));
        } else if (!vacio) {
          respuesta.add([
            LectorCercano(
                BluetoothDevice.fromId('00:11:22:33:44:55'), 'GymOne', -50),
          ]);
        }
        unawaited(respuesta.close());
      },
      // Igual que el servicio real, cada cancelación tiene un Future propio.
      // Evita el Future vacío compartido de Stream.value entre fake zones.
      onCancel: () async {},
    );
    return respuesta.stream;
  }

  @override
  Future<void> conectar(LectorCercano lector) async {
    conexiones++;
    if (!preparado.isCompleted) preparado.complete();
  }

  @override
  Future<List<RedWifi>> leerRedes({bool buscarDeNuevo = false}) async =>
      const [RedWifi('Gym')];
  @override
  Future<void> detenerBusqueda() async {}
  @override
  Future<void> desconectar() async {}
  @override
  Future<void> liberarSesion() async {
    liberaciones++;
    await liberarPendiente?.future;
  }
}

class _Asistente extends AgregarLectorController {
  _Asistente(_Ble ble) : super(ble: ble);
  @override
  void onReady() {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  test('traduce los errores Android y solo reintenta los temporales', () {
    for (final codigo in [1, 2, 3, 5]) {
      final error = explicarFalloBusquedaBle(FlutterBluePlusException(
          ErrorPlatform.android, 'scan', codigo, 'SCAN_FAILED'));
      expect(error.reintentable, isTrue);
      expect(error.codigo, codigo);
    }
    for (final codigo in [4, 6]) {
      final error = explicarFalloBusquedaBle(FlutterBluePlusException(
          ErrorPlatform.android, 'scan', codigo, 'SCAN_FAILED'));
      expect(error.reintentable, isFalse);
    }
    final permiso = explicarFalloBusquedaBle(PlatformException(
        code: 'startScan',
        message: 'Permission android.permission.BLUETOOTH_SCAN required'));
    expect(permiso.tipo, TipoFalloBusquedaBle.permisoBluetooth);
    expect(permiso.reintentable, isFalse);
    final scanner = explicarFalloBusquedaBle(PlatformException(
        code: 'startScan', message: 'getBluetoothLeScanner() is null'));
    expect(scanner.reintentable, isTrue);
    // Los códigos de otras plataformas no tienen el significado de Android.
    expect(
        explicarFalloBusquedaBle(FlutterBluePlusException(
                ErrorPlatform.apple, 'scan', 6, 'error'))
            .tipo,
        TipoFalloBusquedaBle.desconocido);
  });

  test('respeta cinco inicios cada treinta segundos y recupera el cupo', () {
    var tiempo = Duration.zero;
    final limite = LimiteBusquedasBle(tiempo: () => tiempo);
    for (var i = 0; i < 5; i++) {
      expect(limite.reservarInicio(), isTrue);
      tiempo += const Duration(seconds: 1);
    }
    expect(limite.reservarInicio(), isFalse);
    tiempo = const Duration(milliseconds: 29999);
    expect(limite.reservarInicio(), isFalse);
    tiempo = const Duration(seconds: 30);
    expect(limite.reservarInicio(), isTrue);
    expect(limite.reservarInicio(), isFalse);
    tiempo = const Duration(seconds: 31);
    expect(limite.reservarInicio(), isTrue);
  });

  testWidgets('recupera un error temporal con un solo reintento visible',
      (tester) async {
    final ble = _Ble();
    final controller = _Asistente(ble);
    Get.put<AgregarLectorController>(controller);
    await tester.pumpWidget(const GetMaterialApp(home: AgregarLectorView()));
    await controller.buscar();
    await tester.pump();
    expect(ble.busquedas, 1);
    expect(controller.paso.value, PasoAgregar.buscando);
    expect(find.textContaining('Intentando una vez más'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 699));
    expect(ble.busquedas, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(ble.busquedas, 2);
    expect(ble.conexiones, 1,
        reason: 'paso=${controller.paso.value} '
            'lectores=${controller.lectores.length} '
            'cerrado=${controller.isClosed} mensaje=${controller.mensaje.value}');
    expect(controller.paso.value, PasoAgregar.elegirRed);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('si falla dos veces muestra instrucciones y permite copiar',
      (tester) async {
    final ble = _Ble(fallos: 5);
    final controller = _Asistente(ble);
    Get.put<AgregarLectorController>(controller);
    await tester.pumpWidget(const GetMaterialApp(home: AgregarLectorView()));
    await controller.buscar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(ble.busquedas, 2);
    expect(controller.paso.value, PasoAgregar.fallo);
    expect(find.text('Apaga Bluetooth y vuelve a intentar.'), findsOneWidget);
    expect(find.text('Copiar diagnóstico'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(ble.busquedas, 2);
    String? copiado;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
      if (llamada.method == 'Clipboard.setData') {
        copiado = (llamada.arguments as Map)['text'] as String;
      }
      return null;
    });
    await tester.ensureVisible(find.text('Copiar diagnóstico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar diagnóstico'));
    for (var i = 0; i < 20 && copiado == null; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(jsonDecode(copiado!)['version'], 1);
    expect(find.textContaining('Diagnóstico copiado'), findsOneWidget);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('permiso o ubicación requieren instrucciones, sin reintento',
      (tester) async {
    final ble = _Ble(
        error: const FalloBusquedaBle(
            'Activa Ubicación.', TipoFalloBusquedaBle.ubicacion));
    final controller = AgregarLectorController(ble: ble);
    await controller.buscar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(ble.busquedas, 1);
    expect(controller.paso.value, PasoAgregar.fallo);
    expect(controller.mensaje.value, 'Activa Ubicación.');
    controller.onClose();
  });

  testWidgets('una búsqueda vacía no repite otros quince segundos',
      (tester) async {
    final ble = _Ble(fallos: 0, vacio: true);
    final controller = AgregarLectorController(ble: ble);
    await controller.buscar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(ble.busquedas, 1);
    expect(controller.paso.value, PasoAgregar.fallo);
    expect(controller.mensaje.value, contains('No apareció ningún lector'));
    controller.onClose();
  });

  testWidgets('salir cancela el reintento y los toques simultáneos no duplican',
      (tester) async {
    final ble = _Ble(fallos: 5)..liberarPendiente = Completer<void>();
    final controller = AgregarLectorController(ble: ble);
    final inicio = controller.buscar();
    await controller.buscar();
    await tester.pump();
    expect(ble.liberaciones, 1);
    ble.liberarPendiente!.complete();
    await inicio;
    await tester.pump();
    expect(ble.busquedas, 1);
    controller.onClose();
    await tester.pump(const Duration(seconds: 2));
    expect(ble.busquedas, 1);
  });
}

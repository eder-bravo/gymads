import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/data/services/transporte_lector_ble.dart';
import 'package:gymads/app/data/services/estado_configuracion_lector.dart';
import 'package:universal_ble/universal_ble.dart' as u;

const _servicio = '6b1a0001-5c1e-4f7a-9d2e-47796d416473';
String _uuid(int n) => '6b1a000$n-5c1e-4f7a-9d2e-47796d416473';

class _WindowsBle extends u.UniversalBlePlatform {
  u.AvailabilityState disponibilidad = u.AvailabilityState.poweredOn;
  bool conectado = false;
  bool ocupado = false;
  String estado = 'listo';
  String? filtro;
  int detenciones = 0;
  final escritos = <(String, String)>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<u.AvailabilityState> getBluetoothAvailabilityState() async =>
      disponibilidad;
  @override
  Future<u.BleConnectionState> getConnectionState(String deviceId) async =>
      conectado
          ? u.BleConnectionState.connected
          : u.BleConnectionState.disconnected;
  @override
  Future<void> startScan(
      {u.ScanFilter? scanFilter, u.PlatformConfig? platformConfig}) async {
    filtro = scanFilter?.withServices.single;
    updateScanResult(u.BleDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        name: 'GymOne-EEFF',
        rssi: -50,
        services: [_servicio]));
    updateScanResult(u.BleDevice(
        deviceId: 'otro', name: 'Otro aparato', rssi: -30, services: ['180f']));
  }

  @override
  Future<void> stopScan() async {
    detenciones++;
  }

  @override
  Future<void> connect(String deviceId,
      {Duration? connectionTimeout,
      bool autoConnect = false,
      u.ConnectionPlatformConfig? platformConfig}) async {
    conectado = true;
    updateConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    conectado = false;
    updateConnection(deviceId, false);
  }

  @override
  Future<List<u.BleService>> discoverServices(
          String deviceId, bool withDescriptors) async =>
      [
        u.BleService(_servicio, [
          for (var n = 2; n <= 8; n++)
            u.BleCharacteristic(
                _uuid(n),
                [u.CharacteristicProperty.read, u.CharacteristicProperty.write],
                [])
        ])
      ];
  @override
  Future<void> setNotifiable(String deviceId, String service,
      String characteristic, u.BleInputProperty property) async {}
  @override
  Future<Uint8List> readValue(
          String deviceId, String service, String characteristic,
          {Duration? timeout}) async =>
      Uint8List.fromList(utf8.encode(characteristic == _uuid(8)
          ? (ocupado ? 'ajena' : 'tuya')
          : characteristic == _uuid(2)
              ? '-50\twpa2\tGym\n'
              : estado));
  @override
  Future<void> writeValue(
      String deviceId,
      String service,
      String characteristic,
      Uint8List value,
      u.BleOutputProperty property) async {
    escritos.add((characteristic, utf8.decode(value)));
    if (characteristic == _uuid(6) && utf8.decode(value) == 'conectar') {
      estado = 'conectando';
    }
  }
}

void main() {
  late _WindowsBle plataforma;
  late LectorBleService servicio;
  setUp(() {
    plataforma = _WindowsBle();
    u.UniversalBle.setInstance(plataforma);
    servicio = LectorBleService(usarBleWindows: true);
  });
  tearDown(() async {
    await servicio.detenerBusqueda();
    await servicio.liberarSesion();
  });

  test('sin adaptador explica la alternativa por celular o USB', () async {
    plataforma.disponibilidad = u.AvailabilityState.unsupported;
    await expectLater(
        servicio.prepararBluetooth(),
        throwsA(isA<FalloBusquedaBle>()
            .having((e) => e.mensaje, 'estrategia', contains('celular'))));
  });
  test('descubre solo el servicio GymOne y detiene la búsqueda al cancelar',
      () async {
    final lectores =
        await servicio.buscar(duracion: const Duration(milliseconds: 30)).first;
    expect(lectores.map((l) => l.nombre), ['GymOne-EEFF']);
    expect(plataforma.filtro, _servicio);
    await servicio.detenerBusqueda();
    expect(plataforma.detenciones, greaterThanOrEqualTo(2));
  });
  test('reutiliza reservas y protocolo WiFi del firmware en Windows', () async {
    await servicio.conectar(LectorCercano(
        BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'), 'GymOne-EEFF', -50));
    expect(servicio.conectado, isTrue);
    expect(servicio.sesionExclusiva, isTrue);
    expect(servicio.tokenSesion, isNotNull);
    expect((await servicio.leerRedes()).single.ssid, 'Gym');
    await servicio.liberarSesion();
    expect(plataforma.escritos.first.$2, startsWith('tomar:'));
    expect(plataforma.escritos.last.$2, startsWith('soltar:'));
    expect(plataforma.conectado, isFalse);
  });
  test('envía WiFi en orden y suelta BLE para probar la red', () async {
    await servicio.conectar(LectorCercano(
        BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'), 'GymOne-EEFF', -50));
    final resultado = await servicio.enviarWifi(
        ssid: 'Gym', clave: 'clave-wifi', gymId: 'gimnasio');
    expect(resultado, isNull);
    expect(plataforma.escritos.where((e) => e.$1 != _uuid(8)).toList(), [
      (_uuid(3), 'Gym'),
      (_uuid(4), 'clave-wifi'),
      (_uuid(5), 'gimnasio'),
      (_uuid(6), 'conectar'),
    ]);
    expect(plataforma.conectado, isFalse);
    expect(servicio.tokenSesion, isNotNull,
        reason: 'la reserva se conserva mientras prueba WiFi');
  });

  test('reserva de otro equipo impide configurar y libera la conexión',
      () async {
    plataforma.ocupado = true;
    await expectLater(
        servicio.conectar(LectorCercano(
            BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'), 'GymOne-EEFF', -50)),
        throwsA(isA<LectorOcupadoException>()));
    expect(plataforma.conectado, isFalse);
  });
  test('desconexión externa se refleja en el transporte', () async {
    final dispositivo = DispositivoLectorBle(
        BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
        windows: true);
    await dispositivo.connect(timeout: const Duration(seconds: 1));
    expect(dispositivo.isConnected, isTrue);
    plataforma.updateConnection('AA:BB:CC:DD:EE:FF', false);
    await Future<void>.delayed(Duration.zero);
    expect(dispositivo.isDisconnected, isTrue);
    await dispositivo.disconnect();
  });
}

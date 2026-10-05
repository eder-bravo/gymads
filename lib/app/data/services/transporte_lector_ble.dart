import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:universal_ble/universal_ble.dart' as universal;

/// Mantiene el protocolo del firmware y sus reservas en un solo servicio.
/// Windows (WinRT) y Linux (BlueZ) usan Universal BLE; móviles/macOS usan FBP.
class DispositivoLectorBle {
  DispositivoLectorBle(this.original, {required this.windows});
  final BluetoothDevice original;
  final bool windows;
  bool _conectado = false;
  StreamSubscription<bool>? _conexion;
  String get id => original.remoteId.str;
  bool get isConnected => windows ? _conectado : original.isConnected;
  bool get isDisconnected => !isConnected;
  Stream<BluetoothConnectionState> get connectionState => windows
      ? universal.UniversalBle.connectionStream(id).map((c) => c
          ? BluetoothConnectionState.connected
          : BluetoothConnectionState.disconnected)
      : original.connectionState;

  Future<void> connect({required Duration timeout}) async {
    if (!windows) {
      await original.connect(timeout: timeout);
      return;
    }
    _conectado = false;
    await _conexion?.cancel();
    _conexion = universal.UniversalBle.connectionStream(id)
        .listen((c) => _conectado = c);
    if (await universal.UniversalBle.getConnectionState(id) ==
        universal.BleConnectionState.connected) {
      _conectado = true;
      return;
    }
    await universal.UniversalBle.connect(id, timeout: timeout);
    _conectado = true;
  }

  Future<void> disconnect({bool queue = false, int timeout = 3}) async {
    try {
      if (windows) {
        await universal.UniversalBle.disconnect(id,
            timeout: Duration(seconds: timeout), queueId: 'desconexion-$id');
      } else {
        await original.disconnect(queue: queue, timeout: timeout);
      }
    } finally {
      _conectado = false;
      await _conexion?.cancel();
      _conexion = null;
    }
  }

  Future<List<ServicioLectorBle>> discoverServices() async {
    if (windows) {
      final servicios = await universal.UniversalBle.discoverServices(id);
      return servicios
          .map((s) => ServicioLectorBle(
              Guid(s.uuid),
              s.characteristics
                  .map((c) =>
                      CaracteristicaLectorBle.windows(id, s.uuid, c.uuid))
                  .toList()))
          .toList();
    }
    final servicios = await original.discoverServices();
    return servicios
        .map((s) => ServicioLectorBle(s.uuid,
            s.characteristics.map(CaracteristicaLectorBle.movil).toList()))
        .toList();
  }
}

class ServicioLectorBle {
  ServicioLectorBle(this.uuid, this.characteristics);
  final Guid uuid;
  final List<CaracteristicaLectorBle> characteristics;
}

class CaracteristicaLectorBle {
  CaracteristicaLectorBle.movil(BluetoothCharacteristic original)
      : _original = original,
        _id = null,
        _servicio = null,
        uuid = original.uuid;
  CaracteristicaLectorBle.windows(
      String id, String servicio, String caracteristica)
      : _original = null,
        _id = id,
        _servicio = servicio,
        uuid = Guid(caracteristica);
  final BluetoothCharacteristic? _original;
  final String? _id;
  final String? _servicio;
  final Guid uuid;

  Future<List<int>> read({int timeout = 10}) => _original != null
      ? _original.read(timeout: timeout)
      : universal.UniversalBle.read(_id!, _servicio!, uuid.str,
          timeout: Duration(seconds: timeout));
  Future<void> write(List<int> bytes,
          {bool allowLongWrite = false, int timeout = 10}) =>
      _original != null
          ? _original.write(bytes,
              allowLongWrite: allowLongWrite, timeout: timeout)
          : universal.UniversalBle.write(
              _id!, _servicio!, uuid.str, Uint8List.fromList(bytes),
              timeout: Duration(seconds: timeout));
  Future<void> setNotifyValue(bool activo) async {
    if (_original != null) {
      await _original.setNotifyValue(activo);
      return;
    }
    if (activo) {
      await universal.UniversalBle.subscribeNotifications(
          _id!, _servicio!, uuid.str);
    } else {
      await universal.UniversalBle.unsubscribe(_id!, _servicio!, uuid.str);
    }
  }

  Stream<List<int>> get onValueReceived =>
      _original?.onValueReceived ??
      universal.UniversalBle.characteristicValueStream(_id!, uuid.str);
}

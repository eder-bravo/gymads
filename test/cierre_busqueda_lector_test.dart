import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';

class _ConexionPendiente extends LectorBleService {
  _ConexionPendiente({this.demorarRedes = false}) {
    if (demorarRedes) permitirConexion.complete();
  }
  final bool demorarRedes;
  final empezoConexion = Completer<void>();
  final permitirConexion = Completer<void>();
  final empezoLectura = Completer<void>();
  final permitirLectura = Completer<void>();
  bool reservada = false;
  int liberaciones = 0;

  @override
  bool get sesionExclusiva => reservada;
  @override
  Future<void> conectar(LectorCercano lector) async {
    empezoConexion.complete();
    await permitirConexion.future;
    reservada = true;
  }

  @override
  Future<List<RedWifi>> leerRedes({bool buscarDeNuevo = false}) async {
    empezoLectura.complete();
    if (demorarRedes) await permitirLectura.future;
    return const [RedWifi('Gym')];
  }

  @override
  Future<void> liberarSesion() async {
    liberaciones++;
    reservada = false;
  }

  @override
  Future<void> detenerBusqueda() async {}
  @override
  Future<void> desconectar() async => reservada = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lector =
      LectorCercano(BluetoothDevice.fromId('00:11:22:33:44:55'), 'GymOne', -50);

  test('una conexión tardía al salir libera la reserva y no avanza pantalla',
      () async {
    final ble = _ConexionPendiente();
    final controller = AgregarLectorController(ble: ble);
    final preparando = controller.elegirLector(lector);
    await ble.empezoConexion.future;
    controller.onClose();
    ble.permitirConexion.complete();
    await preparando;
    expect(ble.reservada, isFalse);
    expect(ble.liberaciones, 2);
    expect(ble.empezoLectura.isCompleted, isFalse);
    expect(controller.paso.value, PasoAgregar.preparando);
    expect(controller.redes, isEmpty);
  });

  test(
      'si se sale durante la lectura, las redes tardías no reservan ni avanzan',
      () async {
    final ble = _ConexionPendiente(demorarRedes: true);
    final controller = AgregarLectorController(ble: ble);
    final preparando = controller.elegirLector(lector);
    await ble.empezoLectura.future;
    controller.onClose();
    ble.permitirLectura.complete();
    await preparando;
    expect(ble.reservada, isFalse);
    expect(ble.liberaciones, 2);
    expect(controller.paso.value, PasoAgregar.preparando);
    expect(controller.redes, isEmpty);
  });
}

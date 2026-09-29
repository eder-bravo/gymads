import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';

/// Un Bluetooth de mentira que cuenta cuántas veces se suelta el lector y
/// cómo se piden las redes.
class _BleFalso extends LectorBleService {
  _BleFalso({this.falla = false});

  final bool falla;
  int soltado = 0;
  final pedidos = <bool>[]; // buscarDeNuevo de cada leerRedes

  @override
  Future<void> conectar(LectorCercano lector) async {}

  @override
  Future<List<RedWifi>> leerRedes({bool buscarDeNuevo = false}) async {
    pedidos.add(buscarDeNuevo);
    if (falla) throw const LectorBleException('No se pudo hablar con él.');
    return const [RedWifi('Gym', rssi: -50)];
  }

  @override
  Future<void> desconectar() async => soltado++;

  @override
  Future<void> detenerBusqueda() async {}
}

LectorCercano _lector() =>
    LectorCercano(BluetoothDevice.fromId('00:11:22:33:44:55'), 'GymOne-4455', -50);

void main() {
  tearDown(Get.reset);

  test('con las redes en mano suelta el Bluetooth (el lector vuelve a verse)',
      () async {
    final ble = _BleFalso();
    final c = AgregarLectorController(ble: ble);
    await c.elegirLector(_lector());

    expect(c.paso.value, PasoAgregar.elegirRed);
    expect(c.redes.map((r) => r.ssid), ['Gym']);
    // Al conectarse lee lo que el lector ya buscó: no le pide otra búsqueda.
    expect(ble.pedidos, [false]);
    expect(ble.soltado, greaterThanOrEqualTo(1));
  });

  test('si falla también lo suelta', () async {
    final ble = _BleFalso(falla: true);
    final c = AgregarLectorController(ble: ble);
    await c.elegirLector(_lector());

    expect(c.paso.value, PasoAgregar.fallo);
    expect(ble.soltado, greaterThanOrEqualTo(1));
  });

  test('"Buscar de nuevo" pide una búsqueda nueva y luego suelta', () async {
    final ble = _BleFalso();
    final c = AgregarLectorController(ble: ble);
    await c.elegirLector(_lector());
    final antes = ble.soltado;

    await c.actualizarRedes();

    expect(ble.pedidos.last, isTrue);
    expect(ble.soltado, antes + 1);
    expect(c.buscandoRedes.value, isFalse);
  });
}

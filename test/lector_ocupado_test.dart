import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/services/estado_configuracion_lector.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:gymads/app/modules/configuracion/views/agregar_lector_view.dart';

class _Ble extends LectorBleService {
  _Ble({this.reserva = true, this.ocupado = false});
  final bool reserva;
  final bool ocupado;
  int conexiones = 0;
  int desconexiones = 0;
  int liberaciones = 0;

  @override
  bool get sesionExclusiva => reserva;

  @override
  Future<void> conectar(LectorCercano lector) async {
    conexiones++;
    if (ocupado) throw const LectorOcupadoException();
  }

  @override
  Future<List<RedWifi>> leerRedes({bool buscarDeNuevo = false}) async =>
      const [RedWifi('Gym')];

  @override
  Future<void> desconectar() async => desconexiones++;

  @override
  Future<void> liberarSesion() async => liberaciones++;

  @override
  Future<void> detenerBusqueda() async {}
}

LectorCercano _lector({bool ocupado = false}) => LectorCercano(
      BluetoothDevice.fromId('00:11:22:33:44:55'),
      'GymOne-4455',
      -50,
      ocupado: ocupado,
    );

class _Asistente extends AgregarLectorController {
  _Asistente() : super(ble: _Ble());

  @override
  void onReady() {} // La prueba no busca hardware.
}

void main() {
  tearDown(Get.reset);

  test('el anuncio reconoce ocupado y tolera lectores antiguos y otros datos',
      () {
    expect(
        lectorOcupadoEnAnuncio({
          0xffff: [0x47, 0x4f, 1, 1]
        }),
        isTrue);
    for (final datos in <Map<int, List<int>>>[
      {},
      {
        0xffff: [0x47, 0x4f, 1, 0]
      },
      {
        0xffff: [0x47, 0x4f, 2, 1]
      },
      {
        0xffff: [0x47, 0x4f, 1]
      },
      {
        0x004c: [0x47, 0x4f, 1, 1]
      },
    ]) {
      expect(lectorOcupadoEnAnuncio(datos), isFalse);
    }
    expect(EstadoConfig.parse('ocupado').fase, FaseConfig.ocupado);
    expect(EstadoConfig.parse('ocupado').toTexto(), 'ocupado');
  });

  test('el segundo teléfono recibe el aviso sin intentar conectar ni esperar',
      () async {
    final ble = _Ble();
    final controller = AgregarLectorController(ble: ble);
    await controller.elegirLector(_lector(ocupado: true));
    expect(controller.paso.value, PasoAgregar.fallo);
    expect(controller.lectorOcupado.value, isTrue);
    expect(controller.mensaje.value, mensajeLectorOcupado);
    expect(ble.conexiones, 0);
    expect(controller.redes, isEmpty);
  });

  test('si ambos llegan juntos, el rechazo del lector explica que está ocupado',
      () async {
    final controller = AgregarLectorController(ble: _Ble(ocupado: true));
    await controller.elegirLector(_lector());
    expect(controller.lectorOcupado.value, isTrue);
    expect(controller.mensaje.value, mensajeLectorOcupado);
    expect(controller.paso.value, PasoAgregar.fallo);
  });

  test('el primero conserva la reserva al elegir red y escribir despacio',
      () async {
    final ble = _Ble();
    final controller = AgregarLectorController(ble: ble);
    await controller.elegirLector(_lector());
    controller.elegirRed(const RedWifi('Gym'));
    await controller.actualizarRedes();
    expect(controller.paso.value, PasoAgregar.escribirClave);
    expect(ble.desconexiones, 0);
    controller.onClose();
    expect(ble.liberaciones, 1);
  });

  test('con firmware anterior sigue soltando el enlace tras leer las redes',
      () async {
    final ble = _Ble(reserva: false);
    final controller = AgregarLectorController(ble: ble);
    await controller.elegirLector(_lector());
    expect(controller.paso.value, PasoAgregar.elegirRed);
    expect(ble.desconexiones, 1);
  });

  test('discover informa ocupado sin revelar quién lo está configurando', () {
    final lector = LectorEnRed.desdeDiscover('10.0.0.1', {
      'device_type': 'RFID_READER',
      'modo_config': true,
      'config_ocupada': true,
    });
    expect(lector?.configOcupada, isTrue);
  });

  testWidgets('el segundo ve Lector ocupado y Volver a buscar, sin porcentaje',
      (tester) async {
    final controller = _Asistente();
    Get.put<AgregarLectorController>(controller);
    await controller.elegirLector(_lector(ocupado: true));
    await tester.pumpWidget(const GetMaterialApp(home: AgregarLectorView()));
    await tester.pump();
    expect(find.text('Lector ocupado'), findsOneWidget);
    expect(find.text('Volver a buscar'), findsOneWidget);
    expect(find.text(mensajeLectorOcupado), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/config/rfid_config.dart';
import 'package:gymads/app/data/repositories/lector_repository.dart';
import 'package:gymads/app/data/services/espera_configuracion_lector.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _listo = LectorEnRed(
  ip: '192.168.0.80',
  id: '2805A532CD70',
  mine: true,
  claimed: true,
  ssid: 'Gym',
  version: '6.6.1',
);

class _RedFalsa extends LectorRedService {
  _RedFalsa({this.candidatos = const [_listo]});
  final List<LectorEnRed> candidatos;
  Future<LectorEnRed?>? busquedaPendiente;
  Future<ConfirmacionLector>? confirmacionPendiente;
  LectorEnRed? conocido;
  final confirmacionPedida = Completer<void>();

  @override
  Future<LectorEnRed?> buscarMio({
    String? id,
    Duration tiempoMdns = const Duration(seconds: 4),
    bool Function(LectorEnRed)? aceptar,
  }) async {
    if (busquedaPendiente != null) return busquedaPendiente;
    return candidatos.firstWhereOrNull((l) => aceptar == null || aceptar(l));
  }

  @override
  Future<LectorEnRed?> consultar(String ip,
          {Duration timeout = const Duration(seconds: 3)}) async =>
      conocido;

  @override
  Future<ConfirmacionLector> confirmarConfiguracion(LectorEnRed lector,
      {required String intento, String? sesion}) async {
    if (!confirmacionPedida.isCompleted) confirmacionPedida.complete();
    return confirmacionPendiente ?? Future.value(ConfirmacionLector.confirmada);
  }
}

class _BleFalso extends LectorBleService {
  @override
  Future<EstadoConfig?> enviarWifi({
    required String ssid,
    required String clave,
    required String gymId,
  }) async =>
      null;

  @override
  Future<EstadoConfig?> esperarResultado({
    required DateTime hasta,
    required bool Function() cancelado,
  }) async =>
      null;

  @override
  Future<void> desconectar() async {}

  @override
  Future<void> detenerBusqueda() async {}
}

class _RegistroPendiente extends LectorRepository {
  final terminado = Completer<void>();
  final iniciado = Completer<void>();

  @override
  Future<void> registrar(LectorEnRed lector,
      {required String gymId, required bool puedeDarDeAlta}) {
    if (!iniciado.isCompleted) iniciado.complete();
    return terminado.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empieza a descubrir enseguida y descarta un lector aún reiniciándose',
      () async {
    final red = _RedFalsa(candidatos: const [
      LectorEnRed(ip: '192.168.0.81', mine: true, ssid: 'WiFi anterior'),
      LectorEnRed(
          ip: '192.168.0.80', mine: true, ssid: 'Gym', modoConfig: true),
      LectorEnRed(
          ip: '192.168.0.82', id: '00000000AAAA', mine: true, ssid: 'Gym'),
      _listo,
    ]);
    final lector = await esperarLectorConfigurado(
      red: red,
      ssid: 'Gym',
      nombre: 'GymOne-CD70',
      seguir: () => true,
    ).timeout(const Duration(seconds: 1));
    expect(lector, _listo);
  });

  test('la IP conocida confirma sin aguardar a mDNS o al barrido', () async {
    final busqueda = Completer<LectorEnRed?>();
    final red = _RedFalsa()
      ..busquedaPendiente = busqueda.future
      ..conocido = _listo;
    final lector = await esperarLectorConfigurado(
      red: red,
      ssid: 'Gym',
      ip: _listo.ip,
      seguir: () => true,
    ).timeout(const Duration(seconds: 1));
    expect(lector, _listo);
    busqueda.complete(null);
  });

  test('cancelar termina aunque siga pendiente una búsqueda', () async {
    final busqueda = Completer<LectorEnRed?>();
    final cancelacion = Completer<void>();
    final espera = esperarLectorConfigurado(
      red: _RedFalsa()..busquedaPendiente = busqueda.future,
      ssid: 'Gym',
      seguir: () => true,
      cancelar: cancelacion.future,
    );
    cancelacion.complete();
    expect(await espera.timeout(const Duration(seconds: 1)), isNull);
    busqueda.complete(_listo);
  });

  test('el barrido devuelve el lector sin esperar otras IPs pendientes',
      () async {
    final pendiente = Completer<http.Response>();
    final red = LectorRedService(cliente: MockClient((peticion) async {
      if (peticion.url.host == _listo.ip) {
        return http.Response(
            json.encode({'device_id': 'ESP32_RFID_GYMONE', 'mine': true}), 200);
      }
      return pendiente.future;
    }));
    final lector = await red.barrerSubred(
        ips: [_listo.ip, '192.168.0.81'],
        parar: (l) => l.mine).timeout(const Duration(seconds: 1));
    expect(lector?.ip, _listo.ip);
    pendiente.complete(http.Response('', 404));
  });

  test('la confirmación final se autentica y reintenta con el mismo token',
      () async {
    final solicitudes = <http.Request>[];
    final red = LectorRedService(
      gymId: 'gym-1',
      cliente: MockClient((solicitud) async {
        solicitudes.add(solicitud);
        if (solicitudes.length == 1) {
          throw http.ClientException('sin respuesta');
        }
        return http.Response('{"ok":true}', 200);
      }),
    );
    final resultado = await red.confirmarConfiguracion(_listo,
        intento: 'A', sesion: 'sesion-propietaria');
    expect(resultado, ConfirmacionLector.confirmada);
    expect(solicitudes.length, 2);
    expect(solicitudes.first.url.path, '/api/confirmar_config');
    expect(json.decode(solicitudes.first.body),
        {'gym_id': 'gym-1', 'intento': 'A', 'sesion': 'sesion-propietaria'});
    expect(solicitudes.first.body, solicitudes.last.body);
  });

  test('un firmware anterior permite terminar y avisa que no tiene el sonido',
      () async {
    final red = LectorRedService(
        cliente: MockClient((_) async => http.Response('', 404)));
    expect(await red.confirmarConfiguracion(_listo, intento: 'A'),
        ConfirmacionLector.sinSoporte);
  });

  test('un rechazo del dueño no repite la solicitud ni confirma el sonido',
      () async {
    var solicitudes = 0;
    final red = LectorRedService(cliente: MockClient((_) async {
      solicitudes++;
      return http.Response('', 403);
    }));
    expect(await red.confirmarConfiguracion(_listo, intento: 'A'),
        ConfirmacionLector.sinRespuesta);
    expect(solicitudes, 1);
  });

  test('100% espera la confirmación del lector, sin aguardar al servidor',
      () async {
    SharedPreferences.setMockInitialValues({});
    final confirmar = Completer<ConfirmacionLector>();
    final red = _RedFalsa()..confirmacionPendiente = confirmar.future;
    final registro = _RegistroPendiente();
    RfidConfig.gymIdActual = () => 'test-confirmacion';
    RfidConfig.puedeGestionar = () => true;
    RfidConfig.servicioRed = (_) => red;
    RfidConfig.repositorio = () => registro;
    final controller = AgregarLectorController(ble: _BleFalso())..onInit();
    addTearDown(() {
      controller.onClose();
      RfidConfig.gymIdActual = () => null;
      RfidConfig.repositorio = LectorRepository.new;
      RfidConfig.servicioRed = (gymId) => LectorRedService(gymId: gymId);
      Get.reset();
    });
    controller.elegirRed(const RedWifi('Gym'));
    final flujo = controller.conectar();
    await red.confirmacionPedida.future.timeout(const Duration(seconds: 1));
    expect(controller.paso.value, PasoAgregar.comprobando);
    expect(controller.guardandoLector.value, isTrue);
    expect(registro.iniciado.isCompleted, isTrue);
    expect(registro.terminado.isCompleted, isFalse);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('esp32_api_url_test-confirmacion'),
        _listo.baseUrl);

    confirmar.complete(ConfirmacionLector.confirmada);
    await flujo.timeout(const Duration(seconds: 1));
    expect(controller.paso.value, PasoAgregar.listo);
    expect(controller.avisoFinal.value, isNull);
    expect(registro.terminado.isCompleted, isFalse);
    registro.terminado.complete();
  });

  test('un registro tardío no coloca el lector en otro gimnasio', () async {
    SharedPreferences.setMockInitialValues({});
    var gym = 'test-gym-original';
    final registro = _RegistroPendiente();
    RfidConfig.gymIdActual = () => gym;
    RfidConfig.puedeGestionar = () => true;
    RfidConfig.repositorio = () => registro;
    addTearDown(() {
      RfidConfig.gymIdActual = () => null;
      RfidConfig.repositorio = LectorRepository.new;
    });
    await RfidConfig.guardarLector(_listo, esperarRegistro: false);
    gym = 'test-gym-nuevo';
    expect(RfidConfig.baseUrl, isNull);
    registro.terminado.complete();
    await Future<void>.delayed(Duration.zero);
    expect(RfidConfig.registrados, isEmpty);
    expect(RfidConfig.baseUrl, isNull);
  });
}

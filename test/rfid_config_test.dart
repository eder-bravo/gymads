import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/config/rfid_config.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El lector de un gimnasio nunca debe aparecer en otro: ni en una cuenta
/// recién creada en el mismo teléfono, ni al cambiar de cuenta sin cerrar
/// la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? gym;
  final peticiones = <http.Request>[];

  /// Un lector falso en la red, que contesta /api/discover con [cuerpo].
  LectorRedService Function(String) redCon(Map<String, dynamic>? cuerpo) =>
      (gymId) => LectorRedService(
            gymId: gymId,
            cliente: MockClient((peticion) async {
              peticiones.add(peticion);
              if (cuerpo == null) throw http.ClientException('no contesta');
              return http.Response(
                  json.encode({'device_id': 'ESP32_RFID_GYMONE', ...cuerpo}),
                  200);
            }),
          );

  setUp(() {
    gym = null;
    peticiones.clear();
    RfidConfig.gymIdActual = () => gym;
    RfidConfig.puedeGestionar = () => true;
    RfidConfig.servicioRed = redCon(null);
  });

  test('una cuenta nueva no hereda el lector guardado para todo el teléfono',
      () async {
    // Lo que dejaba la versión anterior: una sola configuración por teléfono.
    SharedPreferences.setMockInitialValues({
      'esp32_api_url': 'http://192.168.1.100/api',
      'esp32_api_url_id': 'AABBCCDDEEFF',
      'rfid_enabled': true,
    });
    gym = 'gimnasio-nuevo-1';

    await RfidConfig.loadConfig();

    expect(RfidConfig.isConfigured, isFalse);
    expect(RfidConfig.tieneLector, isFalse);
    expect(RfidConfig.nombreLector, isNull);
    expect(await RfidConfig.lectorActivado(), isFalse);

    // Las claves globales se borran en vez de adoptarse.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('esp32_api_url'), isFalse);
    expect(prefs.containsKey('esp32_api_url_id'), isFalse);
    expect(prefs.containsKey('rfid_enabled'), isFalse);
    expect(prefs.containsKey('esp32_api_url_gimnasio-nuevo-1'), isFalse);
    // Ni siquiera se le preguntó a esa dirección.
    expect(peticiones, isEmpty);
  });

  test('al cambiar de gimnasio no se ve el lector del anterior', () async {
    SharedPreferences.setMockInitialValues({});
    gym = 'gimnasio-a-2';
    await RfidConfig.guardarLector(
        const LectorEnRed(ip: '10.0.0.5', claimed: true, mine: true));
    expect(RfidConfig.isConfigured, isTrue);
    expect(RfidConfig.getCurrentIP(), '10.0.0.5');

    // Otra cuenta, sin cerrar la app.
    gym = 'gimnasio-b-2';
    expect(RfidConfig.isConfigured, isFalse);
    expect(RfidConfig.baseUrl, isNull);
    expect(RfidConfig.tieneLector, isFalse);

    await RfidConfig.loadConfig();
    expect(RfidConfig.isConfigured, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('esp32_api_url_gimnasio-a-2'),
        'http://10.0.0.5/api');
    expect(prefs.getString('esp32_api_url_gimnasio-b-2'), isNull);
  });

  test('sin gimnasio en la sesión no se lee ni se escribe nada', () async {
    SharedPreferences.setMockInitialValues(
        {'esp32_api_url_gimnasio-a-3': 'http://10.0.0.5/api'});
    gym = null;

    await RfidConfig.loadConfig();
    await RfidConfig.guardarLector(const LectorEnRed(ip: '10.0.0.9'));
    await RfidConfig.activarLector(true);

    expect(RfidConfig.isConfigured, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'esp32_api_url_gimnasio-a-3'});
  });

  test('"Usar el lector" es de cada gimnasio y sigue a si tiene lector',
      () async {
    SharedPreferences.setMockInitialValues({});
    gym = 'gimnasio-a-4';
    expect(await RfidConfig.lectorActivado(), isFalse); // sin lector

    await RfidConfig.guardarLector(const LectorEnRed(ip: '10.0.0.5'));
    expect(await RfidConfig.lectorActivado(), isTrue); // con lector

    await RfidConfig.activarLector(false);
    expect(await RfidConfig.lectorActivado(), isFalse); // lo apagaron

    gym = 'gimnasio-b-4';
    expect(await RfidConfig.lectorActivado(), isFalse); // otro gimnasio
  });

  test('si en la dirección guardada contesta un lector libre, se olvida '
      'y NO se reclama por su cuenta', () async {
    // Lo desvincularon desde otro teléfono del gimnasio: sigue en la red,
    // pero ya sin dueño.
    SharedPreferences.setMockInitialValues({
      'esp32_api_url_gimnasio-a-5': 'http://10.0.0.5/api',
      'esp32_api_url_gimnasio-a-5_id': 'AABBCCDDEEFF',
    });
    gym = 'gimnasio-a-5';
    RfidConfig.servicioRed = redCon({'claimed': false, 'mine': false});

    await RfidConfig.loadConfig();

    expect(RfidConfig.isConfigured, isFalse);
    expect(RfidConfig.tieneLector, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('esp32_api_url_gimnasio-a-5'), isFalse);
    expect(prefs.containsKey('esp32_api_url_gimnasio-a-5_id'), isFalse);
    // Solo se preguntó quién es; nunca se mandó /api/claim.
    expect(peticiones.map((p) => p.url.path), everyElement('/api/discover'));
  });

  test('si en la dirección guardada contesta el lector propio, se usa',
      () async {
    SharedPreferences.setMockInitialValues(
        {'esp32_api_url_gimnasio-a-6': 'http://10.0.0.5/api'});
    gym = 'gimnasio-a-6';
    RfidConfig.servicioRed =
        redCon({'claimed': true, 'mine': true, 'id': 'A1B2C3D4E5F6'});

    await RfidConfig.loadConfig();

    expect(RfidConfig.isConfigured, isTrue);
    expect(RfidConfig.nombreLector, 'GymOne-E5F6');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('esp32_api_url_gimnasio-a-6_id'), 'A1B2C3D4E5F6');
  });
}

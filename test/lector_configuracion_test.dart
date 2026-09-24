import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Estado del lector por Bluetooth', () {
    test('ok trae la IP que le dio el router', () {
      final e = EstadoConfig.parse('ok:192.168.0.57');
      expect(e.fase, FaseConfig.ok);
      expect(e.ip, '192.168.0.57');
    });

    test('reconoce cada error', () {
      expect(EstadoConfig.parse('error:clave').fase, FaseConfig.errorClave);
      expect(EstadoConfig.parse('error:sin_red').fase, FaseConfig.errorSinRed);
      expect(EstadoConfig.parse('error:datos').fase, FaseConfig.errorDatos);
      expect(EstadoConfig.parse('error:no_conecta').fase,
          FaseConfig.errorNoConecta);
      expect(FaseConfig.errorNoConecta.esFinal, isTrue);
      expect(EstadoConfig.parse('error:sin_ip').fase, FaseConfig.errorSinIp);
      expect(
          EstadoConfig.parse('error:seguridad').fase, FaseConfig.errorSeguridad);
      expect(FaseConfig.errorSinIp.esFinal, isTrue);
      expect(EstadoConfig.parse('error:otro_gimnasio').fase,
          FaseConfig.errorOtroGimnasio);
    });

    test('los estados intermedios no son finales', () {
      for (final t in ['listo', 'buscando_redes', 'conectando']) {
        expect(EstadoConfig.parse(t).fase.esFinal, isFalse, reason: t);
      }
      expect(EstadoConfig.parse('ok:10.0.0.4').fase.esFinal, isTrue);
    });

    test('un texto desconocido no se confunde con un resultado', () {
      final e = EstadoConfig.parse('algo raro');
      expect(e.fase, FaseConfig.desconocido);
      expect(e.fase.esFinal, isFalse);
    });

    test('tolera espacios y saltos de línea sobrantes', () {
      expect(EstadoConfig.parse(' conectando\n').fase, FaseConfig.conectando);
    });

    test('toTexto vuelve al texto del firmware', () {
      for (final t in [
        'listo',
        'buscando_redes',
        'conectando',
        'ok:192.168.1.9',
        'error:clave',
        'error:sin_red',
        'error:sin_ip',
        'error:seguridad',
        'error:no_conecta',
        'error:datos',
        'error:otro_gimnasio',
      ]) {
        expect(EstadoConfig.parse(t).toTexto(), t);
      }
    });
  });

  group('Redes que ve el lector', () {
    test('firmware 6.1: señal, seguridad y nombre', () {
      final redes = parsearRedes(
          '-48\tclave\tTD Campus_C\n-71\tabierta\tInvitados\n'
          '-88\tempresarial\tEduroam');
      expect(redes.map((r) => r.ssid), ['TD Campus_C', 'Invitados', 'Eduroam']);

      expect(redes[0].rssi, -48);
      expect(redes[0].pideClave, isTrue);
      expect(redes[0].compatible, isTrue);
      expect(redes[0].barras, 3);

      expect(redes[1].seguridad, SeguridadRed.abierta);
      expect(redes[1].pideClave, isFalse);

      expect(redes[2].compatible, isFalse);
      expect(redes[2].senalDebil, isTrue);
      expect(redes[2].barras, 0);
    });

    test('el nombre puede traer espacios al final y tabuladores', () {
      final redes = parsearRedes('-50\tclave\tMi Red \n-60\tclave\tA\tB');
      expect(redes[0].ssid, 'Mi Red ');
      expect(redes[1].ssid, 'A\tB');
    });

    test('firmware anterior: solo el nombre', () {
      final redes = parsearRedes('Gym 5G\nGym\nTotalplay-2368');
      expect(redes.map((r) => r.ssid), ['Gym 5G', 'Gym', 'Totalplay-2368']);
      expect(redes.first.rssi, isNull);
      expect(redes.first.pideClave, isTrue);
    });

    test('sin líneas vacías ni repetidas', () {
      expect(parsearRedes('Gym\n\nGym\nCasa\n').map((r) => r.ssid),
          ['Gym', 'Casa']);
    });

    test('vacío si no vio ninguna', () {
      expect(parsearRedes(''), isEmpty);
    });
  });

  group('Subred del teléfono', () {
    test('las otras 253 direcciones de su /24', () {
      final ips = LectorRedService.ipsDeLaSubred('192.168.0.23');
      expect(ips.length, 253);
      expect(ips, isNot(contains('192.168.0.23')));
      expect(ips.first, '192.168.0.1');
      expect(ips.last, '192.168.0.254');
    });

    test('solo redes privadas', () {
      expect(LectorRedService.esIpPrivada('192.168.1.5'), isTrue);
      expect(LectorRedService.esIpPrivada('10.2.3.4'), isTrue);
      expect(LectorRedService.esIpPrivada('172.20.1.1'), isTrue);
      expect(LectorRedService.esIpPrivada('172.40.1.1'), isFalse);
      expect(LectorRedService.esIpPrivada('8.8.8.8'), isFalse);
      expect(LectorRedService.esIpPrivada('no-es-ip'), isFalse);
    });
  });

  group('Encontrar el lector en la red', () {
    // Una red falsa: el lector propio en .57, uno de otro gimnasio en .80.
    MockClient red({String idPropio = 'AABBCCDDEEFF'}) =>
        MockClient((peticion) async {
          final ip = peticion.url.host;
          final gym = peticion.url.queryParameters['gym_id'];
          Map<String, dynamic>? cuerpo;
          if (ip == '192.168.0.57') {
            cuerpo = {
              'device_id': 'ESP32_RFID_GYMONE',
              'id': idPropio,
              'claimed': true,
              'mine': gym == 'gym-1',
            };
          } else if (ip == '192.168.0.80') {
            cuerpo = {
              'device_id': 'ESP32_RFID_GYMONE',
              'id': '112233445566',
              'claimed': true,
              'mine': gym == 'gym-2',
            };
          } else if (ip == '192.168.0.1') {
            // El router contesta, pero no es un lector.
            return http.Response('<html>router</html>', 200);
          }
          if (cuerpo == null) throw http.ClientException('sin respuesta');
          return http.Response(json.encode(cuerpo), 200);
        });

    final subred = LectorRedService.ipsDeLaSubred('192.168.0.23');

    test('encuentra el lector de este gimnasio y no el del vecino', () async {
      final servicio = LectorRedService(cliente: red(), gymId: 'gym-1');
      final lector = await servicio.barrerSubred(
        ips: subred,
        parar: (l) => l.mine,
      );
      expect(lector?.ip, '192.168.0.57');
      expect(lector?.id, 'AABBCCDDEEFF');
      expect(lector?.baseUrl, 'http://192.168.0.57/api');
    });

    test('sin lector propio en la red devuelve null', () async {
      final servicio = LectorRedService(cliente: red(), gymId: 'gym-3');
      final lector = await servicio.barrerSubred(
        ips: subred,
        parar: (l) => l.mine,
      );
      expect(lector, isNull);
    });

    test('ignora lo que contesta pero no es un lector', () async {
      final servicio = LectorRedService(cliente: red(), gymId: 'gym-1');
      expect(await servicio.consultar('192.168.0.1'), isNull);
    });

    test('buscarTodos devuelve el propio, luego libres, luego ajenos',
        () async {
      final cliente = MockClient((peticion) async {
        final ip = peticion.url.host;
        final gym = peticion.url.queryParameters['gym_id'];
        final cuerpos = {
          '10.0.0.5': {'id': '0000000000A1', 'claimed': true, 'mine': false},
          '10.0.0.6': {'id': '0000000000B2', 'claimed': false, 'mine': false},
          '10.0.0.7': {
            'id': '0000000000C3',
            'claimed': true,
            'mine': gym == 'gym-1',
            'ssid': 'Gym',
          },
        };
        final cuerpo = cuerpos[ip];
        if (cuerpo == null) throw http.ClientException('sin respuesta');
        return http.Response(
            json.encode({'device_id': 'ESP32_RFID_GYMONE', ...cuerpo}), 200);
      });

      final todos = await LectorRedService(cliente: cliente, gymId: 'gym-1')
          .buscarTodos(ips: ['10.0.0.5', '10.0.0.6', '10.0.0.7', '10.0.0.8']);

      expect(todos.map((l) => l.ip), ['10.0.0.7', '10.0.0.6', '10.0.0.5']);
      expect(todos.first.mine, isTrue);
      expect(todos.first.ssid, 'Gym');
      expect(todos.first.nombre, 'GymOne-00C3');
      expect(todos[1].claimed, isFalse);
    });

    test('nombre del lector a partir de su id', () {
      expect(LectorEnRed.nombreDeId('A1B2C3D4E5F6'), 'GymOne-E5F6');
      expect(LectorEnRed.nombreDeId(null), 'Lector GymOne');
    });

    test('reconoce los lectores aún sin actualizar (antes de la v6.4.0)', () {
      for (final idDeLector in ['ESP32_RFID_GYMONE', 'ESP32_RFID_GYMADS']) {
        expect(
          LectorEnRed.desdeDiscover(
              '10.0.0.9', {'device_id': idDeLector, 'id': 'A1B2C3D4E5F6'}),
          isNotNull,
          reason: idDeLector,
        );
      }
      expect(LectorEnRed.desdeDiscover('10.0.0.9', {'device_id': 'OTRO'}),
          isNull);
    });

    test('lee si está en modo configuración', () {
      final l = LectorEnRed.desdeDiscover('10.0.0.9', {
        'device_type': 'RFID_READER',
        'claimed': false,
        'modo_config': true,
        'version': '6.0.0',
      });
      expect(l?.modoConfig, isTrue);
      expect(l?.claimed, isFalse);
      expect(l?.version, '6.0.0');
    });
  });
}

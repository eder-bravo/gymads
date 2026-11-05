import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/data/config/rfid_config.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:gymads/app/modules/configuracion/views/lector_view.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Configuracion extends ConfiguracionController {
  int consultas = 0;
  EstadoLector respuesta = EstadoLector.sinConexion;

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => false;
  @override
  Future<void> cargarEstadoLector() async {}
  @override
  Future<void> comprobarLector(
      {String? ip, bool mostrarProgreso = true}) async {
    consultas++;
    estadoLector.value = respuesta;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String gym;
  late String? Function() gymAnterior;

  setUp(() {
    gymAnterior = RfidConfig.gymIdActual;
    gym = 'gimnasio-prueba-estado';
    RfidConfig.gymIdActual = () => gym;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    RfidConfig.gymIdActual = gymAnterior;
    Get.reset();
  });

  const infoMio = {'claimed': true, 'mine': true, 'modo_config': false};
  http.Response responder(Map<String, dynamic> info) =>
      http.Response(jsonEncode(info), 200);

  test('un fallo transitorio reintenta antes de declarar ausente al lector',
      () async {
    var consultas = 0;
    final info = await http.runWithClient(
      () => RfidConfig.getESP32Info(ip: '192.168.10.104'),
      () => MockClient((r) async {
        expect(r.url.queryParameters['gym_id'], gym);
        if (++consultas == 1) throw http.ClientException('paquete perdido');
        return responder(infoMio);
      }),
    );
    expect(consultas, 2);
    expect(info?['mine'], isTrue);
  });

  test('un lector ajeno que responde no se reintenta ni se marca propio',
      () async {
    final controller = ConfiguracionController();
    var consultas = 0;
    await http.runWithClient(
      () => controller.comprobarLector(ip: '192.168.10.104'),
      () => MockClient((_) async {
        consultas++;
        return responder({'claimed': true, 'mine': false});
      }),
    );
    expect(controller.estadoLector.value, EstadoLector.deOtroGimnasio);
    expect(consultas, 1);
    expect(controller.comprobandoLector.value, isFalse);
  });

  test(
      'el estado de otra cuenta se ignora si la sesión cambia a media consulta',
      () async {
    final controller = ConfiguracionController();
    controller.estadoLector.value = EstadoLector.sinConfigurar;
    await http.runWithClient(
      () => controller.comprobarLector(ip: '192.168.10.104'),
      () => MockClient((_) async {
        gym = 'otro-gimnasio';
        return responder(infoMio);
      }),
    );
    expect(controller.estadoLector.value, EstadoLector.sinConfigurar);
    expect(controller.comprobandoLector.value, isFalse);
  });

  test('las comprobaciones automáticas no acumulan consultas simultáneas',
      () async {
    final controller = ConfiguracionController();
    final pendiente = Completer<http.Response>();
    final iniciada = Completer<void>();
    var consultas = 0;
    await http.runWithClient(() async {
      final primera = controller.comprobarLector(
          ip: '192.168.10.104', mostrarProgreso: false);
      await iniciada.future;
      await controller.comprobarLector(
          ip: '192.168.10.104', mostrarProgreso: false);
      expect(consultas, 1);
      expect(controller.comprobandoLector.value, isFalse);
      pendiente.complete(responder(infoMio));
      await primera;
    },
        () => MockClient((_) {
              consultas++;
              iniciada.complete();
              return pendiente.future;
            }));
    expect(controller.estadoLector.value, EstadoLector.mio);
  });

  testWidgets(
      'el lector reaparece sin pulsar buscar y deja de consultar al salir',
      (tester) async {
    await RfidConfig.guardarLector(const LectorEnRed(ip: '192.168.10.104'));
    final controller =
        Get.put<ConfiguracionController>(_Configuracion()) as _Configuracion;
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.claro,
      home: const LectorView(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tu lector no aparece'), findsOneWidget);
    expect(controller.consultas, 1);

    controller.respuesta = EstadoLector.mio;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text('Lector conectado'), findsOneWidget);
    expect(controller.consultas, 2);

    // Oculta tras otra pantalla: no compite con el asistente Bluetooth.
    unawaited(Get.to<void>(() => const Scaffold(body: Text('Otra pantalla')))!);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(controller.consultas, 2);
    Get.back<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 10));
    expect(controller.consultas, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(controller.consultas, 3);
  });

  testWidgets(
      'al volver a la app se comprueba de inmediato sin esperar al timer',
      (tester) async {
    await RfidConfig.guardarLector(const LectorEnRed(ip: '192.168.10.104'));
    final controller =
        Get.put<ConfiguracionController>(_Configuracion()) as _Configuracion;
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.claro,
      home: const LectorView(),
    ));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(controller.consultas, 1);
    controller.respuesta = EstadoLector.mio;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.consultas, 2);
    expect(find.text('Lector conectado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

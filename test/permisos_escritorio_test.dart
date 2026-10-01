import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/permisos_app.dart';
import 'package:gymads/app/core/utils/telefono_escritorio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('gymone/permisos_escritorio'), null);
  });

  test(
      'Windows no usa permisos Android ni inventa acceso concedido a la cámara',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final solicitud = SolicitudPermisosSistema();
    expect(solicitud.permisos, [PermisoApp.camara]);
    expect(await solicitud.pedirTodos(),
        {PermisoApp.camara: EstadoPermiso.sinDato});
    expect(
        await solicitud.estados(), {PermisoApp.camara: EstadoPermiso.sinDato});
  });

  test('macOS consulta y solicita TCC sin llamar a permission_handler',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final llamadas = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('gymone/permisos_escritorio'), (call) async {
      llamadas.add(call);
      return call.arguments == 'camara' ? 'bloqueado' : 'permitido';
    });
    final solicitud = SolicitudPermisosSistema();
    expect(await solicitud.pedirTodos(), {
      PermisoApp.notificaciones: EstadoPermiso.permitido,
      PermisoApp.camara: EstadoPermiso.bloqueado,
      PermisoApp.bluetooth: EstadoPermiso.permitido,
    });
    expect(llamadas.map((c) => c.method), ['pedir', 'pedir', 'pedir']);
    expect(llamadas.map((c) => c.arguments),
        ['camara', 'bluetooth', 'notificaciones']);
  });

  test('macOS sigue con los demás permisos si la cámara no responde', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final pendiente = Completer<String>();
    final llamadas = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('gymone/permisos_escritorio'), (call) async {
      llamadas.add(call.arguments as String);
      return call.arguments == 'camara' ? pendiente.future : 'permitido';
    });
    final solicitud = SolicitudPermisosSistema(
        tiempoSolicitudEscritorio: const Duration(milliseconds: 20));
    expect(await solicitud.pedirTodos(), {
      PermisoApp.notificaciones: EstadoPermiso.permitido,
      PermisoApp.camara: EstadoPermiso.sinDato,
      PermisoApp.bluetooth: EstadoPermiso.permitido,
    });
    expect(llamadas, ['camara', 'bluetooth', 'notificaciones']);
    pendiente.complete('permitido');
  });

  test('macOS acota la consulta de estados si un canal no responde', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final pendiente = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('gymone/permisos_escritorio'),
            (call) async => call.arguments == 'notificaciones'
                ? pendiente.future
                : 'bloqueado');
    final solicitud = SolicitudPermisosSistema(
        tiempoConsultaEscritorio: const Duration(milliseconds: 20));
    expect(await solicitud.estados(), {
      PermisoApp.notificaciones: EstadoPermiso.sinDato,
      PermisoApp.camara: EstadoPermiso.bloqueado,
      PermisoApp.bluetooth: EstadoPermiso.bloqueado,
    });
    pendiente.complete('permitido');
  });

  test('salir de la pantalla cancela los permisos que faltan por pedir',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final pendiente = Completer<String>();
    final inicio = Completer<void>();
    final llamadas = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('gymone/permisos_escritorio'), (call) async {
      llamadas.add(call.arguments as String);
      if (!inicio.isCompleted) inicio.complete();
      return pendiente.future;
    });
    final solicitud = SolicitudPermisosSistema();
    final respuesta = solicitud.pedirTodos();
    await inicio.future;
    solicitud.cancelar();
    pendiente.complete('permitido');
    await respuesta;
    expect(llamadas, ['camara']);
  });

  test('un error de plugin no oculta el resultado de otros permisos', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('gymone/permisos_escritorio'), (call) async {
      if (call.arguments == 'camara') {
        throw PlatformException(code: 'sin_camara');
      }
      return 'permitido';
    });
    expect(await SolicitudPermisosSistema().pedirTodos(), {
      PermisoApp.notificaciones: EstadoPermiso.permitido,
      PermisoApp.camara: EstadoPermiso.sinDato,
      PermisoApp.bluetooth: EstadoPermiso.permitido,
    });
  });

  test('web no intenta pedir permisos nativos', () {
    expect(permisosDelSistema(ios: false, web: true), isEmpty);
  });

  test('teléfono de escritorio admite México y lada internacional', () {
    expect(telefonoEscritorio('(811) 123-4567'), '+528111234567');
    expect(telefonoEscritorio('+1 415 555 1234'), '+14155551234');
    expect(telefonoEscritorio('abc1234567'), isNull);
    expect(telefonoEscritorio('123'), isNull);
    expect(telefonoEscritorio('1234567890123456'), isNull);
  });
}

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import 'permisos_escritorio.dart';

/// Los permisos de la app, tal como se le presentan a quien la usa.
///
/// Se piden todos juntos, una vez por teléfono, en la pantalla "Permisos de la
/// app" (antes de Inicio), en vez de que cada uno salga suelto cuando alguna
/// pantalla lo necesita.
enum PermisoApp { notificaciones, camara, bluetooth, redLocal }

enum EstadoPermiso {
  permitido,
  denegado,

  /// Negado para siempre: solo se puede activar desde los ajustes del
  /// teléfono.
  bloqueado,

  /// No se pudo saber cómo quedó (la red local de iPhone sin WiFi, por
  /// ejemplo).
  sinDato,
}

/// Los permisos del sistema que forman cada [PermisoApp].
///
/// La red local de iPhone no es de permission_handler (lista vacía): se pide y
/// se consulta con código propio ([estadoRedLocal]). En Android no existe.
/// [sdkAndroid] es null en iPhone.
Map<PermisoApp, List<Permission>> permisosDelSistema({
  required bool ios,
  int? sdkAndroid,
  TargetPlatform? plataforma,
  bool web = false,
}) {
  if (web || plataforma == TargetPlatform.linux) {
    return {};
  }
  if (plataforma == TargetPlatform.macOS) {
    return {
      PermisoApp.notificaciones: const [],
      PermisoApp.camara: const [],
      PermisoApp.bluetooth: const [],
    };
  }
  if (plataforma == TargetPlatform.windows) {
    // La webcam se gestiona en Privacidad. El plugin de permisos devuelve
    // granted sin verificar ese bloqueo, así que se consulta por otra ruta.
    return {PermisoApp.camara: const []};
  }
  return {
    PermisoApp.notificaciones: [Permission.notification],
    PermisoApp.camara: [Permission.camera],
    PermisoApp.bluetooth: ios
        ? [Permission.bluetooth]
        : [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            if (sdkAndroid != null && sdkAndroid <= 30)
              Permission.locationWhenInUse,
          ],
    if (ios) PermisoApp.redLocal: const [],
  };
}

EstadoPermiso estadoDe(PermissionStatus estado) => switch (estado) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional =>
        EstadoPermiso.permitido,
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted =>
        EstadoPermiso.bloqueado,
      PermissionStatus.denied => EstadoPermiso.denegado,
    };

/// La respuesta de la comprobación de red local de iOS (AppDelegate.swift,
/// `PermisoRedLocal`): true concedido, false negado, null sin saber.
///
/// Negada queda como bloqueada: iOS no vuelve a mostrar su aviso, solo se
/// cambia en Ajustes.
EstadoPermiso estadoRedLocal(bool? concedido) => switch (concedido) {
      true => EstadoPermiso.permitido,
      false => EstadoPermiso.bloqueado,
      null => EstadoPermiso.sinDato,
    };

/// El estado de un permiso que se compone de varios del sistema: el peor.
EstadoPermiso peorEstado(Iterable<EstadoPermiso> estados) {
  const orden = [
    EstadoPermiso.bloqueado,
    EstadoPermiso.denegado,
    EstadoPermiso.sinDato,
    EstadoPermiso.permitido,
  ];
  for (final estado in orden) {
    if (estados.contains(estado)) return estado;
  }
  return EstadoPermiso.permitido;
}

/// Consultar y pedir los permisos. Interfaz para poder probar la pantalla sin
/// el teléfono.
abstract class SolicitudPermisos {
  /// Los que aplican en este teléfono, en el orden en que se muestran.
  List<PermisoApp> get permisos;

  Future<Map<PermisoApp, EstadoPermiso>> estados();

  /// Pide todos. El sistema muestra sus avisos uno tras otro; los que ya se
  /// contestaron no vuelven a salir.
  Future<Map<PermisoApp, EstadoPermiso>> pedirTodos();

  /// Deja de pedir los permisos restantes si se abandona la pantalla.
  /// Un aviso que ya abrió el sistema se contesta en el propio sistema.
  void cancelar();

  Future<void> abrirAjustes();
}

class SolicitudPermisosSistema implements SolicitudPermisos {
  SolicitudPermisosSistema({
    this.tiempoSolicitudEscritorio = const Duration(seconds: 50),
    this.tiempoConsultaEscritorio = const Duration(seconds: 8),
  });

  final Duration tiempoSolicitudEscritorio;
  final Duration tiempoConsultaEscritorio;
  final bool _ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  int? _sdk;
  int _solicitud = 0;

  static const _canalRedLocal = MethodChannel('gymone/red_local');

  /// iOS no tiene cómo consultar la red local: `PermisoRedLocal` (en
  /// AppDelegate.swift) lo intenta, y la primera vez eso hace salir el aviso.
  Future<EstadoPermiso> _redLocal() async {
    try {
      return estadoRedLocal(
          await _canalRedLocal.invokeMethod<bool>('comprobar'));
    } catch (e) {
      AppLogger.warning('PermisosApp', 'No se pudo comprobar la red local: $e');
      return EstadoPermiso.sinDato;
    }
  }

  Future<int?> _sdkAndroid() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    return _sdk ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  }

  Future<Map<PermisoApp, List<Permission>>> _mapa() async => permisosDelSistema(
      ios: _ios,
      sdkAndroid: await _sdkAndroid(),
      plataforma: defaultTargetPlatform,
      web: kIsWeb);

  @override
  List<PermisoApp> get permisos => permisosDelSistema(
          ios: _ios, plataforma: defaultTargetPlatform, web: kIsWeb)
      .keys
      .toList();

  Future<EstadoPermiso> _nativo(PermisoApp permiso,
      {bool pedir = false}) async {
    if (_ios) return _redLocal();
    // permission_handler_windows responde granted para cualquier permiso,
    // aunque Privacidad bloquee la webcam: no presentarlo como confirmado.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return EstadoPermiso.sinDato;
    }
    try {
      final respuesta = await PermisosEscritorio.consultar(permiso.name,
          pedir: pedir,
          tiempoLimite:
              pedir ? tiempoSolicitudEscritorio : tiempoConsultaEscritorio);
      return EstadoPermiso.values.firstWhere((e) => e.name == respuesta,
          orElse: () => EstadoPermiso.sinDato);
    } catch (e) {
      AppLogger.warning(
          'PermisosApp', 'No se pudo consultar ${permiso.name}: $e');
      return EstadoPermiso.sinDato;
    }
  }

  @override
  Future<Map<PermisoApp, EstadoPermiso>> estados() async {
    final mapa = await _mapa();
    return {
      for (final entrada in mapa.entries)
        entrada.key: entrada.value.isEmpty
            ? await _nativo(entrada.key)
            : peorEstado([
                for (final permiso in entrada.value)
                  estadoDe(await permiso.status),
              ]),
    };
  }

  @override
  Future<Map<PermisoApp, EstadoPermiso>> pedirTodos() async {
    final solicitud = ++_solicitud;
    final mapa = await _mapa();
    if (solicitud != _solicitud) return {};
    var respuestas = <Permission, PermissionStatus>{};
    try {
      final nativos = [for (final l in mapa.values) ...l];
      if (nativos.isNotEmpty) respuestas = await nativos.request();
    } catch (e) {
      AppLogger.error('PermisosApp', 'No se pudieron pedir los permisos', e);
    }

    final entradas = mapa.entries.toList();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      // El aviso de notificaciones puede quedarse pendiente fuera de la app.
      // Solicitar primero los permisos con diálogo de cámara y Bluetooth.
      const orden = [
        PermisoApp.camara,
        PermisoApp.bluetooth,
        PermisoApp.notificaciones,
      ];
      entradas
          .sort((a, b) => orden.indexOf(a.key).compareTo(orden.indexOf(b.key)));
    }
    final estados = <PermisoApp, EstadoPermiso>{
      for (final permiso in mapa.keys) permiso: EstadoPermiso.sinDato,
    };
    // La red local de iPhone permanece al final. Cada espera de escritorio
    // tiene su límite; una respuesta pendiente no impide pedir las siguientes.
    for (final entrada in entradas) {
      if (solicitud != _solicitud) break;
      estados[entrada.key] = entrada.value.isEmpty
          ? await _nativo(entrada.key, pedir: true)
          : peorEstado([
              for (final permiso in entrada.value)
                estadoDe(respuestas[permiso] ?? await permiso.status),
            ]);
    }
    return estados;
  }

  @override
  void cancelar() => _solicitud++;

  @override
  Future<void> abrirAjustes() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      await PermisosEscritorio.abrirAjustes();
    } else {
      await openAppSettings();
    }
  }
}

/// Si en este teléfono ya se pidieron los permisos.
///
/// Se guarda en el teléfono: los permisos son del teléfono, no de la persona.
/// Si entra otra cuenta en el mismo teléfono, ya están contestados.
class PermisosApp {
  PermisosApp._();

  /// Con otra versión (si algún día se agrega un permiso) se vuelve a mostrar
  /// la pantalla una vez.
  static String get _clave => !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows)
      ? 'permisos_escritorio_v2'
      : 'permisos_pedidos_v1';

  static bool _pedidos = false;
  static Completer<void> _listos = Completer<void>();

  /// Lee de disco si ya se pidieron. Se llama en `main` antes de `runApp`,
  /// para que [yaSePidieron] responda sin esperar (lo usa el middleware de
  /// Inicio).
  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _pedidos = prefs.getBool(_clave) ?? false;
    if (_pedidos && !_listos.isCompleted) _listos.complete();
  }

  static bool get yaSePidieron => _pedidos;

  /// Se completa cuando ya se pidieron. Lo esperan quienes provocarían un
  /// aviso del sistema por su cuenta (el lector, al arrancar): si no, saldría
  /// suelto, encima de la pantalla de permisos.
  static Future<void> get listos => _listos.future;

  /// Tras "Permitir" o "Ahora no": no se vuelve a mostrar la pantalla sola.
  static Future<void> marcarPedidos() async {
    _pedidos = true;
    if (!_listos.isCompleted) _listos.complete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, true);
  }

  @visibleForTesting
  static void reiniciarParaPruebas() {
    _pedidos = false;
    _listos = Completer<void>();
  }
}

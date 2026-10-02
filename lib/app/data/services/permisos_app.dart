import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';

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
}) =>
    {
      PermisoApp.notificaciones: [Permission.notification],
      PermisoApp.camara: [Permission.camera],
      PermisoApp.bluetooth: ios
          ? [Permission.bluetooth]
          : [
              Permission.bluetoothScan,
              Permission.bluetoothConnect,
              // Hasta Android 11, buscar por Bluetooth exige la ubicación.
              if (sdkAndroid != null && sdkAndroid <= 30)
                Permission.locationWhenInUse,
            ],
      if (ios) PermisoApp.redLocal: const [],
    };

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

  Future<void> abrirAjustes();
}

class SolicitudPermisosSistema implements SolicitudPermisos {
  final bool _ios = !kIsWeb && Platform.isIOS;
  int? _sdk;

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
    if (kIsWeb || !Platform.isAndroid) return null;
    return _sdk ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  }

  Future<Map<PermisoApp, List<Permission>>> _mapa() async =>
      permisosDelSistema(ios: _ios, sdkAndroid: await _sdkAndroid());

  @override
  List<PermisoApp> get permisos => [
        PermisoApp.notificaciones,
        PermisoApp.camara,
        PermisoApp.bluetooth,
        if (_ios) PermisoApp.redLocal,
      ];

  @override
  Future<Map<PermisoApp, EstadoPermiso>> estados() async {
    final mapa = await _mapa();
    return {
      for (final entrada in mapa.entries)
        entrada.key: entrada.value.isEmpty
            ? await _redLocal()
            : peorEstado([
                for (final permiso in entrada.value)
                  estadoDe(await permiso.status),
              ]),
    };
  }

  @override
  Future<Map<PermisoApp, EstadoPermiso>> pedirTodos() async {
    final mapa = await _mapa();
    var respuestas = <Permission, PermissionStatus>{};
    try {
      respuestas = await [for (final l in mapa.values) ...l].request();
    } catch (e) {
      AppLogger.error('PermisosApp', 'No se pudieron pedir los permisos', e);
    }

    // La red local (iPhone) al final: comprobarla hace salir su aviso ahora,
    // junto a los demás, y no la primera vez que la app le hable al lector.
    return {
      for (final entrada in mapa.entries)
        entrada.key: entrada.value.isEmpty
            ? await _redLocal()
            : peorEstado([
                for (final permiso in entrada.value)
                  estadoDe(respuestas[permiso] ?? await permiso.status),
              ]),
    };
  }

  @override
  Future<void> abrirAjustes() => openAppSettings();
}

/// Si en este teléfono ya se pidieron los permisos.
///
/// Se guarda en el teléfono: los permisos son del teléfono, no de la persona.
/// Si entra otra cuenta en el mismo teléfono, ya están contestados.
class PermisosApp {
  PermisosApp._();

  /// Con otra versión (si algún día se agrega un permiso) se vuelve a mostrar
  /// la pantalla una vez.
  static const _clave = 'permisos_pedidos_v1';

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EventoBusquedaLector {
  inicio,
  escaneoIniciado,
  encontrados,
  fallo,
  sinLectores,
  cancelada,
  completada,
  reintento,
  limiteFrecuencia,
}

/// Historial local limitado. Nunca guarda anuncios, identificadores de lectores,
/// mensajes de excepciones, redes, tarjetas ni credenciales.
class RegistroBusquedaLector {
  RegistroBusquedaLector({
    Future<Map<String, Object?>> Function()? obtenerMetadatos,
    Future<SharedPreferences> Function()? obtenerPreferencias,
    DateTime Function()? ahora,
  })  : _obtenerMetadatos = obtenerMetadatos ?? _metadatosSistema,
        _obtenerPreferencias =
            obtenerPreferencias ?? SharedPreferences.getInstance,
        _ahora = ahora ?? DateTime.now;

  static final instance = RegistroBusquedaLector();
  static const claveAlmacenamiento = 'diagnostico_busqueda_lector_v1';
  static const maxEventos = 60;

  static const _categorias = {
    'ubicacion',
    'permisoUbicacion',
    'permisoBluetooth',
    'bluetoothApagado',
    'bluetoothNoListo',
    'inicioFallido',
    'interno',
    'demasiadosIntentos',
    'sinCompatibilidad',
    'desconocido',
  };

  final Future<Map<String, Object?>> Function() _obtenerMetadatos;
  final Future<SharedPreferences> Function() _obtenerPreferencias;
  final DateTime Function() _ahora;
  final _eventos = <Map<String, Object?>>[];
  Map<String, Object?> _dispositivo = {};
  SharedPreferences? _preferencias;
  bool _cargado = false;
  Future<void> _cola = Future<void>.value();

  /// La búsqueda puede llamarlo con `unawaited`: exportar espera la cola antes
  /// de generar el diagnóstico. Categorías ajenas se sustituyen por desconocido.
  Future<void> registrar(
    EventoBusquedaLector evento, {
    String? categoria,
    int? codigo,
    int? lectores,
    int? milisegundos,
  }) {
    final entrada = <String, Object?>{
      'fecha': _ahora().toUtc().toIso8601String(),
      'evento': evento.name,
      if (categoria != null)
        'categoria':
            _categorias.contains(categoria) ? categoria : 'desconocido',
      if (codigo != null) 'codigo': codigo,
      if (lectores != null && lectores >= 0) 'lectores': lectores,
      if (milisegundos != null && milisegundos >= 0)
        'milisegundos': milisegundos,
    };
    return _encolar(() async {
      await _cargar();
      _eventos.add(entrada);
      _limitar();
      await _guardar();
    });
  }

  Future<String> exportar() async {
    var salida = '{"version":1,"dispositivo":{},"eventos":[]}';
    await _encolar(() async {
      await _cargar();
      salida = const JsonEncoder.withIndent('  ').convert(_documento);
    });
    return salida;
  }

  Map<String, Object?> get _documento => {
        'version': 1,
        'dispositivo': _dispositivo,
        'eventos': _eventos,
      };

  Future<void> _encolar(Future<void> Function() accion) {
    // Cada operación parte del resultado de la anterior, incluidas las lecturas.
    // Un fallo del almacenamiento no interrumpe la configuración del lector.
    final siguiente = _cola.then((_) async {
      try {
        await accion();
      } catch (_) {
        // El registro es auxiliar; mantenemos lo disponible en memoria.
      }
    });
    _cola = siguiente;
    return siguiente;
  }

  Future<void> _cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      _preferencias =
          await _obtenerPreferencias().timeout(const Duration(seconds: 2));
      final guardado = _preferencias!.getString(claveAlmacenamiento);
      if (guardado != null) _restaurar(guardado);
    } catch (_) {
      // Puede no existir el plugin en esta plataforma o fallar el disco.
    }
    try {
      final metadatos =
          await _obtenerMetadatos().timeout(const Duration(seconds: 2));
      final permitidos = _sanearMetadatos(metadatos);
      if (permitidos.isNotEmpty) _dispositivo = permitidos;
    } catch (_) {
      // El historial sigue siendo útil aunque no haya datos del teléfono.
    }
  }

  void _restaurar(String guardado) {
    final datos = jsonDecode(guardado);
    if (datos is! Map || datos['version'] != 1) return;
    final dispositivo = datos['dispositivo'];
    if (dispositivo is Map) _dispositivo = _sanearMetadatos(dispositivo);
    final eventos = datos['eventos'];
    if (eventos is! List) return;
    for (final evento in eventos) {
      if (evento is! Map) continue;
      if (!EventoBusquedaLector.values
          .any((permitido) => permitido.name == evento['evento'])) {
        continue;
      }
      final fecha = evento['fecha'];
      final instante = fecha is String ? DateTime.tryParse(fecha) : null;
      if (instante == null) continue;
      final categoria = evento['categoria'];
      final codigo = evento['codigo'];
      final lectores = evento['lectores'];
      final milisegundos = evento['milisegundos'];
      _eventos.add({
        'fecha': instante.toUtc().toIso8601String(),
        'evento': evento['evento'] as String,
        if (categoria != null)
          'categoria':
              _categorias.contains(categoria) ? categoria : 'desconocido',
        if (codigo is int) 'codigo': codigo,
        if (lectores is int && lectores >= 0) 'lectores': lectores,
        if (milisegundos is int && milisegundos >= 0)
          'milisegundos': milisegundos,
      });
    }
    _limitar();
  }

  void _limitar() {
    if (_eventos.length > maxEventos) {
      _eventos.removeRange(0, _eventos.length - maxEventos);
    }
  }

  Future<void> _guardar() async {
    await _preferencias?.setString(claveAlmacenamiento, jsonEncode(_documento));
  }

  static Map<String, Object?> _sanearMetadatos(Map datos) {
    final salida = <String, Object?>{};
    final plataforma = datos['plataforma'];
    if (const {'android', 'ios', 'otro'}.contains(plataforma)) {
      salida['plataforma'] = plataforma;
    }
    for (final clave in const ['fabricante', 'modelo', 'version']) {
      final valor = datos[clave];
      if (valor is String && valor.isNotEmpty) {
        salida[clave] = valor.length <= 100 ? valor : valor.substring(0, 100);
      }
    }
    final sdk = datos['sdk'];
    if (sdk is int && sdk > 0) salida['sdk'] = sdk;
    return salida;
  }

  static Future<Map<String, Object?>> _metadatosSistema() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return {
        'plataforma': 'android',
        'fabricante': android.manufacturer,
        'modelo': android.model,
        'version': android.version.release,
        'sdk': android.version.sdkInt,
      };
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return {
        'plataforma': 'ios',
        'fabricante': 'Apple',
        'modelo': ios.model,
        'version': ios.systemVersion,
      };
    }
    return {'plataforma': 'otro'};
  }
}

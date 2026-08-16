import 'package:flutter/foundation.dart';

/// Logger central de la aplicación.
///
/// Reglas de uso:
/// - **Nunca** registrar datos sensibles: correos, teléfonos, nombres de
///   clientes, identificadores de usuario/gimnasio/sucursal, códigos RFID,
///   tokens ni sesiones. Los mensajes deben describir *qué* ocurrió, no
///   *con qué datos*.
/// - Los mensajes son texto plano, sin emojis ni decoración.
/// - Nada se emite en compilaciones de producción: todas las salidas están
///   condicionadas a [kDebugMode].
class AppLogger {
  AppLogger._();

  /// Traza informativa del flujo normal de la aplicación.
  static void info(String tag, String message) {
    _emit('INFO', tag, message);
  }

  /// Situación inesperada de la que la aplicación se recupera.
  static void warning(String tag, String message) {
    _emit('WARN', tag, message);
  }

  /// Fallo de una operación. [error] se registra solo por su tipo para evitar
  /// filtrar datos contenidos en el mensaje de la excepción.
  static void error(String tag, String message, [Object? error]) {
    final detail = error == null ? message : '$message (${error.runtimeType})';
    _emit('ERROR', tag, detail);
  }

  static void _emit(String level, String tag, String message) {
    if (!kDebugMode) return;
    debugPrint('[$level] $tag: $message');
  }
}

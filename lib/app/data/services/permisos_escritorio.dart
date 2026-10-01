import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class PermisosEscritorio {
  static const _canal = MethodChannel('gymone/permisos_escritorio');

  /// macOS usa TCC; permission_handler de esta rama no implementa macOS.
  static Future<String> consultar(String permiso,
          {bool pedir = false, Duration? tiempoLimite}) async =>
      await _canal
          .invokeMethod<String>(pedir ? 'pedir' : 'estado', permiso)
          .timeout(tiempoLimite ??
              (pedir
                  ? const Duration(seconds: 50)
                  : const Duration(seconds: 8))) ??
      'sinDato';

  static Future<void> abrirAjustes() async {
    final uri = defaultTargetPlatform == TargetPlatform.windows
        ? Uri.parse('ms-settings:privacy-webcam')
        : Uri.parse(
            'x-apple.systempreferences:com.apple.preference.security?Privacy_Camera');
    await launchUrl(uri);
  }
}

import 'package:flutter/services.dart';

/// Consulta a Android si el dispositivo puede usar el selector nativo de
/// cuentas de Google. En equipos Huawei sin GMS devuelve `false` y la app usa
/// el flujo OAuth por navegador.
abstract final class GooglePlayServices {
  static const _channel = MethodChannel('com.gymone/google_play_services');

  static Future<bool> get disponibles async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      // Si Android no puede comprobarlo, el navegador es la ruta segura.
      return false;
    }
  }
}

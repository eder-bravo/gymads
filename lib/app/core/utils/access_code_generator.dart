import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Generación y hashing de los códigos de acceso del personal.
///
/// El código se genera SIEMPRE en el dispositivo y nunca viaja al servidor:
/// a Supabase solo se envía su hash SHA-256. Por eso un código perdido no se
/// puede recuperar, solo regenerar.
class AccessCodeGenerator {
  AccessCodeGenerator._();

  /// Alfabeto sin caracteres ambiguos: fuera I, O, 0 y 1.
  /// El código se dicta por teléfono o se manda por WhatsApp, así que
  /// confundir un 0 con una O es un fallo real de soporte.
  static const String _alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Largo del código sin separador. 32^8 ≈ 1.1 billones de combinaciones.
  static const int _largo = 8;

  static final Random _random = Random.secure();

  /// Genera un código nuevo con formato `XXXX-XXXX`.
  static String generar() {
    final chars = List<String>.generate(
      _largo,
      (_) => _alfabeto[_random.nextInt(_alfabeto.length)],
    );
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4).join()}';
  }

  /// Deja el código en su forma canónica: mayúsculas y solo [A-Z0-9].
  ///
  /// Así da igual que el empleado escriba el guion, lo omita, use minúsculas
  /// o pegue el código con espacios alrededor.
  static String normalizar(String codigo) {
    return codigo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// SHA-256 en hex del código normalizado. Es lo único que se guarda.
  static String hash(String codigo) {
    return sha256.convert(utf8.encode(normalizar(codigo))).toString();
  }

  /// Valida la forma del código antes de gastar una llamada al servidor.
  static bool esFormatoValido(String codigo) {
    final limpio = normalizar(codigo);
    if (limpio.length != _largo) return false;
    return limpio.split('').every(_alfabeto.contains);
  }

  /// Presenta un código ya normalizado como `XXXX-XXXX`.
  static String formatear(String codigo) {
    final limpio = normalizar(codigo);
    if (limpio.length != _largo) return limpio;
    return '${limpio.substring(0, 4)}-${limpio.substring(4)}';
  }
}

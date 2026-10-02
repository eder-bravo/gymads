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

  /// Cuántos caracteres tiene el código, sin contar el separador.
  static int get largo => _largo;

  /// Da forma a un código a medio escribir, para el campo de entrada.
  ///
  /// A diferencia de [formatear], acepta cualquier longitud: recorta lo que
  /// sobre de [largo] y pone el guion en su sitio. El separador aparece solo
  /// a partir del quinto carácter, nunca colgando al final de los cuatro
  /// primeros: si se pusiera antes, al borrar se regeneraría solo y la tecla
  /// de retroceso parecería no hacer nada.
  ///
  /// Si lo que llega no es un código limpio sino un texto más largo —lo
  /// típico es que el empleado no copie solo el código, sino todo el mensaje
  /// de WhatsApp que arma `codigo_generado_dialog.dart` ("Hola María, este es
  /// tu código para entrar a...")—, tomar a ciegas los primeros 8 caracteres
  /// válidos saldría de la prosa, no del código. Antes de recortar así, se
  /// busca el código de verdad dentro del texto con [_buscarIncrustado].
  static String formatearParcial(String codigo) {
    final limpio = normalizar(codigo);
    final acotado =
        limpio.length > _largo ? limpio.substring(0, _largo) : limpio;

    // El recorte a ciegas solo es sospechoso cuando llegó más de lo que
    // cabe: mientras se escribe carácter a carácter nunca se pasa de 8, así
    // que este camino no se toca para nada de lo que ya funcionaba.
    if (limpio.length > _largo && !acotado.split('').every(_alfabeto.contains)) {
      final incrustado = _buscarIncrustado(codigo);
      if (incrustado != null) return formatear(incrustado);
    }

    if (acotado.length <= 4) return acotado;
    return '${acotado.substring(0, 4)}-${acotado.substring(4)}';
  }

  /// Busca un código de verdad dentro de un texto más largo.
  ///
  /// Recorre las "palabras" del texto —tandas de letras, dígitos y guiones,
  /// cortadas por espacios, saltos de línea o puntuación— y se queda con la
  /// primera que, ya normalizada, tiene exactamente 8 caracteres y ninguno
  /// fuera del alfabeto del código. Una palabra de la prosa rara vez cae en
  /// esa forma exacta: basta con que tenga una I, una O, un 0 o un 1 —muy
  /// comunes en español— para quedar descartada.
  static String? _buscarIncrustado(String texto) {
    for (final match in RegExp(r'[A-Za-z0-9-]+').allMatches(texto)) {
      final palabra = normalizar(match.group(0)!);
      if (palabra.length == _largo && palabra.split('').every(_alfabeto.contains)) {
        return palabra;
      }
    }
    return null;
  }
}

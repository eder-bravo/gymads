import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los lectores HID (USB, Bluetooth o con receptor USB) escriben como un
/// teclado: el código y una tecla final.
///
/// No hay nada que configurar: se acepta Enter (también el del teclado
/// numérico) o Tab, que son las que traen los lectores. Antes había que
/// elegirla, junto con letras de más que quitar al inicio o al final del
/// código, y nadie sabía para qué era.
abstract final class EscanerFisicoService {
  /// ¿Esta tecla cierra una lectura?
  static bool esFinDeLectura(LogicalKeyboardKey tecla) =>
      tecla == LogicalKeyboardKey.enter ||
      tecla == LogicalKeyboardKey.numpadEnter ||
      tecla == LogicalKeyboardKey.tab;

  /// El código de una lectura, o null si no parece uno: vacío, demasiado
  /// largo o con caracteres de control. Se conservan los ceros a la
  /// izquierda.
  static String? codigoDe(String entrada) {
    final codigo = entrada.trim();
    if (codigo.isEmpty ||
        codigo.length > 256 ||
        codigo.runes.any((c) => c < 32 || c == 127)) {
      return null;
    }
    return codigo;
  }

  /// Borra los ajustes que guardaban las versiones anteriores (tecla final,
  /// prefijo y sufijo): ya no se usan y no deben quedar ocultos.
  static Future<void> olvidarAjustesViejos() async {
    final prefs = await SharedPreferences.getInstance();
    for (final clave in const [
      'escaner_terminador',
      'escaner_prefijo',
      'escaner_sufijo',
    ]) {
      await prefs.remove(clave);
    }
  }
}

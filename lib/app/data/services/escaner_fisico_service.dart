import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TerminadorEscaner { enter, tab }

/// Los lectores HID USB, Bluetooth y con receptor USB escriben como teclado.
class ConfiguracionEscaner {
  const ConfiguracionEscaner(
      {this.terminador = TerminadorEscaner.enter,
      this.prefijo = '',
      this.sufijo = ''});
  final TerminadorEscaner terminador;
  final String prefijo;
  final String sufijo;
  LogicalKeyboardKey get teclaFinal => terminador == TerminadorEscaner.enter
      ? LogicalKeyboardKey.enter
      : LogicalKeyboardKey.tab;

  String? interpretar(String entrada) {
    if (!entrada.startsWith(prefijo) || !entrada.endsWith(sufijo)) return null;
    if (entrada.length < prefijo.length + sufijo.length) return null;
    final codigo = entrada
        .substring(prefijo.length, entrada.length - sufijo.length)
        .trim();
    if (codigo.isEmpty ||
        codigo.length > 256 ||
        codigo.runes.any((c) => c < 32 || c == 127)) {
      return null;
    }
    return codigo;
  }
}

class EscanerFisicoService {
  static final configuracion = ValueNotifier(const ConfiguracionEscaner());
  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    configuracion.value = ConfiguracionEscaner(
        terminador: prefs.getString('escaner_terminador') == 'tab'
            ? TerminadorEscaner.tab
            : TerminadorEscaner.enter,
        prefijo: prefs.getString('escaner_prefijo') ?? '',
        sufijo: prefs.getString('escaner_sufijo') ?? '');
  }

  static Future<void> guardar(ConfiguracionEscaner valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('escaner_terminador', valor.terminador.name);
    await prefs.setString('escaner_prefijo', valor.prefijo);
    await prefs.setString('escaner_sufijo', valor.sufijo);
    configuracion.value = valor;
  }
}

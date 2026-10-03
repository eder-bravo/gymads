import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

abstract final class PlataformaApp {
  static bool get escritorio =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  static bool get escanerFisico => kIsWeb || escritorio;

  /// iPad o tableta Android de 720 puntos o más por su lado corto. Las
  /// tabletas chicas (7–8") y los teléfonos conservan el diseño del teléfono.
  static bool get tableta {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      final vistas = WidgetsBinding.instance.platformDispatcher.views;
      if (vistas.isEmpty) return false;
      final vista = vistas.first;
      return (vista.physicalSize / vista.devicePixelRatio).shortestSide >= 720;
    } catch (_) {
      // Antes de iniciar Flutter (un tema armado de antemano) no hay pantalla
      // que medir: se toma como teléfono.
      return false;
    }
  }

  /// Escritorio o tableta: el diseño de pantalla grande (anchos de lectura,
  /// ventanas modales, acciones con texto, letra mínima). Lo propio del mouse
  /// y del teclado (hover, atajos, "Haz clic") se queda en [escritorio].
  static bool get pantallaGrande => escritorio || tableta;

  /// Cómo se nombra en los textos el aparato que corre la app: "este
  /// teléfono" en el celular y "este equipo" en la computadora. Masculino en
  /// los dos casos, así que "el/este/del ___" no cambia.
  static String get equipo =>
      escritorio ? 'equipo' : (tableta ? 'dispositivo' : 'teléfono');

  /// "Toca" en pantallas táctiles, "Haz clic en" con mouse.
  static String get toca => escritorio ? 'Haz clic en' : 'Toca';

  /// Un valor para pantalla grande (escritorio y tableta) y otro para el
  /// teléfono, que conserva el suyo.
  static T elegir<T>({required T escritorio, required T movil}) =>
      pantallaGrande ? escritorio : movil;
  static bool get ocrMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

/// Un importe para mostrar. En pantalla grande con separador de miles
/// ("\$1,234.50"); en el teléfono, igual que siempre ("\$1234.50").
String dinero(double monto) => PlataformaApp.pantallaGrande
    ? NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2)
        .format(monto)
    : '\$${monto.toStringAsFixed(2)}';

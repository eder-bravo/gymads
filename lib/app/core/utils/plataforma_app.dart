import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

abstract final class PlataformaApp {
  static bool get escritorio =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  static bool get escanerFisico => kIsWeb || escritorio;

  /// Cómo se nombra en los textos el aparato que corre la app: "este
  /// teléfono" en el celular y "este equipo" en la computadora. Masculino en
  /// los dos casos, así que "el/este/del ___" no cambia.
  static String get equipo => escritorio ? 'equipo' : 'teléfono';

  /// "Toca" en pantallas táctiles, "Haz clic en" con mouse.
  static String get toca => escritorio ? 'Haz clic en' : 'Toca';

  /// Un valor para escritorio y otro para el teléfono. Para correcciones que
  /// solo deben verse en macOS/Windows: el teléfono conserva el suyo.
  static T elegir<T>({required T escritorio, required T movil}) =>
      PlataformaApp.escritorio ? escritorio : movil;
  static bool get ocrMovil =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

/// Un importe para mostrar. En escritorio con separador de miles
/// ("\$1,234.50"); en el teléfono, igual que siempre ("\$1234.50").
String dinero(double monto) => PlataformaApp.escritorio
    ? NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2)
        .format(monto)
    : '\$${monto.toStringAsFixed(2)}';

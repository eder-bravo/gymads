import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;

/// Localizaciones en español con el reloj en 12 horas (a.m. / p.m.).
///
/// El formato de hora del selector de Material lo decide el idioma, no un
/// ajuste: `MaterialLocalizationEs` declara `timeOfDayFormatRaw` como
/// `H_colon_mm`, es decir 24 horas. Y `alwaysUse24HourFormat: false` no lo
/// cambia, porque ese parámetro solo sirve para *forzar* 24 horas; en false
/// devuelve el formato del idioma. Comprobado: tanto `es` como `es_MX` dan 24 h.
///
/// La salida fácil sería cargar el locale inglés, pero entonces el reloj
/// diría "Cancel", "OK" y "Select time". Así que se hereda de la clase en
/// español y se cambia solo el formato: los textos siguen todos en español y
/// el selector conserva la entrada exacta de hora y minutos.
class MaterialLocalizations12h extends MaterialLocalizationEs {
  const MaterialLocalizations12h({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  TimeOfDayFormat get timeOfDayFormatRaw => TimeOfDayFormat.h_colon_mm_space_a;

  // El español de España escribe "a. m." con espacio; en México va sin él, y
  // es la forma que usa el resto de la app (ver HoraFormato). Sin esto el
  // reloj diría "6:00 a. m." y la etiqueta de al lado "6:00 a.m.".
  @override
  String get anteMeridiemAbbreviation => 'a.m.';

  @override
  String get postMeridiemAbbreviation => 'p.m.';

  /// Se registra ANTES de `GlobalMaterialLocalizations.delegate`: Flutter usa
  /// el primero que declare soportar el idioma.
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _Delegate();
}

class _Delegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _Delegate();

  /// Solo el español. El resto de idiomas siguen con el delegado normal.
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'es';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final localeName = intl.Intl.canonicalizedLocale(locale.toString());

    // Mismos formatos que construye el delegado de Flutter; solo se replica
    // su preparación para poder inyectar la subclase.
    return initializeDateFormatting(localeName, null).then((_) {
      final existe = intl.DateFormat.localeExists(localeName);
      final nombre = existe ? localeName : 'es';

      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizations12h(
          fullYearFormat: intl.DateFormat.y(nombre),
          compactDateFormat: intl.DateFormat.yMd(nombre),
          shortDateFormat: intl.DateFormat.yMMMd(nombre),
          mediumDateFormat: intl.DateFormat.MMMEd(nombre),
          longDateFormat: intl.DateFormat.yMMMMEEEEd(nombre),
          yearMonthFormat: intl.DateFormat.yMMMM(nombre),
          shortMonthDayFormat: intl.DateFormat.MMMd(nombre),
          decimalFormat: intl.NumberFormat.decimalPattern(nombre),
          twoDigitZeroPaddedFormat: intl.NumberFormat('00', nombre),
        ),
      );
    });
  }

  @override
  bool shouldReload(_Delegate old) => false;
}

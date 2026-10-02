import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/material_localizations_12h.dart';

/// Los delegados en el mismo orden que main.dart.
const _delegates = [
  MaterialLocalizations12h.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<MaterialLocalizations> _cargar(WidgetTester tester, Locale locale) async {
  late MaterialLocalizations l;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: _delegates,
    supportedLocales: const [Locale('es'), Locale('en')],
    home: Builder(builder: (context) {
      l = MaterialLocalizations.of(context);
      return const SizedBox();
    }),
  ));
  await tester.pumpAndSettle();
  return l;
}

void main() {
  testWidgets('en español el reloj queda en 12 h con a.m./p.m.', (tester) async {
    final l = await _cargar(tester, const Locale('es'));
    expect(l.timeOfDayFormat(), TimeOfDayFormat.h_colon_mm_space_a);
  });

  testWidgets('los textos siguen en español y el sufijo va sin espacio',
      (tester) async {
    final l = await _cargar(tester, const Locale('es'));
    expect(l.cancelButtonLabel, 'Cancelar');
    expect(l.okButtonLabel, 'ACEPTAR');
    expect(l.timePickerDialHelpText, 'Seleccionar hora');
    expect(l.anteMeridiemAbbreviation, 'a.m.');
    expect(l.postMeridiemAbbreviation, 'p.m.');
  });

  testWidgets('forzar 24 h sigue funcionando si el sistema lo pide',
      (tester) async {
    final l = await _cargar(tester, const Locale('es'));
    expect(l.timeOfDayFormat(alwaysUse24HourFormat: true),
        TimeOfDayFormat.HH_colon_mm);
  });

  testWidgets('el inglés no se toca', (tester) async {
    final l = await _cargar(tester, const Locale('en'));
    expect(l.cancelButtonLabel, 'Cancel');
    expect(l.timeOfDayFormat(), TimeOfDayFormat.h_colon_mm_space_a);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/material_localizations_12h.dart';

/// Abre el selector de Material igual que lo hace la app y comprueba lo que
/// realmente se pinta: el problema anterior era que salía en 24 h.
void main() {
  testWidgets('el reloj de Material muestra a.m./p.m. en español',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [
        MaterialLocalizations12h.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 18, minute: 30),
            helpText: 'Selecciona la hora',
          ),
          child: const Text('abrir'),
        ),
      ),
    ));

    // Las localizaciones se cargan de forma asíncrona (igual que en el
    // delegado de Flutter), así que hay que asentar el primer frame.
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Los selectores de a.m./p.m. solo existen en el reloj de 12 horas.
    expect(find.text('a.m.'), findsOneWidget);
    expect(find.text('p.m.'), findsOneWidget);

    // Las 18:30 se muestran como 6:30, no como 18:30.
    expect(find.text('6'), findsOneWidget);
    expect(find.text('18'), findsNothing);

    // Y sigue en español.
    expect(find.text('Selecciona la hora'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });
}

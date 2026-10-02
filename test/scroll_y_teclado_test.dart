import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/cabecera_con_lista.dart';
import 'package:gymads/app/core/widgets/refrescable.dart';

void main() {
  group('Refrescable', () {
    Future<ScrollPosition> lista(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Refrescable(
            onRefresh: () async {},
            child: ListView.builder(
              itemCount: 30,
              itemBuilder: (_, i) =>
                  SizedBox(height: 60, child: Text('Fila $i')),
            ),
          ),
        ),
      ));
      return tester.state<ScrollableState>(find.byType(Scrollable)).position;
    }

    testWidgets('la lista no se sale de la pantalla al arrastrarla hasta abajo',
        (tester) async {
      final pos = await lista(tester);

      await tester.fling(find.byType(ListView), const Offset(0, -20000), 8000);
      await tester.pumpAndSettle();

      expect(pos.pixels, lessThanOrEqualTo(pos.maxScrollExtent + 0.5));
      expect(find.text('Fila 29'), findsOneWidget);
    });

    testWidgets('ni hacia arriba: regresa al principio', (tester) async {
      final pos = await lista(tester);
      await tester.fling(find.byType(ListView), const Offset(0, -600), 3000);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(ListView), const Offset(0, 20000), 8000);
      await tester.pumpAndSettle();

      expect(pos.pixels, greaterThanOrEqualTo(pos.minScrollExtent - 0.5));
      expect(find.text('Fila 0'), findsOneWidget);
    });

    testWidgets('una lista corta se puede seguir tirando para recargar',
        (tester) async {
      var recargas = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Refrescable(
            onRefresh: () async => recargas++,
            child: ListView(children: const [Text('Única fila')]),
          ),
        ),
      ));

      await tester.fling(find.text('Única fila'), const Offset(0, 400), 1500);
      await tester.pumpAndSettle();

      expect(recargas, 1);
    });
  });

  testWidgets('CabeceraConLista: abrir el teclado no le quita el foco al campo',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CabeceraConLista(
          cabecera: const [SizedBox(height: 150, child: Text('Cabecera'))],
          lista: ListView(children: const [TextField(key: Key('precio'))]),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('precio')));
    await tester.pump();
    final antes = tester.state<EditableTextState>(find.byType(EditableText));
    expect(antes.widget.focusNode.hasFocus, isTrue);

    // El teclado ocupa 420 pt: el espacio que queda baja de 480.
    tester.view.viewInsets = const FakeViewPadding(bottom: 420 * 3);
    await tester.pumpAndSettle();

    final despues = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(antes, despues), isTrue, reason: 'el campo se reconstruyó');
    expect(despues.widget.focusNode.hasFocus, isTrue);
  });
}

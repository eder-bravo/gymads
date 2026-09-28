import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/global_widgets/cliente_card.dart';

void main() {
  testWidgets(
      'al volver de la ficha, las iniciales de un cliente sin foto no salen '
      'subrayadas', (tester) async {
    final cliente = UserModel(
      id: 'c1',
      name: 'Pepe López',
      phone: '+525500000000',
      joinDate: DateTime(2026, 9, 1),
      userNumber: 'A1B2C3',
    );
    final navegador = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navegador,
      home: Scaffold(
        body: ListView(children: [
          ClienteCard(cliente: cliente, onTap: () {}),
        ]),
      ),
    ));

    // Una "ficha" con el mismo avatar (mismo tag), como ClienteDetailView.
    navegador.currentState!.push(MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Hero(
            tag: 'avatar_c1',
            child: const SizedBox(
                width: 130, height: 130, child: Center(child: Text('PL'))),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    navegador.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // a medio vuelo

    for (final texto in tester.widgetList<Text>(find.text('PL'))) {
      final elemento = tester.element(find.byWidget(texto));
      expect(DefaultTextStyle.of(elemento).style.decoration,
          isNot(TextDecoration.underline));
    }
    expect(find.text('PL'), findsWidgets, reason: 'se ven las iniciales');
    await tester.pumpAndSettle();
  });
}

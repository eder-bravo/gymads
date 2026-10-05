import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';

/// En computadora, una tecla que nadie usa (el lector de códigos fuera de
/// Venta e Inventario) no debe llegar al sistema, que la hace sonar como
/// tecla no válida. Que la marque como atendida es lo que evita el sonido.
void main() {
  Future<void> mostrar(WidgetTester tester) async {
    VentanaEscritorio.silenciarTeclasSueltas();
    addTearDown(VentanaEscritorio.dejarDeSilenciar);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const Text('Clientes'),
          ElevatedButton(onPressed: () {}, child: const Text('Agregar')),
          const TextField(key: Key('campo')),
        ]),
      ),
    ));
    await tester.pump();
  }

  const escritorio = TargetPlatformVariant(
      {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux});

  testWidgets('el lector fuera de su pantalla no suena', (tester) async {
    await mostrar(tester);
    // Un código como lo teclea el lector, y su Enter.
    for (final tecla in [
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.enter,
    ]) {
      expect(await tester.sendKeyEvent(tecla), isTrue, reason: '$tecla');
    }
  }, variant: escritorio);

  testWidgets('en un campo de texto la escritura sigue llegando',
      (tester) async {
    await mostrar(tester);
    await tester.tap(find.byKey(const Key('campo')));
    await tester.pump();
    // Sin atender: el sistema la escribe en el campo.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyA), isFalse);
  }, variant: escritorio);

  testWidgets('los atajos del sistema (⌘/Ctrl/Alt) siguen pasando',
      (tester) async {
    await mostrar(tester);
    for (final modificador in [
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.alt,
    ]) {
      await tester.sendKeyDownEvent(modificador);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyQ), isFalse,
          reason: '$modificador');
      await tester.sendKeyUpEvent(modificador);
    }
  }, variant: escritorio);

  testWidgets('en el teléfono y la tableta no cambia nada', (tester) async {
    await mostrar(tester);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyA), isFalse);
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

/// En computadora, Enter pulsa el botón principal de un diálogo de
/// confirmación; nada más.
void main() {
  tearDown(Get.reset);

  /// Abre un diálogo con "Cancelar" y el botón principal; cuenta los toques.
  Future<({List<String> pulsados})> dialogo(
    WidgetTester tester, {
    bool compacto = true,
    bool activo = true,
    Widget? campo,
  }) async {
    final pulsados = <String>[];
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    Get.dialog<void>(AlertDialog(
      title: const Text('¿Eliminar producto?'),
      content: campo,
      actions: [
        BotonCancelar(onPressed: () {
          pulsados.add('cancelar');
          Get.back();
        }),
        BotonGuardar(
          texto: 'Eliminar',
          compacto: compacto,
          onPressed: activo
              ? () {
                  pulsados.add('eliminar');
                  Get.back();
                }
              : null,
        ),
      ],
    ));
    await tester.pumpAndSettle();
    return (pulsados: pulsados);
  }

  Future<void> enter(WidgetTester tester,
      [LogicalKeyboardKey tecla = LogicalKeyboardKey.enter]) async {
    await tester.sendKeyEvent(tecla);
    await tester.pumpAndSettle();
  }

  const computadoras = TargetPlatformVariant(
      {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux});

  testWidgets('Enter (y el del teclado numérico) confirma', (tester) async {
    // El simulador de pruebas de Windows no conoce el Enter numérico.
    for (final tecla in [
      LogicalKeyboardKey.enter,
      if (defaultTargetPlatform != TargetPlatform.windows)
        LogicalKeyboardKey.numpadEnter
    ]) {
      final (:pulsados) = await dialogo(tester);
      await enter(tester, tecla);
      expect(pulsados, ['eliminar']);
      expect(find.text('¿Eliminar producto?'), findsNothing);
    }
  }, variant: computadoras);

  testWidgets('en el teléfono y la tableta no cambia nada', (tester) async {
    final (:pulsados) = await dialogo(tester);
    await enter(tester);
    expect(pulsados, isEmpty);
    expect(find.text('¿Eliminar producto?'), findsOneWidget);
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('los formularios grandes y las pantallas siguen con clic',
      (tester) async {
    // Botón principal de formulario (no compacto) dentro de una ventana.
    final (:pulsados) = await dialogo(tester, compacto: false);
    await enter(tester);
    expect(pulsados, isEmpty);
    Get.back();
    await tester.pumpAndSettle();

    // Un botón compacto en una pantalla, sin diálogo.
    var cobrado = false;
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: BotonGuardar(
            texto: 'Cobrar', compacto: true, onPressed: () => cobrado = true),
      ),
    ));
    await enter(tester);
    expect(cobrado, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('desactivado no hace nada', (tester) async {
    final (:pulsados) = await dialogo(tester, activo: false);
    await enter(tester);
    expect(pulsados, isEmpty);
    expect(find.text('¿Eliminar producto?'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('con Tab en "Cancelar", Enter cancela', (tester) async {
    final (:pulsados) = await dialogo(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await enter(tester);
    expect(pulsados, ['cancelar']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('en un campo de un renglón confirma; en uno de varios, no',
      (tester) async {
    var (:pulsados) = await dialogo(tester,
        campo: const TextField(key: Key('cantidad'), autofocus: true));
    await tester.enterText(find.byKey(const Key('cantidad')), '5');
    await enter(tester);
    expect(pulsados, ['eliminar']);

    (:pulsados) = await dialogo(tester,
        campo: const TextField(key: Key('nota'), autofocus: true, maxLines: 3));
    await enter(tester);
    expect(pulsados, isEmpty);
    Get.back();
    await tester.pumpAndSettle();

    // Un campo que pasa al siguiente o envía por su cuenta conserva su Enter.
    (:pulsados) = await dialogo(tester,
        campo: TextField(
            key: const Key('codigo'), autofocus: true, onSubmitted: (_) {}));
    await enter(tester);
    expect(pulsados, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('con dos diálogos, solo el de enfrente', (tester) async {
    final (:pulsados) = await dialogo(tester);
    var segundo = 0;
    Get.dialog<void>(AlertDialog(
      title: const Text('¿Seguro?'),
      actions: [
        BotonGuardar(
            texto: 'Sí',
            compacto: true,
            onPressed: () {
              segundo++;
              Get.back();
            }),
      ],
    ));
    await tester.pumpAndSettle();
    await enter(tester);
    expect(segundo, 1);
    expect(pulsados, isEmpty);
    expect(find.text('¿Eliminar producto?'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('el Enter de un lector de códigos no confirma', (tester) async {
    final (:pulsados) = await dialogo(tester);
    KeyDownEvent tecla(LogicalKeyboardKey logica, int ms) => KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: logica,
          timeStamp: Duration(milliseconds: ms),
        );
    // Lector: el código de golpe (10 ms por tecla) y Enter.
    for (final (i, t) in [10, 20, 30, 40].indexed) {
      EnterConfirma.tecla(tecla(LogicalKeyboardKey(0x61 + i), t));
    }
    expect(EnterConfirma.tecla(tecla(LogicalKeyboardKey.enter, 50)),
        KeyEventResult.ignored);
    expect(pulsados, isEmpty);

    // Una persona: teclas sueltas y luego Enter.
    for (final t in [1000, 1250, 1500]) {
      EnterConfirma.tecla(tecla(LogicalKeyboardKey.keyB, t));
    }
    expect(EnterConfirma.tecla(tecla(LogicalKeyboardKey.enter, 1800)),
        KeyEventResult.handled);
    await tester.pumpAndSettle();
    expect(pulsados, ['eliminar']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

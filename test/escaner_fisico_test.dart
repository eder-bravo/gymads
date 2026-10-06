import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/escaner_codigo_view.dart';
import 'package:gymads/app/core/widgets/escaner_fisico_view.dart';
import 'package:gymads/app/data/services/escaner_fisico_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  test('preserva ceros y rechaza lecturas vacías o con control', () {
    expect(EscanerFisicoService.codigoDe('00012345'), '00012345');
    expect(EscanerFisicoService.codigoDe('  00012345 '), '00012345');
    expect(EscanerFisicoService.codigoDe(''), isNull);
    expect(EscanerFisicoService.codigoDe('AB\nCD'), isNull);
    expect(EscanerFisicoService.codigoDe('1' * 257), isNull);
  });

  test(
      'Enter, Enter del teclado numérico y Tab cierran la lectura, sin '
      'configurar nada', () {
    for (final tecla in [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.tab,
    ]) {
      expect(EscanerFisicoService.esFinDeLectura(tecla), isTrue);
    }
    expect(
        EscanerFisicoService.esFinDeLectura(LogicalKeyboardKey.space), isFalse);
  });

  test('borra los ajustes de versiones anteriores', () async {
    SharedPreferences.setMockInitialValues({
      'escaner_terminador': 'tab',
      'escaner_prefijo': 'PRE',
      'escaner_sufijo': 'FIN',
      'otra_cosa': 'se queda',
    });
    await EscanerFisicoService.olvidarAjustesViejos();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'otra_cosa'});
  });

  for (final plataforma in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('$plataforma abre lector físico sin crear escáner de cámara',
        (tester) async {
      debugDefaultTargetPlatformOverride = plataforma;
      await tester.pumpWidget(const GetMaterialApp(home: EscanerCodigoView()));
      await tester.pumpAndSettle();
      expect(find.byType(EscanerFisicoView), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('Enter entrega una lectura y conserva códigos repetidos rápidos',
      (tester) async {
    final recibidos = <String>[];
    final primera = Completer<void>();
    await tester.pumpWidget(GetMaterialApp(
        home: EscanerFisicoView(
            titulo: 'Venta',
            alLeer: (c) async {
              recibidos.add(c);
              if (recibidos.length == 1) await primera.future;
              return '+1 $c';
            })));
    await tester.pumpAndSettle();
    for (final codigo in ['001234', '001234', '56789']) {
      await tester.enterText(find.byType(TextField), codigo);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }
    expect(recibidos, ['001234']);
    primera.complete();
    await tester.pumpAndSettle();
    expect(recibidos, ['001234', '001234', '56789']);
    expect(find.text('+1 56789'), findsOneWidget);
  });

  testWidgets('Tab finaliza sin cambiar el foco; una tecla normal no finaliza',
      (tester) async {
    final recibidos = <String>[];
    await tester.pumpWidget(GetMaterialApp(
        home: EscanerFisicoView(
            titulo: 'Prueba',
            alLeer: (c) async {
              recibidos.add(c);
              return null;
            })));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(recibidos, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(recibidos, ['ABC123']);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue);
  });

  testWidgets('cerrar mientras procesa no ejecuta las lecturas pendientes',
      (tester) async {
    final procesando = Completer<String?>();
    var llamadas = 0;
    await tester.pumpWidget(GetMaterialApp(
        home: EscanerFisicoView(
            titulo: 'Prueba',
            alLeer: (_) {
              llamadas++;
              return procesando.future;
            })));
    await tester.pumpAndSettle();
    for (final c in ['111', '222']) {
      await tester.enterText(find.byType(TextField), c);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    }
    await tester.pumpWidget(const SizedBox());
    procesando.complete('OK');
    await tester.pumpAndSettle();
    expect(llamadas, 1);
    expect(tester.takeException(), isNull);
  });
}

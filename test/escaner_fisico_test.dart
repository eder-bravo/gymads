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
    EscanerFisicoService.configuracion.value = const ConfiguracionEscaner();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  test('preserva ceros y quita solo el prefijo y sufijo definidos', () {
    const config = ConfiguracionEscaner(prefijo: ']C1', sufijo: '#');
    expect(config.interpretar(']C100012345#'), '00012345');
    expect(config.interpretar('00012345#'), isNull);
    expect(config.interpretar(']C100012345'), isNull);
    expect(config.interpretar(']C1#'), isNull);
    expect(const ConfiguracionEscaner().interpretar('AB\nCD'), isNull);
  });

  test('recupera configuración local después de reiniciar', () async {
    await EscanerFisicoService.guardar(const ConfiguracionEscaner(
        terminador: TerminadorEscaner.tab, prefijo: 'PRE', sufijo: 'FIN'));
    EscanerFisicoService.configuracion.value = const ConfiguracionEscaner();
    await EscanerFisicoService.cargar();
    expect(EscanerFisicoService.configuracion.value.teclaFinal,
        LogicalKeyboardKey.tab);
    expect(EscanerFisicoService.configuracion.value.interpretar('PRE00123FIN'),
        '00123');
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
    EscanerFisicoService.configuracion.value =
        const ConfiguracionEscaner(terminador: TerminadorEscaner.tab);
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
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
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

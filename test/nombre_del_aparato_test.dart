import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/modules/configuracion/views/configuracion_view.dart';

/// Los textos que nombran el aparato dicen "teléfono" en el celular,
/// "tableta" en la tableta y "computadora" en escritorio, con su artículo.

Future<void> _pantalla(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('teléfono: sin cambios', (tester) async {
    await _pantalla(tester, const Size(390, 844));
    expect(PlataformaApp.aparato, 'teléfono');
    expect(PlataformaApp.elAparato, 'el teléfono');
    expect(PlataformaApp.delAparato, 'del teléfono');
    expect(PlataformaApp.esteAparato, 'este teléfono');
    expect(PlataformaApp.tuAparato, 'tu teléfono');
    expect(nombreDeApariencia(ThemeMode.system), 'Según el teléfono');
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('tableta: dice tableta', (tester) async {
    await _pantalla(tester, const Size(1180, 820));
    expect(PlataformaApp.aparato, 'tableta');
    expect(PlataformaApp.elAparato, 'la tableta');
    expect(PlataformaApp.delAparato, 'de la tableta');
    expect(PlataformaApp.esteAparato, 'esta tableta');
    expect(PlataformaApp.tuAparato, 'tu tableta');
    expect(nombreDeApariencia(ThemeMode.system), 'Según la tableta');
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('una tableta chica sigue diciendo teléfono', (tester) async {
    await _pantalla(tester, const Size(600, 960));
    expect(PlataformaApp.aparato, 'teléfono');
    expect(nombreDeApariencia(ThemeMode.system), 'Según el teléfono');
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('escritorio: dice computadora', (tester) async {
    await _pantalla(tester, const Size(1280, 800));
    expect(PlataformaApp.aparato, 'computadora');
    expect(PlataformaApp.elAparato, 'la computadora');
    expect(PlataformaApp.delAparato, 'de la computadora');
    expect(PlataformaApp.esteAparato, 'esta computadora');
    expect(PlataformaApp.tuAparato, 'tu computadora');
    expect(nombreDeApariencia(ThemeMode.system), 'Según la computadora');
    expect(nombreDeApariencia(ThemeMode.dark), 'Oscuro');
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.macOS, TargetPlatform.windows}));
}

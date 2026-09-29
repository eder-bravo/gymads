import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/modules/configuracion/views/cambiar_contrasena_view.dart';
import 'package:gymads/core/theme/app_theme.dart';

void main() {
  Future<void> abrir(WidgetTester tester,
      Future<String?> Function(String, String) cambiar) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.claro,
      home: CambiarContrasenaView(cambiar: cambiar),
    ));
  }

  Future<void> llenar(WidgetTester tester, String a, String n, String c) async {
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), a);
    await tester.enterText(campos.at(1), n);
    await tester.enterText(campos.at(2), c);
    await tester.tap(find.text('Cambiar contraseña').last);
    await tester.pump();
  }

  testWidgets('valida antes de mandar nada', (tester) async {
    var llamadas = 0;
    await abrir(tester, (_, __) async {
      llamadas++;
      return null;
    });

    await llenar(tester, 'vieja1', '123', '123');
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);

    await llenar(tester, 'vieja1', 'nueva123', 'otra123');
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);

    await llenar(tester, 'vieja1', 'vieja1', 'vieja1');
    expect(find.text('La nueva debe ser distinta'), findsOneWidget);
    expect(llamadas, 0);
  });

  testWidgets('muestra "Guardando…" y el error que devuelve', (tester) async {
    final respuesta = Completer<String?>();
    String? recibida;
    await abrir(tester, (actual, nueva) {
      recibida = '$actual>$nueva';
      return respuesta.future;
    });

    await llenar(tester, 'vieja1', 'nueva123', 'nueva123');
    expect(recibida, 'vieja1>nueva123');
    expect(find.text('Guardando…'), findsOneWidget);

    respuesta.complete('La contraseña actual no es correcta');
    await tester.pump();
    expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
  });
}

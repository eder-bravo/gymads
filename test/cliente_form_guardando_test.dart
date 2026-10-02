import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';

void main() {
  testWidgets('mientras guarda, "Guardar cliente" se bloquea y dice "Guardando…"',
      (tester) async {
    final guardando = false.obs;
    var guardados = 0;
    final controladores = List.generate(6, (_) => TextEditingController());

    await tester.pumpWidget(GetMaterialApp(
      home: ClienteFormDialog(
        nombreController: controladores[0],
        phoneController: controladores[1],
        emailController: controladores[2],
        addressController: controladores[3],
        userNumberController: controladores[4],
        rfidController: controladores[5],
        onSave: (_, __) => guardados++,
        guardando: guardando,
        fullScreen: true,
      ),
    ));
    await tester.pump();

    ElevatedButton boton() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    expect(find.text('Guardar cliente'), findsOneWidget);
    expect(boton().onPressed, isNotNull);

    guardando.value = true;
    await tester.pump();
    expect(find.text('Guardando…'), findsOneWidget);
    expect(boton().onPressed, isNull, reason: 'un segundo toque no guarda');
    expect(guardados, 0);

    guardando.value = false;
    await tester.pump();
    expect(find.text('Guardar cliente'), findsOneWidget);

    // Cierra el formulario: detiene su consulta periódica al lector.
    await tester.pumpWidget(const SizedBox());
  });
}

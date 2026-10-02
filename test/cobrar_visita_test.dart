import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import 'package:gymads/app/modules/abonar/views/cobrar_visita_view.dart';
import 'package:gymads/core/theme/app_theme.dart';

void main() {
  tearDown(Get.reset);

  Future<CobrarVisitaController> abrir(
    WidgetTester tester, {
    double? precioDia,
    RegistrarVisita? registrar,
  }) async {
    tester.view.physicalSize = const Size(390, 1200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = Get.put(CobrarVisitaController(
      precioDia: precioDia,
      registrar: registrar ?? (_) async => null,
    ));
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.claro,
      home: const CobrarVisitaView(),
    ));
    return c;
  }

  testWidgets('el monto sale con el precio por día y se puede cambiar',
      (tester) async {
    final c = await abrir(tester, precioDia: 50);
    expect(c.montoCtrl.text, '50');
    expect(find.text('Precio por día'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('monto_visita')), '65.5');
    expect(c.monto, 65.5);
  });

  testWidgets('sin precio por día hay que escribir el monto', (tester) async {
    var llamadas = 0;
    await abrir(tester, registrar: (_) async {
      llamadas++;
      return null;
    });
    expect(find.text('No hay precio por día configurado'), findsOneWidget);
    await tester.tap(find.text('Cobrar visita').last);
    await tester.pump();
    expect(find.text('Escribe el monto de la visita'), findsOneWidget);
    expect(llamadas, 0);
  });

  testWidgets('la referencia solo aparece con tarjeta o transferencia',
      (tester) async {
    await abrir(tester, precioDia: 50);
    expect(find.text('Escanear referencia'), findsNothing);
    await tester.tap(find.text('Transferencia'));
    await tester.pump();
    expect(find.text('Escanear referencia'), findsOneWidget);
    await tester.tap(find.text('Efectivo'));
    await tester.pump();
    expect(find.text('Escanear referencia'), findsNothing);
  });

  testWidgets('manda nombre, monto, método y referencia, y dice "Guardando…"',
      (tester) async {
    final respuesta = Completer<String?>();
    DatosVisita? enviado;
    final c = await abrir(tester, precioDia: 50, registrar: (d) {
      enviado = d;
      return respuesta.future;
    });

    await tester.enterText(find.widgetWithText(TextField, 'Nombre (opcional)'),
        '  Juan  ');
    await tester.tap(find.text('Tarjeta de débito'));
    await tester.pump();
    c.setReferenciaPago('004521');
    await tester.tap(find.text('Cobrar visita').last);
    await tester.pump();

    expect(find.text('Guardando…'), findsOneWidget);
    expect(enviado!.nombre, 'Juan');
    expect(enviado!.monto, 50);
    expect(enviado!.metodoPago, 'tarjeta_debito');
    expect(enviado!.referencia, '004521');

    respuesta.complete('No se pudo cobrar la visita. Intenta de nuevo.');
    await tester.pump();
    expect(find.text('No se pudo cobrar la visita. Intenta de nuevo.'),
        findsOneWidget);
  });

  testWidgets('sin nombre y en efectivo no manda nombre ni referencia',
      (tester) async {
    DatosVisita? enviado;
    final c = await abrir(tester, precioDia: 40, registrar: (d) async {
      enviado = d;
      return null;
    });
    c.setReferenciaPago('no-debe-ir');
    expect(await c.cobrar(), 40);
    expect(enviado!.nombre, isNull);
    expect(enviado!.referencia, isNull);
    expect(enviado!.metodoPago, 'efectivo');
  });

  test('en Ingresos una visita se lee "Visita"', () {
    final i = IngresoModel.fromJson({
      'concepto': 'visita',
      'cliente_nombre': 'Visita · Juan',
      'tipo_membresia': 'Visita',
      'monto_base': 50,
      'monto_final': 50,
      'metodo_pago': 'efectivo',
      'usuario_staff': 'Ana',
      'fecha': DateTime(2026, 9, 29).toIso8601String(),
    });
    expect(i.conceptoDescripcion, 'Visita');
    expect(i.clienteId, isNull);
  });
}

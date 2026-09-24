import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import 'package:gymads/app/modules/ingresos/widgets/detalle_ingreso_sheet.dart';

IngresoModel venta(List<Map<String, dynamic>> items,
        {double total = 0, String? referencia}) =>
    IngresoModel.fromJson({
      'id': 'v',
      'concepto': 'producto',
      'fecha': '2026-09-23T18:05:00Z',
      'monto_final': total,
      'metodo_pago': 'tarjeta',
      'referencia_pago': referencia,
      'items_detalle': items,
    });

Map<String, dynamic> item(
        String id, String nombre, int cantidad, double precio) =>
    {
      'product_id': id,
      'product_name': nombre,
      'quantity': cantidad,
      'unit_price': precio,
      'total': cantidad * precio,
    };

void main() {
  group('Productos de una venta', () {
    test('se leen de items_detalle', () {
      final v = venta([item('a', 'Agua 1L', 2, 15)], total: 30);
      expect(v.items.single.nombre, 'Agua 1L');
      expect(v.items.single.cantidad, 2);
      expect(v.items.single.precioUnitario, 15);
      expect(v.items.single.total, 30);
    });

    test('un cobro de membresía no tiene productos', () {
      final cobro = IngresoModel.fromJson({
        'id': 'm',
        'concepto': 'renovacion',
        'monto_final': 350,
      });
      expect(cobro.items, isEmpty);
    });

    test('resumen: agrupa por producto y ordena de más a menos vendido', () {
      final resumen = resumirProductosVendidos([
        venta(
            [item('agua', 'Agua 1L', 2, 15), item('prot', 'Proteína', 1, 80)]),
        venta([item('agua', 'Agua', 3, 15)]),
        venta([item('barra', 'Barra', 1, 25)]),
      ]);

      expect(resumen.map((p) => p.nombre), ['Agua 1L', 'Proteína', 'Barra']);
      final agua = resumen.first;
      // Mismo producto aunque se haya renombrado: vale el nombre más reciente.
      expect(agua.nombre, 'Agua 1L');
      expect(agua.cantidad, 5);
      expect(agua.monto, 75);
      // Empate en piezas: primero el de más dinero.
      expect(resumen[1].nombre, 'Proteína');
    });
  });

  testWidgets(
      'tocar una venta muestra sus productos, total, método y referencia',
      (tester) async {
    final v = venta(
      [item('agua', 'Agua 1L', 2, 15), item('barra', 'Barra', 1, 25)],
      total: 55,
      referencia: 'A1B2',
    );
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarDetalleIngreso(context, v),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Venta de producto'), findsOneWidget);
    expect(find.text('Agua 1L'), findsOneWidget);
    expect(find.text('2 × \$15.00'), findsOneWidget);
    expect(find.text('\$30.00'), findsOneWidget);
    expect(find.text('Barra'), findsOneWidget);
    expect(find.text('\$55.00'), findsOneWidget);
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(find.text('A1B2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

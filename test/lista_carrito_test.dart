import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/sale_model.dart';
import 'package:gymads/app/modules/point_of_sale/widgets/lista_carrito.dart';
import 'package:gymads/core/theme/app_theme.dart';

SaleItem _item(String nombre, int cantidad, double precio) => SaleItem(
      productId: nombre,
      productName: nombre,
      quantity: cantidad,
      unitPrice: precio,
      total: cantidad * precio,
    );

void main() {
  late List<(String, int)> cambios;

  Future<void> mostrar(WidgetTester tester, List<SaleItem> items) {
    cambios = [];
    return tester.pumpWidget(MaterialApp(
      theme: AppTheme.oscuro,
      home: Scaffold(
        body: ListaCarrito(
          items: items,
          onCambiarCantidad: (item, cantidad) =>
              cambios.add((item.productId, cantidad)),
        ),
      ),
    ));
  }

  testWidgets('muestra cada producto con su cantidad y subtotal',
      (tester) async {
    await mostrar(tester, [_item('Agua 1L', 2, 15), _item('Barra', 1, 40)]);

    expect(find.text('Agua 1L'), findsOneWidget);
    expect(find.text('2 × \$15.00  =  \$30.00'), findsOneWidget);
    expect(find.text('Barra'), findsOneWidget);
    expect(find.text('1 × \$40.00  =  \$40.00'), findsOneWidget);
  });

  testWidgets('+ suma uno y − resta uno', (tester) async {
    await mostrar(tester, [_item('Agua 1L', 2, 15)]);

    await tester.tap(find.byTooltip('Uno más'));
    await tester.tap(find.byTooltip('Uno menos'));

    expect(cambios, [('Agua 1L', 3), ('Agua 1L', 1)]);
  });

  testWidgets('con una sola pieza el botón quita el producto', (tester) async {
    await mostrar(tester, [_item('Barra', 1, 40)]);

    expect(find.byTooltip('Uno menos'), findsNothing);
    await tester.tap(find.byTooltip('Quitar'));

    expect(cambios, [('Barra', 0)]);
  });
}

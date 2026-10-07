import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/modules/inventario/controllers/inventario_controller.dart';
import 'package:gymads/app/modules/inventario/views/inventario_view.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:showcaseview/showcaseview.dart';

class _Inventario extends InventarioController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => true;
}

void main() {
  const moviles =
      TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});
  late ShowcaseView tour;
  setUp(() => tour = ShowcaseView.register());
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  Future<void> mostrar(WidgetTester tester, Size pantalla,
      {double escala = 1, bool conProductos = true}) async {
    tester.view.physicalSize = pantalla * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final controller = Get.put<InventarioController>(_Inventario());
    controller.inventoryStats.assignAll({
      'totalProducts': 1250,
      'totalStock': 123456,
      'totalValue': 12345678.90,
    });
    if (conProductos)
      controller.products.assignAll([
        Product(
            id: 'agua',
            name: 'Agua',
            description: 'Botella',
            categoryId: null,
            price: 20,
            stock: 100,
            isActive: true,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026)),
      ]);
    controller.filterProducts();
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.oscuro,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: const InventarioView(),
    ));
    await tester.pumpAndSettle();
  }

  for (final ancho in [320.0, 390.0, 430.0]) {
    testWidgets('resumen en una fila y dentro del teléfono de ancho $ancho',
        (tester) async {
      await mostrar(tester, Size(ancho, 700));
      final posiciones = [
        for (final texto in ['1250', '123456', '\$12345678.90'])
          tester.getTopLeft(find.text(texto)).dy,
      ];
      expect(posiciones[1], closeTo(posiciones[0], 1));
      expect(posiciones[2], closeTo(posiciones[0], 1));
      expect(find.text('Total Productos'), findsOneWidget);
      expect(find.text('Stock Total'), findsOneWidget);
      expect(find.text('Valor Total'), findsOneWidget);
      final resumen = tester.getRect(find.byType(ResumenAdaptable));
      expect(resumen.left, greaterThanOrEqualTo(0));
      expect(resumen.right, lessThanOrEqualTo(ancho));
      expect(resumen.height, lessThan(90));
      expect(find.text('Agua').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: moviles);
  }

  testWidgets('con letra grande el resumen se acomoda sin desbordar',
      (tester) async {
    await mostrar(tester, const Size(320, 700), escala: 2, conProductos: false);
    expect(tester.getTopLeft(find.text('123456')).dy,
        greaterThan(tester.getTopLeft(find.text('1250')).dy));
    expect(find.text('\$12345678.90'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: moviles);

  testWidgets('en horizontal el resumen cabe y permite alcanzar los productos',
      (tester) async {
    await mostrar(tester, const Size(844, 390));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Agua').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: moviles);
}

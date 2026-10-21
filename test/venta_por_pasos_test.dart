import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/models/sale_model.dart';
import 'package:gymads/app/data/repositories/sale_repository.dart';
import 'package:gymads/app/modules/point_of_sale/controllers/point_of_sale_controller.dart';
import 'package:gymads/app/modules/point_of_sale/views/point_of_sale_view.dart';
import 'package:gymads/app/modules/point_of_sale/widgets/ficha_producto.dart';
import 'package:gymads/app/modules/point_of_sale/widgets/lista_carrito.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:showcaseview/showcaseview.dart';

/// Guarda la venta sin ir a la red.
class _Ventas implements SaleRepository {
  final guardadas = <Sale>[];

  @override
  Future<({Sale? sale, List<String> stockFallido})> createSale(
      Sale sale) async {
    guardadas.add(sale);
    return (sale: sale, stockFallido: const <String>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Venta extends PointOfSaleController {
  _Venta(this.ventas) : super(saleRepository: ventas);
  final _Ventas ventas;

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  // Tras cobrar recarga el stock: aquí no hay red.
  @override
  Future<void> loadProducts({bool silencioso = false}) async {}
}

List<Product> _productos() => [
      for (final (i, (nombre, precio)) in [
        ('Agua natural 1 L', 15.0),
        ('Barra de proteína', 40.0),
        ('Bebida isotónica', 25.0),
      ].indexed)
        Product(
          id: '$i',
          name: nombre,
          barcode: '00$i',
          price: precio,
          stock: 10,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ];

void main() {
  late ShowcaseView tour;
  late _Venta venta;

  setUp(() {
    tour = ShowcaseView.register();
    venta = Get.put<PointOfSaleController>(_Venta(_Ventas())) as _Venta;
    venta.availableProducts.addAll(_productos());
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  Future<void> mostrar(WidgetTester tester, Size tamano,
      {bool claro = false, double escala = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      theme: claro ? AppTheme.claro : AppTheme.oscuro,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: VentanaEscritorio(child: child!),
      ),
      home: const PointOfSaleView(),
    ));
    await tester.pumpAndSettle();
  }

  for (final claro in [false, true]) {
    testWidgets(
        'teléfono ${claro ? 'claro' : 'oscuro'}: productos, revisar, cómo '
        'paga, con cuánto y ¡Listo! con el cambio', (tester) async {
      await mostrar(tester, const Size(390, 844), claro: claro);
      // Las fichas solo agregan: sin botones de quitar.
      expect(find.byTooltip('Quitar uno'), findsNothing);
      await tester.tap(find.text('Agua natural 1 L'));
      await tester.tap(find.text('Agua natural 1 L'));
      await tester.tap(find.text('Barra de proteína'));
      await tester.pumpAndSettle();
      expect(venta.totalUnidades, 3);
      expect(find.text('Llevas 2'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(find.text('Revisa la venta'), findsOneWidget);
      // Las cantidades se corrigen aquí.
      await tester.tap(find.byTooltip('Uno menos'));
      await tester.pumpAndSettle();
      expect(venta.totalUnidades, 2);

      // Atrás regresa a los productos sin perder la venta.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(venta.totalUnidades, 2);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ir a cobrar'));
      await tester.pumpAndSettle();
      expect(find.text('Paso 3 de 4'), findsOneWidget);
      await tester.tap(find.text('Efectivo'));
      await tester.pumpAndSettle();
      expect(find.text('Paso 4 de 4'), findsOneWidget);
      expect(find.text('¿Con cuánto paga?'), findsOneWidget);
      expect(find.text('Escribe con cuánto paga'), findsOneWidget);

      // $55: con un billete de $100 le tocan $45 de cambio.
      await tester.tap(find.text('\$100.00'));
      await tester.pumpAndSettle();
      expect(find.text('Cambio'), findsOneWidget);
      await tester.tap(find.text('Cobrar \$55.00'));
      await tester.pumpAndSettle();

      expect(venta.ventas.guardadas.single.cambio, 45);
      expect(find.text('¡Listo!'), findsOneWidget);
      expect(find.text('\$45.00'), findsOneWidget);
      expect(venta.cartItems, isEmpty);

      // "Nueva venta" regresa a los productos, no a cobrar otra vez.
      await tester.tap(find.text('Nueva venta'));
      await tester.pumpAndSettle();
      expect(find.byType(FichaProducto), findsNWidgets(3));
      expect(
          find.text('Toca o escanea productos para empezar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('teléfono: con tarjeta el paso 4 pide el folio', (tester) async {
    await mostrar(tester, const Size(390, 844));
    await tester.tap(find.text('Bebida isotónica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a cobrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta de débito'));
    await tester.pumpAndSettle();
    expect(find.text('Folio del pago'), findsOneWidget);
    await tester.tap(find.text('Cobrar \$25.00'));
    await tester.pumpAndSettle();
    expect(venta.ventas.guardadas.single.metodoPago, 'tarjeta_debito');
    expect(find.text('Cobraste \$25.00 en tarjeta de débito.'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('teléfono con letra grande: cada paso cabe', (tester) async {
    await mostrar(tester, const Size(390, 844), escala: 2);
    await tester.tap(find.text('Agua natural 1 L'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Ir a cobrar').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Ir a cobrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efectivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exacto'));
    await tester.pumpAndSettle();
    expect(find.text('Cobrar \$15.00').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final claro in [false, true]) {
    testWidgets(
        'escritorio ${claro ? 'claro' : 'oscuro'}: venta a la izquierda, '
        'cobro a la derecha y acciones abajo', (tester) async {
      await mostrar(tester, const Size(1280, 800), claro: claro);
      expect(find.text('Escanea o elige un producto'), findsOneWidget);
      await tester.tap(find.text('Barra de proteína'));
      await tester.tap(find.text('Barra de proteína'));
      await tester.pumpAndSettle();

      // Agregar, solo en la ficha; en la venta solo se resta.
      expect(find.byTooltip('Uno más'), findsNothing);
      expect(
          find.descendant(
              of: find.byType(ListaCarrito),
              matching: find.byTooltip('Uno menos')),
          findsOneWidget);
      expect(tester.getRect(find.byType(ListaCarrito)).right,
          lessThan(tester.getRect(find.byType(FichaProducto).first).left));

      await tester.tap(find.text('Cobrar \$80.00'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo paga?'), findsOneWidget);
      // Mientras se cobra, la venta se lee pero no se cambia.
      expect(find.byTooltip('Uno menos'), findsNothing);
      expect(find.text('Escribe con cuánto paga'), findsOneWidget);
      // El aviso va junto al botón: al cambiar de forma de pago (y con ello
      // el aviso) la venta no brinca.
      final total = tester.getRect(find.text('Total'));
      await tester.tap(find.text('Tarjeta de débito'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe con cuánto paga'), findsNothing);
      expect(tester.getRect(find.text('Total')), total);
      await tester.tap(find.text('Efectivo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exacto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrar \$80.00'));
      await tester.pumpAndSettle();
      expect(find.text('¡Listo!'), findsOneWidget);
      expect(venta.etapa, EtapaVenta.listo);

      // Escanear en "¡Listo!" empieza la venta siguiente.
      await venta.agregarPorCodigo('000');
      await tester.pumpAndSettle();
      expect(venta.etapa, EtapaVenta.productos);
      expect(venta.totalUnidades, 1);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  testWidgets('escritorio: vaciar la venta pide confirmación', (tester) async {
    await mostrar(tester, const Size(1280, 800));
    await tester.tap(find.text('Agua natural 1 L'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaciar venta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(venta.totalUnidades, 1);
    await tester.tap(find.text('Vaciar venta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaciar'));
    await tester.pumpAndSettle();
    expect(venta.cartItems, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  test('montos rápidos: exacto y los billetes que siguen', () async {
    await venta.addProductToCart(venta.availableProducts[1]); // $40
    expect(venta.montosRapidos, [40, 50, 100, 200]);
  });
}

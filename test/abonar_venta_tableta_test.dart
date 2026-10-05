import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:gymads/app/modules/abonar/views/abonar_view.dart';
import 'package:gymads/app/modules/point_of_sale/controllers/point_of_sale_controller.dart';
import 'package:gymads/app/modules/point_of_sale/views/point_of_sale_view.dart';
import 'package:gymads/app/modules/point_of_sale/widgets/lista_carrito.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// Abonar y Venta en tableta: Venta con el carrito al lado como escritorio
/// (acostada), y Abonar con todo a la vista y cobro directo.

class _Usuarios extends Fake implements UserRepository {
  _Usuarios([this.clientes = const []]);
  final List<UserModel> clientes;
  @override
  Future<List<UserModel>> getAllUsers() async => clientes;
}

/// Uno al día, uno vencido y uno nuevo.
List<UserModel> _tresClientes() {
  final ahora = DateTime.now();
  UserModel cliente(String nombre, DateTime? vence) => UserModel(
        id: nombre,
        name: nombre,
        phone: '+520000000000',
        joinDate: DateTime(2026),
        expirationDate: vence,
        userNumber: '1',
      );
  return [
    cliente('Ana López', ahora.add(const Duration(days: 20))),
    cliente('Carlos Ruiz', ahora.subtract(const Duration(days: 5))),
    cliente('María Pérez', null),
  ];
}

class _Precios extends Fake implements AbonoPricesRepository {
  @override
  Future<AbonoPricesModel> getPrices() async =>
      const AbonoPricesModel(priceMonth: 500);
}

class _Ingresos extends Fake implements IngresoService {}

class _SinTours implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async => {};
  @override
  Future<void> marcarVisto(String rol, String tourId) async {}
}

class _Venta extends PointOfSaleController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

const _tabletas =
    TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});

void main() {
  late ShowcaseView tour;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tour = ShowcaseView.register();
    Get.put(WelcomeTourService(
      toursDelEmpleado: _SinTours(),
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'owner_admin', esEmpleado: false),
    ));
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  Future<void> mostrar(WidgetTester tester, Widget pantalla, Size tamano,
      {double escala = 1}) async {
    tester.view.physicalSize = tamano * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.oscuro,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: VentanaEscritorio(child: child!),
      ),
      home: pantalla,
    ));
    await tester.pumpAndSettle();
  }

  AbonarController abonar() {
    final c = Get.put(AbonarController(
      userRepository: _Usuarios(),
      ingresoService: _Ingresos(),
      pricesRepository: _Precios(),
    ));
    c.selectedClient.value = UserModel(
      name: 'Juan Pérez',
      phone: '+520000000000',
      joinDate: DateTime(2026, 1, 1),
      userNumber: '1',
    );
    return c;
  }

  testWidgets('abonar en tableta: clientes en tarjetas con su estado',
      (tester) async {
    final c = Get.put(AbonarController(
      userRepository: _Usuarios(_tresClientes()),
      ingresoService: _Ingresos(),
      pricesRepository: _Precios(),
    ));
    // Acostada (iPad de 13"): tres tarjetas en una fila.
    await mostrar(tester, const AbonarView(), const Size(1366, 1024));
    final tops = [
      for (final n in ['Ana López', 'Carlos Ruiz', 'María Pérez'])
        tester.getTopLeft(find.text(n)).dy
    ];
    expect(tops.toSet().length, 1);
    expect(find.textContaining('Pagado hasta el'), findsOneWidget);
    expect(find.textContaining('Venció el'), findsOneWidget);
    expect(find.text('Cliente nuevo'), findsOneWidget);
    // "Cobrar visita" en la misma fila que el buscador.
    expect(tester.getCenter(find.textContaining('Cobrar visita')).dy,
        closeTo(tester.getCenter(find.text('Buscar cliente...')).dy, 2));
    // De pie: dos por fila.
    await mostrar(tester, const AbonarView(), const Size(1024, 1366));
    expect(tester.getTopLeft(find.text('Ana López')).dy,
        tester.getTopLeft(find.text('Carlos Ruiz')).dy);
    expect(tester.getTopLeft(find.text('María Pérez')).dy,
        greaterThan(tester.getTopLeft(find.text('Ana López')).dy));
    // Tocar una tarjeta abre su cobro.
    await tester.tap(find.text('Carlos Ruiz'));
    await tester.pumpAndSettle();
    expect(c.selectedClient.value?.name, 'Carlos Ruiz');
    expect(find.text('¿Cuánto tiempo paga?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);

  testWidgets('las tarjetas de clientes caben con texto grande',
      (tester) async {
    Get.put(AbonarController(
      userRepository: _Usuarios(_tresClientes()),
      ingresoService: _Ingresos(),
      pricesRepository: _Precios(),
    ));
    for (final escala in [1.3, 2.0]) {
      for (final tamano in [
        const Size(1366, 1024),
        const Size(1024, 1366),
        const Size(1180, 820),
        const Size(820, 1180),
      ]) {
        await mostrar(tester, const AbonarView(), tamano, escala: escala);
        expect(tester.takeException(), isNull,
            reason: '$tamano, texto $escala');
      }
    }
  }, variant: _tabletas);

  testWidgets('abonar acostada: pasos a la izquierda, resumen y cobro al lado',
      (tester) async {
    abonar();
    await mostrar(tester, const AbonarView(), const Size(1180, 820));
    // Todo abierto a la vez, sin "Continuar".
    expect(find.text('¿Cuánto tiempo paga?'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Cobrar \$500'), findsOneWidget);
    // El resumen y el botón, a la derecha de los pasos.
    expect(tester.getTopLeft(find.text('Resumen')).dx,
        greaterThan(tester.getTopRight(find.text('¿Cuánto tiempo paga?')).dx));
    expect(tester.getTopLeft(find.text('Cobrar \$500')).dx,
        greaterThan(tester.getCenter(find.text('Efectivo')).dx));
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);

  testWidgets('abonar de pie: todo en una columna y cobro directo abajo',
      (tester) async {
    abonar();
    await mostrar(tester, const AbonarView(), const Size(820, 1180));
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Cobrar \$500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);

  testWidgets('abono libre en tableta calcula el total de varios periodos',
      (tester) async {
    final c = abonar();
    await mostrar(tester, const AbonarView(), const Size(1180, 820));
    await tester.tap(find.text('Abono libre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cantidad_libre')), '2');
    await tester.tap(find.text('Años'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('monto_libre')), '300');
    await tester.pumpAndSettle();
    expect(c.totalAmount, 600);
    expect(find.text('Cobrar \$600'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await mostrar(tester, const AbonarView(), const Size(820, 1180));
    expect(find.text('Cobrar \$600'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);

  // Escritorio (macOS, Windows y Linux): el mismo diseño que la tableta
  // acostada. Antes era una columna angosta con mucho espacio vacío.
  const escritorio = TargetPlatformVariant(
      {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux});

  testWidgets('abonar en escritorio: clientes en tarjetas, sin vacío',
      (tester) async {
    final c = Get.put(AbonarController(
      userRepository: _Usuarios(_tresClientes()),
      ingresoService: _Ingresos(),
      pricesRepository: _Precios(),
    ));
    await mostrar(tester, const AbonarView(), const Size(1280, 800));
    final tops = [
      for (final n in ['Ana López', 'Carlos Ruiz', 'María Pérez'])
        tester.getTopLeft(find.text(n)).dy
    ];
    expect(tops.toSet().length, 1);
    expect(tester.getCenter(find.textContaining('Cobrar visita')).dy,
        closeTo(tester.getCenter(find.text('Buscar cliente...')).dy, 2));
    await tester.tap(find.text('Carlos Ruiz'));
    await tester.pumpAndSettle();
    expect(c.selectedClient.value?.name, 'Carlos Ruiz');
    expect(tester.takeException(), isNull);
  }, variant: escritorio);

  testWidgets('abonar en escritorio: pasos y, al lado, resumen y cobro',
      (tester) async {
    abonar();
    await mostrar(tester, const AbonarView(), const Size(1280, 800));
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Resumen')).dx,
        greaterThan(tester.getTopRight(find.text('¿Cuánto tiempo paga?')).dx));
    expect(tester.getTopLeft(find.text('Cobrar \$500')).dx,
        greaterThan(tester.getCenter(find.text('Efectivo')).dx));
    expect(tester.takeException(), isNull);
  }, variant: escritorio);

  testWidgets('abonar en escritorio cabe con texto grande', (tester) async {
    Get.put(AbonarController(
      userRepository: _Usuarios(_tresClientes()),
      ingresoService: _Ingresos(),
      pricesRepository: _Precios(),
    ));
    final c = Get.find<AbonarController>();
    for (final escala in [1.0, 1.3, 2.0]) {
      for (final tamano in [
        const Size(960, 600),
        const Size(1280, 800),
        const Size(1920, 1000),
      ]) {
        c.selectedClient.value = null;
        await mostrar(tester, const AbonarView(), tamano, escala: escala);
        expect(tester.takeException(), isNull,
            reason: 'buscar $tamano, texto $escala');
        c.selectedClient.value = c.searchResults.first;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'cobro $tamano, texto $escala');
      }
    }
  }, variant: escritorio);

  testWidgets('abonar cabe con texto grande, de pie y acostada',
      (tester) async {
    abonar();
    for (final escala in [1.3, 2.0]) {
      for (final tamano in [const Size(1180, 820), const Size(820, 1180)]) {
        await mostrar(tester, const AbonarView(), tamano, escala: escala);
        expect(tester.takeException(), isNull,
            reason: '$tamano, texto $escala');
      }
    }
  }, variant: _tabletas);

  testWidgets('venta acostada: el carrito al lado, como en escritorio',
      (tester) async {
    final c = Get.put<PointOfSaleController>(_Venta());
    await mostrar(tester, const PointOfSaleView(), const Size(1180, 820));
    expect(find.text('Venta actual'), findsOneWidget);
    await c.addProductToCart(Product(
      id: '1',
      name: 'Agua natural 1 L',
      description: '',
      categoryId: null,
      price: 15,
      stock: 10,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ListaCarrito), findsOneWidget);
    // De pie no cabe: el resumen va abajo, como antes.
    await mostrar(tester, const PointOfSaleView(), const Size(820, 1180));
    expect(find.text('Venta actual'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);
}

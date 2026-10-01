import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:gymads/app/modules/abonar/views/abonar_view.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Usuarios extends Fake implements UserRepository {
  @override
  Future<List<UserModel>> getAllUsers() async => [];
}

class _Precios extends Fake implements AbonoPricesRepository {
  _Precios(this.precios);
  final AbonoPricesModel precios;

  @override
  Future<AbonoPricesModel> getPrices() async => precios;
}

class _Ingresos extends Fake implements IngresoService {}

class _SinTours implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async => {};
  @override
  Future<void> marcarVisto(String rol, String tourId) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.put(WelcomeTourService(
      toursDelEmpleado: _SinTours(),
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'owner_admin', esEmpleado: false),
    ));
  });
  tearDown(Get.reset);

  Future<AbonarController> abrir(WidgetTester tester, AbonoPricesModel precios,
      {double ancho = 390}) async {
    tester.view.physicalSize = Size(ancho, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final controller = Get.put(AbonarController(
      userRepository: _Usuarios(),
      ingresoService: _Ingresos(),
      pricesRepository: _Precios(precios),
    ));
    controller.selectedClient.value = UserModel(
      name: 'Juan Pérez',
      phone: '+520000000000',
      joinDate: DateTime(2026, 1, 1),
      userNumber: '1',
    );
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.oscuro,
      home: const AbonarView(),
    ));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
      'costo fijo: cada paso se cierra al continuar y el último dice cuánto '
      'se cobra', (tester) async {
    await abrir(tester,
        const AbonoPricesModel(priceMonth: 500, priceWeek: 150));

    expect(find.text('Cliente nuevo'), findsOneWidget);
    // Paso 1 abierto, solo con los periodos que tienen precio.
    expect(find.text('1 semana'), findsOneWidget);
    expect(find.text('1 día'), findsNothing);
    // Los pasos que siguen se ven, pero sin su contenido.
    expect(find.text('¿Cómo paga?'), findsOneWidget);
    expect(find.text('Efectivo'), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.byTooltip('Uno más'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Paso 1 cerrado con lo elegido; paso 2 abierto.
    expect(find.text('2 meses · \$1,000'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(find.byTooltip('Uno más'), findsNothing);
    expect(find.text('Efectivo'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Los dos cerrados; el resumen abierto y el botón con el monto.
    expect(find.text('Cambiar'), findsNWidgets(2));
    expect(find.text('2 meses × \$500'), findsOneWidget);
    expect(find.textContaining('Pagado hasta: '), findsOneWidget);
    expect(find.text('Cobrar \$1,000'), findsOneWidget);

    // "Cambiar" en el paso 1 lo vuelve a abrir.
    await tester.tap(find.text('Cambiar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 semana'));
    await tester.pump();
    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('2 semanas · \$300'), findsOneWidget);
  });

  testWidgets('abono libre: sin el monto no se puede continuar',
      (tester) async {
    await abrir(tester, const AbonoPricesModel(priceMonth: 500));

    await tester.tap(find.text('Abono libre'));
    await tester.pump();
    expect(find.text('Escribe cuánto paga'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monto_libre')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('monto_libre')), '800');
    await tester.pump();
    expect(find.text('Escribe cuánto paga'), findsNothing);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Cobrar \$800'), findsOneWidget);
  });

  testWidgets('sin precios configurados abre directo en abono libre',
      (tester) async {
    await abrir(tester, const AbonoPricesModel());

    expect(find.text('Costo fijo'), findsNothing);
    expect(find.byKey(const Key('monto_libre')), findsOneWidget);
    expect(find.text('1 día'), findsWidgets);
  });

  testWidgets('en un teléfono angosto no se sale nada', (tester) async {
    final controller = await abrir(
        tester,
        const AbonoPricesModel(
            priceMonth: 12500, priceWeek: 3500, priceDay: 50, priceYear: 99999),
        ancho: 320);
    for (var i = 0; i < 11; i++) {
      controller.incrementDuration();
    }
    await tester.tap(find.text('1 semana'));
    await tester.pumpAndSettle();
    expect(find.text('12 semanas'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

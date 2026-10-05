import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:gymads/app/modules/abonar/views/abonar_view.dart';
import 'package:gymads/app/modules/home/controllers/resumen_del_dia.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// "Cobrar visita" en Abonar sale con su precio desde el primer cuadro si ya
/// se conocía, en teléfono, tableta y escritorio: antes aparecía sin precio y
/// un instante después con él.

class _Usuarios extends Fake implements UserRepository {
  @override
  Future<List<UserModel>> getAllUsers() async => [];
}

/// Precios que tardan en llegar: hasta que la prueba completa la consulta.
class _PreciosLentos extends Fake implements AbonoPricesRepository {
  final consulta = Completer<AbonoPricesModel>();
  @override
  Future<AbonoPricesModel> getPrices() => consulta.future;
}

class _Ingresos extends Fake implements IngresoService {}

class _SinTours implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async => {};
  @override
  Future<void> marcarVisto(String rol, String tourId) async {}
}

class _Tenant extends GetxService implements TenantContextService {
  @override
  String? get currentGymId => 'gym';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _versiones = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.macOS,
  TargetPlatform.windows,
});

const _precios = AbonoPricesModel(priceDay: 50, priceMonth: 500);

void main() {
  late ShowcaseView tour;
  setUp(() {
    tour = ShowcaseView.register();
    SharedPreferences.setMockInitialValues({});
    AbonoPricesRepository.olvidarParaPruebas();
    Get.put<TenantContextService>(_Tenant());
    Get.put(WelcomeTourService(
      toursDelEmpleado: _SinTours(),
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'owner_admin', esEmpleado: false),
    ));
  });
  tearDown(() {
    tour.unregister();
    AbonoPricesRepository.olvidarParaPruebas();
    Get.reset();
  });

  /// Abre Abonar y deja que termine de mostrarse, con la consulta de
  /// precios todavía pendiente.
  Future<_PreciosLentos> abrir(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _PreciosLentos();
    Get.put(AbonarController(
      userRepository: _Usuarios(),
      ingresoService: _Ingresos(),
      pricesRepository: repo,
    ));
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.oscuro,
      home: const AbonarView(),
    ));
    await tester.pumpAndSettle();
    expect(repo.consulta.isCompleted, isFalse);
    return repo;
  }

  for (final tamano in [const Size(390, 844), const Size(1280, 820)]) {
    testWidgets(
        'con precio conocido, sale con él desde el primer cuadro '
        '(${tamano.width.toInt()})', (tester) async {
      AbonoPricesRepository.recordarParaPruebas('gym', _precios);
      final repo = await abrir(tester, tamano);
      expect(find.text('Cobrar visita · \$50'), findsOneWidget);
      expect(find.text('Cobrar visita'), findsNothing);
      // Llegan los mismos precios: no cambia nada.
      repo.consulta.complete(_precios);
      await tester.pumpAndSettle();
      expect(find.text('Cobrar visita · \$50'), findsOneWidget);
    }, variant: _versiones);

    testWidgets(
        'si el precio cambió, se actualiza al llegar '
        '(${tamano.width.toInt()})', (tester) async {
      AbonoPricesRepository.recordarParaPruebas('gym', _precios);
      final repo = await abrir(tester, tamano);
      repo.consulta.complete(const AbonoPricesModel(priceDay: 70));
      await tester.pumpAndSettle();
      expect(find.text('Cobrar visita · \$70'), findsOneWidget);
    }, variant: _versiones);

    testWidgets(
        'sin precio configurado, se queda como estaba '
        '(${tamano.width.toInt()})', (tester) async {
      AbonoPricesRepository.recordarParaPruebas(
          'gym', const AbonoPricesModel());
      final repo = await abrir(tester, tamano);
      expect(find.text('Cobrar visita'), findsOneWidget);
      repo.consulta.complete(const AbonoPricesModel());
      await tester.pumpAndSettle();
      expect(find.text('Cobrar visita'), findsOneWidget);
    }, variant: _versiones);
  }

  test('el panel del día parte del precio conocido', () {
    AbonoPricesRepository.recordarParaPruebas('gym', _precios);
    expect(ResumenDelDia(precioDelDia: () async => 50).precioDia.value, 50);
    AbonoPricesRepository.olvidarParaPruebas();
    AbonoPricesRepository.recordarParaPruebas('gym', const AbonoPricesModel());
    expect(ResumenDelDia().precioDia.value, isNull);
  });
}

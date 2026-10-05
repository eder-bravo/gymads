import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/widgets/menu_lateral.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/data/models/staff_profile_model.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/configuracion/bindings/configuracion_binding.dart';
import 'package:gymads/app/modules/configuracion/controllers/abono_prices_controller.dart';
import 'package:gymads/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:gymads/app/modules/inventario/bindings/inventario_binding.dart';
import 'package:gymads/app/modules/inventario/controllers/inventario_controller.dart';
import 'package:gymads/app/modules/configuracion/views/configuracion_view.dart';
import 'package:gymads/app/routes/app_pages.dart';
import 'package:gymads/core/theme/app_theme.dart';

/// Cerrar sesión desde Configuración: la pantalla ya no debe buscar un
/// controlador que acaba de borrarse, en ninguna plataforma.

StaffProfileModel _perfil() => StaffProfileModel(
      id: '1',
      userId: 'u',
      gymId: 'g',
      branchId: 'b',
      role: 'owner_admin',
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Como el real: cerrar sesión pone el perfil en null (y `can` lo lee).
class _Tenant extends GetxService implements TenantContextService {
  @override
  final staffProfileRx = Rx<StaffProfileModel?>(_perfil());
  @override
  bool get isAuthenticated => staffProfileRx.value != null;
  @override
  StaffProfileModel? get staffProfile => staffProfileRx.value;
  @override
  String? get currentGymId => staffProfileRx.value?.gymId;
  @override
  DateTime? get accountCreatedAt => DateTime(2026);
  @override
  bool can(Permission permiso) => staffProfileRx.value != null;
  @override
  Future<void> clearProfile() async => staffProfileRx.value = null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Configuracion extends ConfiguracionController {
  @override
  bool get tieneContrasena => true;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => TenantContextService.to.can(permiso);
  @override
  Future<void> cargarEstadoLector() async {}
  @override
  Future<void> loadControlAccesos() async {}
}

/// Como el real: `fenix`, por si una pantalla vieja se lleva el controlador.
class _Binding extends Bindings {
  @override
  void dependencies() =>
      Get.lazyPut<ConfiguracionController>(() => _Configuracion(), fenix: true);
}

void main() {
  pruebasDeNavegacion();

  test('los bindings compartidos recrean su controlador en vez de fallar',
      () async {
    // Configuración y sus subpantallas; Inventario y su formulario.
    ConfiguracionBinding().dependencies();
    InventarioBinding().dependencies();
    expect(await Get.delete<ConfiguracionController>(), isTrue);
    expect(await Get.delete<AbonoPricesController>(), isTrue);
    expect(await Get.delete<InventarioController>(), isTrue);
    // Quedan registrados: el siguiente `Get.find` los vuelve a crear.
    expect(Get.isRegistered<ConfiguracionController>(), isTrue);
    expect(Get.isRegistered<AbonoPricesController>(), isTrue);
    expect(Get.isRegistered<InventarioController>(), isTrue);
    Get.reset();
  });

  late ShowcaseView tour;
  setUp(() {
    tour = ShowcaseView.register();
    WelcomeTourService.recorridoEnCurso.value = false;
    Get.put<TenantContextService>(_Tenant());
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  const plataformas = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  });

  testWidgets(
      'en computadora, "Cerrar sesión" es un botón; en el teléfono, '
      'la tarjeta de siempre', (tester) async {
    tester.view.physicalSize = const Size(1280, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.claro,
      builder: (context, child) => VentanaEscritorio(child: child!),
      initialRoute: Routes.CONFIGURACION,
      getPages: [
        GetPage(
            name: Routes.CONFIGURACION,
            page: () => const ConfiguracionView(),
            binding: _Binding()),
      ],
    ));
    await tester.pumpAndSettle();
    final boton = find.widgetWithText(OutlinedButton, 'Cerrar sesión');
    final tarjeta = find.widgetWithText(ListTile, 'Cerrar sesión');
    if (PlataformaApp.escritorio) {
      expect(boton, findsOneWidget);
      expect(tarjeta, findsNothing);
      // Alineado con el borde izquierdo de las tarjetas de arriba.
      // (el Card mide también su margen de 4).
      expect(tester.getTopLeft(boton).dx,
          tester.getTopLeft(find.widgetWithText(Card, 'Apariencia')).dx + 4);
    } else {
      expect(boton, findsNothing);
      expect(tarjeta, findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.android,
      }));

  for (final tamano in [const Size(390, 844), const Size(1180, 820)]) {
    testWidgets('cerrar sesión desde Configuración (${tamano.width.toInt()})',
        (tester) async {
      tester.view.physicalSize = tamano * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.oscuro,
        // Como en main.dart: fundido corto en escritorio.
        defaultTransition: PlataformaApp.escritorio ? Transition.fadeIn : null,
        transitionDuration:
            PlataformaApp.escritorio ? const Duration(milliseconds: 160) : null,
        builder: (context, child) => VentanaEscritorio(child: child!),
        initialRoute: Routes.HOME,
        getPages: [
          GetPage(
              name: Routes.HOME,
              page: () => const Scaffold(body: Text('Inicio'))),
          GetPage(
              name: Routes.CONFIGURACION,
              page: () => const ConfiguracionView(),
              binding: _Binding()),
          GetPage(
              name: Routes.LOGIN,
              page: () => const Scaffold(body: Text('Inicia sesión'))),
        ],
      ));
      await tester.pumpAndSettle();
      Get.toNamed(Routes.CONFIGURACION);
      await tester.pumpAndSettle();
      final controlador = Get.find<ConfiguracionController>();

      // Como `logout()`: el diálogo de confirmación, que se cierra justo
      // antes de navegar.
      Get.dialog(const AlertDialog(content: Text('¿Seguro?')));
      await tester.pumpAndSettle();
      Get.back();
      // El orden de _performLogout: cargando, perfil fuera, Login, listo.
      controlador.isLoading.value = true;
      await Get.find<TenantContextService>().clearProfile();
      await tester.pump(const Duration(milliseconds: 1));
      Get.offAllNamed(Routes.LOGIN);
      controlador.isLoading.value = false;
      controlador.userName.value = 'otro';
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Inicia sesión'), findsOneWidget);
    }, variant: plataformas);
  }
}

/// Configuración y Cuenta comparten controlador. Volver a Configuración
/// desde la barra lateral estando en Cuenta saca las dos pantallas y abre una
/// nueva: la vieja, al terminar de salir, no debe llevarse el controlador de
/// la nueva.
void pruebasDeNavegacion() {
  late ShowcaseView tour;
  setUp(() {
    tour = ShowcaseView.register();
    WelcomeTourService.recorridoEnCurso.value = false;
    Get.put<TenantContextService>(_Tenant());
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  testWidgets('volver a Configuración desde Cuenta con la barra lateral',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.oscuro,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 160),
      navigatorObservers: [MenuLateral.observador],
      builder: (context, child) => VentanaEscritorio(child: child!),
      initialRoute: Routes.HOME,
      getPages: [
        GetPage(
            name: Routes.HOME,
            page: () => const Scaffold(body: Text('Inicio'))),
        GetPage(
            name: Routes.CONFIGURACION,
            page: () => const ConfiguracionView(),
            binding: _Binding()),
        GetPage(
            name: Routes.CUENTA,
            page: () => const Scaffold(body: Text('Cuenta')),
            binding: _Binding()),
      ],
    ));
    await tester.pumpAndSettle();
    Get.toNamed(Routes.CONFIGURACION);
    await tester.pumpAndSettle();
    Get.toNamed(Routes.CUENTA);
    await tester.pumpAndSettle();

    MenuLateral.ir(Routes.CONFIGURACION);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.CONFIGURACION);
    expect(Get.isRegistered<ConfiguracionController>(), isTrue,
        reason: 'el controlador de la pantalla nueva sigue ahí');

    // Cerrar sesión: el perfil sale y la pantalla se redibuja.
    await Get.find<TenantContextService>().clearProfile();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));

  // En teléfono y tableta no hay barra lateral, pero reemplazar Configuración
  // por sí misma (o por una hermana) tiene el mismo cruce.
  for (final tamano in [const Size(390, 844), const Size(1180, 820)]) {
    testWidgets(
        'reemplazar Configuración por sí misma (${tamano.width.toInt()})',
        (tester) async {
      tester.view.physicalSize = tamano * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.oscuro,
        builder: (context, child) => VentanaEscritorio(child: child!),
        initialRoute: Routes.HOME,
        getPages: [
          GetPage(
              name: Routes.HOME,
              page: () => const Scaffold(body: Text('Inicio'))),
          GetPage(
              name: Routes.CONFIGURACION,
              page: () => const ConfiguracionView(),
              binding: _Binding()),
          GetPage(
              name: Routes.CUENTA,
              page: () => const Scaffold(body: Text('Cuenta')),
              binding: _Binding()),
        ],
      ));
      await tester.pumpAndSettle();
      Get.toNamed(Routes.CONFIGURACION);
      await tester.pumpAndSettle();
      Get.toNamed(Routes.CUENTA);
      await tester.pumpAndSettle();
      // Reemplaza las dos por una nueva, sin esperar a que terminen de salir.
      Get.offNamedUntil(
          Routes.CONFIGURACION, (r) => r.settings.name == Routes.HOME);
      await tester.pumpAndSettle();
      await Get.find<TenantContextService>().clearProfile();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(Get.isRegistered<ConfiguracionController>(), isTrue);
    },
        variant: const TargetPlatformVariant(
            {TargetPlatform.android, TargetPlatform.iOS}));
  }
}

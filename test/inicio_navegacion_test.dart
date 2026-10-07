import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/widgets/menu_lateral.dart';
import 'package:gymads/app/data/models/staff_profile_model.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/app/modules/home/controllers/home_controller.dart';
import 'package:gymads/app/modules/home/views/home_view.dart';
import 'package:gymads/app/routes/app_pages.dart';
import 'package:gymads/core/theme/app_theme.dart';

import 'herramientas/resumen_de_prueba.dart';

/// Inicio al navegar, en los tres diseños: entrar a una sección y volver,
/// volver reemplazando la pila (como al terminar los permisos o el modo de
/// cobro: por un momento hay dos Inicio montados), girar o redimensionar.
/// Ninguno debe lanzar errores, como "setState() called during build".

class _Inicio extends HomeController {
  @override
  void onReady() {}
  @override
  Future<void> checkOnboarding() async {}
  @override
  bool can(Permission permiso) => true;
}

class _Tenant extends GetxService implements TenantContextService {
  @override
  final staffProfileRx = Rx<StaffProfileModel?>(null);
  @override
  bool get isAuthenticated => true;
  @override
  bool can(Permission permiso) => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Diseno = ({String nombre, TargetPlatform plataforma, Size tamano});

const _disenos = <_Diseno>[
  (
    nombre: 'teléfono',
    plataforma: TargetPlatform.android,
    tamano: Size(390, 844)
  ),
  (nombre: 'teléfono', plataforma: TargetPlatform.iOS, tamano: Size(390, 844)),
  (nombre: 'tableta', plataforma: TargetPlatform.iOS, tamano: Size(1180, 820)),
  (
    nombre: 'tableta',
    plataforma: TargetPlatform.android,
    tamano: Size(1280, 800)
  ),
  (
    nombre: 'escritorio',
    plataforma: TargetPlatform.macOS,
    tamano: Size(1280, 800)
  ),
  (
    nombre: 'escritorio',
    plataforma: TargetPlatform.windows,
    tamano: Size(1920, 1080)
  ),
  (
    nombre: 'escritorio',
    plataforma: TargetPlatform.linux,
    tamano: Size(1920, 1080)
  ),
];

Future<void> _app(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  GetPage seccion(String ruta, String titulo) => GetPage(
        name: ruta,
        page: () => ScaffoldAdaptable(
          appBar: GymAppBar(title: titulo),
          body: Text('Pantalla de $titulo'),
        ),
      );
  await tester.pumpWidget(GetMaterialApp(
    theme: AppTheme.oscuro,
    builder: (context, child) => VentanaEscritorio(child: child!),
    initialRoute: Routes.HOME,
    navigatorObservers: [MenuLateral.observador],
    getPages: [
      GetPage(name: Routes.HOME, page: () => const HomeView()),
      seccion(Routes.CLIENTES, 'Clientes'),
      seccion(Routes.ONBOARDING_PAYMENT_MODE, 'Modo de cobro'),
    ],
  ));
  await tester.pumpAndSettle();
}

void main() {
  late ShowcaseView tour;
  setUp(() {
    tour = ShowcaseView.register();
    WelcomeTourService.recorridoEnCurso.value = false;
    Get.put<TenantContextService>(_Tenant());
    Get.put<HomeController>(_Inicio());
    Get.put(resumenDePrueba());
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  for (final d in _disenos) {
    testWidgets(
        '${d.nombre} (${d.plataforma.name}): Inicio sin errores al navegar',
        (tester) async {
      await _app(tester, d.tamano);
      expect(tester.takeException(), isNull, reason: 'al abrir');

      // Entrar a una sección y volver.
      Get.toNamed(Routes.CLIENTES);
      await tester.pumpAndSettle();
      Get.back();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'al volver');

      // Volver reemplazando la pila, desde el modo de cobro.
      for (final ruta in [Routes.ONBOARDING_PAYMENT_MODE]) {
        Get.toNamed(ruta);
        await tester.pumpAndSettle();
        Get.offAllNamed(Routes.HOME);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'desde $ruta');
      }
      // Dos veces seguidas sobre el mismo Inicio.
      Get.offAllNamed(Routes.HOME);
      Get.offAllNamed(Routes.HOME);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'doble reemplazo');

      // Girar la tableta / cambiar el tamaño de la ventana.
      tester.view.physicalSize = d.tamano.flipped * 2;
      await tester.pumpAndSettle();
      tester.view.physicalSize = d.tamano * 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'al girar');

      // En pantalla grande los números de hoy siguen ahí.
      if (d.nombre != 'teléfono') {
        expect(find.text('\$4,350'), findsOneWidget);
      }
    }, variant: TargetPlatformVariant({d.plataforma}));
  }

  testWidgets('escritorio: cambiar de sección con la barra y volver a Inicio',
      (tester) async {
    await _app(tester, const Size(1280, 800));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de Clientes'), findsOneWidget);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Accesos rápidos'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'vuelta $i');
    }
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.macOS, TargetPlatform.windows}));
}

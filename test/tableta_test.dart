import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/widgets/menu_lateral.dart';
import 'package:gymads/app/data/models/staff_profile_model.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/home/controllers/home_controller.dart';
import 'package:gymads/app/modules/home/views/home_view.dart';
import 'package:gymads/core/theme/app_theme.dart';

import 'herramientas/resumen_de_prueba.dart';

const _tabletas =
    TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});

class _Inicio extends HomeController {
  final abiertos = <String>[];
  @override
  void goToConfiguracion() => abiertos.add('Configuración');
  @override
  void goToPointOfSale() => abiertos.add('Vender');
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

/// Un iPad de 11" (o una tableta Android de 10") en puntos.
Future<void> _pantalla(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

Future<void> _mostrar(WidgetTester tester, Widget pantalla,
    {Size tamano = const Size(1180, 820), double escala = 1}) async {
  await _pantalla(tester, tamano);
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

void main() {
  late ShowcaseView tour;
  setUp(() {
    tour = ShowcaseView.register();
    WelcomeTourService.recorridoEnCurso.value = false;
    Get.put<TenantContextService>(_Tenant());
    Get.put(resumenDePrueba());
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  testWidgets('tableta: iPad o Android con 720 puntos o más de lado corto',
      (tester) async {
    for (final (tamano, esTableta) in [
      (const Size(1180, 820), true), // iPad acostado
      (const Size(820, 1180), true), // iPad de pie
      (const Size(1366, 1024), true), // iPad Pro 12.9"
      (const Size(600, 960), false), // tableta de 7–8": como teléfono
      (const Size(390, 844), false), // teléfono
    ]) {
      await _pantalla(tester, tamano);
      expect(PlataformaApp.tableta, esTableta, reason: '$tamano');
      expect(PlataformaApp.pantallaGrande, esTableta, reason: '$tamano');
      expect(PlataformaApp.escritorio, isFalse);
      expect(PlataformaApp.equipo, esTableta ? 'dispositivo' : 'teléfono');
      expect(PlataformaApp.elegir(escritorio: 'grande', movil: 'chica'),
          esTableta ? 'grande' : 'chica');
    }
  }, variant: _tabletas);

  testWidgets('en escritorio no cuenta como tableta', (tester) async {
    await _pantalla(tester, const Size(1180, 820));
    expect(PlataformaApp.tableta, isFalse);
    expect(PlataformaApp.pantallaGrande, isTrue);
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.macOS, TargetPlatform.windows}));

  testWidgets(
      'inicio de tableta: números arriba, un dato en cada recuadro y '
      'actividad debajo', (tester) async {
    final inicio = Get.put<HomeController>(_Inicio()) as _Inicio;
    await _mostrar(tester, const HomeView());
    // Sin barra lateral: en tableta se navega desde Inicio.
    expect(find.byType(MenuLateral), findsNothing);
    // Los números de hoy van encima de los módulos.
    expect(find.text('\$4,350'), findsOneWidget);
    expect(tester.getTopLeft(find.text('38')).dy,
        lessThan(tester.getTopLeft(find.text('Vender')).dy));
    // Cada recuadro dice algo del día.
    expect(find.text('1 venta hoy'), findsOneWidget);
    expect(find.text('1 membresía cobrada hoy'), findsOneWidget);
    expect(find.text('6 con membresía vigente'), findsOneWidget);
    // Inventario ocupa todo su lugar, del ancho de Abonar y Clientes juntos.
    final inventario = tester.getRect(find
        .ancestor(of: find.text('Inventario'), matching: find.byType(InkWell))
        .first);
    final abonar = tester.getRect(find
        .ancestor(of: find.text('Abonar'), matching: find.byType(InkWell))
        .first);
    final clientes = tester.getRect(find
        .ancestor(of: find.text('Clientes'), matching: find.byType(InkWell))
        .first);
    expect(inventario.left, closeTo(abonar.left, 1));
    expect(inventario.right, closeTo(clientes.right, 1));
    // Configuración con su nombre, no un engrane solo.
    await tester.tap(find.text('Configuración'));
    await tester.tap(find.text('Vender'));
    await tester.pump();
    expect(inicio.abiertos, ['Configuración', 'Vender']);
    // Debajo, la actividad del día.
    await tester.scrollUntilVisible(find.text('Últimas entradas'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Últimas entradas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);

  testWidgets('inicio de tableta cabe de pie, acostado y con texto grande',
      (tester) async {
    Get.put<HomeController>(_Inicio());
    for (final escala in [1.0, 1.3, 2.0]) {
      for (final tamano in [
        const Size(1180, 820),
        const Size(820, 1180),
        const Size(1366, 1024),
        const Size(744, 1133), // iPad mini
      ]) {
        await _mostrar(tester, const HomeView(),
            tamano: tamano, escala: escala);
        expect(tester.takeException(), isNull,
            reason: 'Inicio $tamano, texto $escala');
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Inicio $tamano, texto $escala, al desplazar');
      }
    }
  }, variant: _tabletas);

  testWidgets('la ventana modal deja espacio al teclado en pantalla',
      (tester) async {
    await _mostrar(tester, const Scaffold(body: SizedBox.expand()));
    abrirFormulario(() => Scaffold(
          appBar: AppBar(title: const Text('Formulario')),
          body: const TextField(),
          bottomNavigationBar: const Text('Guardar'),
        ));
    await tester.pumpAndSettle();
    expect(find.byType(VentanaFormulario), findsOneWidget);
    final formulario = find.ancestor(
        of: find.text('Formulario'), matching: find.byType(Scaffold));
    final alto = tester.getSize(formulario).height;
    // Teclado de 340 puntos.
    tester.view.viewInsets = const FakeViewPadding(bottom: 680);
    await tester.pumpAndSettle();
    final conTeclado = tester.getRect(find.text('Guardar'));
    expect(conTeclado.bottom, lessThanOrEqualTo(820 - 340));
    expect(tester.getSize(formulario).height, lessThan(alto));
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);
}

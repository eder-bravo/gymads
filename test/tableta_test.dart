import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
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
    VentanaEscritorio.margenDeControles.value = 0;
  });

  // ─── Ventanas (iPadOS 26+ y tabletas Android) ───

  test('la escala de tableta no baja de 100 %', () {
    double e(double a, double b) =>
        VentanaEscritorio.escalaDeTableta(Size(a, b));
    // El mínimo de la ventana en iPad.
    expect(
        e(VentanaEscritorio.minimoTableta.width,
            VentanaEscritorio.minimoTableta.height),
        1.1);
    expect(e(500, 700), 1.0);
  });

  testWidgets('los botones de la ventana no tapan la barra superior',
      (tester) async {
    Get.put<HomeController>(_Inicio());
    const modulo = ScaffoldAdaptable(
      appBar: GymAppBar(title: 'Módulo'),
      body: SizedBox.expand(),
    );
    await _mostrar(tester, modulo);
    final sinControles = tester.getTopLeft(find.text('Módulo')).dy;
    // iPadOS 26+ en ventana: 32 puntos de botones arriba a la izquierda.
    VentanaEscritorio.margenDeControles.value = 32;
    await tester.pumpAndSettle();
    // La barra baja exactamente lo que ocupan los botones en la pantalla,
    // con cualquier escala.
    expect(tester.getTopLeft(find.text('Módulo')).dy - sinControles,
        closeTo(32, 0.5));
    // Inicio también.
    await _mostrar(tester, const HomeView());
    final inicio = tester.getTopLeft(find.text('Inicio')).dy;
    VentanaEscritorio.margenDeControles.value = 0;
    await tester.pumpAndSettle();
    expect(
        inicio - tester.getTopLeft(find.text('Inicio')).dy, closeTo(32, 0.5));
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);

  testWidgets('cambiar el tamaño de la ventana no vuelve a montar la pantalla',
      (tester) async {
    final campo = TextEditingController();
    addTearDown(campo.dispose);
    await _mostrar(
        tester, Scaffold(body: Center(child: TextField(controller: campo))));
    await tester.enterText(find.byType(TextField), 'Juan');
    final estado = tester.state(find.byType(TextField));
    // De 125 % a 110 % (el mínimo), con y sin los botones de la ventana.
    for (final tamano in [
      const Size(900, 760),
      VentanaEscritorio.minimoTableta,
      const Size(1366, 1024),
    ]) {
      await _pantalla(tester, tamano);
      VentanaEscritorio.margenDeControles.value =
          VentanaEscritorio.margenDeControles.value == 0 ? 32 : 0;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TextField)), same(estado),
          reason: '$tamano');
      expect(campo.text, 'Juan');
    }
  }, variant: _tabletas);

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

  testWidgets('inicio de tableta: números arriba y un dato en cada recuadro',
      (tester) async {
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
    // Sin la sección de actividad: los números de arriba ya lo dicen.
    expect(find.text('Últimas entradas'), findsNothing);
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

  testWidgets(
      'inicio de tableta de pie: Vender a lo ancho arriba y los demás en '
      'una fila abajo', (tester) async {
    Get.put<HomeController>(_Inicio());
    for (final tamano in [const Size(1024, 1366), const Size(820, 1180)]) {
      for (final escala in [1.0, 1.3, 2.0]) {
        await _mostrar(tester, const HomeView(),
            tamano: tamano, escala: escala);
        expect(tester.takeException(), isNull,
            reason: 'de pie $tamano, texto $escala');
      }
      await _mostrar(tester, const HomeView(), tamano: tamano);
      Rect tarjeta(String texto) => tester.getRect(find
          .ancestor(of: find.text(texto), matching: find.byType(InkWell))
          .first);
      final vender = tarjeta('Vender');
      final abonar = tarjeta('Abonar');
      final clientes = tarjeta('Clientes');
      final inventario = tarjeta('Inventario');
      // Vender ocupa todo el ancho de la fila de abajo.
      expect(vender.left, closeTo(abonar.left, 1));
      expect(vender.right, closeTo(inventario.right, 1));
      // Los otros tres, debajo de Vender y en la misma fila.
      for (final r in [abonar, clientes, inventario]) {
        expect(r.top, greaterThan(vender.bottom));
        expect(r.top, closeTo(abonar.top, 1));
      }
    }
    // Acostada, Vender sigue a la izquierda de los demás.
    await _mostrar(tester, const HomeView());
    expect(
        tester
            .getRect(find
                .ancestor(
                    of: find.text('Abonar'), matching: find.byType(InkWell))
                .first)
            .left,
        greaterThan(tester
            .getRect(find
                .ancestor(
                    of: find.text('Vender'), matching: find.byType(InkWell))
                .first)
            .right));
  }, variant: _tabletas);

  test('escala de tableta según el lado corto, igual acostada o de pie', () {
    double e(double a, double b) =>
        VentanaEscritorio.escalaDeTableta(Size(a, b));
    expect(e(1180, 820), 1.25); // iPad de 11"
    expect(e(820, 1180), 1.25);
    expect(e(1133, 744), 1.15); // iPad mini
    expect(e(1366, 1024), 1.5); // iPad de 13" (Air M2 o Pro), con tope
    expect(e(1024, 1366), 1.5);
    expect(e(1500, 1100), 1.5); // más grande: no pasa del tope
    expect(e(1280, 800), 1.25); // Android de 10"
  });

  testWidgets('todas las pantallas crecen igual, Inicio incluido',
      (tester) async {
    Get.put<HomeController>(_Inicio());
    await _mostrar(
        tester,
        const ScaffoldAdaptable(
            body: Text('Módulo', style: TextStyle(fontSize: 20))));
    // Se ve al 125 %: lo que mide el texto, por 1.25 en la pantalla.
    expect(tester.getRect(find.text('Módulo')).height,
        closeTo(tester.getSize(find.text('Módulo')).height * 1.25, 0.5));
    expect(MediaQuery.sizeOf(tester.element(find.text('Módulo'))),
        const Size(944, 656));

    await _mostrar(tester, const HomeView());
    // Inicio, en proporción con las demás pantallas.
    expect(MediaQuery.sizeOf(tester.element(find.text('Vender'))),
        const Size(944, 656));
    expect(tester.takeException(), isNull);
  }, variant: _tabletas);

  testWidgets('en teléfono y tableta chica no hay escala', (tester) async {
    for (final tamano in [const Size(390, 844), const Size(600, 960)]) {
      await _mostrar(tester, const Scaffold(body: Text('Módulo')),
          tamano: tamano);
      expect(MediaQuery.sizeOf(tester.element(find.text('Módulo'))), tamano);
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

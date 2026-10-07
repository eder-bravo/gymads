import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class _Acceso implements ToursDelEmpleado {
  final vistos_ = <String>{};
  @override
  Future<Set<String>?> vistos(String rol) async => {...vistos_};
  @override
  Future<void> marcarVisto(String rol, String tourId) async =>
      vistos_.add(tourId);
}

void main() {
  const moviles =
      TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});
  late WelcomeTourService tours;
  late _Acceso acceso;
  late GlobalKey<NavigatorState> navegador;
  late List<GlobalKey> pasos;
  late GetPageRoute<void> ruta;
  var tocados = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    acceso = _Acceso();
    navegador = GlobalKey<NavigatorState>();
    pasos = [GlobalKey(), GlobalKey()];
    tocados = 0;
    tours = WelcomeTourService(
      toursDelEmpleado: acceso,
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'mostrador', esEmpleado: true),
    ).init();
  });

  tearDown(() {
    tours.cancelarRecorridoEnCurso();
    tours.dejarDeEscuchar();
    ShowcaseView.get().unregister();
    WelcomeTourService.recorridoEnCurso.value = false;
    Get.reset();
  });

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> mostrar(WidgetTester tester, {bool iniciar = true}) async {
    await tester.pumpWidget(GetMaterialApp(
      navigatorKey: navegador,
      navigatorObservers: [WelcomeTourService.observador],
      home: const Scaffold(body: Text('Inicio')),
    ));
    ruta = GetPageRoute<void>(
      popGesture: true,
      page: () => Scaffold(
        appBar: AppBar(title: const Text('Pantalla guiada')),
        body: Column(children: [
          TextButton(
              onPressed: () => tocados++, child: const Text('Fuera del paso')),
          for (var i = 0; i < pasos.length; i++)
            TourStep(
              tourKey: pasos[i],
              title: 'Paso ${i + 1}',
              description: 'Guía ${i + 1}',
              isFirstStep: i == 0,
              isLastStep: i == pasos.length - 1,
              child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: TextButton(
                      onPressed: () => tocados++, child: Text('Bloque $i'))),
            ),
        ]),
      ),
    );
    navegador.currentState!.push(ruta);
    await tester.pumpAndSettle();
    if (iniciar) {
      final arranque = tours.startIfPending(AppTours.inventario, pasos);
      await esperar(tester);
      await arranque;
      await esperar(tester);
      expect(find.text('Guía 1'), findsOneWidget);
      expect(WelcomeTourService.recorridoEnCurso.value, isTrue);
    }
  }

  testWidgets('Atrás y el gesto de borde quedan bloqueados hasta saltar',
      (tester) async {
    await mostrar(tester);
    expect(ruta.popDisposition, RoutePopDisposition.doNotPop);
    expect(ruta.popGestureEnabled, isFalse);
    await tester.binding.handlePopRoute();
    await esperar(tester);
    await tester.dragFrom(const Offset(1, 300), const Offset(750, 0));
    await esperar(tester);
    expect(ruta.isCurrent, isTrue);
    expect(find.text('Guía 1'), findsOneWidget);
    expect(acceso.vistos_, isEmpty);

    await tester.tap(find.text('Saltar'));
    await esperar(tester);
    expect(ruta.popGestureEnabled, isTrue);
    expect(ruta.popDisposition, RoutePopDisposition.pop);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(acceso.vistos_, contains(AppTours.inventario));
  }, variant: moviles);

  testWidgets(
      'solo funcionan los botones del recorrido; terminar libera la pantalla',
      (tester) async {
    await mostrar(tester);
    await tester.tapAt(tester.getCenter(find.text('Fuera del paso')));
    await tester.tapAt(tester.getCenter(find.text('Bloque 0')));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await esperar(tester);
    expect(tocados, 0);
    await tester.tap(find.text('Siguiente'));
    await esperar(tester);
    expect(find.text('Guía 2'), findsOneWidget);
    expect(ruta.popDisposition, RoutePopDisposition.doNotPop);
    await tester.tap(find.text('Entendido'));
    await esperar(tester);
    await tester.tap(find.text('Fuera del paso'));
    expect(tocados, 1);
    expect(ruta.popDisposition, RoutePopDisposition.pop);
  }, variant: moviles);

  testWidgets('si la app cambia de pantalla cancela la guía sin marcarla vista',
      (tester) async {
    await mostrar(tester);
    navegador.currentState!.push(GetPageRoute<void>(
      page: () => const Scaffold(body: Text('Otra pantalla')),
    ));
    await esperar(tester);
    expect(find.text('Otra pantalla'), findsOneWidget);
    expect(find.text('Guía 1'), findsNothing);
    expect(WelcomeTourService.recorridoEnCurso.value, isFalse);
    expect(await tours.isPending(AppTours.inventario), isTrue);
    expect(acceso.vistos_, isEmpty);
  }, variant: moviles);

  testWidgets('sin recorrido se puede salir con Atrás', (tester) async {
    await mostrar(tester, iniciar: false);
    expect(ruta.popGestureEnabled, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
  }, variant: moviles);
}

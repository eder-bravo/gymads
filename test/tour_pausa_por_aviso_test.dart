import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// Un empleado que todavía no ha visto ningún recorrido.
class _Acceso implements ToursDelEmpleado {
  final vistos_ = <String>{};
  @override
  Future<Set<String>?> vistos(String rol) async => {...vistos_};
  @override
  Future<void> marcarVisto(String rol, String tourId) async =>
      vistos_.add(tourId);
}

void main() {
  final pasos = [GlobalKey(), GlobalKey(), GlobalKey()];
  final navegador = GlobalKey<NavigatorState>();
  late WelcomeTourService tours;
  late _Acceso acceso;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    acceso = _Acceso();
    tours = WelcomeTourService(
      toursDelEmpleado: acceso,
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'mostrador', esEmpleado: true),
    ).init();
  });
  tearDown(() {
    // Cada prueba registra su propio tour: el anterior no debe quedar abierto.
    final tour = ShowcaseView.get();
    if (tour.isShowcaseRunning) tour.dismiss();
    tour.unregister();
    WelcomeTourService.recorridoEnCurso.value = false;
  });

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Inicio con tres pasos y su recorrido ya en pantalla, en el paso 1.
  Future<void> inicioConTour(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navegador,
      home: Scaffold(
        body: Column(children: [
          for (var i = 0; i < 3; i++)
            TourStep(
              tourKey: pasos[i],
              title: 'Paso ${i + 1}',
              description: 'Explicación ${i + 1}',
              isFirstStep: i == 0,
              isLastStep: i == 2,
              child: SizedBox(height: 120, child: Text('Bloque ${i + 1}')),
            ),
        ]),
      ),
    ));
    // showcaseview registra los pasos al reconstruirse la pantalla.
    navegador.currentState!.push(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Otra'))));
    await tester.pumpAndSettle();
    navegador.currentState!.pop();
    await tester.pumpAndSettle();

    final arranque = tours.startIfPending(AppTours.home, pasos);
    await esperar(tester);
    await arranque;
    await esperar(tester);
    expect(find.text('Explicación 1'), findsOneWidget);
  }

  Future<void> siguiente(WidgetTester tester) async {
    ShowcaseView.get().next();
    await esperar(tester);
  }

  testWidgets(
      'llega un aviso a mitad del recorrido: se oculta y al cerrarse vuelve '
      'en el mismo paso', (tester) async {
    await inicioConTour(tester);
    await siguiente(tester);
    expect(find.text('Explicación 2'), findsOneWidget);

    WelcomeTourService.avisoAbierto();
    await esperar(tester);
    expect(find.text('Explicación 2'), findsNothing);
    expect(WelcomeTourService.recorridoEnCurso.value, isFalse);
    // Pausado no es visto.
    expect(await tours.isPending(AppTours.home), isTrue);

    WelcomeTourService.avisoCerrado();
    await esperar(tester);
    expect(find.text('Explicación 2'), findsOneWidget);
    expect(find.text('Explicación 1'), findsNothing);

    // Terminado después de retomarlo, queda visto.
    await siguiente(tester);
    expect(find.text('Explicación 3'), findsOneWidget);
    await siguiente(tester);
    expect(acceso.vistos_, contains(AppTours.home));
  });

  testWidgets('dos avisos seguidos: vuelve al cerrarse el último',
      (tester) async {
    await inicioConTour(tester);

    WelcomeTourService.avisoAbierto();
    await esperar(tester);
    WelcomeTourService.avisoAbierto();
    await esperar(tester);
    WelcomeTourService.avisoCerrado();
    await esperar(tester);
    expect(find.text('Explicación 1'), findsNothing);

    WelcomeTourService.avisoCerrado();
    await esperar(tester);
    expect(find.text('Explicación 1'), findsOneWidget);
  });

  testWidgets(
      'si el aviso lleva a otra pantalla y se sale de Inicio, queda '
      'pendiente', (tester) async {
    await inicioConTour(tester);

    WelcomeTourService.avisoAbierto();
    await esperar(tester);
    navegador.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Clientes'))),
      (_) => false,
    );
    await tester.pumpAndSettle();
    WelcomeTourService.avisoCerrado();
    await esperar(tester);

    expect(WelcomeTourService.recorridoEnCurso.value, isFalse);
    expect(acceso.vistos_, isEmpty);
    expect(await tours.isPending(AppTours.home), isTrue);
  });
}

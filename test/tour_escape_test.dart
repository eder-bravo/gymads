import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// En computadora, Esc salta el recorrido de la pantalla, igual que "Saltar".
class _Acceso implements ToursDelEmpleado {
  final vistos_ = <String>{};
  @override
  Future<Set<String>?> vistos(String rol) async => {...vistos_};
  @override
  Future<void> marcarVisto(String rol, String tourId) async =>
      vistos_.add(tourId);
}

void main() {
  final pasos = [GlobalKey(), GlobalKey()];
  final navegador = GlobalKey<NavigatorState>();
  late WelcomeTourService tours;
  late _Acceso acceso;

  const escritorio = TargetPlatformVariant(
      {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    acceso = _Acceso();
  });
  tearDown(() {
    tours.dejarDeEscuchar();
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

  /// Una pantalla con dos pasos y un botón que abre una ventana modal con su
  /// Esc para cerrar, como `VentanaFormulario`.
  Future<void> mostrar(WidgetTester tester) async {
    // Se crea dentro de la prueba: la plataforma de la variante ya aplica.
    tours = WelcomeTourService(
      toursDelEmpleado: acceso,
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'mostrador', esEmpleado: true),
    ).init();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navegador,
      home: Scaffold(
        body: Column(children: [
          for (var i = 0; i < 2; i++)
            TourStep(
              tourKey: pasos[i],
              title: 'Paso ${i + 1}',
              description: 'Explicación ${i + 1}',
              isFirstStep: i == 0,
              isLastStep: i == 1,
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
  }

  Future<void> conRecorrido(WidgetTester tester) async {
    await mostrar(tester);
    final arranque = tours.startIfPending(AppTours.home, pasos);
    await esperar(tester);
    await arranque;
    await esperar(tester);
    expect(find.text('Explicación 1'), findsOneWidget);
  }

  testWidgets('Esc quita el recorrido y lo da por visto, como "Saltar"',
      (tester) async {
    await conRecorrido(tester);
    expect(find.text('Saltar (Esc)'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await esperar(tester);
    expect(find.text('Explicación 1'), findsNothing);
    expect(WelcomeTourService.recorridoEnCurso.value, isFalse);
    expect(acceso.vistos_, contains(AppTours.home));
  }, variant: escritorio);

  testWidgets('sin recorrido, Esc sigue cerrando una ventana modal',
      (tester) async {
    await mostrar(tester);
    var cerrada = false;
    navegador.currentState!
        .push(MaterialPageRoute(
            builder: (_) => CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () =>
                        navegador.currentState!.maybePop(),
                  },
                  child: const Focus(
                      autofocus: true, child: Scaffold(body: Text('Modal'))),
                )))
        .then((_) => cerrada = true);
    await tester.pumpAndSettle();
    expect(find.text('Modal'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(cerrada, isTrue);
    expect(acceso.vistos_, isEmpty);
  }, variant: escritorio);

  testWidgets('en el teléfono, Esc no salta el recorrido', (tester) async {
    await conRecorrido(tester);
    expect(find.text('Saltar'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await esperar(tester);
    expect(find.text('Explicación 1'), findsOneWidget);
    expect(acceso.vistos_, isEmpty);
  });
}

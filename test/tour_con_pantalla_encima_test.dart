import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un empleado que todavía no ha visto ningún recorrido.
class _SinVer implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async => {};
  @override
  Future<void> marcarVisto(String rol, String tourId) async {}
}

void main() {
  final paso = GlobalKey();
  final navegador = GlobalKey<NavigatorState>();
  late WelcomeTourService tours;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tours = WelcomeTourService(
      toursDelEmpleado: _SinVer(),
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'mostrador', esEmpleado: true),
    ).init();
  });
  tearDown(() => WelcomeTourService.recorridoEnCurso.value = false);

  Future<void> clientes(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        navigatorKey: navegador,
        home: Scaffold(
          body: TourStep(
            tourKey: paso,
            title: 'Clientes',
            description: 'Aquí están tus clientes.',
            isFirstStep: true,
            child: const SizedBox(height: 200, child: Text('Lista')),
          ),
        ),
      ));

  /// Deja correr la espera del servicio (hasta 5 s) y el arranque.
  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> abrirFormulario() async => navegador.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Nuevo cliente')),
        ),
      );

  testWidgets(
      'con el formulario de alta encima (llegando desde "Registrar"), el '
      'recorrido de Clientes espera y sale al cerrarlo', (tester) async {
    await clientes(tester);
    abrirFormulario();
    await tester.pumpAndSettle();

    final arranque = tours.startIfPending(AppTours.clientes, [paso]);
    await esperar(tester);
    await esperar(tester);

    expect(WelcomeTourService.recorridoEnCurso.value, isFalse);
    expect(find.text('Aquí están tus clientes.'), findsNothing);

    navegador.currentState!.pop();
    // Sin pumpAndSettle: el recorrido arranca y su animación no se detiene.
    await esperar(tester);
    await arranque;
    // El recorrido se pinta con un pequeño retraso.
    await esperar(tester);

    expect(WelcomeTourService.recorridoEnCurso.value, isTrue);
    expect(find.text('Aquí están tus clientes.'), findsOneWidget);
  });

  testWidgets(
      'si se guarda y se sale de Clientes con el formulario encima, el '
      'recorrido queda pendiente', (tester) async {
    await clientes(tester);
    abrirFormulario();
    await tester.pumpAndSettle();

    final arranque = tours.startIfPending(AppTours.clientes, [paso]);
    await esperar(tester);

    // Como al guardar desde el lector: se va a Abonar y Clientes se cierra.
    navegador.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Abonar'))),
      (_) => false,
    );
    await tester.pumpAndSettle();
    await esperar(tester);
    await arranque;

    expect(WelcomeTourService.recorridoEnCurso.value, isFalse);
    expect(await tours.isPending(AppTours.clientes), isTrue);
  });

  testWidgets(
      'con el aviso del lector en pantalla (bienvenida), el recorrido espera '
      'a que se cierre', (tester) async {
    await clientes(tester);
    // showcaseview registra el paso al reconstruirse la pantalla.
    abrirFormulario();
    await tester.pumpAndSettle();
    navegador.currentState!.pop();
    await tester.pumpAndSettle();

    WelcomeTourService.avisoAbierto();
    final arranque = tours.startIfPending(AppTours.clientes, [paso]);
    await esperar(tester);
    await esperar(tester);
    expect(WelcomeTourService.recorridoEnCurso.value, isFalse);

    WelcomeTourService.avisoCerrado();
    await esperar(tester);
    await arranque;
    await esperar(tester);
    expect(WelcomeTourService.recorridoEnCurso.value, isTrue);
  });
}

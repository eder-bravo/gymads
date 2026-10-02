import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:showcaseview/showcaseview.dart';

void main() {
  late ShowcaseView tour;
  late ScrollController desplazamiento;
  late int tocado;
  final paso = GlobalKey();

  /// [listaResaltada]: lo resaltado es una lista con su propio scroll (como
  /// el paso "Clientes" de la pantalla de clientes).
  Future<void> pantallaConTour(WidgetTester tester,
      {ScrollController? listaResaltada}) async {
    tour = ShowcaseView.register(disableBarrierInteraction: true);
    addTearDown(tour.unregister);
    addTearDown(() => WelcomeTourService.recorridoEnCurso.value = false);
    desplazamiento = ScrollController();
    tocado = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: desplazamiento,
          children: [
            const SizedBox(height: 120),
            TourStep(
              tourKey: paso,
              title: 'Lista',
              description: 'Aquí están tus clientes.',
              isFirstStep: true,
              child: GestureDetector(
                onTap: () => tocado++,
                child: SizedBox(
                  height: 300,
                  child: listaResaltada == null
                      ? const Center(child: Text('Resaltado'))
                      : ListView(
                          controller: listaResaltada,
                          children: [
                            const SizedBox(
                                height: 80, child: Text('Resaltado')),
                            for (var i = 0; i < 20; i++)
                              SizedBox(height: 80, child: Text('Cliente $i')),
                          ],
                        ),
                ),
              ),
            ),
            for (var i = 0; i < 30; i++)
              SizedBox(height: 80, child: Text('Fila $i')),
          ],
        ),
      ),
    ));

    // Lo que hace WelcomeTourService al arrancar un recorrido.
    WelcomeTourService.recorridoEnCurso.value = true;
    tour.startShowCase([paso]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tour.isShowcaseRunning, isTrue);
  }

  testWidgets(
      'durante el tour, arrastrar sobre lo resaltado no mueve la '
      'pantalla', (tester) async {
    await pantallaConTour(tester);
    final centro = tester.getCenter(find.text('Resaltado'));

    await tester.dragFrom(centro, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(desplazamiento.offset, 0);
  });

  testWidgets('si lo resaltado es una lista, tampoco se desplaza',
      (tester) async {
    final lista = ScrollController();
    await pantallaConTour(tester, listaResaltada: lista);

    await tester.dragFrom(
        tester.getCenter(find.byType(ListView).last), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(lista.offset, 0);
    expect(desplazamiento.offset, 0);
  });

  testWidgets('ni arrastrando sobre la parte oscura', (tester) async {
    await pantallaConTour(tester);

    await tester.dragFrom(const Offset(200, 700), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(desplazamiento.offset, 0);
  });

  testWidgets('tocar lo resaltado no hace su acción real', (tester) async {
    await pantallaConTour(tester);

    await tester.tapAt(tester.getCenter(find.text('Resaltado')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tocado, 0);
  });

  testWidgets('al terminar el tour se puede desplazar otra vez',
      (tester) async {
    await pantallaConTour(tester);
    tour.dismiss();
    WelcomeTourService.recorridoEnCurso.value = false;
    await tester.pump(const Duration(milliseconds: 500));

    await tester.dragFrom(const Offset(200, 500), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(desplazamiento.offset, greaterThan(0));
  });
}

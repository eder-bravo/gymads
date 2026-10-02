import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/modules/home/widgets/fondo_estirable.dart';

/// Revisa lo que de verdad se PINTA (no solo dónde quedan las cajas): el hueco
/// del rebote se veía en el teléfono aunque la posición calculada fuera buena.
void main() {
  const fondoPantalla = Color(0xFFFFFFFF);
  const cabecera = Color(0xFFFF0000);
  final key = GlobalKey();

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Como Inicio: el cuerpo empieza detrás de la barra de estado.
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: fondoPantalla,
          extendBodyBehindAppBar: true,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              child: Column(children: [
                const SizedBox(
                  height: 120,
                  child: FondoEstirable(
                    colorArriba: LinearGradient(colors: [cabecera, cabecera]),
                    decoracion: BoxDecoration(color: cabecera),
                    child: SizedBox(height: 120, width: double.infinity),
                  ),
                ),
                Container(height: 1500, color: const Color(0xFF00FF00)),
              ]),
            ),
          ),
        ),
      ),
    ));
  }

  Future<Color> pixel(WidgetTester tester, int y) async {
    late Color c;
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage();
      final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final o = (y * img.width + 200) * 4;
      c = Color.fromARGB(
          255, d.getUint8(o), d.getUint8(o + 1), d.getUint8(o + 2));
    });
    return c;
  }

  testWidgets('en reposo, la cabecera empieza arriba y termina en su lugar',
      (tester) async {
    await abrir(tester);
    expect(await pixel(tester, 2), cabecera);
    expect(await pixel(tester, 110), cabecera);
    expect(await pixel(tester, 130), const Color(0xFF00FF00));
  });

  testWidgets('al jalar hacia abajo no queda hueco arriba', (tester) async {
    await abrir(tester);
    final g = await tester.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(0, 200));
    await tester.pump();
    // Antes aquí se veía el fondo de la pantalla (el hueco).
    for (final y in [2, 40, 80]) {
      expect(await pixel(tester, y), cabecera, reason: 'y=$y');
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(await pixel(tester, 130), const Color(0xFF00FF00));
  });

  testWidgets('al bajar normalmente, la prolongación no se asoma',
      (tester) async {
    await abrir(tester);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    // La cabecera ya salió por arriba: arriba se ve el contenido (verde,
    // con el leve tinte de la barra de Material), nunca la prolongación roja.
    final arriba = await pixel(tester, 2);
    expect(arriba.r, lessThan(0.2));
    expect(arriba.g, greaterThan(0.8));
    expect(await pixel(tester, 400), const Color(0xFF00FF00));
  });
}

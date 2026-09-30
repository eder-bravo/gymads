import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:gymads/app/modules/configuracion/views/lector_view.dart';
import 'package:gymads/app/modules/configuracion/widgets/ilustracion_lector.dart';
import 'package:gymads/core/theme/app_theme.dart';

void main() {
  Future<void> dibujar(WidgetTester tester, ThemeData tema, EstadoLector e,
      {bool comprobando = false}) {
    return tester.pumpWidget(MaterialApp(
      theme: tema,
      home: Scaffold(
        body: IlustracionLector(
          estado: e,
          titulo: tituloDelEstado(e),
          comprobando: comprobando,
        ),
      ),
    ));
  }

  for (final (nombre, tema) in [
    ('claro', AppTheme.claro),
    ('oscuro', AppTheme.oscuro),
  ]) {
    testWidgets('$nombre: cada estado se dibuja con su título', (tester) async {
      for (final e in EstadoLector.values) {
        await dibujar(tester, tema, e);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(tituloDelEstado(e)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await dibujar(tester, tema, EstadoLector.mio, comprobando: true);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Buscando tu lector…'), findsOneWidget);
    });
  }

  testWidgets('reconectando dice eso (y que no lo desconecten), no "no aparece"',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: const Scaffold(
        body: IlustracionLector(
          estado: EstadoLector.sinConexion,
          titulo: 'Tu lector no aparece',
          comprobando: true,
          textoComprobando: 'Reconectando el lector…',
          detalle: 'Tarda unos segundos. No lo desconectes.',
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reconectando el lector…'), findsOneWidget);
    expect(find.text('Tarda unos segundos. No lo desconectes.'), findsOneWidget);
    expect(find.text('Tu lector no aparece'), findsNothing);
  });

  testWidgets('sin lector ni conexión el dibujo queda quieto', (tester) async {
    for (final e in [
      EstadoLector.sinConfigurar,
      EstadoLector.sinConexion,
      EstadoLector.deOtroGimnasio,
    ]) {
      await dibujar(tester, AppTheme.oscuro, e);
      // Termina: no hay animación en bucle.
      await tester.pumpAndSettle();
    }
  });
}

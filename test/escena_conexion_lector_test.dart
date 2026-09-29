import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:gymads/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:gymads/app/modules/configuracion/views/lector_view.dart';
import 'package:gymads/app/modules/configuracion/widgets/escena_conexion_lector.dart';
import 'package:gymads/core/theme/app_theme.dart';

void main() {
  group('Etapa de la animación para cada paso del asistente', () {
    test('del Bluetooth al WiFi, en orden', () {
      expect(etapaDe(PasoAgregar.buscando, null), EtapaConexion.buscando);
      expect(etapaDe(PasoAgregar.preparando, null),
          EtapaConexion.conectandoBluetooth);
      expect(etapaDe(PasoAgregar.elegirRed, null), EtapaConexion.eligiendoWifi);
      expect(
          etapaDe(PasoAgregar.escribirClave, null), EtapaConexion.eligiendoWifi);
      expect(
          etapaDe(PasoAgregar.conectando, null), EtapaConexion.conectandoWifi);
      expect(etapaDe(PasoAgregar.comprobando, null), EtapaConexion.comprobando);
      expect(etapaDe(PasoAgregar.listo, null), EtapaConexion.listo);
    });

    test('un fallo se marca donde ocurrió', () {
      expect(etapaDe(PasoAgregar.fallo, null), EtapaConexion.falloBluetooth);
      expect(etapaDe(PasoAgregar.fallo, PasoAgregar.buscando),
          EtapaConexion.falloBluetooth);
      expect(etapaDe(PasoAgregar.fallo, PasoAgregar.preparando),
          EtapaConexion.falloBluetooth);
      expect(etapaDe(PasoAgregar.fallo, PasoAgregar.conectando),
          EtapaConexion.falloWifi);
      expect(etapaDe(PasoAgregar.fallo, PasoAgregar.comprobando),
          EtapaConexion.falloWifi);
    });

    test('el controlador recuerda el paso anterior al fallo', () {
      final controller = AgregarLectorController()..onInit();
      controller.paso.value = PasoAgregar.conectando;
      controller.paso.value = PasoAgregar.fallo;
      expect(controller.pasoAntesDelFallo, PasoAgregar.conectando);
      expect(etapaDe(controller.paso.value, controller.pasoAntesDelFallo),
          EtapaConexion.falloWifi);
    });
  });

  group('Pasos: Bluetooth · WiFi · Listo', () {
    test('se van completando', () {
      const p = EstadoPaso.pendiente,
          c = EstadoPaso.enCurso,
          h = EstadoPaso.hecho,
          f = EstadoPaso.fallo;
      expect(estadosDePasos(EtapaConexion.buscando), [c, p, p]);
      expect(estadosDePasos(EtapaConexion.eligiendoWifi), [h, c, p]);
      expect(estadosDePasos(EtapaConexion.conectandoWifi), [h, c, p]);
      expect(estadosDePasos(EtapaConexion.listo), [h, h, h]);
      expect(estadosDePasos(EtapaConexion.falloBluetooth), [f, p, p]);
      expect(estadosDePasos(EtapaConexion.falloWifi), [h, f, p]);
    });
  });

  Future<void> dibujar(WidgetTester tester, EtapaConexion etapa,
      {ThemeData? tema}) {
    return tester.pumpWidget(MaterialApp(
      theme: tema ?? AppTheme.oscuro,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            EscenaConexion(etapa: etapa),
            PasosConexion(etapa: etapa),
          ]),
        ),
      ),
    ));
  }

  for (final (nombre, tema) in [
    ('oscuro', AppTheme.oscuro),
    ('claro', AppTheme.claro),
  ]) {
    testWidgets('$nombre: se dibuja en todas las etapas', (tester) async {
      for (final etapa in EtapaConexion.values) {
        await dibujar(tester, etapa, tema: tema);
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull, reason: '$etapa');
        expect(find.text('Bluetooth'), findsOneWidget);
      }
    });
  }

  testWidgets('mientras se espera hay movimiento; al elegir la red, no',
      (tester) async {
    await dibujar(tester, EtapaConexion.conectandoWifi);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await dibujar(tester, EtapaConexion.eligiendoWifi);
    // Termina: la escena quieta no deja nada animándose.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('al terminar, los tres pasos quedan palomeados', (tester) async {
    await dibujar(tester, EtapaConexion.listo);
    await tester.pumpAndSettle();
    // Tres en los pasos y una en el lector.
    expect(find.byIcon(Icons.check), findsNWidgets(4));
  });

  testWidgets('con "reducir movimiento" no hay bucle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.oscuro,
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: EscenaConexion(etapa: EtapaConexion.buscando)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('Pantalla del lector', () {
    test('cada estado dice solo un título corto', () {
      for (final estado in EstadoLector.values) {
        final titulo = tituloDelEstado(estado);
        expect(titulo, isNotEmpty);
        expect(titulo.length, lessThan(25), reason: '$estado: $titulo');
        // Sin el nombre técnico del aparato.
        expect(titulo, isNot(contains('GymOne-')));
      }
    });
  });
}

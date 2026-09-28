import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/data/services/tema_service.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:gymads/core/theme/siempre_oscuro.dart';

/// Contraste WCAG entre dos colores opacos (1 a 21).
double contraste(Color a, Color b) {
  double canal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luz(Color c) =>
      0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  final l1 = luz(a), l2 = luz(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  group('Colores', () {
    test('el modo oscuro conserva los colores de siempre', () {
      const o = ColoresTema.oscuro;
      expect(o.backgroundColor, const Color.fromARGB(255, 27, 27, 27));
      expect(o.cardBackground, const Color.fromARGB(255, 18, 18, 18));
      expect(o.containerBackground, const Color.fromARGB(255, 14, 14, 14));
      expect(o.textPrimary, const Color.fromARGB(255, 210, 210, 210));
      expect(o.textSecondary, const Color.fromARGB(255, 192, 192, 192));
      expect(o.textHint, const Color(0xFFBDBDBD));
      expect(o.titleColor, const Color.fromARGB(255, 255, 145, 90));
      expect(o.contraste, Colors.white);
    });

    for (final (nombre, c) in [
      ('oscuro', ColoresTema.oscuro),
      ('claro', ColoresTema.claro),
    ]) {
      test('$nombre: los textos se leen sobre el fondo y las tarjetas', () {
        for (final fondo in [c.backgroundColor, c.cardBackground]) {
          expect(contraste(c.textPrimary, fondo), greaterThanOrEqualTo(4.5));
          expect(contraste(c.textSecondary, fondo), greaterThanOrEqualTo(4.5));
          expect(contraste(c.titleColor, fondo), greaterThanOrEqualTo(3));
        }
      });
    }

    test('el cambio de modo se anima (lerp) sin saltos raros', () {
      final mitad = ColoresTema.oscuro.lerp(ColoresTema.claro, 0.5);
      expect(mitad.backgroundColor,
          Color.lerp(ColoresTema.oscuro.backgroundColor,
              ColoresTema.claro.backgroundColor, 0.5));
      expect(ColoresTema.oscuro.lerp(ColoresTema.claro, 1).textPrimary,
          ColoresTema.claro.textPrimary);
    });
  });

  group('Temas', () {
    test('cada tema trae su brillo y sus colores', () {
      expect(AppTheme.oscuro.brightness, Brightness.dark);
      expect(AppTheme.claro.brightness, Brightness.light);
      expect(AppTheme.oscuro.extension<ColoresTema>(), ColoresTema.oscuro);
      expect(AppTheme.claro.extension<ColoresTema>(), ColoresTema.claro);
      expect(AppTheme.claro.scaffoldBackgroundColor,
          ColoresTema.claro.backgroundColor);
      expect(AppTheme.oscuro.dialogTheme.backgroundColor,
          ColoresTema.oscuro.cardBackground);
    });

    test('la barra de estado se lee en cada modo', () {
      expect(AppTheme.oscuro.appBarTheme.systemOverlayStyle?.statusBarBrightness,
          Brightness.dark);
      expect(AppTheme.claro.appBarTheme.systemOverlayStyle?.statusBarBrightness,
          Brightness.light);
    });
  });

  group('TemaService', () {
    tearDown(Get.reset);

    test('sin nada guardado, sigue al teléfono', () {
      expect(TemaService(leer: () => null).modo.value, ThemeMode.system);
    });

    test('recupera lo guardado', () {
      expect(TemaService(leer: () => 'claro').modo.value, ThemeMode.light);
      expect(TemaService(leer: () => 'oscuro').modo.value, ThemeMode.dark);
      expect(TemaService(leer: () => 'otra cosa').modo.value, ThemeMode.system);
    });

    testWidgets('al elegir un modo, la app cambia al instante y se guarda',
        (tester) async {
      String? guardado;
      final tema = TemaService(leer: () => null, guardar: (v) => guardado = v);
      late Color fondo;
      await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.claro,
        darkTheme: AppTheme.oscuro,
        themeMode: tema.modo.value,
        home: Builder(builder: (context) {
          fondo = context.colores.backgroundColor;
          return const SizedBox();
        }),
      ));
      // El simulador de pruebas está en claro.
      expect(fondo, ColoresTema.claro.backgroundColor);

      tema.cambiar(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(fondo, ColoresTema.oscuro.backgroundColor);
      expect(guardado, 'oscuro');

      tema.cambiar(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(fondo, ColoresTema.claro.backgroundColor);
      expect(guardado, 'claro');
    });
  });

  testWidgets('la cámara y el escáner van oscuros aunque la app esté en claro',
      (tester) async {
    late Brightness brillo;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: SiempreOscuro(
        child: Builder(builder: (context) {
          brillo = Theme.of(context).brightness;
          return const SizedBox();
        }),
      ),
    ));
    expect(brillo, Brightness.dark);
  });

  for (final (nombre, tema) in [
    ('oscuro', AppTheme.oscuro),
    ('claro', AppTheme.claro),
  ]) {
    testWidgets('$nombre: las piezas comunes toman los colores del modo',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: tema,
        home: const Scaffold(
          appBar: GymAppBar(title: 'Clientes'),
          body: Column(children: [
            TituloSeccion('Datos', detalle: 'Detalle'),
            NotaObligatorio(),
            AppSearchField(hintText: 'Buscar'),
          ]),
          bottomNavigationBar: PieDeFormulario(
            child: BotonGuardar(texto: 'Guardar', onPressed: null),
          ),
        ),
      ));
      final colores = tema.extension<ColoresTema>()!;
      final titulo = tester.widget<Text>(find.text('Datos'));
      expect(titulo.style?.color, colores.textPrimary);
      final barra = tester.widget<Material>(find.descendant(
          of: find.byType(AppBar), matching: find.byType(Material)).first);
      expect(barra.color, colores.backgroundColor);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/modules/shared/utils/recorte_circulo.dart';
import 'package:gymads/app/modules/shared/widgets/photo_capture_widget.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:image/image.dart' as img;

void main() {
  // Un iPhone en vertical.
  const vista = Size(390, 844);

  group('Foto recortada al círculo', () {
    test('el círculo es la guía, centrado y un poco arriba', () {
      final c = circuloGuia(vista);
      expect(c.center.dx, 195);
      expect(c.center.dy, closeTo(844 * 0.45, 0.001));
      expect(c.width / 2, 200); // 25 % del alto, máximo 200
    });

    test('con la vista previa del mismo tamaño que la foto, es el círculo',
        () {
      // Una foto de 780x1688 (el doble de la pantalla) con vista previa de
      // pantalla completa.
      const pantalla = Size(300, 600);
      final c = circuloGuia(pantalla);
      final cuadro = cuadroDelCirculo(
          vista: pantalla, vistaPrevia: pantalla, ancho: 900, alto: 1800);
      expect(cuadro.width, closeTo(c.width * 3, 1));
      expect(cuadro.center.dx, closeTo(c.center.dx * 3, 1));
      expect(cuadro.center.dy, closeTo(c.center.dy * 3, 1));
    });

    test('con la imagen de la cámara centrada, descuenta el margen', () {
      // Pantalla alta con la cámara 4:3 (en vertical, 3:4) centrada.
      const pantalla = Size(300, 800);
      const previa = Size(300, 400);
      final c = circuloGuia(pantalla); // radio 200, centro y 360
      final cuadro = cuadroDelCirculo(
          vista: pantalla, vistaPrevia: previa, ancho: 600, alto: 800);
      // Escala 2; la previa empieza en y = 200, y la foto en 0.
      expect(cuadro.center.dy, closeTo((c.center.dy - 200) * 2, 1));
      expect(cuadro.width, lessThanOrEqualTo(600)); // sin salirse
    });

    test('nunca se sale de la foto', () {
      final cuadro = cuadroDelCirculo(
          vista: vista,
          vistaPrevia: const Size(390, 520),
          ancho: 3024,
          alto: 4032);
      expect(cuadro.left, greaterThanOrEqualTo(0));
      expect(cuadro.top, greaterThanOrEqualTo(0));
      expect(cuadro.right, lessThanOrEqualTo(3024));
      expect(cuadro.bottom, lessThanOrEqualTo(4032));
      expect(cuadro.width, cuadro.height);
    });

    Future<String> foto(Directory dir, int ancho, int alto) async {
      final ruta = '${dir.path}/foto.jpg';
      File(ruta).writeAsBytesSync(
          img.encodeJpg(img.Image(width: ancho, height: alto)));
      return ruta;
    }

    test('se guarda cuadrada y en alta resolución', () async {
      final dir = await Directory.systemTemp.createTemp('foto');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = await foto(dir, 3024, 4032);

      await prepararFoto(ruta,
          vista: const Size(390, 844), vistaPrevia: const Size(390, 520));

      final r = img.decodeImage(File(ruta).readAsBytesSync())!;
      expect(r.width, r.height);
      expect(r.width, ladoMaximoFoto);
    });

    test('una foto chica no se agranda', () async {
      final dir = await Directory.systemTemp.createTemp('foto');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = await foto(dir, 720, 1280);

      await prepararFoto(ruta,
          vista: const Size(360, 640), vistaPrevia: const Size(360, 640));

      final r = img.decodeImage(File(ruta).readAsBytesSync())!;
      expect(r.width, r.height);
      expect(r.width, lessThanOrEqualTo(720));
    });

    test('sin círculo (cámara genérica), la foto queda completa', () async {
      final dir = await Directory.systemTemp.createTemp('foto');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = await foto(dir, 720, 1280);

      await prepararFoto(ruta);

      final r = img.decodeImage(File(ruta).readAsBytesSync())!;
      expect((r.width, r.height), (720, 1280));
    });

    test('si el archivo no es una foto, lo deja como estaba', () async {
      final dir = await Directory.systemTemp.createTemp('foto');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = '${dir.path}/roto.jpg';
      File(ruta).writeAsStringSync('no soy una foto');

      await prepararFoto(ruta,
          vista: const Size(390, 844), vistaPrevia: const Size(390, 520));

      expect(File(ruta).readAsStringSync(), 'no soy una foto');
    });
  });

  testWidgets('con el teclado abierto, el botón de guardar queda a la vista',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(
        body: const TextField(autofocus: true),
        bottomNavigationBar: PieDeFormulario(
          child: BotonGuardar(texto: 'Guardar cliente', onPressed: () {}),
        ),
      ),
    ));
    await tester.pump();

    final boton = tester.getRect(find.text('Guardar cliente'));
    // Todo el botón por encima del teclado (que ocupa los últimos 300).
    expect(boton.bottom, lessThanOrEqualTo(844 - 300));
  });

  testWidgets('el aro de la foto se pinta encima, no debajo de la foto',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(
        body: PhotoCaptureWidget(onPhotoTaken: (_) {}, obligatoria: true),
      ),
    ));
    final circulo = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(PhotoCaptureWidget),
            matching: find.byType(Container)))
        .firstWhere((c) => c.foregroundDecoration != null);
    final aro = circulo.foregroundDecoration! as BoxDecoration;
    expect(aro.border, isNotNull);
    // Y no también debajo, donde la foto lo tapaba.
    expect((circulo.decoration! as BoxDecoration).border, isNull);
  });
}

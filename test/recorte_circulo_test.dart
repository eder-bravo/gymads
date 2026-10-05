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

  group('Foto completa', () {
    test('el círculo es solo una guía, centrado y un poco arriba', () {
      final c = circuloGuia(vista);
      expect(c.center.dx, 195);
      expect(c.center.dy, closeTo(844 * 0.45, 0.001));
      expect(c.width / 2, 200); // 25 % del alto, máximo 200
    });

    Future<String> foto(Directory dir, int ancho, int alto) async {
      final ruta = '${dir.path}/foto.jpg';
      File(ruta).writeAsBytesSync(
          img.encodeJpg(img.Image(width: ancho, height: alto)));
      return ruta;
    }

    test('se guarda completa, no solo lo de adentro del círculo', () async {
      final dir = await Directory.systemTemp.createTemp('foto');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = await foto(dir, 720, 1280);

      await prepararFotoCompleta(ruta);

      final resultado = img.decodeImage(File(ruta).readAsBytesSync())!;
      expect((resultado.width, resultado.height), (720, 1280));
    });

    test('una foto muy grande se achica sin cambiar su forma', () async {
      final dir = await Directory.systemTemp.createTemp('foto');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = await foto(dir, 3024, 4032);

      await prepararFotoCompleta(ruta);

      final resultado = img.decodeImage(File(ruta).readAsBytesSync())!;
      expect((resultado.width, resultado.height), (1200, 1600));
    });

    test('si el archivo no es una foto, lo deja como estaba', () async {
      final dir = await Directory.systemTemp.createTemp('foto');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = '${dir.path}/roto.jpg';
      File(ruta).writeAsStringSync('no soy una foto');

      await prepararFotoCompleta(ruta);

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

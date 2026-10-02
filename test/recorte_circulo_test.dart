import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/modules/shared/utils/recorte_circulo.dart';
import 'package:gymads/app/modules/shared/widgets/photo_capture_widget.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:image/image.dart' as img;

void main() {
  // Un iPhone en vertical; la vista previa de la cámara, 9:16.
  const vista = Size(390, 844);
  const aspecto = 9 / 16;

  void esCuadradoDentro(Rect r, Size foto) {
    expect(r.width, closeTo(r.height, 0.001));
    expect(r.left, greaterThanOrEqualTo(-0.001));
    expect(r.top, greaterThanOrEqualTo(-0.001));
    expect(r.right, lessThanOrEqualTo(foto.width + 0.001));
    expect(r.bottom, lessThanOrEqualTo(foto.height + 0.001));
  }

  group('Recorte al círculo guía', () {
    test('foto con la misma proporción que la vista previa', () {
      const foto = Size(720, 1280);
      final r = recorteDelCirculo(
          vista: vista, aspectoVistaPrevia: aspecto, foto: foto);
      esCuadradoDentro(r, foto);
      // El círculo está centrado a lo ancho y un poco arriba del centro.
      expect(r.center.dx, closeTo(360, 1));
      expect(r.center.dy, lessThan(foto.height / 2));
      expect(r.center.dy, closeTo(562, 2));
    });

    test('foto más ancha que la vista previa (4:3): se toma su centro', () {
      const foto = Size(3024, 4032);
      final r = recorteDelCirculo(
          vista: vista, aspectoVistaPrevia: aspecto, foto: foto);
      esCuadradoDentro(r, foto);
      expect(r.center.dx, closeTo(1512, 1));
      // El lado del círculo en la foto, no la foto completa.
      expect(r.width, lessThan(foto.width));
      expect(r.width, closeTo(2326, 3));
    });

    test('en pantallas bajas el recorte no se sale de la foto', () {
      const foto = Size(720, 1280);
      final r = recorteDelCirculo(
        vista: const Size(390, 500),
        aspectoVistaPrevia: aspecto,
        foto: foto,
      );
      esCuadradoDentro(r, foto);
    });

    test('la máscara y el recorte usan el mismo círculo', () {
      final c = circuloGuia(vista);
      expect(c.center.dx, 195);
      expect(c.center.dy, closeTo(844 * 0.45, 0.001));
      expect(c.width / 2, 200); // 25 % del alto, máximo 200
    });

    test('recorta el archivo y lo deja cuadrado', () async {
      final dir = await Directory.systemTemp.createTemp('recorte');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = '${dir.path}/foto.jpg';
      File(ruta).writeAsBytesSync(
          img.encodeJpg(img.Image(width: 720, height: 1280)));

      await recortarFotoAlCirculo(ruta,
          vista: vista, aspectoVistaPrevia: aspecto);

      final resultado = img.decodeImage(File(ruta).readAsBytesSync())!;
      expect(resultado.width, resultado.height);
      expect(resultado.width, 720);
    });

    test('si el archivo no es una foto, lo deja como estaba', () async {
      final dir = await Directory.systemTemp.createTemp('recorte');
      addTearDown(() => dir.delete(recursive: true));
      final ruta = '${dir.path}/roto.jpg';
      File(ruta).writeAsStringSync('no soy una foto');

      await recortarFotoAlCirculo(ruta,
          vista: vista, aspectoVistaPrevia: aspecto);

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

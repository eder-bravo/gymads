import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/pdf_report_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la letra de los reportes tiene guiones, acentos y ñ', () async {
    for (final archivo in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final fuente = PdfTtfFont(
          PdfDocument(), await rootBundle.load('assets/fonts/$archivo'));
      for (final c in '–—…•áéíóúüñÑ¿¡“”'.runes) {
        expect(fuente.isRuneSupported(c), isTrue,
            reason: '$archivo no tiene "${String.fromCharCode(c)}"');
      }
    }
  });

  test('el reporte se arma sin caracteres que falten', () async {
    final avisos = <String>[];
    await PdfReportService.prepararFuentes();

    await runZoned(
      () => PdfReportService.crearDocumento(
        titulo: 'Reporte de entradas',
        periodo: '30 sep 2026',
        construir: (_) => [
          PdfReportService.tarjetasResumen([('Hora pico', '8 – 10 a.m.')]),
          pw.Text('Sin dato: —'),
          pw.Text('José Núñez',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ).save(),
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, linea) => avisos.add(linea),
      ),
    );

    expect(avisos.where((m) => m.contains('Unable to find a font')), isEmpty);
  });
}

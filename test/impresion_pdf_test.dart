import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/pdf_preview_view.dart';
import 'package:gymads/app/data/services/pdf_report_service.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

class _Impresion extends PrintingPlatform {
  final trabajos = <Uint8List>[];
  final compartidos = <Uint8List>[];
  Completer<bool>? pendiente;

  @override
  Future<PrintingInfo> info() async => const PrintingInfo(
        canPrint: true,
        canRaster: true,
        canShare: true,
        dynamicLayout: true,
      );

  @override
  Future<bool> layoutPdf(
      Printer? printer,
      LayoutCallback onLayout,
      String name,
      PdfPageFormat format,
      bool dynamicLayout,
      bool usePrinterSettings,
      OutputType outputType,
      bool forceCustomPrintPaper) async {
    // La plataforma soporta layout dinámico, pero estos reportes deben llegar
    // listos antes de abrir el panel nativo que bloqueaba el hilo en macOS.
    if (dynamicLayout) throw StateError('Impresión dinámica bloqueante');
    trabajos.add(await onLayout(format));
    pendiente = Completer<bool>();
    return pendiente!.future;
  }

  @override
  Stream<PdfRaster> raster(
      Uint8List document, List<int>? pages, double dpi) async* {
    // El rasterizado nativo se verifica aparte en macOS; aquí se prueba
    // el contrato de impresión sin crear un decodificador de imagen.
  }

  @override
  Future<bool> sharePdf(Uint8List bytes, String filename, Rect bounds,
      String? subject, String? body, List<String>? emails) async {
    compartidos.add(bytes);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Documento extends pw.Document {
  int guardados = 0;
  @override
  Future<Uint8List> save({bool enableEventLoopBalancing = false}) {
    guardados++;
    return super.save(enableEventLoopBalancing: enableEventLoopBalancing);
  }
}

const _escritorio =
    TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.windows});

void main() {
  late PrintingPlatform anterior;
  late _Impresion plugin;
  setUp(() {
    anterior = PrintingPlatform.instance;
    plugin = _Impresion();
    PrintingPlatform.instance = plugin;
  });
  tearDown(() {
    PrintingPlatform.instance = anterior;
    Get.reset();
  });

  Future<Uint8List> abrir(WidgetTester tester) async {
    final doc = pw.Document()
      ..addPage(pw.Page(build: (_) => pw.Text('Prueba')));
    final bytes = await doc.save();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.claro,
        home: PdfPreviewView(
            titulo: 'Reporte de prueba',
            nombreArchivo: 'prueba.pdf',
            construir: (_) async => bytes)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return bytes;
  }

  testWidgets('imprime el PDF fijo y cancelar permite volver a imprimir',
      (tester) async {
    final bytes = await abrir(tester);
    await tester.tap(find.byIcon(Icons.print));
    await tester.pump(const Duration(seconds: 1));
    expect(plugin.trabajos, [bytes]);
    expect(tester.takeException(), isNull);
    plugin.pendiente!.complete(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byIcon(Icons.print));
    await tester.pump(const Duration(seconds: 1));
    expect(plugin.trabajos, [bytes, bytes]);
    plugin.pendiente!.complete(true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: _escritorio);

  testWidgets('compartir conserva el mismo documento que imprimir',
      (tester) async {
    final bytes = await abrir(tester);
    await tester.tap(find.byIcon(Icons.share));
    await tester.pump(const Duration(seconds: 1));
    expect(plugin.compartidos, [bytes]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: _escritorio);

  testWidgets(
      'el reporte se guarda una vez para todas las acciones de la vista',
      (tester) async {
    final doc = _Documento()..addPage(pw.Page(build: (_) => pw.Text('Prueba')));
    await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.claro, home: const Scaffold()));
    final salida = PdfReportService.mostrarPreview(doc,
        titulo: 'Reporte de prueba', nombreArchivo: 'prueba.pdf');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final preview = tester.widget<PdfPreviewView>(find.byType(PdfPreviewView));
    final primera = await preview.construir(PdfPageFormat.a4);
    final segunda = await preview.construir(PdfPageFormat.a4);
    expect(doc.guardados, 1);
    expect(primera, same(segunda));
    Get.back<void>();
    await tester.pump(const Duration(seconds: 1));
    await salida;
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: _escritorio);
}

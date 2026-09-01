import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../global_widgets/app_header.dart';

/// Vista previa de un reporte antes de compartirlo o imprimirlo.
///
/// El documento se arma en un isolate aparte (`PdfPreview` llama a
/// [construir] fuera del hilo de UI), así que un reporte de cientos de
/// movimientos no congela la pantalla.
class PdfPreviewView extends StatelessWidget {
  const PdfPreviewView({
    super.key,
    required this.titulo,
    required this.nombreArchivo,
    required this.construir,
  });

  final String titulo;
  final String nombreArchivo;
  final Future<Uint8List> Function(PdfPageFormat format) construir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GymAppBar(title: titulo),
      body: PdfPreview(
        build: construir,
        pdfFileName: nombreArchivo,
        // El formato lo fija el reporte; ofrecer cambiarlo solo descuadra
        // las tablas.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: PdfPageFormat.a4,
        scrollViewDecoration: const BoxDecoration(
          color: AppColors.backgroundColor,
        ),
        pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
        actionBarTheme: const PdfActionBarTheme(
          backgroundColor: AppColors.cardBackground,
          iconColor: AppColors.accent,
        ),
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
    );
  }
}

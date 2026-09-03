import 'package:get/get.dart';

import '../../core/utils/hora_formato.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/widgets/pdf_preview_view.dart';
import 'tenant_context_service.dart';

/// Piezas comunes de los reportes en PDF: encabezado, tarjetas de resumen,
/// tablas y pie de página.
///
/// Cada módulo arma su propio documento con estos ladrillos, para que el
/// reporte de ingresos y el de entradas se vean como el mismo papel.
class PdfReportService {
  // Paleta equivalente a AppColors, en PdfColor. El PDF se imprime en blanco,
  // así que aquí los textos son oscuros aunque la app sea de tema oscuro.
  static const PdfColor accent = PdfColor.fromInt(0xFFFF6F00);
  static const PdfColor textPrimary = PdfColor.fromInt(0xFF1A1A1A);
  static const PdfColor textSecondary = PdfColor.fromInt(0xFF6B6B6B);
  static const PdfColor separador = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor fondoSuave = PdfColor.fromInt(0xFFF5F5F5);

  /// Documento en blanco con márgenes y pie de página ya puestos.
  ///
  /// [construir] recibe el ancho útil y devuelve el contenido; se usa
  /// `MultiPage` para que una tabla larga se reparta sola en varias hojas.
  static pw.Document crearDocumento({
    required String titulo,
    required String periodo,
    required List<pw.Widget> Function(pw.Context context) construir,
  }) {
    final doc = pw.Document(title: titulo);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
        header: (context) => context.pageNumber == 1
            ? _encabezado(titulo, periodo)
            : pw.SizedBox(height: 0),
        footer: _pie,
        build: construir,
      ),
    );

    return doc;
  }

  static pw.Widget _encabezado(String titulo, String periodo) {
    final tenant = Get.isRegistered<TenantContextService>()
        ? TenantContextService.to
        : null;
    final gimnasio = tenant?.gymName ?? '';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (gimnasio.isNotEmpty)
                pw.Text(
                  gimnasio,
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                titulo,
                style: pw.TextStyle(
                  fontSize: 20,
                  color: textPrimary,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(periodo,
                  style: const pw.TextStyle(fontSize: 13, color: accent)),
            ],
          ),
          pw.Text(
            'Emitido el ${_fechaHoraLegible(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: textSecondary),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pie(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: textSecondary),
      ),
    );
  }

  /// Título de sección con una línea debajo.
  static pw.Widget seccion(String titulo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: separador)),
      ),
      child: pw.Text(
        titulo,
        style: pw.TextStyle(
          fontSize: 13,
          color: textPrimary,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  /// Fila de cifras destacadas: etiqueta arriba, número grande abajo.
  static pw.Widget tarjetasResumen(List<(String, String)> datos) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: fondoSuave,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          for (final (etiqueta, valor) in datos)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(etiqueta,
                      style: const pw.TextStyle(
                          fontSize: 9, color: textSecondary)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    valor,
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: textPrimary,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Desglose etiqueta / importe / porcentaje sobre el total.
  static pw.Widget desglose(Map<String, double> datos,
      {required String Function(double) formato}) {
    if (datos.isEmpty) {
      return pw.Text('Sin datos',
          style: const pw.TextStyle(fontSize: 10, color: textSecondary));
    }

    final total = datos.values.fold<double>(0, (s, v) => s + v);
    final ordenados = datos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      children: [
        for (final e in ordenados)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(e.key,
                      style: const pw.TextStyle(
                          fontSize: 10, color: textPrimary)),
                ),
                pw.Text(formato(e.value),
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: textPrimary,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 12),
                pw.SizedBox(
                  width: 44,
                  child: pw.Text(
                    total == 0
                        ? '—'
                        : '${(e.value / total * 100).toStringAsFixed(1)}%',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                        fontSize: 10, color: textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Tabla con cabecera que se repite en cada página.
  static pw.Widget tabla({
    required List<String> columnas,
    required List<List<String>> filas,
    List<int>? pesos,
    Set<int> alineadasDerecha = const {},
  }) {
    if (filas.isEmpty) {
      return pw.Text('Sin movimientos en este periodo',
          style: const pw.TextStyle(fontSize: 10, color: textSecondary));
    }

    final anchos = <int, pw.TableColumnWidth>{
      for (var i = 0; i < columnas.length; i++)
        i: pw.FlexColumnWidth((pesos?[i] ?? 1).toDouble()),
    };

    return pw.TableHelper.fromTextArray(
      columnWidths: anchos,
      headers: columnas,
      data: filas,
      border: null,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        color: textPrimary,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(color: fondoSuave),
      cellStyle: const pw.TextStyle(fontSize: 9, color: textPrimary),
      cellHeight: 18,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      headerPadding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      cellAlignments: {
        for (var i = 0; i < columnas.length; i++)
          i: alineadasDerecha.contains(i)
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: separador, width: .5)),
      ),
    );
  }

  /// Abre la vista previa dentro de la app, con compartir e imprimir.
  static Future<void> mostrarPreview(
    pw.Document doc, {
    required String titulo,
    required String nombreArchivo,
  }) {
    return Get.to<void>(
      () => PdfPreviewView(
        titulo: titulo,
        nombreArchivo: nombreArchivo,
        construir: (_) => doc.save(),
      ),
    )!;
  }

  /// Nombre de archivo sin espacios ni acentos, con la fecha del día.
  static String nombreArchivo(String base) {
    final now = DateTime.now();
    final fecha = '${now.year}-${_dosDigitos(now.month)}-${_dosDigitos(now.day)}';
    return '${base.toLowerCase().replaceAll(' ', '-')}-$fecha.pdf';
  }

  static String _fechaHoraLegible(DateTime d) =>
      '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}/${d.year} '
      '${_dosDigitos(d.hour)}:${_dosDigitos(d.minute)}';

  static String horaLegible(DateTime d) => HoraFormato.deFecha(d);

  static String fechaCorta(DateTime d) =>
      '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}';

  static String _dosDigitos(int n) => n.toString().padLeft(2, '0');
}

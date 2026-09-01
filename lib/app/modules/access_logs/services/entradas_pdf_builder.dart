import 'package:pdf/widgets.dart' as pw;

import '../../../data/models/access_log_model.dart';
import '../../../data/services/pdf_report_service.dart';

/// Arma el reporte de entradas: resumen, afluencia por franja horaria con la
/// hora pico marcada, y el detalle de los accesos del periodo.
class EntradasPdfBuilder {
  /// Resolución de la barra de afluencia, en partes de `flex`.
  static const int _escala = 100;

  static pw.Document construir({
    required String periodoLabel,
    required String sufijoPeriodo,
    required List<AccessLogModel> accesos,
    required List<AccessLogModel> entradas,
    required int salidas,
    required bool muestraSalidas,
    required Map<int, int> porFranja,
    required int? franjaPico,
    required String Function(int) etiquetaFranja,
  }) {
    final totalEntradas = entradas.length;

    return PdfReportService.crearDocumento(
      titulo: 'Reporte de entradas',
      periodo: periodoLabel,
      construir: (context) => [
        PdfReportService.tarjetasResumen([
          ('Entradas $sufijoPeriodo', '$totalEntradas'),
          if (muestraSalidas) ('Salidas', '$salidas'),
          (
            'Hora pico',
            franjaPico == null ? '—' : etiquetaFranja(franjaPico),
          ),
        ]),

        PdfReportService.seccion('Afluencia por franja horaria'),
        _tablaFranjas(porFranja, franjaPico, etiquetaFranja, totalEntradas),

        PdfReportService.seccion('Detalle de accesos (${accesos.length})'),
        PdfReportService.tabla(
          columnas: [
            'Fecha',
            'Hora',
            'Cliente',
            if (muestraSalidas) 'Tipo',
            'Registró',
          ],
          pesos: muestraSalidas ? const [2, 2, 6, 2, 4] : const [2, 2, 7, 5],
          filas: [
            for (final a in accesos)
              [
                PdfReportService.fechaCorta(a.accessTime),
                PdfReportService.horaLegible(a.accessTime),
                a.userName,
                if (muestraSalidas)
                  a.accessType == 'salida' ? 'Salida' : 'Entrada',
                a.staffUser,
              ],
          ],
        ),
      ],
    );
  }

  /// Franjas con una barra proporcional: el perfil del día se lee de un
  /// vistazo, sin necesidad de incrustar una gráfica como imagen.
  static pw.Widget _tablaFranjas(
    Map<int, int> porFranja,
    int? franjaPico,
    String Function(int) etiquetaFranja,
    int total,
  ) {
    if (porFranja.isEmpty || total == 0) {
      return pw.Text('Sin entradas en este periodo',
          style: const pw.TextStyle(
              fontSize: 10, color: PdfReportService.textSecondary));
    }

    final maximo = porFranja.values.reduce((a, b) => a > b ? a : b);
    final franjas = porFranja.keys.toList();

    // Proporción de la barra en centésimas, para repartirla con `flex`.
    int llenoDe(int hora) =>
        maximo == 0 ? 0 : ((porFranja[hora]! / maximo) * _escala).round();

    return pw.Column(
      children: [
        for (final hora in franjas)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    etiquetaFranja(hora),
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfReportService.textPrimary,
                      fontWeight: hora == franjaPico
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
                // Barra proporcional al máximo del periodo. Se reparte con
                // dos Expanded en vez de un ancho fraccionario, que el
                // paquete pdf no ofrece.
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      if (llenoDe(hora) > 0)
                        pw.Expanded(
                          flex: llenoDe(hora),
                          child: pw.Container(
                            height: 9,
                            decoration: pw.BoxDecoration(
                              color: PdfReportService.accent,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      if (llenoDe(hora) < _escala)
                        pw.Expanded(
                          flex: _escala - llenoDe(hora),
                          child: pw.Container(
                            height: 9,
                            decoration: pw.BoxDecoration(
                              color: PdfReportService.fondoSuave,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.SizedBox(
                  width: 30,
                  child: pw.Text(
                    '${porFranja[hora]}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfReportService.textPrimary,
                      fontWeight: hora == franjaPico
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 42,
                  child: pw.Text(
                    hora == franjaPico ? '  pico' : '',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfReportService.accent),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

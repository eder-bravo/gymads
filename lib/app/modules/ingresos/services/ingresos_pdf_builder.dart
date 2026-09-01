import 'package:pdf/widgets.dart' as pw;

import '../../../data/models/ingreso_model.dart';
import '../../../data/services/pdf_report_service.dart';

/// Arma el reporte de ingresos: resumen, desglose por concepto y por método
/// de pago, y el detalle de todas las transacciones del periodo.
class IngresosPdfBuilder {
  static pw.Document construir({
    required String periodoLabel,
    required String totalLabel,
    required EstadisticasIngresos estadisticas,
    required List<IngresoModel> ingresos,
  }) {
    return PdfReportService.crearDocumento(
      titulo: 'Reporte de ingresos',
      periodo: periodoLabel,
      construir: (context) => [
        PdfReportService.tarjetasResumen([
          (totalLabel, _moneda(estadisticas.totalIngresos)),
          ('Transacciones', '${estadisticas.totalTransacciones}'),
          ('Promedio', _moneda(estadisticas.promedioTransaccion)),
        ]),

        PdfReportService.seccion('Por concepto'),
        PdfReportService.desglose(
          _conNombresLegibles(estadisticas.ingresosPorConcepto),
          formato: _moneda,
        ),

        PdfReportService.seccion('Por método de pago'),
        PdfReportService.desglose(
          _metodosLegibles(estadisticas.ingresosPorMetodo),
          formato: _moneda,
        ),

        PdfReportService.seccion(
            'Detalle de transacciones (${ingresos.length})'),
        PdfReportService.tabla(
          columnas: const [
            'Fecha',
            'Cliente',
            'Concepto',
            'Método',
            'Monto',
          ],
          pesos: const [2, 5, 4, 3, 3],
          alineadasDerecha: const {4},
          filas: [
            for (final i in ingresos)
              [
                '${PdfReportService.fechaCorta(i.fecha)} '
                    '${PdfReportService.horaLegible(i.fecha)}',
                i.clienteNombre,
                i.conceptoDescripcion,
                i.metodoPagoDescripcion,
                _moneda(i.montoFinal),
              ],
          ],
        ),
      ],
    );
  }

  /// Los conceptos se guardan como claves ('renovacion'); en papel se leen.
  static Map<String, double> _conNombresLegibles(Map<String, double> datos) {
    const nombres = {
      'registro': 'Registro nuevo',
      'renovacion': 'Renovación',
      'producto': 'Venta de producto',
      'abono': 'Abono',
    };
    return {
      for (final e in datos.entries) nombres[e.key] ?? e.key: e.value,
    };
  }

  static Map<String, double> _metodosLegibles(Map<String, double> datos) {
    const nombres = {
      'efectivo': 'Efectivo',
      'tarjeta': 'Tarjeta',
      'tarjeta_debito': 'Tarjeta de débito',
      'tarjeta_credito': 'Tarjeta de crédito',
      'transferencia': 'Transferencia',
      'mixto': 'Mixto',
    };
    return {
      for (final e in datos.entries) nombres[e.key] ?? e.key: e.value,
    };
  }

  static String _moneda(double v) => '\$${v.toStringAsFixed(2)}';
}

import 'package:flutter/material.dart';
import '../../../core/utils/plataforma_app.dart';
import '../../../core/widgets/diseno_escritorio.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import '../controllers/ingresos_controller.dart';
import 'detalle_ingreso_sheet.dart';

/// Tarjeta de una transacción de ingreso, reutilizable en la vista de
/// ingresos del mes y en la vista de todas las transacciones. Al tocarla se
/// ve su detalle (en una venta, los productos que llevó).
class TransactionTile extends StatelessWidget {
  final IngresoModel ingreso;

  const TransactionTile({super.key, required this.ingreso});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final controller = Get.find<IngresosController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => mostrarDetalleIngreso(context, ingreso),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.disabled.withOpacity(0.4)),
            ),
            child: FilaConDetalle(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: controller
                      .getColorForConcepto(ingreso.concepto)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForConcepto(ingreso.concepto),
                  color: controller.getColorForConcepto(ingreso.concepto),
                  size: 24,
                ),
              ),
              principal: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingreso.clienteNombre,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Text(
                        ingreso.conceptoDescripcion,
                        style: TextStyle(
                          fontSize: 14,
                          color: c.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: controller
                              .getColorForMetodoPago(ingreso.metodoPago)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          ingreso.metodoPagoDescripcion,
                          style: TextStyle(
                            fontSize: 12,
                            color: controller
                                .getColorForMetodoPago(ingreso.metodoPago),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((ingreso.referenciaPago ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ref. ${ingreso.referenciaPago}',
                      style: TextStyle(
                        fontSize: legible(12),
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              detalle: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    controller.formatCurrency(ingreso.montoFinal),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      fontSize: 17,
                      // En escritorio, cifras del mismo ancho: los importes
                      // se alinean de una fila a otra.
                      fontFeatures: PlataformaApp.pantallaGrande
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.formatFechaCorta(ingreso.fecha),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForConcepto(String concepto) {
    switch (concepto) {
      case 'nuevo_registro':
        return Icons.person_add;
      case 'renovacion':
        return Icons.refresh;
      case 'registro':
        return Icons.how_to_reg;
      case 'visita':
        return Icons.confirmation_number_outlined;
      default:
        return Icons.receipt;
    }
  }
}

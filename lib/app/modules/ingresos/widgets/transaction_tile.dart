import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import '../controllers/ingresos_controller.dart';

/// Tarjeta de una transacción de ingreso, reutilizable en la vista de
/// ingresos del mes y en la vista de todas las transacciones.
class TransactionTile extends StatelessWidget {
  final IngresoModel ingreso;

  const TransactionTile({super.key, required this.ingreso});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<IngresosController>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.disabled.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          // Icono del concepto
          Container(
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
          const SizedBox(width: 12),

          // Información de la transacción
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingreso.clienteNombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ingreso.conceptoDescripcion,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Monto y fecha
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                controller.formatCurrency(ingreso.montoFinal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                controller.formatFechaCorta(ingreso.fecha),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
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
      default:
        return Icons.receipt;
    }
  }
}

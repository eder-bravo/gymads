import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/ingresos_controller.dart';

class IngresosView extends GetView<IngresosController> {
  const IngresosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Ingresos'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshData(),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selector de mes (compacto, en español)
            _buildMonthSelector(),

            // Total de ingresos del mes
            _buildMonthTotal(),

            const SizedBox(height: 12),

            // Encabezado de la lista
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Transacciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.titleColor,
                    ),
                  ),
                  const Spacer(),
                  Obx(() => Text(
                        '${controller.ingresos.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de transacciones a pantalla completa
            Expanded(child: _buildTransactionsList()),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SELECTOR DE MES
  // ─────────────────────────────────────────────────────────
  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.accent),
              onPressed: controller.goToPreviousMonth,
              tooltip: 'Mes anterior',
            ),
            Expanded(
              child: Obx(() => Text(
                    controller.mesSeleccionadoLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  )),
            ),
            Obx(() => IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: controller.puedeAvanzarMes
                        ? AppColors.accent
                        : AppColors.disabled,
                  ),
                  onPressed: controller.puedeAvanzarMes
                      ? controller.goToNextMonth
                      : null,
                  tooltip: 'Mes siguiente',
                )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TOTAL DEL MES
  // ─────────────────────────────────────────────────────────
  Widget _buildMonthTotal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.success.withOpacity(0.18),
              AppColors.success.withOpacity(0.06),
            ],
          ),
          border: Border.all(color: AppColors.success.withOpacity(0.25)),
        ),
        child: Obx(() {
          final stats = controller.estadisticas.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total de ingresos de ${controller.nombreMesSeleccionado}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                controller.formatCurrency(stats.totalIngresos),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${stats.totalTransacciones} transacciones · Promedio ${controller.formatCurrency(stats.promedioTransaccion)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LISTA DE TRANSACCIONES
  // ─────────────────────────────────────────────────────────
  Widget _buildTransactionsList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        );
      }

      if (!controller.tieneIngresos) {
        return RefreshIndicator(
          onRefresh: controller.refreshData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 80),
              Icon(Icons.receipt_long,
                  size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Center(
                child: Text(
                  'No hay transacciones este mes',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.refreshData,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: controller.ingresos.length,
          itemBuilder: (context, index) {
            return _buildTransactionTile(controller.ingresos[index]);
          },
        ),
      );
    });
  }

  Widget _buildTransactionTile(ingreso) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
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
              size: 20,
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
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                          fontSize: 10,
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
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                controller.formatFechaCorta(ingreso.fecha),
                style: const TextStyle(
                  fontSize: 11,
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

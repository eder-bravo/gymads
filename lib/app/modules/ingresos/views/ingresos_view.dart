import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import '../../../core/widgets/periodo_selector.dart';
import '../controllers/ingresos_controller.dart';
import '../widgets/transaction_tile.dart';
import 'todas_transacciones_view.dart';

class IngresosView extends GetView<IngresosController> {
  const IngresosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GymAppBar(
        title: 'Ingresos',
        actions: [
          Obx(() => IconButton(
                icon: controller.isExportando.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                onPressed: controller.isExportando.value
                    ? null
                    : controller.exportarPdf,
                tooltip: 'Reporte en PDF',
              )),
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
            // Periodo: día, semana, mes o rango a medida
            TourStep(
              tourKey: controller.keyPeriodo,
              title: 'Periodo',
              description: 'Elige si quieres ver el día, la semana o el mes, '
                  'o define tu propio rango de fechas.',
              borderRadius: 20,
              isFirstStep: true,
              child: PeriodoSelector(controller: controller),
            ),

            // Total de ingresos del mes
            TourStep(
              tourKey: controller.keyTotal,
              title: 'Total del periodo',
              description: 'La suma de todo lo cobrado en el periodo que '
                  'tengas seleccionado: abonos y ventas.',
              borderRadius: 20,
              child: _buildMonthTotal(),
            ),

            const SizedBox(height: 12),

            // Encabezado de la lista
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
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
                  TourStep(
                    tourKey: controller.keyVerTodas,
                    title: 'Ver todas',
                    description: 'Abre el historial completo, sin el filtro '
                        'de periodo.',
                    borderRadius: 12,
                    child: TextButton.icon(
                      onPressed: _verTodasLasTransacciones,
                      icon: const Icon(Icons.list_alt_outlined, size: 18),
                      label: const Text('Ver todas'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de transacciones a pantalla completa
            Expanded(
              child: TourStep(
                tourKey: controller.keyLista,
                title: 'Transacciones',
                description: 'Cada cobro registrado, con su fecha, su monto y '
                    'de dónde vino.',
                isLastStep: true,
                child: _buildTransactionsList(),
              ),
            ),
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
                      controller.periodoTotalLabel,
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
                  'No hay transacciones en este periodo',
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
            return TransactionTile(ingreso: controller.ingresos[index]);
          },
        ),
      );
    });
  }

  // Abre la vista a pantalla completa con todas las transacciones
  void _verTodasLasTransacciones() {
    controller.fetchTodasLasTransacciones();
    Get.to(() => const TodasTransaccionesView());
  }

}

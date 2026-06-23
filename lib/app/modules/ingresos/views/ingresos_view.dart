import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/ingresos_controller.dart';
import '../widgets/transaction_tile.dart';
import 'todas_transacciones_view.dart';

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
                  TextButton.icon(
                    onPressed: _verTodasLasTransacciones,
                    icon: const Icon(Icons.list_alt_outlined, size: 18),
                    label: const Text('Ver todas'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                  ),
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
            Obx(() => IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: controller.puedeRetrocederMes
                        ? AppColors.accent
                        : AppColors.disabled,
                  ),
                  onPressed: controller.puedeRetrocederMes
                      ? controller.goToPreviousMonth
                      : null,
                  tooltip: 'Mes anterior',
                )),
            Expanded(
              child: Builder(
                builder: (context) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showMonthPicker(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() => Text(
                              controller.mesSeleccionadoLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            )),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down,
                            color: AppColors.accent, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
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

  // Abre un selector de mes/año para saltar a un mes específico
  void _showMonthPicker(BuildContext context) {
    final now = DateTime.now();
    final current = controller.fechaInicio.value ?? now;
    int displayYear = current.year;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecciona un mes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Navegador de año
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(builder: (_) {
                          final minYear = controller.anioCreacionCuenta;
                          final puedeRetroceder =
                              minYear == null || displayYear > minYear;
                          return IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              color: puedeRetroceder
                                  ? AppColors.accent
                                  : AppColors.disabled,
                            ),
                            onPressed: puedeRetroceder
                                ? () => setState(() => displayYear--)
                                : null,
                            tooltip: 'Año anterior',
                          );
                        }),
                        Text(
                          '$displayYear',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: displayYear < now.year
                                ? AppColors.accent
                                : AppColors.disabled,
                          ),
                          onPressed: displayYear < now.year
                              ? () => setState(() => displayYear++)
                              : null,
                          tooltip: 'Año siguiente',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Cuadrícula de meses
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isFuture =
                            controller.esMesFuturo(displayYear, month);
                        final isAnterior = controller.esMesAnteriorACreacion(
                            displayYear, month);
                        final isDisabled = isFuture || isAnterior;
                        final isSelected = displayYear == current.year &&
                            month == current.month;
                        final shortName =
                            IngresosController.nombresMesesCortos[index];
                        final label = '${shortName[0].toUpperCase()}'
                            '${shortName.substring(1)}';

                        return Material(
                          color: isSelected
                              ? AppColors.accent.withOpacity(0.2)
                              : AppColors.containerBackground,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: isDisabled
                                ? null
                                : () {
                                    controller.seleccionarMes(
                                        displayYear, month);
                                    Get.back();
                                  },
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isDisabled
                                      ? AppColors.disabled
                                      : isSelected
                                          ? AppColors.accent
                                          : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

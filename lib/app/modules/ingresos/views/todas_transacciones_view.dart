import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import '../controllers/ingresos_controller.dart';
import '../widgets/transaction_tile.dart';

/// Vista a pantalla completa con todas las transacciones registradas,
/// sin filtro de mes.
class TodasTransaccionesView extends GetView<IngresosController> {
  const TodasTransaccionesView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 960,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
        title: 'Todas las transacciones',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.fetchTodasLasTransacciones,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contador de transacciones
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Obx(() => Text(
                        '${controller.todasTransacciones.length} transacciones',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      )),
                ],
              ),
            ),

            // Lista
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final c = context.colores;
    return Obx(() {
      if (controller.isLoadingTodas.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        );
      }

      if (controller.todasTransacciones.isEmpty) {
        return RefreshIndicator(
          onRefresh: controller.fetchTodasLasTransacciones,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              Icon(Icons.receipt_long, size: 64, color: c.textSecondary),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No hay transacciones registradas',
                  style: TextStyle(color: c.textSecondary),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.fetchTodasLasTransacciones,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: controller.todasTransacciones.length,
          itemBuilder: (context, index) {
            return TransactionTile(
                ingreso: controller.todasTransacciones[index]);
          },
        ),
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/ingresos_controller.dart';
import '../widgets/transaction_tile.dart';

/// Vista a pantalla completa con todas las transacciones registradas,
/// sin filtro de mes.
class TodasTransaccionesView extends GetView<IngresosController> {
  const TodasTransaccionesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Todas las transacciones'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      )),
                ],
              ),
            ),

            // Lista
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
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
            children: const [
              SizedBox(height: 80),
              Icon(Icons.receipt_long, size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Center(
                child: Text(
                  'No hay transacciones registradas',
                  style: TextStyle(color: AppColors.textSecondary),
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

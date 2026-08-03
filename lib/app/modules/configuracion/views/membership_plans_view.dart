import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/membership_plan_model.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/membership_plans_controller.dart';
import 'membership_plan_form_view.dart';

/// Pantalla de administración de Abonos Fijos (planes de membresía).
class MembershipPlansView extends GetView<MembershipPlansController> {
  const MembershipPlansView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GymAppBar(
        title: 'Abonos Fijos',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openPlanForm(),
            tooltip: 'Agregar plan',
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          if (controller.planes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.card_membership,
                      size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay planes configurados',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _openPlanForm(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Crear primer plan',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadPlanes,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: controller.planes.length,
              itemBuilder: (context, index) {
                final plan = controller.planes[index];
                return _buildPlanCard(plan);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlanCard(MembershipPlanModel plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: ListTile(
        onTap: () => _openPlanForm(plan: plan),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.card_membership, color: AppColors.accent),
        ),
        title: Text(
          plan.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${plan.descripcionPeriodo} — \$${plan.price.toStringAsFixed(2)}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => controller.deletePlan(plan),
          tooltip: 'Eliminar',
        ),
      ),
    );
  }

  /// Abre el formulario a pantalla completa de creación/edición de un plan.
  void _openPlanForm({MembershipPlanModel? plan}) {
    Get.to(() => MembershipPlanFormView(plan: plan));
  }
}

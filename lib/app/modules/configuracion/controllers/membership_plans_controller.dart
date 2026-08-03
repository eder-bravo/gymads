import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/membership_plan_model.dart';
import 'package:gymads/app/data/repositories/membership_plan_repository.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';

/// Controlador de la pantalla de Abonos Fijos (planes de membresía).
class MembershipPlansController extends GetxController {
  final MembershipPlanRepository repository = MembershipPlanRepository();

  final planes = <MembershipPlanModel>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadPlanes();
  }

  Future<void> loadPlanes() async {
    isLoading.value = true;
    try {
      final result = await repository.getPlans();
      planes.assignAll(result);
    } finally {
      isLoading.value = false;
    }
  }

  /// Crea o actualiza un plan. Retorna true si tuvo éxito.
  Future<bool> savePlan({
    MembershipPlanModel? existing,
    required String name,
    required String periodType,
    required int periodCount,
    required double price,
  }) async {
    isSaving.value = true;
    try {
      if (existing != null) {
        final updated = await repository.updatePlan(existing.copyWith(
          name: name,
          periodType: periodType,
          periodCount: periodCount,
          price: price,
        ));
        if (updated != null) {
          final index = planes.indexWhere((p) => p.id == existing.id);
          if (index != -1) planes[index] = updated;
          planes.sort((a, b) => a.price.compareTo(b.price));
          planes.refresh();
          SnackbarHelper.success('Éxito', 'Plan actualizado correctamente');
          return true;
        }
      } else {
        final created = await repository.createPlan(MembershipPlanModel(
          id: '',
          name: name,
          periodType: periodType,
          periodCount: periodCount,
          price: price,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        if (created != null) {
          planes.add(created);
          planes.sort((a, b) => a.price.compareTo(b.price));
          SnackbarHelper.success('Éxito', 'Plan creado correctamente');
          return true;
        }
      }
      SnackbarHelper.error('Error', 'No se pudo guardar el plan');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Pide confirmación y elimina el plan.
  Future<void> deletePlan(MembershipPlanModel plan) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar plan',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '¿Eliminar el plan "${plan.name}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await repository.deletePlan(plan.id);
    if (success) {
      planes.removeWhere((p) => p.id == plan.id);
      SnackbarHelper.success('Éxito', 'Plan eliminado');
    } else {
      SnackbarHelper.error('Error', 'No se pudo eliminar el plan');
    }
  }
}

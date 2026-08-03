import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/membership_plan_model.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/membership_plans_controller.dart';

/// Formulario a pantalla completa para crear o editar un plan de abono fijo.
class MembershipPlanFormView extends GetView<MembershipPlansController> {
  final MembershipPlanModel? plan;

  const MembershipPlanFormView({super.key, this.plan});

  bool get isEditing => plan != null;

  static const periodTypes = ['Meses', 'Semanas', 'Días', 'Años'];

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: plan?.name ?? '');
    final countController =
        TextEditingController(text: '${plan?.periodCount ?? 1}');
    final priceController = TextEditingController(
        text: plan != null ? plan!.price.toStringAsFixed(2) : '');
    final periodType = (plan?.periodType ?? 'Meses').obs;

    InputDecoration decoration(String label, {String? prefix}) =>
        InputDecoration(
          labelText: label,
          prefixText: prefix,
          prefixStyle: const TextStyle(color: AppColors.accent),
          filled: true,
          fillColor: AppColors.containerBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        );

    Future<void> onSave() async {
      if (!formKey.currentState!.validate()) return;
      final success = await controller.savePlan(
        existing: plan,
        name: nameController.text.trim(),
        periodType: periodType.value,
        periodCount: int.parse(countController.text),
        price: double.parse(priceController.text),
      );
      if (success) Get.back();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GymAppBar(
        title: isEditing ? 'Editar Plan' : 'Nuevo Plan',
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() => TextButton(
                onPressed: controller.isSaving.value ? null : onSave,
                child: controller.isSaving.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEditing ? 'Guardar' : 'Crear',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              )),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_membership,
                          color: AppColors.accent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing
                              ? 'Actualiza los datos del plan'
                              : 'Define un plan de precio fijo que el staff podrá seleccionar directamente en Abonar',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  textCapitalization: TextCapitalization.words,
                  decoration: decoration('Nombre del plan'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: countController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: decoration('Cantidad'),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return (n == null || n <= 0) ? 'Inválido' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Obx(() => DropdownButtonFormField<String>(
                            value: periodType.value,
                            decoration: decoration('Periodo'),
                            dropdownColor: AppColors.cardBackground,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            items: periodTypes
                                .map((t) => DropdownMenuItem(
                                    value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) periodType.value = v;
                            },
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  decoration:
                      decoration('Precio total del plan', prefix: '\$ '),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return (n == null || n <= 0) ? 'Inválido' : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

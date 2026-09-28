import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/abono_prices_controller.dart';

/// Pantalla de Precios de Abonos: precio fijo por día, semana, mes y año.
class AbonoPricesView extends GetView<AbonoPricesController> {
  const AbonoPricesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const GymAppBar(title: 'Precios de abonos'),
      // Como en los demás formularios: el botón para guardar, fijo abajo.
      bottomNavigationBar: Obx(() => controller.isLoading.value
          ? const SizedBox.shrink()
          : PieDeFormulario(
              child: BotonGuardar(
                texto: controller.isOnboarding ? 'Continuar' : 'Guardar precios',
                guardando: controller.isSaving.value,
                onPressed: () => controller.savePrices(),
              ),
            )),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.attach_money,
                          color: AppColors.accent, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Al registrar un abono el precio se llena solo según '
                          'el periodo elegido y el total se calcula automáticamente.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const TituloSeccion('Precio por periodo',
                    detalle: 'Deja vacío el periodo que no ofrezcas.'),
                _priceField(
                  controller: controller.dayController,
                  label: 'Precio por día',
                  icon: Icons.today,
                ),
                const SizedBox(height: 16),
                _priceField(
                  controller: controller.weekController,
                  label: 'Precio por semana',
                  icon: Icons.date_range,
                ),
                const SizedBox(height: 16),
                _priceField(
                  controller: controller.monthController,
                  label: 'Precio por mes',
                  icon: Icons.calendar_month,
                ),
                const SizedBox(height: 16),
                _priceField(
                  controller: controller.yearController,
                  label: 'Precio por año',
                  icon: Icons.event_repeat,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _priceField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: '\$ ',
        prefixStyle: const TextStyle(
          color: AppColors.accent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

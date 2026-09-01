import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/configuracion_controller.dart';

class ConfiguracionView extends GetView<ConfiguracionController> {
  const ConfiguracionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const GymAppBar(title: 'Configuración'),
      body: SafeArea(
        child: Obx(() => ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Header con información básica del usuario
                _buildUserHeader(),

                const SizedBox(height: 24),

                // Lista de opciones de configuración
                _buildConfigurationOptions(),
              ],
            )),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Card(
      elevation: 4,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.titleColor,
              ),
              child: const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.titleColor,
                child: Icon(
                  Icons.person,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                controller.userName.value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationOptions() {
    return Column(
      children: [
        // Opción de Cuenta
        TourStep(
          tourKey: controller.keyCuenta,
          title: 'Cuenta',
          description: 'Tus datos personales, el nombre del gimnasio y el '
              'lector de tarjetas.',
          borderRadius: 12,
          isFirstStep: true,
          child: _buildOptionTile(
            icon: Icons.account_circle,
            iconColor: AppColors.info,
            title: 'Cuenta',
            subtitle: 'Información personal y configuración de cuenta',
            onTap: () => controller.openAccountSettings(),
            trailing: _buildStatusIndicator(true),
          ),
        ),

        // Precios de abonos: administración, solo el dueño.
        if (controller.isOwner) ...[
          const SizedBox(height: 12),
          TourStep(
            tourKey: controller.keyPrecios,
            title: 'Precios de abonos',
            description: 'Define cuánto cuesta un día, una semana, un mes o un '
                'año. Al cobrar, el monto se calcula solo.',
            borderRadius: 12,
            child: _buildOptionTile(
              icon: Icons.attach_money,
              iconColor: AppColors.success,
              title: 'Precios de Abonos',
              subtitle: 'Precio por día, semana, mes y año',
              onTap: () => controller.openAbonoPrices(),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Categorías de productos (inventario y punto de venta)
        TourStep(
          tourKey: controller.keyCategorias,
          title: 'Categorías de productos',
          description: 'Los grupos con los que ordenas tus productos en el '
              'inventario y en el punto de venta.',
          borderRadius: 12,
          // Para el staff este es el último paso; para el dueño aún viene
          // "Accesos del personal".
          isLastStep: !controller.isOwner,
          child: _buildOptionTile(
            icon: Icons.category,
            iconColor: AppColors.accent,
            title: 'Categorías de productos',
            subtitle: 'Organiza el inventario y el punto de venta',
            onTap: () => controller.openCategorias(),
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.textSecondary),
          ),
        ),

        // Accesos del personal: solo el dueño puede crear y revocar.
        if (controller.isOwner) ...[
          const SizedBox(height: 12),
          TourStep(
            tourKey: controller.keyAccesos,
            title: 'Accesos del personal',
            description: 'Da acceso a tus empleados con un código. Entran sin '
                'correo ni contraseña y no ven esta configuración.',
            borderRadius: 12,
            child: _buildOptionTile(
              icon: Icons.badge,
              iconColor: AppColors.brand,
              title: 'Accesos del personal',
              subtitle: 'Códigos de entrada para tus empleados',
              onTap: () => controller.openStaffAccesos(),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),

          // Entradas y salidas de los clientes, y horario del gimnasio.
          const SizedBox(height: 12),
          TourStep(
            tourKey: controller.keyControlAccesos,
            title: 'Control de accesos',
            description: 'Decide si además de la entrada quieres marcar la '
                'salida de tus clientes, y en qué horario abres.',
            borderRadius: 12,
            isLastStep: true,
            child: _buildOptionTile(
              icon: Icons.door_front_door_outlined,
              iconColor: AppColors.info,
              title: 'Control de accesos',
              subtitle: 'Entradas, salidas y horario del gimnasio',
              onTap: () => controller.openControlAccesos(),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Sección de acciones peligrosas
        _buildDangerousActions(),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool enabled = true,
  }) {
    return Card(
      elevation: 3,
      color: enabled ? AppColors.cardBackground : AppColors.disabled,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.cardBackground,
        ),
        child: ListTile(
          enabled: enabled,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: enabled ? iconColor : AppColors.textHint,
              size: 26,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: enabled ? AppColors.textPrimary : AppColors.textHint,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? AppColors.textSecondary : AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing: trailing ??
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: enabled ? AppColors.textSecondary : AppColors.textHint,
              ),
          onTap: enabled ? onTap : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isActive) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isActive ? AppColors.success : AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildDangerousActions() {
    return Card(
      elevation: 3,
      color: AppColors.error.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout,
                  color: AppColors.error,
                  size: 26,
                ),
              ),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.error,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Salir de la aplicación',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.error.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 18, color: AppColors.error.withOpacity(0.8)),
              onTap: controller.logout,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ],
        ),
      ),
    );
  }
}

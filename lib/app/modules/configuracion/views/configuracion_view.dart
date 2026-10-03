import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../data/services/tema_service.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/configuracion_controller.dart';
import '../../../core/utils/plataforma_app.dart';
import 'escaner_configuracion_view.dart';

class ConfiguracionView extends GetView<ConfiguracionController> {
  const ConfiguracionView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 960,
      backgroundColor: c.backgroundColor,
      appBar: const GymAppBar(title: 'Configuración'),
      body: SafeArea(
        child: Obx(() => ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Header con información básica del usuario
                _buildUserHeader(context),

                const SizedBox(height: 24),

                // Lista de opciones de configuración
                _buildConfigurationOptions(context),
              ],
            )),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final c = context.colores;
    return Card(
      elevation: 4,
      color: c.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.titleColor,
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: c.titleColor,
                child: const Icon(
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationOptions(BuildContext context) {
    final c = context.colores;
    final opciones = <Widget>[
      // Opción de Cuenta
      if (PlataformaApp.escanerFisico) ...[
        _buildOptionTile(context,
            icon: Icons.barcode_reader,
            iconColor: AppColors.accent,
            title: 'Escáner de códigos',
            subtitle: 'Conexión USB o Bluetooth, ajustes y prueba',
            onTap: () => Get.to(() => const EscanerConfiguracionView())),
        const SizedBox(height: 16),
      ],
      TourStep(
        tourKey: controller.keyCuenta,
        title: 'Cuenta',
        description: 'Tus datos, el gimnasio y tu contraseña.',
        borderRadius: 12,
        isFirstStep: true,
        isLastStep: controller.esUltimoPasoDelTour(controller.keyCuenta),
        child: _buildOptionTile(
          context,
          icon: Icons.account_circle,
          iconColor: AppColors.info,
          title: 'Cuenta',
          subtitle: 'Información personal y configuración de cuenta',
          onTap: () => controller.openAccountSettings(),
          trailing: _buildStatusIndicator(true),
        ),
      ),

      // Claro, oscuro o como el teléfono. Se guarda en este teléfono y la
      // ve cualquier rol. Sin paso de tour: no vuelve a mostrar el tour a
      // quien ya lo vio.
      const SizedBox(height: 12),
      TourStep(
        tourKey: controller.keyApariencia,
        title: 'Apariencia',
        description: PlataformaApp.escritorio
            ? 'Clara, oscura o como tu sistema.'
            : 'Clara, oscura o como tu teléfono.',
        borderRadius: 12,
        isLastStep: controller.esUltimoPasoDelTour(controller.keyApariencia),
        child: _buildOptionTile(
          context,
          icon: Icons.brightness_6_outlined,
          iconColor: AppColors.accent,
          title: 'Apariencia',
          subtitle: _HojaApariencia.nombre(TemaService.to.modo.value),
          onTap: () => mostrarHojaAdaptable<void>(
            context,
            showDragHandle: true,
            anchoMaximo: 420,
            builder: (_) => const _HojaApariencia(),
          ),
        ),
      ),

      // Precios de abonos: los fija quien puede tocar el gimnasio.
      if (controller.can(Permission.gestionarPreciosAbonos)) ...[
        const SizedBox(height: 12),
        TourStep(
          tourKey: controller.keyPrecios,
          title: 'Precios de abonos',
          description: 'Cuánto cuesta un día, una semana, un mes o un año.',
          borderRadius: 12,
          isLastStep: controller.esUltimoPasoDelTour(controller.keyPrecios),
          child: _buildOptionTile(
            context,
            icon: Icons.attach_money,
            iconColor: AppColors.success,
            title: 'Precios de Abonos',
            subtitle: 'Precio por día, semana, mes y año',
            onTap: () => controller.openAbonoPrices(),
            trailing:
                Icon(Icons.arrow_forward_ios, size: 16, color: c.textSecondary),
          ),
        ),
      ],

      // Categorías de productos (inventario y punto de venta)
      if (controller.can(Permission.gestionarCategorias)) ...[
        const SizedBox(height: 12),
        TourStep(
          tourKey: controller.keyCategorias,
          title: 'Categorías de productos',
          description: 'Para agrupar tus productos.',
          borderRadius: 12,
          isLastStep: controller.esUltimoPasoDelTour(controller.keyCategorias),
          child: _buildOptionTile(
            context,
            icon: Icons.category,
            iconColor: AppColors.accent,
            title: 'Categorías de productos',
            subtitle: 'Organiza el inventario y el punto de venta',
            onTap: () => controller.openCategorias(),
            trailing:
                Icon(Icons.arrow_forward_ios, size: 16, color: c.textSecondary),
          ),
        ),
      ],

      // Accesos del personal: el dueño y el encargado, cada uno solo sobre
      // los roles por debajo del suyo.
      if (controller.can(Permission.gestionarAccesosStaff)) ...[
        const SizedBox(height: 12),
        TourStep(
          tourKey: controller.keyAccesos,
          title: 'Accesos del personal',
          description:
              'Tus empleados entran con un código, sin correo ni contraseña.',
          borderRadius: 12,
          isLastStep: controller.esUltimoPasoDelTour(controller.keyAccesos),
          child: _buildOptionTile(
            context,
            icon: Icons.badge,
            iconColor: AppColors.brand,
            title: 'Accesos del personal',
            subtitle: 'Códigos de entrada para tus empleados',
            onTap: () => controller.openStaffAccesos(),
            trailing:
                Icon(Icons.arrow_forward_ios, size: 16, color: c.textSecondary),
          ),
        ),
      ],

      // Entradas y salidas de los clientes, y horario del gimnasio.
      if (controller.can(Permission.gestionarControlAccesos)) ...[
        const SizedBox(height: 12),
        TourStep(
          tourKey: controller.keyControlAccesos,
          title: 'Control de accesos',
          description: 'Si se marca la salida y en qué horario abres.',
          borderRadius: 12,
          isLastStep:
              controller.esUltimoPasoDelTour(controller.keyControlAccesos),
          child: _buildOptionTile(
            context,
            icon: Icons.door_front_door_outlined,
            iconColor: AppColors.info,
            title: 'Control de accesos',
            subtitle: 'Entradas, salidas y horario del gimnasio',
            onTap: () => controller.openControlAccesos(),
            trailing:
                Icon(Icons.arrow_forward_ios, size: 16, color: c.textSecondary),
          ),
        ),
      ],

      // El lector de tarjetas: su IP y a qué gimnasio pertenece.
      if (controller.can(Permission.gestionarControlAccesos)) ...[
        const SizedBox(height: 12),
        TourStep(
          tourKey: controller.keyLector,
          title: 'Lector de tarjetas',
          description: 'Conecta y vincula el lector a tu gimnasio.',
          borderRadius: 12,
          isLastStep: controller.esUltimoPasoDelTour(controller.keyLector),
          child: _buildOptionTile(
            context,
            icon: Icons.nfc,
            iconColor: AppColors.brand,
            title: 'Lector de tarjetas',
            subtitle: 'Vinculación y dirección del lector',
            onTap: () => controller.openLector(),
            trailing:
                Icon(Icons.arrow_forward_ios, size: 16, color: c.textSecondary),
          ),
        ),
      ],

      // Los permisos se piden todos al entrar la primera vez; aquí se ve
      // cómo quedaron y se corrigen.
      const SizedBox(height: 12),
      TourStep(
        tourKey: controller.keyPermisos,
        title: 'Permisos de la app',
        description: 'Revisa el acceso a los dispositivos de este equipo.',
        borderRadius: 12,
        isLastStep: controller.esUltimoPasoDelTour(controller.keyPermisos),
        child: _buildOptionTile(
          context,
          icon: Icons.verified_user_outlined,
          iconColor: AppColors.info,
          title: 'Permisos de la app',
          subtitle: 'Cámara, notificaciones y lector de tarjetas',
          onTap: () => controller.openPermisos(),
          trailing:
              Icon(Icons.arrow_forward_ios, size: 16, color: c.textSecondary),
        ),
      ),

      const SizedBox(height: 24),

      // Sección de acciones peligrosas
      _buildDangerousActions(),
    ];
    if (!PlataformaApp.pantallaGrande) return Column(children: opciones);
    // En escritorio las opciones van en dos columnas en vez de una lista
    // larga de tarjetas separadas; las acciones peligrosas quedan aparte,
    // debajo y a todo lo ancho.
    final tarjetas = opciones.where((w) => w is! SizedBox).toList();
    final peligrosas = tarjetas.removeLast();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResumenAdaptable(anchoMinimo: 380, espacio: 12, children: tarjetas),
        const SizedBox(height: 24),
        peligrosas,
      ],
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool enabled = true,
  }) {
    final c = context.colores;
    return Card(
      elevation: 3,
      color: enabled ? c.cardBackground : c.disabled,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
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
            color: enabled ? iconColor : c.textHint,
            size: 26,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: enabled ? c.textPrimary : c.textHint,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? c.textSecondary : c.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: enabled ? c.textSecondary : c.textHint,
            ),
        onTap: enabled ? onTap : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

/// Elegir el modo: según el teléfono, claro u oscuro. El cambio se ve al
/// instante en toda la app.
class _HojaApariencia extends StatelessWidget {
  const _HojaApariencia();

  static String nombre(ThemeMode modo) => switch (modo) {
        ThemeMode.system =>
          PlataformaApp.escritorio ? 'Según el sistema' : 'Según el teléfono',
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
      };

  static IconData _icono(ThemeMode modo) => switch (modo) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tema = TemaService.to;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Apariencia',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final modo in const [
              ThemeMode.system,
              ThemeMode.light,
              ThemeMode.dark,
            ])
              Obx(() {
                final elegido = tema.modo.value == modo;
                return ListTile(
                  leading: Icon(
                    _icono(modo),
                    color: elegido ? AppColors.accent : c.textSecondary,
                  ),
                  title: Text(
                    nombre(modo),
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: elegido
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    tema.cambiar(modo);
                    Navigator.of(context).pop();
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

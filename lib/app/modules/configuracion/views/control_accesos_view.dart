import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/models/gym_settings_model.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/configuracion_controller.dart';

/// Entradas y salidas de los clientes, y horario del gimnasio.
///
/// Cada control guarda al momento de cambiarlo; no hay botón de guardar.
class ControlAccesosView extends StatefulWidget {
  const ControlAccesosView({super.key});

  @override
  State<ControlAccesosView> createState() => _ControlAccesosViewState();
}

class _ControlAccesosViewState extends State<ControlAccesosView> {
  ConfiguracionController get controller => Get.find<ConfiguracionController>();

  @override
  void initState() {
    super.initState();
    // Se relee al entrar por si se cambió desde otro dispositivo. En
    // initState y no en build: build se repite y volvería a consultar cada vez.
    controller.loadControlAccesos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const GymAppBar(title: 'Control de accesos'),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoadingAccesos.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final ajustes = controller.accesosSettings.value;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionLabel('REGISTRO'),
              const SizedBox(height: 8),
              _buildSalidasTile(ajustes),
              const SizedBox(height: 24),
              _buildSectionLabel('HORARIO DEL GIMNASIO'),
              const SizedBox(height: 8),
              _buildHorarioTile(
                context,
                label: 'Abre',
                hora: ajustes.horaApertura,
                onSelect: controller.setHoraApertura,
              ),
              const SizedBox(height: 8),
              _buildHorarioTile(
                context,
                label: 'Cierra',
                hora: ajustes.horaCierre,
                onSelect: controller.setHoraCierre,
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'El reporte de entradas usa este horario para mostrar las '
                  'horas con más afluencia.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSalidasTile(GymSettingsModel ajustes) {
    return Card(
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        value: ajustes.registrarSalidas,
        onChanged: controller.setRegistrarSalidas,
        activeColor: AppColors.accent,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.titleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.door_front_door_outlined,
              color: AppColors.titleColor, size: 22),
        ),
        title: const Text(
          'Registrar salidas',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            ajustes.registrarSalidas
                ? 'El segundo pase del día marca la salida del cliente'
                : 'Solo se registra la entrada de cada día',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildHorarioTile(
    BuildContext context, {
    required String label,
    required HoraDelDia hora,
    required Future<void> Function(HoraDelDia) onSelect,
  }) {
    return Card(
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.titleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.schedule,
              color: AppColors.titleColor, size: 22),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            hora.etiqueta,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: const Icon(Icons.edit_outlined,
            size: 20, color: AppColors.titleColor),
        onTap: () => _elegirHora(context, hora, onSelect),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Future<void> _elegirHora(
    BuildContext context,
    HoraDelDia actual,
    Future<void> Function(HoraDelDia) onSelect,
  ) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual.hora, minute: actual.minuto),
      helpText: 'Selecciona la hora',
      // El reloj sale en 12 h por MaterialLocalizations12h (ver main.dart);
      // el idioma por sí solo lo daría en 24 h.
      builder: (context, child) => Theme(
        data: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (elegida != null) {
      await onSelect(HoraDelDia(elegida.hour, elegida.minute));
    }
  }
}

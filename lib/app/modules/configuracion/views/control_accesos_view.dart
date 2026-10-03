import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
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
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 880,
      backgroundColor: c.backgroundColor,
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
              _buildSectionLabel('REGISTRO', escritorio: 'Registro'),
              const SizedBox(height: 8),
              _buildSalidasTile(ajustes),
              const SizedBox(height: 24),
              _buildSectionLabel('HORARIO DEL GIMNASIO',
                  escritorio: 'Horario del gimnasio'),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Se usa en el reporte de entradas.',
                  style: TextStyle(
                    fontSize: legible(12),
                    color: c.textSecondary,
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

  Widget _buildSectionLabel(String label, {String? escritorio}) {
    final c = context.colores;
    // En escritorio, el mismo título de sección que los formularios.
    if (PlataformaApp.pantallaGrande) return TituloSeccion(escritorio ?? label);
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSalidasTile(GymSettingsModel ajustes) {
    final c = context.colores;
    return Card(
      elevation: 2,
      color: c.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        value: ajustes.registrarSalidas,
        onChanged: controller.setRegistrarSalidas,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.titleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.door_front_door_outlined,
              color: c.titleColor, size: 22),
        ),
        title: Text(
          'Registrar salidas',
          style: TextStyle(
            fontSize: 16,
            color: c.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            ajustes.registrarSalidas
                ? 'El segundo pase del día marca la salida del cliente'
                : 'Solo se registra la entrada de cada día',
            style: TextStyle(
              fontSize: legible(13),
              color: c.textSecondary,
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
    final c = context.colores;
    return Card(
      elevation: 2,
      color: c.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.titleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.schedule, color: c.titleColor, size: 22),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: legible(12),
            color: c.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            hora.etiqueta,
            style: TextStyle(
              fontSize: 16,
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // En escritorio dice qué hace; en el teléfono, el lápiz de siempre.
        trailing: PlataformaApp.pantallaGrande
            ? TextButton.icon(
                onPressed: () => _elegirHora(context, hora, onSelect),
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Cambiar hora'),
                style: TextButton.styleFrom(
                  foregroundColor: c.titleColor,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              )
            : Icon(Icons.edit_outlined, size: 20, color: c.titleColor),
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
    );

    if (elegida != null) {
      await onSelect(HoraDelDia(elegida.hour, elegida.minute));
    }
  }
}

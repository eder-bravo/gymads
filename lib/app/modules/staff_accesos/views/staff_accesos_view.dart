import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/staff_role.dart';
import '../../../data/models/staff_acceso_model.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/staff_accesos_controller.dart';
import 'codigo_generado_dialog.dart';
import 'staff_acceso_form_dialog.dart';

/// Accesos del personal. Solo la ve el dueño del gimnasio.
class StaffAccesosView extends GetView<StaffAccesosController> {
  const StaffAccesosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const GymAppBar(title: 'Accesos del personal'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: _crear,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Nuevo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (controller.accesos.isEmpty) return _buildEmpty();
          return _buildList();
        }),
      ),
    );
  }

  // ============================================
  // ACCIONES
  // ============================================

  Future<void> _crear() async {
    final creado = await showStaffAccesoFormDialog();
    if (creado == null) return;

    await showCodigoGeneradoDialog(
      nombre: creado.nombre,
      codigo: creado.codigo,
      gymName: TenantContextService.to.gymName ?? 'el gimnasio',
    );
  }

  /// Cambia el rol sin regenerar el código: si la persona ya está trabajando,
  /// su perfil cambia con el acceso y no tiene que volver a entrar.
  Future<void> _cambiarRol(StaffAccesoModel acceso) async {
    final elegido = await Get.dialog<StaffRole>(
      SimpleDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Rol de ${acceso.nombre}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: controller.rolesAsignables.map((rol) {
          final actual = rol == acceso.rol;
          return SimpleDialogOption(
            onPressed: () => Get.back(result: rol),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    actual
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: actual ? AppColors.accent : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rol.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rol.descripcion,
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (elegido != null) await controller.cambiarRol(acceso, elegido);
  }

  Future<void> _regenerar(StaffAccesoModel acceso) async {
    final confirmado = await _confirmar(
      titulo: 'Generar código nuevo',
      mensaje: acceso.estaActivo
          ? '${acceso.nombre} dejará de tener acceso en el dispositivo donde '
              'entró y tendrá que usar el código nuevo.'
          : 'El código anterior de ${acceso.nombre} dejará de servir.',
      textoConfirmar: 'Generar',
      color: AppColors.warning,
    );
    if (!confirmado) return;

    final codigo = await controller.regenerarCodigo(acceso);
    if (codigo == null) return;

    await showCodigoGeneradoDialog(
      nombre: acceso.nombre,
      codigo: codigo,
      gymName: TenantContextService.to.gymName ?? 'el gimnasio',
      esRegenerado: true,
    );
  }

  Future<void> _revocar(StaffAccesoModel acceso) async {
    final confirmado = await _confirmar(
      titulo: 'Revocar acceso',
      mensaje: '${acceso.nombre} perderá el acceso a la app. Podrás volver a '
          'darle uno generando un código nuevo.',
      textoConfirmar: 'Revocar',
      color: AppColors.warning,
    );
    if (confirmado) await controller.revocar(acceso);
  }

  Future<void> _eliminar(StaffAccesoModel acceso) async {
    final confirmado = await _confirmar(
      titulo: 'Eliminar acceso',
      mensaje: 'Se borrará el acceso de ${acceso.nombre} por completo. '
          'Esta acción no se puede deshacer.',
      textoConfirmar: 'Eliminar',
      color: AppColors.error,
    );
    if (confirmado) await controller.eliminar(acceso);
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
    required Color color,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        content: Text(
          mensaje,
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.9),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(textoConfirmar,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ============================================
  // UI
  // ============================================

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined,
                size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes personal',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea un acceso y comparte el código. Tu empleado entra sin '
              'correo ni contraseña, y no verá la configuración del gimnasio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _crear,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'Crear el primero',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        itemCount: controller.accesos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildTile(controller.accesos[index]),
      ),
    );
  }

  Widget _buildTile(StaffAccesoModel acceso) {
    final color = _colorEstado(acceso);

    return Card(
      elevation: 3,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_iconoEstado(acceso), color: color, size: 22),
        ),
        title: Text(
          acceso.nombre,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                acceso.estadoTexto,
                style: TextStyle(color: color, fontSize: 13),
              ),
              // El rol es lo que decide qué ve esta persona al entrar, así que
              // se lee de un vistazo sin abrir el menú.
              Text(
                '  ·  ${acceso.rol.label}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // La lista muestra a todo el equipo, pero solo se puede actuar sobre
        // los roles por debajo del propio: un encargado ve a otro encargado y
        // al dueño, y sin esto tendría un menú cuyas opciones fallan todas.
        trailing: !controller.puedeGestionar(acceso)
            ? null
            : PopupMenuButton<String>(
                color: AppColors.cardBackground,
                icon:
                    const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (value) {
                  switch (value) {
                    case 'renombrar':
                      showStaffAccesoFormDialog(existing: acceso);
                      break;
                    case 'rol':
                      _cambiarRol(acceso);
                      break;
                    case 'regenerar':
                      _regenerar(acceso);
                      break;
                    case 'revocar':
                      _revocar(acceso);
                      break;
                    case 'eliminar':
                      _eliminar(acceso);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  _menuItem('renombrar', Icons.edit, 'Cambiar nombre'),
                  _menuItem('rol', Icons.badge_outlined, 'Cambiar rol'),
                  _menuItem(
                      'regenerar', Icons.autorenew, 'Generar código nuevo'),
                  // Revocar solo tiene sentido si todavía hay algo que cortar.
                  if (!acceso.estaRevocado)
                    _menuItem('revocar', Icons.block, 'Revocar acceso',
                        color: AppColors.warning),
                  _menuItem('eliminar', Icons.delete_outline, 'Eliminar',
                      color: AppColors.error),
                ],
              ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color color = AppColors.textPrimary,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Color _colorEstado(StaffAccesoModel acceso) {
    if (acceso.estaActivo) return AppColors.success;
    if (acceso.estaPendiente) return AppColors.warning;
    return AppColors.error;
  }

  IconData _iconoEstado(StaffAccesoModel acceso) {
    if (acceso.estaActivo) return Icons.person;
    if (acceso.estaPendiente) return Icons.vpn_key;
    return Icons.person_off;
  }
}

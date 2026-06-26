import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/configuracion_controller.dart';

/// Account settings view — shows and allows editing of user profile data
class CuentaView extends GetView<ConfiguracionController> {
  const CuentaView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Mi Cuenta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Obx(() => ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Avatar + name header
                _buildProfileHeader(),
                const SizedBox(height: 24),

                // Personal info section
                _buildSectionLabel('Información Personal'),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.person_outline,
                  label: 'Nombre(s)',
                  value: controller.firstName.value,
                  onEdit: () => _showEditDialog(
                    context,
                    title: 'Nombre(s)',
                    currentValue: controller.firstName.value,
                    onSave: (val) => controller.updateFirstName(val),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.person_outline,
                  label: 'Apellidos',
                  value: controller.lastName.value,
                  onEdit: () => _showEditDialog(
                    context,
                    title: 'Apellidos',
                    currentValue: controller.lastName.value,
                    onSave: (val) => controller.updateLastName(val),
                  ),
                ),

                const SizedBox(height: 24),

                // Account info section
                _buildSectionLabel('Cuenta'),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  label: 'Correo electrónico',
                  value: controller.userEmail.value,
                  editable: false,
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Rol',
                  value: controller.userRole.value,
                  editable: false,
                ),

                const SizedBox(height: 24),

                // Gym info section
                _buildSectionLabel('Gimnasio'),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.fitness_center,
                  label: 'Gimnasio',
                  value: controller.gymName.value.isNotEmpty
                      ? controller.gymName.value
                      : 'Cargando...',
                  editable: false,
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Sucursal',
                  value: controller.branchName.value.isNotEmpty
                      ? controller.branchName.value
                      : 'Cargando...',
                  editable: false,
                ),

                const SizedBox(height: 40),

                // Danger zone
                _buildSectionLabel('Zona de Peligro'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Borrar todos los datos',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Elimina permanentemente tu gimnasio, clientes, inventario, pagos y tu cuenta. Esta acción no se puede deshacer.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => controller.deleteGymAndAccount(),
                          icon: const Icon(Icons.delete_forever, size: 20),
                          label: const Text('Borrar datos'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[400],
                            side: BorderSide(color: Colors.red[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            )),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 4,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.titleColor.withOpacity(0.2),
                border: Border.all(
                  color: AppColors.titleColor.withOpacity(0.5),
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.titleColor.withOpacity(0.1),
                child: Text(
                  _getInitials(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              controller.userName.value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              controller.userEmail.value,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials() {
    final first = controller.firstName.value;
    final last = controller.lastName.value;
    String initials = '';
    if (first.isNotEmpty) initials += first[0].toUpperCase();
    if (last.isNotEmpty) initials += last[0].toUpperCase();
    if (initials.isEmpty) {
      initials = controller.userName.value.isNotEmpty
          ? controller.userName.value[0].toUpperCase()
          : '?';
    }
    return initials;
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
    bool editable = true,
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
          child: Icon(icon, color: AppColors.titleColor, size: 22),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            value.isNotEmpty ? value : '—',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: editable && onEdit != null
            ? IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 20, color: AppColors.titleColor),
                onPressed: onEdit,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context, {
    required String title,
    required String currentValue,
    required Function(String) onSave,
  }) {
    final textController = TextEditingController(text: currentValue);

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Editar $title',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: title,
            labelStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.titleColor),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newValue = textController.text.trim();
              if (newValue.isNotEmpty) {
                onSave(newValue);
                Get.back();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

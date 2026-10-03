import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/permissions.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/configuracion_controller.dart';
import '../../../core/widgets/formulario.dart';

/// Account settings view — shows and allows editing of user profile data
class CuentaView extends GetView<ConfiguracionController> {
  const CuentaView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 800,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
          title: PlataformaApp.elegir(
              escritorio: 'Mi cuenta', movil: 'Mi Cuenta')),
      body: SafeArea(
        child: Obx(() => ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Avatar + name header
                _buildProfileHeader(context),
                const SizedBox(height: 24),

                // Personal info section
                _buildSectionLabel(context, 'Información Personal',
                    escritorio: 'Información personal'),
                const SizedBox(height: 12),
                _buildInfoTile(
                  context,
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
                  context,
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
                _buildSectionLabel(context, 'Cuenta'),
                const SizedBox(height: 12),
                // El staff entra con código, sin correo: no tiene sentido
                // mostrar una fila vacía.
                if (controller.userEmail.value.isNotEmpty) ...[
                  _buildInfoTile(
                    context,
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: controller.userEmail.value,
                    editable: false,
                  ),
                  const SizedBox(height: 8),
                ],
                if (controller.tieneContrasena) ...[
                  _buildInfoTile(
                    context,
                    icon: Icons.lock_outline,
                    label: 'Contraseña',
                    value: '••••••••',
                    onEdit: controller.abrirCambiarContrasena,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildInfoTile(
                  context,
                  icon: Icons.badge_outlined,
                  label: 'Rol',
                  value: controller.userRole.value,
                  editable: false,
                ),

                const SizedBox(height: 24),

                // Gym info section
                _buildSectionLabel(context, 'Gimnasio'),
                const SizedBox(height: 12),
                _buildInfoTile(
                  context,
                  icon: Icons.fitness_center,
                  label: 'Gimnasio',
                  value: controller.gymName.value.isNotEmpty
                      ? controller.gymName.value
                      : 'Cargando...',
                  // Espeja la política RLS de `gyms`: dueño y encargado.
                  editable:
                      TenantContextService.to.can(Permission.editarGimnasio),
                  onEdit: () => _showEditDialog(
                    context,
                    title: 'Gimnasio',
                    currentValue: controller.gymName.value,
                    onSave: (val) => controller.updateGymName(val),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoTile(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'Sucursal',
                  value: controller.branchName.value.isNotEmpty
                      ? controller.branchName.value
                      : 'Cargando...',
                  // Espeja la política RLS de `branches`: dueño y encargado.
                  editable:
                      TenantContextService.to.can(Permission.editarGimnasio),
                  onEdit: () => _showEditDialog(
                    context,
                    title: 'Sucursal',
                    currentValue: controller.branchName.value,
                    onSave: (val) => controller.updateBranchName(val),
                  ),
                ),

                // Borrar el gimnasio es lo único que ni el encargado puede:
                // queda solo para el dueño.
                if (TenantContextService.to
                    .can(Permission.eliminarGimnasio)) ...[
                  const SizedBox(height: 40),

                  // Danger zone
                  _buildSectionLabel(context, 'Zona de Peligro',
                      escritorio: 'Zona de peligro'),
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
                        Text(
                          'Borrar todos los datos',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Elimina permanentemente tu gimnasio, clientes, inventario, pagos y tu cuenta. Esta acción no se puede deshacer.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: legible(12),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          // En escritorio, del ancho de su texto: un botón
                          // rojo de lado a lado parece la acción principal.
                          width:
                              PlataformaApp.pantallaGrande ? null : double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: controller.isLoading.value
                                ? null
                                : () => controller.deleteGymAndAccount(),
                            icon: controller.isLoading.value
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.delete_forever, size: 20),
                            label: Text(controller.isLoading.value
                                ? 'Borrando...'
                                : 'Borrar datos'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[400],
                              side: BorderSide(color: Colors.red[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal:
                                      PlataformaApp.pantallaGrande ? 24 : 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            )),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final c = context.colores;
    if (PlataformaApp.pantallaGrande) return _cabeceraEscritorio(context);
    return Card(
      elevation: 4,
      color: c.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.titleColor.withOpacity(0.2),
                border: Border.all(
                  color: c.titleColor.withOpacity(0.5),
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: c.titleColor.withOpacity(0.1),
                child: Text(
                  _getInitials(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: c.titleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              controller.userName.value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              controller.userEmail.value,
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// En escritorio, avatar y datos en una fila: el bloque alto centrado del
  /// teléfono dejaba mucho hueco en la ventana.
  Widget _cabeceraEscritorio(BuildContext context) {
    final c = context.colores;
    return Card(
      elevation: 2,
      color: c.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: c.titleColor.withOpacity(0.15),
              child: Text(
                _getInitials(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: c.titleColor,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.userName.value.isNotEmpty
                        ? controller.userName.value
                        : '—',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  if (controller.userEmail.value.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      controller.userEmail.value,
                      style: TextStyle(fontSize: 15, color: c.textSecondary),
                    ),
                  ],
                ],
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

  Widget _buildSectionLabel(BuildContext context, String label,
      {String? escritorio}) {
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

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
    bool editable = true,
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
          child: Icon(icon, color: c.titleColor, size: 22),
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
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              fontSize: 16,
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: editable && onEdit != null && PlataformaApp.pantallaGrande
            // En escritorio, "Editar" con texto: un lápiz suelto no dice
            // qué hace.
            ? TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
                style: TextButton.styleFrom(
                  foregroundColor: c.titleColor,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              )
            : editable && onEdit != null
                ? IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 20, color: c.titleColor),
                    onPressed: onEdit,
                  )
                : null,
        // Toda la fila abre la edición, no solo el lápiz.
        onTap: editable ? onEdit : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context, {
    required String title,
    required String currentValue,
    required Future<void> Function(String) onSave,
  }) {
    Get.dialog(
      _EditFieldDialog(
        title: title,
        currentValue: currentValue,
        onSave: onSave,
      ),
    );
  }
}

/// Diálogo de edición de un solo campo de texto.
///
/// Es un StatefulWidget (y no un simple Get.dialog con controllers
/// externos) a propósito: así el TextEditingController se libera en
/// State.dispose(), que Flutter solo llama cuando el widget se
/// desmonta de verdad (tras la animación de cierre). Liberarlo antes
/// —p. ej. con `whenComplete` sobre el Future del diálogo— provoca
/// "A TextEditingController was used after being disposed" porque el
/// diálogo sigue montado un instante más mientras se anima su salida.
class _EditFieldDialog extends StatefulWidget {
  final String title;
  final String currentValue;
  final Future<void> Function(String) onSave;

  const _EditFieldDialog({
    required this.title,
    required this.currentValue,
    required this.onSave,
  });

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.currentValue);
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newValue = _textController.text.trim();
    if (newValue.isEmpty) {
      // En escritorio se dice por qué no se guarda; antes no pasaba nada.
      if (PlataformaApp.pantallaGrande) {
        setState(() => _error = 'Escribe ${widget.title.toLowerCase()}.');
      }
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSave(newValue);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return AlertDialog(
      scrollable: true,
      backgroundColor: c.cardBackground,
      title: Text(
        'Editar ${widget.title}',
        style: TextStyle(color: c.textPrimary),
      ),
      content: TextField(
        controller: _textController,
        autofocus: true,
        style: TextStyle(color: c.textPrimary),
        decoration: InputDecoration(labelText: widget.title, errorText: _error),
        // En escritorio, Enter guarda.
        onSubmitted: PlataformaApp.pantallaGrande ? (_) => _handleSave() : null,
      ),
      actions: [
        BotonCancelar(onPressed: _isSaving ? null : () => Get.back()),
        // Se espera a que termine la escritura antes de cerrar, para que
        // el error (si lo hay) aparezca con el diálogo todavía abierto.
        BotonGuardar(
          texto: 'Guardar',
          compacto: true,
          guardando: _isSaving,
          onPressed: _handleSave,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/models/staff_acceso_model.dart';
import '../controllers/staff_accesos_controller.dart';

/// Alta de un acceso nuevo o renombrado de uno existente.
///
/// Solo pide el nombre: el empleado no tiene correo ni contraseña, entra con
/// el código. Al crear devuelve el nombre y el código en claro; al renombrar
/// devuelve null.
Future<({String nombre, String codigo})?> showStaffAccesoFormDialog({
  StaffAccesoModel? existing,
}) {
  return Get.dialog<({String nombre, String codigo})>(
    _StaffAccesoFormDialog(existing: existing),
    barrierDismissible: false,
  );
}

class _StaffAccesoFormDialog extends StatefulWidget {
  final StaffAccesoModel? existing;

  const _StaffAccesoFormDialog({this.existing});

  @override
  State<_StaffAccesoFormDialog> createState() => _StaffAccesoFormDialogState();
}

class _StaffAccesoFormDialogState extends State<_StaffAccesoFormDialog> {
  late final TextEditingController _nombreCtrl;
  String? _error;

  StaffAccesosController get _controller => Get.find<StaffAccesosController>();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.existing?.nombre ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del empleado');
      return;
    }
    setState(() => _error = null);

    if (_isEditing) {
      final ok = await _controller.renombrar(widget.existing!, nombre);
      // El diálogo no se cierra si falló: el usuario no debe creer que guardó.
      if (ok) Get.back();
      return;
    }

    final codigo = await _controller.crear(nombre);
    if (codigo != null) Get.back(result: (nombre: nombre, codigo: codigo));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Cambiar nombre' : 'Nuevo acceso',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isEditing
                  ? 'Así verás a esta persona en la lista.'
                  : 'Se generará un código para que esta persona entre. '
                      'No necesita correo ni contraseña.',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              onSubmitted: (_) => _guardar(),
              decoration: InputDecoration(
                labelText: 'Nombre del empleado',
                hintText: 'Ej: María López',
                errorText: _error,
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintStyle:
                    TextStyle(color: AppColors.textHint.withOpacity(0.5)),
                filled: true,
                fillColor: AppColors.containerBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Obx(() {
              final saving = _controller.isSaving.value;
              return Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: saving ? null : () => Get.back(),
                      child: const Text('Cancelar',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isEditing ? 'Guardar' : 'Generar código',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

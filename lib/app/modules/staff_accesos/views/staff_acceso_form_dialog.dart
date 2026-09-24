import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/staff_role.dart';
import '../../../data/models/staff_acceso_model.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/staff_accesos_controller.dart';

/// Alta de un acceso nuevo o renombrado de uno existente.
///
/// Al crear pide el nombre y el rol, en pantalla completa: las opciones de
/// rol con su descripción no caben cómodas en un diálogo. Al renombrar solo
/// pide el nombre, en un diálogo (el rol se cambia desde la lista, sin tener
/// que regenerar el código). El empleado no tiene correo ni contraseña: entra
/// con el código.
///
/// Devuelve el nombre y el código en claro al crear, y null al renombrar.
Future<({String nombre, String codigo})?> showStaffAccesoFormDialog({
  StaffAccesoModel? existing,
}) {
  if (existing == null) {
    return Get.to<({String nombre, String codigo})>(
      () => const _StaffAccesoFormDialog(),
      fullscreenDialog: true,
    )!;
  }
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

  /// El rol que se entregará. Arranca en Staff, que es el trabajo más común y
  /// el que menos permisos concede: si alguien acepta el valor por defecto sin
  /// leerlo, se equivoca por el lado seguro.
  late StaffRole _rol;

  String? _error;

  StaffAccesosController get _controller => Get.find<StaffAccesosController>();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.existing?.nombre ?? '');

    final asignables = _controller.rolesAsignables;
    _rol = widget.existing?.rol ??
        (asignables.contains(StaffRole.branchStaff)
            ? StaffRole.branchStaff
            : asignables.first);
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

    final codigo = await _controller.crear(nombre, _rol);
    if (codigo != null) Get.back(result: (nombre: nombre, codigo: codigo));
  }

  /// Una opción del selector: el nombre del rol y, debajo, qué alcance tiene.
  /// La descripción va a la vista porque elegir mal aquí es lo que abre o
  /// cierra medio menú al empleado.
  Widget _buildOpcionRol(StaffRole rol) {
    final seleccionado = rol == _rol;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _rol = rol),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.containerBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado
                  ? AppColors.accent
                  : Colors.white.withOpacity(0.06),
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                seleccionado
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color:
                    seleccionado ? AppColors.accent : AppColors.textSecondary,
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
                        fontSize: 14,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      _isEditing ? _dialogoRenombrar() : _pantallaNuevo();

  /// Crear: pantalla completa con el botón fijo abajo.
  Widget _pantallaNuevo() {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const GymAppBar(title: 'Nuevo acceso'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _explicacion(
                'Se generará un código para que esta persona entre. '
                'No necesita correo ni contraseña.'),
            const SizedBox(height: 20),
            _campoNombre(),
            const SizedBox(height: 24),
            const Text(
              'Qué podrá hacer',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._controller.rolesAsignables.map(_buildOpcionRol),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _botonGuardar('Generar código'),
        ),
      ),
    );
  }

  /// Renombrar: un solo campo, en un diálogo.
  Widget _dialogoRenombrar() {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      // Ancho de diálogo aunque el teléfono esté de lado, y desplazable si
      // no cabe a lo alto.
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cambiar nombre',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _explicacion('Así verás a esta persona en la lista.'),
            const SizedBox(height: 20),
            _campoNombre(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Obx(() => TextButton(
                        onPressed: _controller.isSaving.value
                            ? null
                            : () => Get.back(),
                        child: const Text('Cancelar',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )),
                ),
                const SizedBox(width: 10),
                Expanded(child: _botonGuardar('Guardar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _explicacion(String texto) => Text(
        texto,
        style: TextStyle(
          color: AppColors.textSecondary.withOpacity(0.8),
          fontSize: 13,
          height: 1.35,
        ),
      );

  Widget _campoNombre() => TextField(
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
          hintStyle: TextStyle(color: AppColors.textHint.withOpacity(0.5)),
          filled: true,
          fillColor: AppColors.containerBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _botonGuardar(String texto) => Obx(() {
        final saving = _controller.isSaving.value;
        return ElevatedButton(
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
                  texto,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
        );
      });
}

import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/staff_role.dart';
import '../../../data/models/staff_acceso_model.dart';
import '../../../core/widgets/formulario.dart';
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
    return abrirFormulario<({String nombre, String codigo})>(
      () => const _StaffAccesoFormDialog(),
    );
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
    final c = context.colores;
    final seleccionado = rol == _rol;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _rol = rol),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado
                ? AppColors.accent.withOpacity(0.08)
                : c.contraste.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado
                  ? AppColors.accent
                  : c.contraste.withOpacity(0.10),
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
                color: seleccionado ? AppColors.accent : c.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rol.label,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rol.descripcion,
                      style: TextStyle(
                        color: c.textSecondary.withOpacity(0.8),
                        fontSize: legible(12),
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
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 760,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
        title: 'Nuevo acceso',
        // En la ventana de escritorio, una X para cerrar (no una flecha).
        leading: PlataformaApp.pantallaGrande
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: () => Get.back(),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _explicacion('Entrará con un código, sin correo ni contraseña.'),
            const SizedBox(height: 20),
            _campoNombre(),
            const SizedBox(height: 24),
            const TituloSeccion('Qué podrá hacer'),
            ..._controller.rolesAsignables.map(_buildOpcionRol),
          ],
        ),
      ),
      bottomNavigationBar: PieDeFormulario(
        alCancelar: () => Get.back(),
        child: _botonGuardar('Generar código'),
      ),
    );
  }

  /// Renombrar: un solo campo, en un diálogo.
  Widget _dialogoRenombrar() {
    final c = context.colores;
    return Dialog(
      backgroundColor: c.cardBackground,
      // Ancho de diálogo aunque el teléfono esté de lado, y desplazable si
      // no cabe a lo alto.
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cambiar nombre',
              style: TextStyle(
                color: c.textPrimary,
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Obx(() => BotonCancelar(
                      onPressed:
                          _controller.isSaving.value ? null : () => Get.back(),
                    )),
                const SizedBox(width: 8),
                _botonGuardar('Guardar', compacto: true),
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
          color: context.colores.textSecondary.withOpacity(0.8),
          fontSize: 13,
          height: 1.35,
        ),
      );

  Widget _campoNombre() => TextField(
        controller: _nombreCtrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: context.colores.textPrimary),
        onSubmitted: (_) => _guardar(),
        decoration: InputDecoration(
          labelText: 'Nombre del empleado',
          hintText: 'Ej: María López',
          errorText: _error,
          prefixIcon: const Icon(Icons.person_outline),
        ),
      );

  Widget _botonGuardar(String texto, {bool compacto = false}) =>
      Obx(() => BotonGuardar(
            texto: texto,
            compacto: compacto,
            guardando: _controller.isSaving.value,
            onPressed: _guardar,
          ));
}

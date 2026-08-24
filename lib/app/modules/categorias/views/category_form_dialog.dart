import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../data/models/product_model.dart';
import '../controllers/categorias_controller.dart';
import 'widgets/category_icon_picker.dart';

/// Diálogo de alta y edición de categoría, compartido por la pantalla de
/// Categorías y por el atajo `+` del formulario de producto.
///
/// Devuelve la categoría creada o editada, o null si se canceló. Devolverla
/// es lo que permite al formulario de producto autoseleccionarla, que era el
/// principal fastidio del flujo anterior.
Future<ProductCategory?> showCategoryFormDialog({
  ProductCategory? existing,
}) {
  // El controlador puede no existir si se abre desde el formulario de
  // producto, que vive en otro módulo.
  if (!Get.isRegistered<CategoriasController>()) {
    Get.put(CategoriasController());
  }

  return Get.dialog<ProductCategory>(
    _CategoryFormDialog(existing: existing),
    barrierDismissible: false,
  );
}

class _CategoryFormDialog extends StatefulWidget {
  final ProductCategory? existing;

  const _CategoryFormDialog({this.existing});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late String _iconKey;
  String? _nameError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _iconKey = widget.existing?.icon ?? CategoryIcons.fallbackKey;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'El nombre es obligatorio');
      return;
    }
    setState(() => _nameError = null);

    final controller = Get.find<CategoriasController>();
    final description = _descCtrl.text.trim();

    if (_isEditing) {
      final ok = await controller.edit(
        widget.existing!,
        name: name,
        description: description,
        icon: _iconKey,
      );
      if (!ok) return; // el diálogo sigue abierto para corregir
      final saved =
          controller.categories.firstWhere((c) => c.id == widget.existing!.id);
      Get.back(result: saved);
    } else {
      final created = await controller.create(
        name: name,
        description: description,
        icon: _iconKey,
      );
      if (created == null) return;
      Get.back(result: created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CategoriasController>();

    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        _isEditing ? 'Editar categoría' : 'Nueva categoría',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej: Suplementos',
                errorText: _nameError,
                filled: true,
                fillColor: AppColors.containerBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                filled: true,
                fillColor: AppColors.containerBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Icono',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            CategoryIconPicker(
              selectedKey: _iconKey,
              onSelected: (key) => setState(() => _iconKey = key),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Obx(() => ElevatedButton(
              onPressed: controller.isSaving.value ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.accent.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: controller.isSaving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Guardar' : 'Crear',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            )),
      ],
    );
  }
}

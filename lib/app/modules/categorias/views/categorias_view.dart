import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../data/models/product_model.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/categorias_controller.dart';
import 'category_form_dialog.dart';
import '../../../core/widgets/centrado_desplazable.dart';
import '../../../core/widgets/formulario.dart';

/// Pantalla de gestión de categorías de producto.
class CategoriasView extends GetView<CategoriasController> {
  const CategoriasView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 960,
      backgroundColor: c.backgroundColor,
      appBar: const GymAppBar(title: 'Categorías'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => showCategoryFormDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva',
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
          if (controller.categories.isEmpty) return _buildEmpty(context);
          return _buildList(context);
        }),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final c = context.colores;
    return CentradoDesplazable(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: 64, color: c.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes categorías',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sirven para organizar el inventario y el punto de venta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => showCategoryFormDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Crear la primera',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final c = context.colores;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              Icon(Icons.drag_indicator,
                  size: 16, color: c.textSecondary.withOpacity(0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mantén pulsada una categoría para cambiar su orden.',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            itemCount: controller.categories.length,
            onReorder: controller.reorder,
            itemBuilder: (context, index) {
              final category = controller.categories[index];
              return _buildTile(context, category, key: ValueKey(category.id));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTile(BuildContext context, ProductCategory category,
      {required Key key}) {
    final c = context.colores;
    final count = controller.countFor(category.id);
    final isInactive = !category.isActive;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.contraste.withOpacity(0.06)),
      ),
      child: Opacity(
        opacity: isInactive ? 0.55 : 1,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(CategoryIcons.resolve(category.icon),
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          category.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isInactive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Inactiva',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1 ? '1 producto' : '$count productos',
                    style: TextStyle(
                      color: c.textSecondary.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: c.cardBackground,
              icon: Icon(Icons.more_vert,
                  color: c.textSecondary.withOpacity(0.8)),
              onSelected: (value) => _onMenuAction(context, value, category),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isInactive ? 'Reactivar' : 'Desactivar'),
                ),
                if (controller.puedeGestionar)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar',
                        style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMenuAction(
      BuildContext context, String action, ProductCategory category) {
    switch (action) {
      case 'edit':
        showCategoryFormDialog(existing: category);
        break;
      case 'toggle':
        controller.toggleActive(category);
        break;
      case 'delete':
        _confirmDelete(context, category);
        break;
    }
  }

  /// Con productos asignados ni siquiera se ofrece borrar: se explica por qué
  /// y se propone desactivar, que es lo que casi siempre se quiere.
  void _confirmDelete(BuildContext context, ProductCategory category) {
    final c = context.colores;
    final count = controller.countFor(category.id);
    final hasProducts = count > 0;

    Get.dialog(
      AlertDialog(
        scrollable: true,
        backgroundColor: c.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          hasProducts ? 'No se puede eliminar' : '¿Eliminar categoría?',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          hasProducts
              ? '"${category.name}" tiene ${count == 1 ? '1 producto' : '$count productos'}. '
                  'Para eliminarla, primero muévelos o elimínalos.\n\n'
                  'También puedes desactivarla: dejará de aparecer al crear '
                  'productos, pero los que ya la usan la conservan.'
              : '¿Eliminar "${category.name}"? Esta acción no se puede deshacer.',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [
          BotonCancelar(onPressed: () => Get.back()),
          if (hasProducts)
            BotonGuardar(
              texto: 'Desactivar',
              compacto: true,
              onPressed: () {
                Get.back();
                controller.toggleActive(category);
              },
            )
          else
            BotonGuardar(
              texto: 'Eliminar',
              compacto: true,
              color: AppColors.error,
              onPressed: () {
                Get.back();
                controller.delete(category);
              },
            ),
        ],
      ),
    );
  }
}

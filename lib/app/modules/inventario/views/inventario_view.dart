import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/routes/app_pages.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/app/core/utils/category_icons.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import '../controllers/inventario_controller.dart';
import 'stock_adjust_dialog.dart';

class InventarioView extends GetView<InventarioController> {
  const InventarioView({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GymAppBar(
        title: 'Inventario',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshAll(),
          ),
          TourStep(
            tourKey: controller.keyCategorias,
            title: 'Categorías',
            description: 'Crea y ordena las categorías con las que agrupas '
                'tus productos aquí y en el punto de venta.',
            borderRadius: 24,
            child: IconButton(
              icon: const Icon(Icons.category_outlined),
              tooltip: 'Categorías',
              onPressed: () async {
                await Get.toNamed(Routes.CATEGORIAS);
                // Al volver pueden haber cambiado nombres, iconos u orden.
                controller.loadCategories();
              },
            ),
          ),
          TourStep(
            tourKey: controller.keyAgregar,
            title: 'Agregar producto',
            description: 'Registra un producto nuevo con su precio, su stock '
                'y la categoría a la que pertenece.',
            borderRadius: 24,
            isFirstStep: true,
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                controller.resetForm();
                Get.toNamed(Routes.PRODUCT_FORM);
              },
              tooltip: 'Agregar producto',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatsSection(),
            _buildFaltantesBanner(),
            TourStep(
              tourKey: controller.keyBuscar,
              title: 'Buscador',
              description: 'Localiza cualquier producto escribiendo su nombre.',
              child: _buildSearchBar(),
            ),
            _buildCategoryFilter(),
            Expanded(
              child: TourStep(
                tourKey: controller.keyLista,
                title: 'Tus productos',
                description: 'Toca un producto para ver su detalle, editarlo '
                    'o registrar entradas y salidas de stock.',
                isLastStep: true,
                child: _buildProductList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsSection() {
    return Obx(() {
      if (controller.inventoryStats.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total Productos', '${controller.inventoryStats['totalProducts'] ?? 0}'),
            _buildStatItem('Stock Total', '${controller.inventoryStats['totalStock'] ?? 0}'),
            _buildStatItem('Valor Total', '\$${(controller.inventoryStats['totalValue'] ?? 0.0).toStringAsFixed(2)}'),
          ],
        ),
      );
    });
  }
  
  /// Resumen de lo vendido sin existencias. Solo aparece si hay faltantes,
  /// para no robar espacio cuando el inventario está sano.
  Widget _buildFaltantesBanner() {
    return Obx(() {
      if (!controller.hayFaltantes) return const SizedBox.shrink();

      final productos = controller.productosConFaltante.length;
      final unidades = controller.unidadesFaltantes;
      final valor = controller.valorFaltante;

      final filtrando = controller.soloFaltantes.value;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Deja en la lista solo lo que hay que reponer.
          onTap: controller.toggleSoloFaltantes,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(filtrando ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.error.withOpacity(filtrando ? 0.7 : 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vendidos sin existencias',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$productos ${productos == 1 ? 'producto' : 'productos'} · '
                        '$unidades ${unidades == 1 ? 'unidad' : 'unidades'} · '
                        '\$${valor.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        filtrando
                            ? 'Toca para ver todos los productos'
                            : 'Se descontarán solas al reponer stock',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  filtrando ? Icons.filter_alt : Icons.chevron_right,
                  color: AppColors.error,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppSearchField(
        hintText: 'Buscar productos...',
        onChanged: controller.setSearchQuery,
      ),
    );
  }
  
  Widget _buildCategoryFilter() {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.all(16),
        child: CategoryFilterChips(
          categories: controller.activeCategories
              .map((c) => CategoryChipData(
                    id: c.id,
                    label: c.name,
                    icon: CategoryIcons.resolve(c.icon),
                  ))
              .toList(),
          selectedId: controller.selectedCategoryId.value,
          onSelected: controller.setSelectedCategory,
        ),
      );
    });
  }
  
  Widget _buildProductList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
          ),
        );
      }
      
      // Inventario realmente vacío.
      if (controller.products.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'No hay productos registrados',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  controller.resetForm();
                  Get.toNamed(Routes.PRODUCT_FORM);
                },
                icon: const Icon(Icons.add),
                label: const Text('Agregar primer producto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }

      // Hay productos, pero ninguno pasa el filtro. Antes esto no se
      // comprobaba y quedaba un hueco en blanco sin ningún mensaje.
      if (controller.filteredProducts.isEmpty) {
        final hayFiltroDeCategoria = controller.selectedCategoryId.value != null;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off,
                    size: 56, color: AppColors.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  hayFiltroDeCategoria
                      ? 'No hay productos en esta categoría'
                      : 'Ningún producto coincide con la búsqueda',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                if (hayFiltroDeCategoria) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => controller.setSelectedCategory(null),
                    icon: const Icon(Icons.clear, color: AppColors.accent),
                    label: const Text('Ver todas',
                        style: TextStyle(color: AppColors.accent)),
                  ),
                ],
              ],
            ),
          ),
        );
      }


      return ListView.builder(
        itemCount: controller.filteredProducts.length,
        itemBuilder: (context, index) {
          final product = controller.filteredProducts[index];
          return _buildProductCard(product);
        },
      );
    });
  }
  
  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.cardBackground,
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withOpacity(0.2),
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : 'P',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // El precio va en la línea del nombre, no junto al stock: abajo
        // comparte fila con los botones de ajuste y no cabían los tres.
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.description,
              style: const TextStyle(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: product.stock > 0 ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    // En negativo el número suelto no dice nada: son unidades
                    // que ya se vendieron y hay que reponer.
                    product.stock < 0
                        ? 'Faltan ${-product.stock}'
                        : 'Stock: ${product.stock}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Ajuste de una unidad, pegado al stock que modifica.
                _buildStockStepper(product),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          color: AppColors.cardBackground,
          onSelected: (value) {
            if (value == 'edit') {
              controller.editProduct(product);
              Get.toNamed(Routes.PRODUCT_FORM, arguments: {'isEditing': true});
            } else if (value == 'stock') {
              showStockAdjustDialog(product);
            } else if (value == 'deactivate') {
              controller.deactivateProduct(product.id);
            } else if (value == 'delete') {
              controller.deleteProduct(product.id);
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Text('Editar', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'stock',
              child: Row(
                children: [
                  Icon(Icons.sync_alt, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Text('Ajustar stock', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
            // Desactivar exige no tener existencias; ofrecerlo con stock solo
            // llevaba al aviso de que no se puede.
            if (product.stock <= 0)
              PopupMenuItem<String>(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(Icons.visibility_off, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Text('Desactivar', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            // Siempre mostrar "Eliminar permanentemente"
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: AppColors.error, size: 20),
                  const SizedBox(width: 12),
                  Text('Eliminar permanentemente', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showProductDetail(product),
      ),
    );
  }

  /// Botones de una unidad para corregir el stock sin abrir nada.
  Widget _buildStockStepper(Product product) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(
          Icons.remove,
          AppColors.warning,
          'Quitar una unidad',
          () => controller.ajustarStock(product, -1, nota: 'Ajuste rápido'),
        ),
        _stepperButton(
          Icons.add,
          AppColors.success,
          'Agregar una unidad',
          () => controller.ajustarStock(product, 1, nota: 'Ajuste rápido'),
        ),
      ],
    );
  }

  Widget _stepperButton(
      IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }


  void _showProductDetail(Product product) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(product.name, style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Descripción', product.description),
            _buildDetailRow('Categoría', controller.categoryNameFor(product)),
            _buildDetailRow('Precio de venta', '\$${product.price.toStringAsFixed(2)}'),
            _buildDetailRow(
              'Stock actual',
              product.stock < 0
                  ? 'Faltan ${-product.stock} unidades'
                  : '${product.stock} unidades',
              valueColor: product.stock < 0 ? AppColors.error : null,
            ),
            _buildDetailRow('Estado', product.isActive ? 'Activo' : 'Inactivo'),
            _buildDetailRow('Creado', '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cerrar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.editProduct(product);
              Get.toNamed(Routes.PRODUCT_FORM, arguments: {'isEditing': true});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight:
                    valueColor == null ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

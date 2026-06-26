import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/inventario_controller.dart';

class ProductFormView extends GetView<InventarioController> {
  const ProductFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments as Map<String, dynamic>? ?? {};
    final bool isEditing = arguments['isEditing'] ?? false;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();

    // Use an Rx variable so the dropdown stays reactive
    final selectedCategory = RxnString(null);

    // Si estamos editando, llenar los campos con los datos del producto actual
    if (isEditing && controller.currentProduct.value != null) {
      final product = controller.currentProduct.value!;
      nameController.text = product.name;
      descriptionController.text = product.description;
      priceController.text = product.price.toString();
      stockController.text = product.stock.toString();
      selectedCategory.value = product.category;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () {
            controller.resetForm();
            Get.back();
          },
        ),
        actions: [
          Obx(() {
            return TextButton(
              onPressed: controller.isLoading.value
                  ? null
                  : () {
                      if (formKey.currentState!.validate()) {
                        controller.saveProduct({
                          'name': nameController.text,
                          'description': descriptionController.text,
                          'category': selectedCategory.value ?? '',
                          'price': priceController.text,
                          'stock': stockController.text,
                        });
                      }
                    },
              child: controller.isLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isEditing ? 'Actualizar' : 'Guardar',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sección de información básica
                _buildSectionCard(
                  title: 'Información Básica',
                  icon: Icons.info_outline,
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del producto *',
                        hintText: 'Ej: Proteína Whey 1kg',
                        prefixIcon:
                            Icon(Icons.shopping_bag, color: AppColors.accent),
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(
                            r'[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ\s.,\-()]')),
                        LengthLimitingTextInputFormatter(100),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa el nombre del producto';
                        }
                        if (value.trim().length < 2) {
                          return 'El nombre debe tener al menos 2 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Describe las características del producto...',
                        prefixIcon:
                            Icon(Icons.description, color: AppColors.accent),
                        helperText: 'Opcional - Máximo 500 caracteres',
                        helperStyle: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(500),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown — reactive with Obx
                    Obx(() {
                      final cats = controller.categories;
                      final currentVal = selectedCategory.value;

                      // Ensure value is valid in list
                      final validValue = cats.any((c) => c.name == currentVal)
                          ? currentVal
                          : null;

                      return DropdownButtonFormField<String>(
                        value: validValue,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Categoría *',
                          prefixIcon:
                              const Icon(Icons.category, color: AppColors.accent),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: AppColors.accent, size: 22),
                            tooltip: 'Crear categoría',
                            onPressed: () => _showCreateCategoryDialog(),
                          ),
                        ),
                        dropdownColor: AppColors.cardBackground,
                        items: cats.map((category) {
                          return DropdownMenuItem<String>(
                            value: category.name,
                            child: Text(
                              category.name,
                              style:
                                  const TextStyle(color: AppColors.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedCategory.value = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor selecciona una categoría';
                          }
                          return null;
                        },
                        hint: Text(
                          cats.isEmpty
                              ? 'Crea una categoría primero'
                              : 'Selecciona una categoría',
                          style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.6)),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 24),

                // Sección de precio
                _buildSectionCard(
                  title: 'Precio',
                  icon: Icons.attach_money,
                  children: [
                    TextFormField(
                      controller: priceController,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Precio de venta *',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.monetization_on,
                            color: AppColors.accent),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(
                            color: AppColors.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                        helperText: 'Precio unitario en MXN',
                        helperStyle: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa el precio';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Debe ser mayor a 0';
                        }
                        if (price > 9999999.99) {
                          return 'Precio muy alto';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sección de stock
                _buildSectionCard(
                  title: 'Stock Inicial',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    TextFormField(
                      controller: stockController,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Cantidad disponible *',
                        hintText: '0',
                        prefixIcon: const Icon(Icons.inventory,
                            color: AppColors.accent),
                        suffixText: 'unidades',
                        suffixStyle: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                        helperText: 'Unidades en existencia',
                        helperStyle: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa la cantidad';
                        }
                        final stock = int.tryParse(value);
                        if (stock == null || stock < 0) {
                          return 'Debe ser 0 o mayor';
                        }
                        if (stock > 999999) {
                          return 'Stock muy alto';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Nueva Categoría',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej: Suplementos',
                prefixIcon: Icon(Icons.label, color: AppColors.accent),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes, color: AppColors.accent),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                controller.saveCategory(
                    nameCtrl.text.trim(), descCtrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

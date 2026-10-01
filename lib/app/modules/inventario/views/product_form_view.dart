import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/app/core/utils/category_icons.dart';
import '../controllers/inventario_controller.dart';
import 'stock_adjust_dialog.dart';

class ProductFormView extends GetView<InventarioController> {
  const ProductFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final arguments = Get.arguments as Map<String, dynamic>? ?? {};
    final bool isEditing = arguments['isEditing'] ?? false;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final barcodeController = TextEditingController();

    // Id de la categoría, no el nombre: así renombrarla no desenlaza nada.
    final selectedCategoryId = RxnString(null);

    // Si estamos editando, llenar los campos con los datos del producto actual
    if (isEditing && controller.currentProduct.value != null) {
      final product = controller.currentProduct.value!;
      nameController.text = product.name;
      descriptionController.text = product.description;
      priceController.text = product.price.toString();
      stockController.text = product.stock.toString();
      barcodeController.text = product.barcode ?? '';
      selectedCategoryId.value = product.categoryId;
    } else if (arguments['barcode'] is String) {
      // Llega desde "Código no registrado" al escanear en el inventario.
      barcodeController.text = arguments['barcode'] as String;
    }

    return ScaffoldAdaptable(
      anchoMaximo: 760,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
        title: isEditing ? 'Editar producto' : 'Nuevo producto',
        leading: Obx(() => IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
              onPressed: controller.guardandoProducto.value
                  ? null
                  : () {
                      controller.resetForm();
                      Get.back();
                    },
            )),
      ),
      // Como en los demás formularios: el botón para guardar, fijo abajo.
      bottomNavigationBar: PieDeFormulario(
        child: Obx(() => BotonGuardar(
              texto: isEditing ? 'Guardar cambios' : 'Guardar producto',
              guardando: controller.guardandoProducto.value,
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  controller.saveProduct({
                    'name': nameController.text,
                    'description': descriptionController.text,
                    'category_id': selectedCategoryId.value,
                    'price': priceController.text,
                    'barcode': barcodeController.text,
                    // Al editar el stock no se toca aquí.
                    if (!isEditing) 'stock': stockController.text,
                  });
                }
              },
            )),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sección de información básica
                _seccion(
                  title: 'Datos del producto',
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: c.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del producto *',
                        hintText: 'Ej: Proteína Whey 1kg',
                        prefixIcon: Icon(Icons.shopping_bag),
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9áéíóúÁÉÍÓÚñÑüÜ\s.,\-()]')),
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
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        hintText:
                            'Describe las características del producto...',
                        prefixIcon: const Icon(Icons.description),
                        helperText: 'Opcional - Máximo 500 caracteres',
                        helperStyle:
                            TextStyle(fontSize: 11, color: c.textSecondary),
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
                      // Solo las activas se pueden asignar a un producto.
                      final cats = controller.activeCategories;
                      final currentVal = selectedCategoryId.value;

                      // Red de seguridad por si la categoría se borró estando
                      // el formulario abierto (con ids esto ya es raro).
                      final validValue = cats.any((c) => c.id == currentVal)
                          ? currentVal
                          : null;

                      return DropdownButtonFormField<String>(
                        value: validValue,
                        style: TextStyle(color: c.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                          prefixIcon: Icon(Icons.category),
                        ),
                        dropdownColor: c.cardBackground,
                        items: cats.map((category) {
                          return DropdownMenuItem<String>(
                            value: category.id,
                            child: Row(
                              children: [
                                Icon(CategoryIcons.resolve(category.icon),
                                    size: 18, color: AppColors.accent),
                                const SizedBox(width: 10),
                                Text(
                                  category.name,
                                  style: TextStyle(color: c.textPrimary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedCategoryId.value = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor selecciona una categoría';
                          }
                          return null;
                        },
                        hint: Text(
                          cats.isEmpty
                              ? 'Crea categorías desde Configuración'
                              : 'Selecciona una categoría',
                          style: TextStyle(
                              color: c.textSecondary.withOpacity(0.6)),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 24),

                // Sección de precio
                _seccion(
                  title: 'Precio',
                  children: [
                    TextFormField(
                      controller: priceController,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Precio de venta *',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.monetization_on),
                        prefixText: '\$ ',
                        prefixStyle: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                        helperText: 'Precio unitario en MXN',
                        helperStyle:
                            TextStyle(fontSize: 11, color: c.textSecondary),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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

                // Código de barras: el del fabricante, para poder escanear el
                // producto y ajustar su stock sin buscarlo en la lista.
                _seccion(
                  title: 'Código de barras',
                  children: [
                    TextFormField(
                      controller: barcodeController,
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Código (opcional)',
                        hintText: 'Escanéalo del envase o escríbelo',
                        prefixIcon: const Icon(Icons.qr_code),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Escanear',
                          onPressed: () async {
                            final codigo = await controller.escanearCodigo(
                              titulo: 'Código del producto',
                              instruccion:
                                  'Apunta al código de barras del envase',
                            );
                            if (codigo != null) barcodeController.text = codigo;
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sección de stock.
                //
                // Al editar es de solo lectura: este campo se cargaba al abrir
                // la pantalla y se reenviaba tal cual, así que cambiar el
                // precio devolvía el stock a como estaba y borraba las ventas
                // hechas mientras tanto. El stock solo se mueve por diferencia,
                // desde "Ajustar stock".
                if (isEditing)
                  _buildStockSoloLectura(context)
                else
                  _seccion(
                    title: 'Stock inicial',
                    children: [
                      TextFormField(
                        controller: stockController,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Cantidad disponible *',
                          hintText: '0',
                          prefixIcon: const Icon(Icons.inventory),
                          suffixText: 'unidades',
                          suffixStyle:
                              TextStyle(color: c.textSecondary, fontSize: 14),
                          helperText: 'Unidades en existencia',
                          helperStyle:
                              TextStyle(fontSize: 11, color: c.textSecondary),
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

  /// Stock del producto en edición: se muestra, no se escribe. Para moverlo
  /// está "Ajustar", que trabaja por diferencia.
  Widget _buildStockSoloLectura(BuildContext context) {
    final c = context.colores;
    return Obx(() {
      final product = controller.currentProduct.value;
      if (product == null) return const SizedBox.shrink();

      final faltante = product.stock < 0;

      return _seccion(
        title: 'Stock',
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faltante
                          ? 'Faltan ${-product.stock}'
                          : '${product.stock}',
                      style: TextStyle(
                        color: faltante ? AppColors.error : c.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      faltante
                          ? 'unidades vendidas sin existencias'
                          : 'unidades en existencia',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showStockAdjustDialog(product),
                icon: const Icon(Icons.sync_alt, size: 18),
                label: const Text('Ajustar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  /// Un grupo de campos, con su título: igual que en los demás formularios.
  Widget _seccion({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(title),
        ...children,
      ],
    );
  }
}

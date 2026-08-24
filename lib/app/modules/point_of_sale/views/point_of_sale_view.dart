import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/point_of_sale_controller.dart';
import '../../../data/models/product_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/category_icons.dart';
import '../../../global_widgets/app_header.dart';

class PointOfSaleView extends GetView<PointOfSaleController> {
  const PointOfSaleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const GymAppBar(title: 'Punto de Venta'),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: AppSearchField(
                hintText: 'Buscar productos...',
                onChanged: controller.searchProducts,
              ),
            ),

            // Filtro de categorías
            Padding(
              padding: const EdgeInsets.all(12),
              child: Obx(() => CategoryFilterChips(
                    categories: controller.activeCategories
                        .map((c) => CategoryChipData(
                              id: c.id,
                              label: c.name,
                              icon: CategoryIcons.resolve(c.icon),
                            ))
                        .toList(),
                    selectedId: controller.selectedCategoryId,
                    onSelected: controller.setSelectedCategory,
                  )),
            ),

            // Grid de productos
            Expanded(
              child: Obx(() {
                if (controller.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final products = controller.filteredProducts;

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No hay productos disponibles',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final isTablet = MediaQuery.of(context).size.width > 600;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(products[index]);
                  },
                );
              }),
            ),

            // Panel inferior fijo del carrito
            _buildCartPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Obx(() {
      final cartItem = controller.cartItems.firstWhereOrNull(
        (item) => item.productId == product.id,
      );
      final quantity = cartItem?.quantity ?? 0;
      final inCart = quantity > 0;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart ? AppColors.accent : AppColors.accent.withOpacity(0.12),
            width: inCart ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono de categoría + badge de stock
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.containerBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CategoryIcons.resolve(
                        controller.categoryById[product.categoryId]?.icon),
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                _buildStockBadge(product.stock),
              ],
            ),
            const SizedBox(height: 10),

            // Nombre
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),

            // Precio
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 10),

            // Control de cantidad
            _buildQuantityControl(product, quantity),
          ],
        ),
      );
    });
  }

  Widget _buildStockBadge(int stock) {
    final bool lowStock = stock <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lowStock ? AppColors.warning : AppColors.success,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$stock',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildQuantityControl(Product product, int quantity) {
    if (quantity == 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => controller.addProductToCart(product),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.containerBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => controller.updateCartItemQuantity(
              product.id,
              quantity - 1,
            ),
            icon: const Icon(Icons.remove, size: 18),
            color: AppColors.textSecondary,
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => controller.addProductToCart(product),
            icon: const Icon(Icons.add, size: 18),
            color: AppColors.accent,
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel(BuildContext context) {
    return Obx(() {
      final itemCount = controller.cartItems.length;
      final total = controller.finalAmount;
      final isEmpty = itemCount == 0;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isEmpty ? 14 : 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: isEmpty
              ? Center(
                  child: Text(
                    'Selecciona productos para cobrar',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_bag_outlined,
                          color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),

                    // Info del carrito
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$itemCount ${itemCount == 1 ? 'producto' : 'productos'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botón limpiar
                    IconButton(
                      onPressed: () => controller.clearCart(),
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.textSecondary,
                      tooltip: 'Vaciar carrito',
                    ),
                    const SizedBox(width: 4),

                    // Botón cobrar
                    ElevatedButton(
                      onPressed: () => _showPaymentDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Cobrar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  void _showPaymentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Título
              const Text(
                'Confirmar Pago',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Resumen rápido
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.containerBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Obx(() => Column(
                      children: [
                        _buildSummaryRow(
                            '${controller.cartItems.length} productos',
                            '\$${controller.totalAmount.toStringAsFixed(2)}'),
                        if (controller.discountAmount > 0) ...[
                          const SizedBox(height: 8),
                          _buildSummaryRow('Descuento',
                              '-\$${controller.discountAmount.toStringAsFixed(2)}'),
                        ],
                        const Divider(height: 24),
                        _buildSummaryRow(
                          'TOTAL',
                          '\$${controller.finalAmount.toStringAsFixed(2)}',
                          isBold: true,
                        ),
                      ],
                    )),
              ),
              const SizedBox(height: 20),

              // Método de pago
              const Text(
                'Método de pago',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              _buildPaymentMethodChips(),
              const SizedBox(height: 16),

              // Campo monto recibido (solo efectivo)
              Obx(() {
                if (controller.selectedPaymentMethod == 'efectivo') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monto recibido',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(color: AppColors.accent),
                          filled: true,
                          fillColor: AppColors.containerBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          final amount = double.tryParse(value) ?? 0.0;
                          controller.setReceivedAmount(amount);
                        },
                      ),
                      if (controller.changeAmount > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Cambio: \$${controller.changeAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              // Campo folio / referencia (tarjeta y transferencia)
              Obx(() {
                if (!controller.usaReferenciaPago) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Folio o referencia (opcional)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      // Fuerza un campo nuevo al cambiar de método de pago,
                      // para que no arrastre el texto de la operación anterior.
                      key: ValueKey(
                          'referencia_${controller.selectedPaymentMethod}'),
                      style: const TextStyle(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Ej: 004521',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        prefixIcon: const Icon(
                          Icons.receipt_long,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppColors.containerBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onChanged: controller.setReferenciaPago,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),

              // Botón procesar
              Obx(() => ElevatedButton(
                    onPressed: controller.canProcessSale() &&
                            !controller.isProcessingPayment
                        ? () => _processSale(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: controller.isProcessingPayment
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Procesar Venta',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  )),
              const SizedBox(height: 12),

              // Botón cancelar
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChips() {
    return Obx(() => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.paymentMethods.map((method) {
            final selected = controller.selectedPaymentMethod == method;
            return GestureDetector(
              onTap: () => controller.setPaymentMethod(method),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.accent
                        : AppColors.accent.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForPaymentMethod(method),
                      size: 16,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getPaymentMethodName(method),
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ));
  }

  IconData _iconForPaymentMethod(String method) {
    switch (method) {
      case 'efectivo':
        return Icons.payments_outlined;
      case 'tarjeta_debito':
      case 'tarjeta_credito':
        return Icons.credit_card;
      case 'transferencia':
        return Icons.account_balance_outlined;
      case 'mixto':
        return Icons.call_split;
      default:
        return Icons.payment;
    }
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.accent : AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta_debito':
        return 'Tarjeta de Débito';
      case 'tarjeta_credito':
        return 'Tarjeta de Crédito';
      case 'transferencia':
        return 'Transferencia';
      case 'mixto':
        return 'Mixto';
      default:
        return method;
    }
  }

  void _processSale(BuildContext context) async {
    final navigator = Navigator.of(context);
    final success = await controller.processSale();
    if (success) {
      navigator.pop(); // Cerrar modal
      SnackbarHelper.success('Éxito', 'Venta procesada correctamente');
    }
  }
}

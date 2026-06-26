import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../ingresos/controllers/ingresos_controller.dart';

class PointOfSaleController extends GetxController {
  final ProductRepository _productRepository = ProductRepository();
  final SaleRepository _saleRepository = SaleRepository();

  // Estado del carrito
  final RxList<SaleItem> _cartItems = <SaleItem>[].obs;
  final RxDouble _totalAmount = 0.0.obs;
  final RxDouble _taxAmount = 0.0.obs;
  final RxDouble _discountAmount = 0.0.obs;
  final RxDouble _finalAmount = 0.0.obs;

  // Estado de la UI
  final RxBool _isLoading = false.obs;
  final RxBool _isProcessingPayment = false.obs;
  final RxString _selectedPaymentMethod = 'efectivo'.obs;
  final RxDouble _receivedAmount = 0.0.obs;
  final RxDouble _changeAmount = 0.0.obs;

  // Lista de productos disponibles
  final RxList<Product> _availableProducts = <Product>[].obs;
  final RxString _searchQuery = ''.obs;

  // Configuración de impuestos
  final RxDouble _taxRate = 0.0.obs; // 0% por defecto, configurable

  // Getters
  List<SaleItem> get cartItems => _cartItems;
  double get totalAmount => _totalAmount.value;
  double get taxAmount => _taxAmount.value;
  double get discountAmount => _discountAmount.value;
  double get finalAmount => _finalAmount.value;

  bool get isLoading => _isLoading.value;
  bool get isProcessingPayment => _isProcessingPayment.value;
  String get selectedPaymentMethod => _selectedPaymentMethod.value;
  double get receivedAmount => _receivedAmount.value;
  double get changeAmount => _changeAmount.value;

  List<Product> get availableProducts => _availableProducts;
  List<Product> get filteredProducts {
    if (_searchQuery.value.isEmpty) {
      return _availableProducts;
    }
    return _availableProducts
        .where((product) =>
            product.name
                .toLowerCase()
                .contains(_searchQuery.value.toLowerCase()) ||
            product.category
                .toLowerCase()
                .contains(_searchQuery.value.toLowerCase()))
        .toList();
  }

  String get searchQuery => _searchQuery.value;
  double get taxRate => _taxRate.value;

  // Métodos de pago disponibles
  final List<String> paymentMethods = [
    'efectivo',
    'tarjeta_debito',
    'tarjeta_credito',
    'transferencia',
    'mixto'
  ];

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  /// Cargar productos disponibles
  Future<void> loadProducts() async {
    try {
      _isLoading.value = true;
      final products = await _productRepository.getAllProducts();
      _availableProducts.assignAll(products.where((p) => p.stock > 0));
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar productos: $e');
      }
      SnackbarHelper.error('Error', 'No se pudieron cargar los productos');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Buscar productos
  void searchProducts(String query) {
    _searchQuery.value = query;
  }

  /// Agregar producto al carrito
  void addProductToCart(Product product, {int quantity = 1}) {
    if (product.stock < quantity) {
      SnackbarHelper.error('Stock insuficiente',
          'Solo hay ${product.stock} unidades disponibles');
      return;
    }

    // Verificar si el producto ya está en el carrito
    final existingIndex =
        _cartItems.indexWhere((item) => item.productId == product.id);

    if (existingIndex != -1) {
      // Actualizar cantidad existente
      final existingItem = _cartItems[existingIndex];
      final newQuantity = existingItem.quantity + quantity;

      if (newQuantity > product.stock) {
        SnackbarHelper.error('Stock insuficiente',
            'Solo hay ${product.stock} unidades disponibles');
        return;
      }

      _cartItems[existingIndex] = existingItem.copyWith(quantity: newQuantity);
    } else {
      // Agregar nuevo item
      final saleItem = SaleItem(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        unitPrice: product.price,
        total: product.price * quantity,
      );
      _cartItems.add(saleItem);
    }

    _calculateTotals();

    SnackbarHelper.success('Producto agregado', '${product.name} x$quantity');
  }

  /// Actualizar cantidad de un item en el carrito
  void updateCartItemQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index != -1) {
      // Verificar stock disponible
      final product =
          _availableProducts.firstWhereOrNull((p) => p.id == productId);
      if (product != null && newQuantity > product.stock) {
        SnackbarHelper.error('Stock insuficiente',
            'Solo hay ${product.stock} unidades disponibles');
        return;
      }

      _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
      _calculateTotals();
    }
  }

  /// Remover producto del carrito
  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    _calculateTotals();
  }

  /// Limpiar carrito
  void clearCart() {
    _cartItems.clear();
    _calculateTotals();
    _receivedAmount.value = 0.0;
    _changeAmount.value = 0.0;
  }

  /// Calcular totales
  void _calculateTotals() {
    _totalAmount.value = _cartItems.fold(0.0, (sum, item) => sum + item.total);
    _taxAmount.value = _totalAmount.value * _taxRate.value;
    _finalAmount.value =
        _totalAmount.value + _taxAmount.value - _discountAmount.value;

    // Recalcular cambio si hay monto recibido
    if (_receivedAmount.value > 0) {
      _changeAmount.value = _receivedAmount.value - _finalAmount.value;
    }
  }

  /// Establecer método de pago
  void setPaymentMethod(String method) {
    _selectedPaymentMethod.value = method;
  }

  /// Establecer monto recibido
  void setReceivedAmount(double amount) {
    _receivedAmount.value = amount;
    _changeAmount.value = amount - _finalAmount.value;
  }

  /// Aplicar descuento
  void applyDiscount(double discount) {
    _discountAmount.value = discount;
    _calculateTotals();
  }

  /// Configurar tasa de impuesto
  void setTaxRate(double rate) {
    _taxRate.value = rate;
    _calculateTotals();
  }

  /// Validar si se puede procesar la venta
  bool canProcessSale() {
    if (_cartItems.isEmpty) return false;
    if (_selectedPaymentMethod.value == 'efectivo') {
      return _receivedAmount.value >= _finalAmount.value;
    }
    return true;
  }

  /// Procesar venta
  Future<bool> processSale() async {
    if (!canProcessSale()) {
      SnackbarHelper.error(
          'Error', 'No se puede procesar la venta. Verifique los datos.');
      return false;
    }

    try {
      _isProcessingPayment.value = true;

      // Crear objeto de venta
      final sale = Sale(
        // No incluir clienteId para ventas directas de productos
        clienteNombre: 'Venta Directa',
        concepto: 'producto',
        tipoMembresia: 'ninguna',
        montoBase: _totalAmount.value,
        montoFinal: _finalAmount.value,
        metodoPago: _selectedPaymentMethod.value,
        usuarioStaff: 'staff_user', // TODO: Obtener del contexto de usuario
        descuento: _discountAmount.value,
        fecha: DateTime.now(),
        items: List.from(_cartItems),
        // Nuevos campos para ventas de productos
        impuestos: _taxAmount.value,
        montoRecibido: _receivedAmount.value,
        cambio: _changeAmount.value,
        ventaTipo: 'producto',
        subtotal: _totalAmount.value,
      );

      // Procesar venta en el repositorio
      final result = await _saleRepository.createSale(sale);

      if (result != null) {
        SnackbarHelper.success(
            'Venta procesada', 'Venta completada exitosamente');

        // Limpiar carrito y estado
        clearCart();
        _selectedPaymentMethod.value = 'efectivo';

        // Recargar productos para actualizar stock
        await loadProducts();

        // Refrescar datos de ingresos globalmente
        IngresosController.refreshIngresosGlobally();

        return true;
      } else {
        SnackbarHelper.error('Error', 'No se pudo procesar la venta');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al procesar venta: $e');
      }
      SnackbarHelper.error('Error', 'Error inesperado al procesar la venta');
      return false;
    } finally {
      _isProcessingPayment.value = false;
    }
  }

  /// Obtener estadísticas rápidas
  Future<Map<String, dynamic>> getQuickStats() async {
    return await _saleRepository.getSalesStats();
  }
}

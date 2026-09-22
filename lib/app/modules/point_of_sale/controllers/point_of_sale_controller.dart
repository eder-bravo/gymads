import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/screen_tour_mixin.dart';
import '../../../core/widgets/escaner_codigo_view.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/services/ocr_referencia_service.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../data/services/welcome_tour_service.dart';
import '../../ingresos/controllers/ingresos_controller.dart';

class PointOfSaleController extends GetxController with ScreenTourMixin {
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
  final RxString _referenciaPago = ''.obs;

  // Lista de productos disponibles
  final RxList<Product> _availableProducts = <Product>[].obs;
  final RxString _searchQuery = ''.obs;

  // Filtro de categoría. `null` = todas.
  final RxList<ProductCategory> _categories = <ProductCategory>[].obs;
  final RxnString _selectedCategoryId = RxnString();

  /// Productos fijados arriba, los que más se venden. Se guardan por gimnasio
  /// en el dispositivo: es una comodidad del mostrador, no un dato del negocio.
  final RxSet<String> _pinnedProductIds = <String>{}.obs;

  /// Productos para los que ya se aceptó vender sin existencias en esta venta.
  /// Evita repetir el aviso en cada unidad del mismo producto. Se limpia con
  /// el carrito.
  final Set<String> _faltantesConfirmados = <String>{};

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
  String get referenciaPago => _referenciaPago.value;

  List<Product> get availableProducts => _availableProducts;
  List<Product> get filteredProducts {
    final query = _searchQuery.value.toLowerCase();
    final byId = categoryById;

    final matches = _availableProducts.where((product) {
      final matchesCategory = _selectedCategoryId.value == null ||
          product.categoryId == _selectedCategoryId.value;

      // La búsqueda también mira el nombre de la categoría, como antes; ahora
      // hay que resolverlo por el mapa porque el producto solo guarda el id.
      final categoryName =
          (byId[product.categoryId]?.name ?? '').toLowerCase();

      // El código de barras entra para poder teclearlo cuando el escáner no
      // lo lee (envase arrugado, poca luz).
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          categoryName.contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query.trim());

      return matchesCategory && matchesSearch;
    });

    // Los fijados primero. Se reparte en dos listas en vez de ordenar porque
    // `List.sort` no es estable y revolvería el orden dentro de cada grupo.
    final pinned = <Product>[];
    final rest = <Product>[];
    for (final product in matches) {
      (isPinned(product.id) ? pinned : rest).add(product);
    }
    return [...pinned, ...rest];
  }

  bool isPinned(String productId) => _pinnedProductIds.contains(productId);

  /// Fija o suelta un producto (pulsación larga sobre su tarjeta).
  Future<void> togglePinned(Product product) async {
    final wasPinned = isPinned(product.id);
    if (wasPinned) {
      _pinnedProductIds.remove(product.id);
    } else {
      _pinnedProductIds.add(product.id);
    }

    SnackbarHelper.info(
      product.name,
      wasPinned ? 'Ya no está fijado arriba' : 'Fijado arriba',
    );
    await _savePinnedProducts();
  }

  static String? _pinnedKey() {
    final gymId = TenantContextService.to.currentGymId;
    return gymId == null ? null : 'pos_pinned_products_$gymId';
  }

  Future<void> _loadPinnedProducts() async {
    final key = _pinnedKey();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    _pinnedProductIds.addAll(prefs.getStringList(key) ?? const []);
  }

  Future<void> _savePinnedProducts() async {
    final key = _pinnedKey();
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, _pinnedProductIds.toList());
  }

  /// Búsqueda por id para resolver nombre e icono de la categoría.
  Map<String, ProductCategory> get categoryById => {
        for (final c in _categories) c.id: c,
      };

  /// Categorías que se ofrecen en el filtro.
  List<ProductCategory> get activeCategories =>
      _categories.where((c) => c.isActive).toList();

  String get searchQuery => _searchQuery.value;
  double get taxRate => _taxRate.value;

  List<ProductCategory> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId.value;

  // Métodos de pago disponibles
  final List<String> paymentMethods = [
    'efectivo',
    'tarjeta_debito',
    'tarjeta_credito',
    'transferencia',
    'mixto'
  ];

  // Métodos que admiten folio / referencia de la operación
  static const List<String> _metodosConReferencia = [
    'tarjeta_debito',
    'tarjeta_credito',
    'transferencia',
  ];

  /// Si el método de pago seleccionado admite folio / referencia
  bool get usaReferenciaPago =>
      _metodosConReferencia.contains(_selectedPaymentMethod.value);

  // ─── Tour de bienvenida ───
  final keyBuscar = GlobalKey();
  final keyCategorias = GlobalKey();
  final keyProductos = GlobalKey();
  final keyCarrito = GlobalKey();

  @override
  String get tourId => AppTours.puntoDeVenta;

  @override
  List<GlobalKey> get tourSteps =>
      [keyBuscar, keyCategorias, keyProductos, keyCarrito];

  @override
  void onClose() {
    referenciaCtrl.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    loadProducts();
    loadCategories();
    _loadPinnedProducts();
  }

  /// Recarga todo lo que se ve en el mostrador.
  ///
  /// Recarga las tres cosas y no solo los productos: el stock cambia con cada
  /// venta, pero una categoría nueva o un producto fijado desde otro
  /// dispositivo tampoco aparecerían nunca.
  Future<void> refrescar() async {
    await Future.wait([
      loadProducts(),
      loadCategories(),
      _loadPinnedProducts(),
    ]);
  }

  /// Cargar productos disponibles
  ///
  /// Se muestran también los agotados y los que están en negativo: sin
  /// existencias se sigue pudiendo cobrar, y el stock queda como faltante.
  /// Filtra por activos porque, al dejar de esconder los de stock 0, un
  /// producto desactivado aparecería en el mostrador.
  Future<void> loadProducts() async {
    try {
      _isLoading.value = true;
      final products = await _productRepository.getActiveProducts();
      _availableProducts.assignAll(products);
    } catch (e) {
      AppLogger.error('PointOfSaleController', 'Error al cargar productos', e);
      SnackbarHelper.error('Error', 'No se pudieron cargar los productos');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Cargar categorías disponibles para el filtro
  Future<void> loadCategories() async {
    try {
      _categories.value = await _productRepository.getAllCategories();
    } catch (e) {
      AppLogger.error('PointOfSaleController', 'Error al cargar categorías', e);
    }
  }

  /// Establecer la categoría seleccionada del filtro. `null` = todas.
  void setSelectedCategory(String? categoryId) {
    _selectedCategoryId.value = categoryId;
  }

  /// Buscar productos
  void searchProducts(String query) {
    _searchQuery.value = query;
  }

  /// Busca un producto por su código de barras, en memoria.
  ///
  /// La lista ya está cargada, así que no hace falta ir a la red: cada lectura
  /// del escáner se resuelve al instante.
  Product? productoPorBarcode(String codigo) {
    final buscado = codigo.trim();
    if (buscado.isEmpty) return null;
    return _availableProducts.firstWhereOrNull((p) => p.barcode == buscado);
  }

  /// Abre el escáner en modo continuo: cada código leído suma una unidad de
  /// su producto al carrito, hasta que se toca "Listo".
  Future<void> escanearAlCarrito() async {
    await Get.to<void>(
      () => EscanerCodigoView(
        titulo: 'Escanear productos',
        instruccion: 'Escanea cada producto para agregarlo a la venta',
        alLeer: _agregarPorCodigo,
      ),
    );
  }

  /// Devuelve el aviso que muestra el escáner tras cada lectura.
  Future<String?> _agregarPorCodigo(String codigo) async {
    final producto = productoPorBarcode(codigo);
    if (producto == null) return 'Código no registrado';

    final antes = _cantidadEnCarrito(producto.id);
    await addProductToCart(producto);

    // `addProductToCart` no avisa si se canceló el aviso de "sin
    // existencias"; se sabe comparando la cantidad.
    final despues = _cantidadEnCarrito(producto.id);
    if (despues == antes) return 'No se agregó ${producto.name}';
    return '+1 ${producto.name} (llevas $despues)';
  }

  int _cantidadEnCarrito(String productId) =>
      _cartItems.firstWhereOrNull((i) => i.productId == productId)?.quantity ??
      0;

  /// Cuánto quedará el stock de un producto si se cobra el carrito tal como
  /// está. Negativo significa faltante: unidades que salen sin existencias.
  int stockProyectado(String productId) {
    final product = _availableProducts.firstWhereOrNull((p) => p.id == productId);
    if (product == null) return 0;
    final enCarrito = _cartItems
        .firstWhereOrNull((item) => item.productId == productId)
        ?.quantity ??
        0;
    return product.stock - enCarrito;
  }

  /// Productos del carrito que dejarán el stock en negativo al cobrar.
  List<SaleItem> get itemsSinExistencias => _cartItems
      .where((item) => stockProyectado(item.productId) < 0)
      .toList();

  /// Agregar producto al carrito
  ///
  /// Nunca bloquea por falta de stock: si no hay existencias la venta se hace
  /// igual y el stock queda negativo (el faltante). Solo pide confirmación la
  /// primera vez que un producto cruza a negativo dentro de esta venta.
  Future<void> addProductToCart(Product product, {int quantity = 1}) async {
    final existingIndex =
        _cartItems.indexWhere((item) => item.productId == product.id);
    final cantidadActual =
        existingIndex != -1 ? _cartItems[existingIndex].quantity : 0;
    final nuevaCantidad = cantidadActual + quantity;

    if (!await _confirmarFaltante(product, nuevaCantidad)) return;

    if (existingIndex != -1) {
      _cartItems[existingIndex] =
          _cartItems[existingIndex].copyWith(quantity: nuevaCantidad);
    } else {
      _cartItems.add(SaleItem(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        unitPrice: product.price,
        total: product.price * quantity,
      ));
    }

    _calculateTotals();
  }

  /// Actualizar cantidad de un item en el carrito
  Future<void> updateCartItemQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index == -1) return;

    final product =
        _availableProducts.firstWhereOrNull((p) => p.id == productId);
    if (product != null && !await _confirmarFaltante(product, newQuantity)) {
      return;
    }

    _cartItems[index] = _cartItems[index].copyWith(quantity: newQuantity);
    _calculateTotals();
  }

  /// Pide confirmación si [cantidad] deja el stock del producto en negativo y
  /// aún no se aceptó para este producto en esta venta. Devuelve false solo si
  /// el usuario cancela.
  Future<bool> _confirmarFaltante(Product product, int cantidad) async {
    final restante = product.stock - cantidad;
    if (restante >= 0) return true;
    if (_faltantesConfirmados.contains(product.id)) return true;

    final confirmado = await Get.dialog<bool>(
          AlertDialog(
            scrollable: true,
            backgroundColor: AppColors.cardBackground,
            title: const Text('Sin existencias',
                style: TextStyle(color: AppColors.textPrimary)),
            content: Text(
              product.stock > 0
                  ? 'Solo quedan ${product.stock} de ${product.name}.\n\n'
                      'Puedes venderlo igual: el stock quedará en ${-restante} '
                      'unidades faltantes y se descontarán solas cuando repongas.'
                  : 'No hay existencias de ${product.name}.\n\n'
                      'Puedes venderlo igual: el stock quedará en ${-restante} '
                      'unidades faltantes y se descontarán solas cuando repongas.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Vender igual'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmado) _faltantesConfirmados.add(product.id);
    return confirmado;
  }

  /// Remover producto del carrito
  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    _faltantesConfirmados.remove(productId);
    _calculateTotals();
  }

  /// Limpiar carrito
  void clearCart() {
    _cartItems.clear();
    _faltantesConfirmados.clear();
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
    // Reiniciar monto recibido/cambio: son específicos de un intento de pago
    // en efectivo, no deben sobrevivir al cambiar de método.
    _receivedAmount.value = 0.0;
    _changeAmount.value = 0.0;
    // La referencia pertenece a la operación con tarjeta/transferencia
    // concreta, tampoco debe sobrevivir al cambiar de método.
    _limpiarReferencia();
  }

  /// Establecer monto recibido
  void setReceivedAmount(double amount) {
    _receivedAmount.value = amount;
    _changeAmount.value = amount - _finalAmount.value;
  }

  /// Establecer folio / referencia de la operación
  void setReferenciaPago(String value) {
    _referenciaPago.value = value;
  }

  // =================== REFERENCIA POR FOTO ===================

  /// Referencias que el OCR encontró en la foto, para que la persona elija.
  /// Se sugieren, nunca se dan por buenas: el campo sigue siendo editable.
  final RxList<String> referenciasSugeridas = <String>[].obs;

  final RxBool leyendoReferencia = false.obs;

  /// Si ya se leyó una foto. Distingue "no se reconoció nada" de "aún no se
  /// ha intentado".
  final RxBool referenciaEscaneada = false.obs;

  /// El campo de texto de la referencia. Vive en el controlador porque el
  /// OCR necesita poder escribir en él, y la vista es un StatelessWidget que
  /// se reconstruye: un controller creado ahí perdería el texto.
  final TextEditingController referenciaCtrl = TextEditingController();

  /// Toma o elige la foto del comprobante y le busca la referencia.
  ///
  /// La foto solo sirve para leerla: no se sube ni se guarda. Lo que queda
  /// registrado es la referencia, igual que si se hubiera tecleado.
  ///
  /// La galería entra a propósito: muchos comprobantes llegan por mensajería
  /// y nunca pasan por la cámara.
  Future<void> escanearReferencia({required bool desdeCamara}) async {
    File? foto;
    try {
      final elegida = await ImagePicker().pickImage(
        source: desdeCamara ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        // Sin comprimir de más: la referencia suele ir en letra pequeña y
        // una imagen agresivamente reducida deja al OCR sin nada que leer.
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (elegida == null) return;

      foto = File(elegida.path);

      leyendoReferencia.value = true;
      final candidatos = await OcrReferenciaService.extraerCandidatos(foto);
      referenciasSugeridas.assignAll(candidatos);
      referenciaEscaneada.value = true;

      // Si solo hay una lectura clara, se propone ya escrita para ahorrar un
      // toque. Sigue pudiendo corregirse.
      if (candidatos.length == 1 && _referenciaPago.value.trim().isEmpty) {
        usarReferenciaSugerida(candidatos.first);
      }
    } catch (e) {
      AppLogger.error(
          'PointOfSaleController', 'Error al leer la referencia', e);
      SnackbarHelper.error('Error', 'No se pudo usar esa imagen.');
    } finally {
      leyendoReferencia.value = false;
      if (foto != null) await _borrarFotoTemporal(foto);
    }
  }

  /// Borra la copia que image_picker dejó en la caché de la app.
  ///
  /// Solo si está dentro del directorio temporal: image_picker siempre
  /// entrega una copia ahí, pero si algún día devolviera el original de la
  /// galería, no se debe tocar la foto de la persona.
  Future<void> _borrarFotoTemporal(File foto) async {
    try {
      final temporal = await getTemporaryDirectory();
      if (foto.path.startsWith(temporal.path) && await foto.exists()) {
        await foto.delete();
      }
    } catch (_) {
      AppLogger.warning('PointOfSaleController',
          'No se pudo borrar la foto temporal de la referencia');
    }
  }

  /// Pone en el campo una de las referencias que leyó el OCR.
  void usarReferenciaSugerida(String referencia) {
    _referenciaPago.value = referencia;
    referenciaCtrl.text = referencia;
    referenciaCtrl.selection =
        TextSelection.collapsed(offset: referencia.length);
  }

  /// Vacía el campo de referencia y lo que leyó el OCR.
  void _limpiarReferencia() {
    _referenciaPago.value = '';
    referenciaCtrl.clear();
    referenciasSugeridas.clear();
    referenciaEscaneada.value = false;
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
        referenciaPago: _referenciaPago.value.trim().isEmpty
            ? null
            : _referenciaPago.value.trim(),
      );

      // Procesar venta en el repositorio
      final resultado = await _saleRepository.createSale(sale);
      final result = resultado.sale;

      // El cobro salió bien pero algún stock no se movió: hay que avisarlo,
      // porque el inventario queda mal y solo se arregla a mano.
      if (result != null && resultado.stockFallido.isNotEmpty) {
        SnackbarHelper.error(
          'Revisa el inventario',
          'La venta se registró, pero no se pudo descontar el stock de '
              '${resultado.stockFallido.join(', ')}.',
        );
      }

      if (result != null) {
        // La notificación de éxito la muestra la vista tras cerrar el modal,
        // para evitar el doble snackbar que se auto-cancelaba con clearSnackBars().

        // Limpiar carrito y estado
        clearCart();
        _selectedPaymentMethod.value = 'efectivo';
        _limpiarReferencia();

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
      AppLogger.error('PointOfSaleController', 'Error al procesar venta', e);
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

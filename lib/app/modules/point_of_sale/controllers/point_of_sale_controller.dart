import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/screen_tour_mixin.dart';
import '../../../core/widgets/escaner_codigo_view.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sale_repository.dart';

import '../../../core/utils/referencia_de_pago.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../data/services/carrito_guardado.dart';
import '../../../data/services/welcome_tour_service.dart';
import '../../ingresos/controllers/ingresos_controller.dart';
import 'package:gymads/app/data/services/cambios_en_vivo_service.dart';
import 'package:gymads/app/core/widgets/espera_global.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';

/// En qué va la venta en escritorio y tableta: el panel de la derecha
/// cambia según esto (como el autocobro del súper). En el teléfono cada
/// momento es su propia pantalla.
enum EtapaVenta { productos, cobro, listo }

/// Lo que se cobró, para mostrarlo en "¡Listo!" después de vaciar el carrito.
class VentaTerminada {
  const VentaTerminada({
    required this.total,
    required this.metodo,
    required this.recibido,
    required this.cambio,
    required this.unidades,
  });

  final double total;
  final String metodo;
  final double recibido;
  final double cambio;
  final int unidades;
}

class PointOfSaleController extends GetxController
    with ScreenTourMixin, RecargaEnVivoMixin, ReferenciaDePago {
  PointOfSaleController({
    CarritoGuardado? carritoGuardado,
    SaleRepository? saleRepository,
  })  : _carritoGuardado = carritoGuardado,
        _saleRepositoryOverride = saleRepository;

  CarritoGuardado? _carritoGuardado;
  Future<void>? _cargaCarrito;
  bool _carritoModificado = false;

  /// Se comparte la misma carga entre el arranque y la primera interacción.
  Future<void> restaurarCarrito() => _cargaCarrito ??= _restaurarCarrito();

  Future<void> _restaurarCarrito() async {
    _carritoGuardado ??= CarritoGuardado.deSesionActual();
    final borrador = await _carritoGuardado?.leer();
    if (_carritoModificado) {
      await guardarCarrito();
    } else if (borrador != null && !isClosed) {
      _cartItems.assignAll(borrador.items);
      _discountAmount.value = borrador.descuento;
      _taxRate.value = borrador.impuesto;
      _calculateTotals(guardar: false);
    }
  }

  Future<void> guardarCarrito() async {
    _carritoModificado = true;
    await _carritoGuardado?.guardar(
      _cartItems,
      descuento: discountAmount,
      impuesto: taxRate,
    );
  }

  late final ProductRepository _productRepository = ProductRepository();
  final SaleRepository? _saleRepositoryOverride;
  late final SaleRepository _saleRepository =
      _saleRepositoryOverride ?? SaleRepository();

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
  final Rx<EtapaVenta> _etapa = EtapaVenta.productos.obs;
  final Rxn<VentaTerminada> _ultimaVenta = Rxn<VentaTerminada>();

  // Lista de productos disponibles
  final RxList<Product> _availableProducts = <Product>[].obs;
  final RxString _searchQuery = ''.obs;

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

  /// Piezas en la venta: dos aguas y una barra son 3, no 2 renglones.
  int get totalUnidades => _cartItems.fold(0, (s, i) => s + i.quantity);
  double get totalAmount => _totalAmount.value;
  double get taxAmount => _taxAmount.value;
  double get discountAmount => _discountAmount.value;
  double get finalAmount => _finalAmount.value;

  bool get isLoading => _isLoading.value;
  bool get isProcessingPayment => _isProcessingPayment.value;
  String get selectedPaymentMethod => _selectedPaymentMethod.value;
  double get receivedAmount => _receivedAmount.value;
  double get changeAmount => _changeAmount.value;
  String get referenciaPago => referenciaTexto.value;
  EtapaVenta get etapa => _etapa.value;
  VentaTerminada? get ultimaVenta => _ultimaVenta.value;

  /// Pasa al cobro (escritorio y tableta). Sin productos no hay qué cobrar.
  void irACobrar() {
    if (_cartItems.isEmpty) return;
    _etapa.value = EtapaVenta.cobro;
  }

  /// Vuelve a los productos para corregir la venta antes de cobrar.
  void regresarALaVenta() => _etapa.value = EtapaVenta.productos;

  /// Después de "¡Listo!": empieza otra venta.
  void nuevaVenta() {
    _ultimaVenta.value = null;
    _etapa.value = EtapaVenta.productos;
  }

  /// Qué falta para poder cobrar, o null si ya se puede.
  String? get faltaParaCobrar {
    if (_cartItems.isEmpty) return 'Agrega productos a la venta';
    if (_selectedPaymentMethod.value != 'efectivo') return null;
    if (_receivedAmount.value <= 0) return 'Escribe con cuánto paga';
    final falta = _finalAmount.value - _receivedAmount.value;
    return falta > 0.004 ? 'Faltan ${dinero(falta)}' : null;
  }

  /// Atajos para el efectivo: el monto exacto y los billetes que le siguen.
  List<double> get montosRapidos {
    final total = _finalAmount.value;
    if (total <= 0) return const [];
    final billetes = [20.0, 50.0, 100.0, 200.0, 500.0, 1000.0]
        .where((b) => b > total)
        .take(3);
    return [total, ...billetes];
  }

  List<Product> get availableProducts => _availableProducts;
  List<Product> get filteredProducts {
    final query = _searchQuery.value.toLowerCase();

    // El código de barras entra para poder teclearlo cuando el escáner no lo
    // lee (envase arrugado, poca luz).
    final matches = _availableProducts.where((product) =>
        query.isEmpty ||
        product.name.toLowerCase().contains(query) ||
        (product.barcode ?? '').toLowerCase().contains(query.trim()));

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

  String get searchQuery => _searchQuery.value;
  double get taxRate => _taxRate.value;

  // Métodos de pago disponibles (los mismos que en Abonar, más mixto).
  final List<String> paymentMethods = [...metodosDePago, 'mixto'];

  /// Si el método de pago seleccionado admite folio / referencia
  bool get usaReferenciaPago =>
      metodosConReferencia.contains(_selectedPaymentMethod.value);

  // ─── Tour de bienvenida ───
  final keyEscanear = GlobalKey();
  final keyBuscar = GlobalKey();
  final keyProductos = GlobalKey();
  final keyCarrito = GlobalKey();

  @override
  String get tourId => AppTours.puntoDeVenta;

  @override
  List<GlobalKey> get tourSteps =>
      [keyEscanear, keyBuscar, keyProductos, keyCarrito];

  @override
  void onInit() {
    super.onInit();
    restaurarCarrito();
    loadProducts();
    _loadPinnedProducts();
    // El stock cambia con las ventas de otro teléfono; un producto nuevo
    // aparece solo.
    recargarAlCambiar(
        {TablaEnVivo.productos}, () => loadProducts(silencioso: true));
  }

  /// Recarga todo lo que se ve en el mostrador.
  ///
  /// Recarga también los fijados: el stock cambia con cada venta, pero un
  /// producto fijado desde otro dispositivo no aparecería nunca.
  Future<void> refrescar() async {
    await Future.wait([
      loadProducts(),
      _loadPinnedProducts(),
    ]);
  }

  /// Cargar productos disponibles
  ///
  /// Se muestran también los agotados y los que están en negativo: sin
  /// existencias se sigue pudiendo cobrar, y el stock queda como faltante.
  /// Filtra por activos porque, al dejar de esconder los de stock 0, un
  /// producto desactivado aparecería en el mostrador.
  ///
  /// [silencioso]: sin spinner ni mensajes de error (recarga automática).
  Future<void> loadProducts({bool silencioso = false}) async {
    try {
      if (!silencioso) _isLoading.value = true;
      final products = await _productRepository.getActiveProducts();
      _availableProducts.assignAll(products);
    } catch (e) {
      AppLogger.error('PointOfSaleController', 'Error al cargar productos', e);
      if (!silencioso) {
        SnackbarHelper.error('Error', 'No se pudieron cargar los productos');
      }
    } finally {
      if (!silencioso) _isLoading.value = false;
    }
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
        alLeer: agregarPorCodigo,
      ),
    );
  }

  /// Devuelve el aviso que muestra el escáner tras cada lectura.
  Future<String?> agregarPorCodigo(String codigo) async {
    if (isLoading || isProcessingPayment) {
      return 'Espera a que termine la operación';
    }
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
    final product =
        _availableProducts.firstWhereOrNull((p) => p.id == productId);
    if (product == null) return 0;
    final enCarrito = _cartItems
            .firstWhereOrNull((item) => item.productId == productId)
            ?.quantity ??
        0;
    return product.stock - enCarrito;
  }

  /// Productos del carrito que dejarán el stock en negativo al cobrar.
  List<SaleItem> get itemsSinExistencias =>
      _cartItems.where((item) => stockProyectado(item.productId) < 0).toList();

  /// Agregar producto al carrito
  ///
  /// Nunca bloquea por falta de stock: si no hay existencias la venta se hace
  /// igual y el stock queda negativo (el faltante). Solo pide confirmación la
  /// primera vez que un producto cruza a negativo dentro de esta venta.
  Future<void> addProductToCart(Product product, {int quantity = 1}) async {
    await restaurarCarrito();
    if (isClosed || quantity <= 0) return;
    // Agregar (o escanear) en "¡Listo!" empieza la venta siguiente.
    if (_etapa.value == EtapaVenta.listo) nuevaVenta();
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
    await restaurarCarrito();
    if (isClosed) return;
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
            title: const Text('Sin existencias'),
            content: Text(
              product.stock > 0
                  ? 'Solo quedan ${product.stock} de ${product.name}.\n\nPuedes venderlo igual y quedará en negativo hasta que repongas.'
                  : 'No hay existencias de ${product.name}.\n\nPuedes venderlo igual y quedará en negativo hasta que repongas.',
            ),
            actions: [
              BotonCancelar(onPressed: () => Get.back(result: false)),
              BotonGuardar(
                texto: 'Vender igual',
                compacto: true,
                onPressed: () => Get.back(result: true),
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
    if (_cartItems.isEmpty && _etapa.value == EtapaVenta.cobro) {
      _etapa.value = EtapaVenta.productos;
    }
  }

  /// Limpiar carrito
  void clearCart() {
    _cartItems.clear();
    _faltantesConfirmados.clear();
    _discountAmount.value = 0.0;
    _calculateTotals();
    _receivedAmount.value = 0.0;
    _changeAmount.value = 0.0;
    // Sin productos no hay cobro abierto.
    if (_etapa.value == EtapaVenta.cobro) _etapa.value = EtapaVenta.productos;
  }

  /// Calcular totales
  void _calculateTotals({bool guardar = true}) {
    _totalAmount.value = _cartItems.fold(0.0, (sum, item) => sum + item.total);
    _taxAmount.value = _totalAmount.value * _taxRate.value;
    _finalAmount.value =
        _totalAmount.value + _taxAmount.value - _discountAmount.value;

    // Recalcular cambio si hay monto recibido
    if (_receivedAmount.value > 0) {
      _changeAmount.value = _receivedAmount.value - _finalAmount.value;
    }
    if (guardar) guardarCarrito();
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
    limpiarReferencia();
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
    await restaurarCarrito();
    if (isClosed || isProcessingPayment) return false;
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
        referenciaPago: referenciaParaGuardar,
      );

      // Procesar venta en el repositorio. Si falla, la espera ya lo dice
      // (y deja reintentar); el carrito sigue como estaba.
      final resultado = await EsperaGlobal.to.guardar(
        () => _saleRepository.createSale(sale),
        queHace: 'registrar la venta',
        generico: 'La venta no se registró. Intenta de nuevo.',
        siQuedoEnDuda: 'Puede que la venta sí se haya registrado. Revisa '
            'Ingresos antes de volver a cobrar.',
      );
      if (resultado == null) return false;
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
        // Lo cobrado se guarda antes de vaciar el carrito: "¡Listo!" muestra
        // el total y el cambio.
        _ultimaVenta.value = VentaTerminada(
          total: _finalAmount.value,
          metodo: _selectedPaymentMethod.value,
          recibido: _receivedAmount.value,
          cambio: _changeAmount.value > 0 ? _changeAmount.value : 0,
          unidades: totalUnidades,
        );

        // Limpiar carrito y estado
        clearCart();
        _etapa.value = EtapaVenta.listo;
        await guardarCarrito();
        _selectedPaymentMethod.value = 'efectivo';
        limpiarReferencia();

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

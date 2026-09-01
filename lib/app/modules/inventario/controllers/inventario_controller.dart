import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/auth_utils.dart';
import 'package:gymads/app/core/utils/screen_tour_mixin.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/repositories/product_repository.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';

class InventarioController extends GetxController with ScreenTourMixin {
  // `late` a propósito: el repositorio abre el cliente de Supabase al
  // construirse, y como campo directo obligaba a tener Supabase inicializado
  // solo por crear el controller.
  late final ProductRepository productRepository = ProductRepository();

  // Método helper para mostrar snackbars de forma segura
  void _showSnackbarSafe(String title, String message,
      {bool isError = false, bool isWarning = false}) {
    // Usar Future.delayed para asegurar que el overlay esté disponible
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        // Verificar que hay un contexto válido
        final context = Get.context;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $message'),
              backgroundColor: isError
                  ? Colors.red
                  : (isWarning ? Colors.orange : Colors.green),
              duration: isWarning
                  ? const Duration(seconds: 4)
                  : const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        AppLogger.error(
            'InventarioController', 'No se pudo mostrar la notificación', e);
      }
    });
  }

  // Estado observable para productos
  final RxList<Product> products = <Product>[].obs;
  final RxList<Product> filteredProducts = <Product>[].obs;
  final RxList<ProductCategory> categories = <ProductCategory>[].obs;

  // Estado para la búsqueda
  final RxString searchQuery = ''.obs;

  /// Id de la categoría filtrada. `null` significa "todas".
  final RxnString selectedCategoryId = RxnString();

  /// Muestra solo lo que hay que reponer (stock negativo).
  final RxBool soloFaltantes = false.obs;

  // Estado para el formulario
  final Rx<Product?> currentProduct = Rx<Product?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isUploading = false.obs;
  final RxBool isEditing = false.obs;

  // Estadísticas
  final RxMap<String, dynamic> inventoryStats = <String, dynamic>{}.obs;

  // Para transacciones
  final RxList<ProductTransaction> transactions = <ProductTransaction>[].obs;
  final Rx<TransactionType> selectedTransactionType =
      TransactionType.entrada.obs;
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  // ─── Tour de bienvenida ───
  final keyAgregar = GlobalKey();
  final keyCategorias = GlobalKey();
  final keyBuscar = GlobalKey();
  final keyLista = GlobalKey();

  @override
  String get tourId => AppTours.inventario;

  @override
  List<GlobalKey> get tourSteps =>
      [keyAgregar, keyCategorias, keyBuscar, keyLista];

  @override
  void onInit() {
    super.onInit();
    loadProducts();
    loadCategories();
    loadInventoryStats();
  }

  @override
  void onClose() {
    quantityController.dispose();
    notesController.dispose();
    priceController.dispose();
    super.onClose();
  }

  void resetForm() {
    currentProduct.value = null;
    isEditing.value = false;
    quantityController.clear();
    notesController.clear();
    priceController.clear();
  }

  Future<void> loadProducts() async {
    isLoading.value = true;
    try {
      products.value = await productRepository.getAllProducts();
      filterProducts();
    } catch (e) {
      AppLogger.error('InventarioController', 'Error al cargar productos', e);
      _showSnackbarSafe('Error', 'No se pudieron cargar los productos',
          isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadCategories() async {
    try {
      // Se cargan también las inactivas: hacen falta para resolver el nombre
      // de un producto cuya categoría se desactivó.
      categories.value = await productRepository.getAllCategories();
      filterProducts();
    } catch (e) {
      AppLogger.error('InventarioController', 'Error al cargar categorías', e);
    }
  }

  /// Categorías que se pueden elegir al crear o filtrar.
  List<ProductCategory> get activeCategories =>
      categories.where((c) => c.isActive).toList();

  /// Búsqueda por id para resolver el nombre y el icono de un producto.
  Map<String, ProductCategory> get categoryById => {
        for (final c in categories) c.id: c,
      };

  String categoryNameFor(Product product) =>
      categoryById[product.categoryId]?.name ?? 'Sin categoría';

  /// Recarga todo. El botón de refrescar solo llamaba a `loadProducts`, así
  /// que una categoría creada en otro dispositivo nunca aparecía.
  Future<void> refreshAll() async {
    await Future.wait([
      loadCategories(),
      loadProducts(),
      loadInventoryStats(),
    ]);
  }

  Future<void> loadInventoryStats() async {
    try {
      inventoryStats.value = await productRepository.getInventoryStats();
    } catch (e) {
      AppLogger.error(
          'InventarioController', 'Error al cargar estadísticas', e);
    }
  }

  void filterProducts() {
    filteredProducts.value = products.where((product) {
      bool matchesSearch = searchQuery.isEmpty ||
          product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(searchQuery.toLowerCase());

      bool matchesCategory = selectedCategoryId.value == null ||
          product.categoryId == selectedCategoryId.value;

      bool matchesFaltante = !soloFaltantes.value || product.stock < 0;

      return matchesSearch && matchesCategory && matchesFaltante;
    }).toList();
  }

  /// Muestra solo los productos con faltante. Lo activa el aviso de
  /// "vendidos sin existencias" para ir directo a lo que hay que reponer.
  void toggleSoloFaltantes() {
    soloFaltantes.value = !soloFaltantes.value;
    filterProducts();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    filterProducts();
  }

  void setSelectedCategory(String? categoryId) {
    selectedCategoryId.value = categoryId;
    filterProducts();
  }

  Future<void> saveProduct(Map<String, dynamic> productData) async {
    isLoading.value = true;

    try {
      final now = DateTime.now();

      if (isEditing.value && currentProduct.value != null) {
        // Actualizar producto existente.
        // El stock no viaja aquí: se mueve solo por deltas desde "Ajustar
        // stock". `updateProduct` tampoco lo envía, así que una venta hecha
        // mientras esta pantalla estaba abierta no se pierde.
        final updatedProduct = currentProduct.value!.copyWith(
          name: productData['name'],
          description: productData['description'],
          categoryId: productData['category_id'],
          price: double.parse(productData['price']),
          isActive: true,
          updatedAt: now,
        );

        final result = await productRepository.updateProduct(updatedProduct);

        if (result != null) {
          int index = products.indexWhere((p) => p.id == result.id);
          if (index >= 0) {
            products[index] = result;
            products.refresh();
          }

          Get.back();
          _showSnackbarSafe('Éxito', 'Producto actualizado correctamente');
        }
      } else {
        // Crear nuevo producto
        final newProduct = Product(
          id: const Uuid().v4(),
          name: productData['name'],
          description: productData['description'],
          categoryId: productData['category_id'],
          price: double.parse(productData['price']),
          stock: int.parse(productData['stock']),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        final result = await productRepository.createProduct(newProduct);

        if (result != null) {
          products.add(result);
          products.refresh();

          Get.back();
          _showSnackbarSafe('Éxito', 'Producto creado correctamente');
        }
      }

      filterProducts();
      loadInventoryStats();
    } catch (e) {
      AppLogger.error('InventarioController', 'Error al guardar producto', e);
      _showSnackbarSafe('Error', 'No se pudo guardar el producto',
          isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  void editProduct(Product product) {
    currentProduct.value = product;
    isEditing.value = true;
  }

  Future<void> deactivateProduct(String productId) async {
    try {
      // Buscar el producto para verificar su stock
      final product = products.firstWhere((p) => p.id == productId);

      // Solo permitir desactivación si no hay stock
      if (product.stock > 0) {
        _showSnackbarSafe(
          'Error',
          'No se puede desactivar un producto con stock disponible (${product.stock} unidades). Debe tener 0 unidades para desactivarlo.',
          isWarning: true,
        );
        return;
      }

      final result = await productRepository.deactivateProduct(productId);

      if (result) {
        // Dar tiempo al sistema antes de actualizar la UI
        await Future.delayed(const Duration(milliseconds: 100));

        // Actualizar el producto en la lista en lugar de eliminarlo
        final index = products.indexWhere((p) => p.id == productId);
        if (index >= 0) {
          products[index] = products[index].copyWith(isActive: false);
        }
        filterProducts();
        loadInventoryStats();

        _showSnackbarSafe('Éxito', 'Producto desactivado correctamente');
      }
    } catch (e) {
      AppLogger.error(
          'InventarioController', 'Error al desactivar producto', e);
      _showSnackbarSafe('Error', 'No se pudo desactivar el producto',
          isError: true);
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      // Mostrar confirmación antes de eliminar permanentemente
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: Text(
            'Eliminar Producto',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar este producto permanentemente?\n\nEsta acción no se puede deshacer.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final result = await productRepository.deleteProduct(productId);

        if (result) {
          // Dar tiempo al sistema antes de actualizar la UI
          await Future.delayed(const Duration(milliseconds: 100));

          final index = products.indexWhere((p) => p.id == productId);
          if (index >= 0) {
            products.removeAt(index);
          }
          filterProducts();
          loadInventoryStats();

          _showSnackbarSafe('Éxito', 'Producto eliminado permanentemente');
        }
      }
    } catch (e) {
      AppLogger.error('InventarioController', 'Error al eliminar producto', e);
      _showSnackbarSafe('Error', 'No se pudo eliminar el producto',
          isError: true);
    }
  }

  Future<void> loadProductTransactions(String productId) async {
    isLoading.value = true;
    try {
      transactions.value =
          await productRepository.getProductTransactions(productId);
    } catch (e) {
      AppLogger.error(
          'InventarioController', 'Error al cargar transacciones', e);
    } finally {
      isLoading.value = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // AJUSTE DE STOCK
  // ══════════════════════════════════════════════════════════

  /// Suma [delta] al stock del producto y deja constancia del movimiento.
  ///
  /// Siempre es un delta, nunca un valor absoluto: así "tengo 9 y entran 5"
  /// da 14, y reponer sobre un faltante lo salda solo (-3 + 10 = 7).
  ///
  /// Devuelve el stock resultante, o null si falló.
  Future<int?> ajustarStock(Product product, int delta,
      {String? nota, double? precioUnitario}) async {
    if (delta == 0) return product.stock;

    try {
      final transaction = ProductTransaction(
        id: const Uuid().v4(),
        productId: product.id,
        productName: product.name,
        type: delta > 0 ? TransactionType.entrada : TransactionType.salida,
        quantity: delta.abs(),
        unitPrice: precioUnitario ?? 0.0,
        notes: nota ?? '',
        staffUser: AuthUtils.getStaffIdentifier(),
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final nuevoStock = await productRepository.recordTransaction(transaction);
      if (nuevoStock == null) {
        _showSnackbarSafe('Error', 'No se pudo actualizar el stock',
            isError: true);
        return null;
      }

      // Refleja el nuevo stock sin recargar toda la lista: el ajuste rápido
      // con +/- se dispara muchas veces seguidas.
      final index = products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        products[index] = products[index].copyWith(stock: nuevoStock);
        products.refresh();
      }

      // El formulario de edición muestra el stock desde aquí; sin esto
      // seguiría enseñando el valor de antes del ajuste.
      if (currentProduct.value?.id == product.id) {
        currentProduct.value =
            currentProduct.value!.copyWith(stock: nuevoStock);
      }
      filterProducts();
      loadInventoryStats();

      return nuevoStock;
    } catch (e) {
      AppLogger.error('InventarioController', 'Error al ajustar stock', e);
      _showSnackbarSafe('Error', 'No se pudo actualizar el stock',
          isError: true);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  // FALTANTES
  //
  // Un stock negativo son unidades que se vendieron sin existencias. No se
  // guarda en ninguna parte: se deriva del propio stock, así que desaparece
  // solo cuando se repone.
  // ══════════════════════════════════════════════════════════

  List<Product> get productosConFaltante =>
      products.where((p) => p.stock < 0).toList();

  /// Unidades que se deben en total.
  int get unidadesFaltantes =>
      productosConFaltante.fold(0, (suma, p) => suma - p.stock);

  /// Lo que valen esas unidades a precio de venta.
  double get valorFaltante => productosConFaltante.fold(
      0.0, (suma, p) => suma + (-p.stock) * p.price);

  bool get hayFaltantes => productosConFaltante.isNotEmpty;
}

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/repositories/product_repository.dart';

class InventarioController extends GetxController {
  final ProductRepository productRepository = ProductRepository();

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
        // Si falla, simplemente logueamos el mensaje
        print('${isError ? '❌' : (isWarning ? '⚠️' : '✅')} $title: $message');
      }
    });
  }

  // Estado observable para productos
  final RxList<Product> products = <Product>[].obs;
  final RxList<Product> filteredProducts = <Product>[].obs;
  final RxList<ProductCategory> categories = <ProductCategory>[].obs;

  // Estado para la búsqueda
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = 'Todas'.obs;

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
      print('Error al cargar productos: $e');
      _showSnackbarSafe('Error', 'No se pudieron cargar los productos',
          isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadCategories() async {
    try {
      print('🔵 [Inventario] Loading categories...');
      categories.value = await productRepository.getAllCategories();
      print('🔵 [Inventario] Loaded ${categories.length} categories');
      for (final c in categories) {
        print('   → ${c.name} (${c.id})');
      }
    } catch (e) {
      print('❌ Error al cargar categorías: $e');
    }
  }

  Future<void> loadInventoryStats() async {
    try {
      inventoryStats.value = await productRepository.getInventoryStats();
    } catch (e) {
      print('Error al cargar estadísticas: $e');
    }
  }

  void filterProducts() {
    filteredProducts.value = products.where((product) {
      bool matchesSearch = searchQuery.isEmpty ||
          product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          product.description.toLowerCase().contains(searchQuery.toLowerCase());

      bool matchesCategory = selectedCategory.value == 'Todas' ||
          product.category == selectedCategory.value;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    filterProducts();
  }

  void setSelectedCategory(String category) {
    selectedCategory.value = category;
    filterProducts();
  }

  Future<void> saveProduct(Map<String, dynamic> productData) async {
    isLoading.value = true;

    try {
      final now = DateTime.now();

      if (isEditing.value && currentProduct.value != null) {
        // Actualizar producto existente
        final updatedProduct = currentProduct.value!.copyWith(
          name: productData['name'],
          description: productData['description'],
          category: productData['category'],
          price: double.parse(productData['price']),
          stock: int.parse(productData['stock']),
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
          category: productData['category'],
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
      print('Error al guardar producto: $e');
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
      print('Error al desactivar producto: $e');
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
      print('Error al eliminar producto: $e');
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
      print('Error al cargar transacciones: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> recordTransaction(String productId, String productName) async {
    if (quantityController.text.isEmpty) {
      _showSnackbarSafe('Error', 'Debes ingresar una cantidad', isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final int quantity = int.parse(quantityController.text);
      final String notes = notesController.text;
      final double unitPrice = priceController.text.isNotEmpty
          ? double.parse(priceController.text)
          : 0.0;

      final transaction = ProductTransaction(
        id: const Uuid().v4(),
        productId: productId,
        productName: productName,
        type: selectedTransactionType.value,
        quantity: quantity,
        unitPrice: unitPrice,
        notes: notes,
        staffUser: 'Admin', // Esto debería venir del usuario logueado
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final result = await productRepository.recordTransaction(transaction);

      if (result) {
        // Recargar el producto y las transacciones
        await loadProducts();
        await loadProductTransactions(productId);
        await loadInventoryStats();

        quantityController.clear();
        notesController.clear();
        priceController.clear();

        Get.back(); // Cerrar el diálogo

        _showSnackbarSafe('Éxito', 'Transacción registrada correctamente');
      }
    } catch (e) {
      print('Error al registrar transacción: $e');
      _showSnackbarSafe('Error', 'No se pudo registrar la transacción',
          isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveCategory(String name, String description) async {
    if (name.isEmpty) {
      _showSnackbarSafe('Error', 'El nombre de la categoría es obligatorio',
          isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final now = DateTime.now();

      final newCategory = ProductCategory(
        id: const Uuid().v4(),
        name: name,
        description: description,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final result = await productRepository.createCategory(newCategory);

      if (result != null) {
        categories.add(result);
        categories.refresh();

        Get.back();
        _showSnackbarSafe('Éxito', 'Categoría creada correctamente');
      }
    } catch (e) {
      print('Error al guardar categoría: $e');
      _showSnackbarSafe('Error', 'No se pudo guardar la categoría',
          isError: true);
    } finally {
      isLoading.value = false;
    }
  }
}

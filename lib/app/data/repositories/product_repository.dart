import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/services/supabase_service.dart';
import 'package:gymads/app/data/services/tenant_query_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  // Obtener todos los productos
  Future<List<Product>> getAllProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .order('name', ascending: true);

      return response.map<Product>((json) => Product.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al obtener productos', e);
      return [];
    }
  }

  // Obtener productos activos
  Future<List<Product>> getActiveProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('is_active', true)
          .order('name', ascending: true);

      return response.map<Product>((json) => Product.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al obtener productos activos', e);
      return [];
    }
  }

  // Obtener productos con stock bajo
  Future<List<Product>> getLowStockProducts(int threshold) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('is_active', true)
          .lte('stock', threshold)
          .order('stock', ascending: true);

      return response.map<Product>((json) => Product.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al obtener productos con stock bajo', e);
      return [];
    }
  }

  // Buscar productos
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .order('name', ascending: true);

      return response.map<Product>((json) => Product.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al buscar productos', e);
      return [];
    }
  }

  // Crear un nuevo producto
  Future<Product?> createProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .insert(TenantQueryHelper.withTenant(product.toJsonForInsert()))
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al crear producto', e);
      return null;
    }
  }

  // Actualizar un producto existente
  //
  // El payload se arma campo a campo en vez de mandar `toJson()` entero para
  // dejar fuera `stock`: el formulario lo carga al abrirse y lo reenviaba tal
  // cual, así que editar el precio pisaba el stock con un valor viejo y
  // borraba las ventas hechas mientras la pantalla estaba abierta. El stock
  // solo se mueve por deltas, en `ajustarStock`.
  Future<Product?> updateProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .update({
            'name': product.name,
            'description': product.description,
            'category_id': product.categoryId,
            'price': product.price,
            'is_active': product.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', product.id)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al actualizar producto', e);
      return null;
    }
  }

  /// Suma [delta] al stock del producto y devuelve el stock resultante.
  ///
  /// El cálculo lo hace la base en un solo UPDATE (`ajustar_stock_producto`),
  /// no la app: dos cajas leyendo y escribiendo por separado se pisaban.
  ///
  /// El resultado puede ser negativo a propósito — es el faltante, lo vendido
  /// sin existencias. Por eso reponer lo salda solo: -3 + 10 = 7.
  Future<int> ajustarStock(String productId, int delta) async {
    final nuevoStock = await _supabase.rpc('ajustar_stock_producto', params: {
      'p_product_id': productId,
      'p_delta': delta,
    });
    return nuevoStock as int;
  }

  // Eliminar un producto (cambiar a inactivo)
  Future<bool> deactivateProduct(String productId) async {
    try {
      await _supabase.from('products').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', productId);

      return true;
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al desactivar producto', e);
      return false;
    }
  }

  /// Registra el movimiento y mueve el stock, devolviendo el stock resultante.
  ///
  /// Ya no recorta a 0 en las salidas: un stock negativo es información — son
  /// las unidades que salieron sin existencias — y recortarlo las perdía, de
  /// modo que al reponer se contaba de más.
  Future<int?> recordTransaction(ProductTransaction transaction) async {
    try {
      await _supabase.from('product_transactions').insert(
            TenantQueryHelper.withTenant(transaction.toJson()),
          );

      final delta = switch (transaction.type) {
        TransactionType.entrada => transaction.quantity,
        TransactionType.salida || TransactionType.venta => -transaction.quantity,
        // El ajuste fija el stock en un valor concreto, así que necesita saber
        // dónde está para calcular el salto.
        TransactionType.ajuste => transaction.quantity -
            ((await _supabase
                    .from('products')
                    .select('stock')
                    .eq('id', transaction.productId)
                    .single())['stock'] as int),
      };

      return await ajustarStock(transaction.productId, delta);
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al registrar transacción', e);
      return null;
    }
  }

  // Obtener historial de transacciones de un producto
  Future<List<ProductTransaction>> getProductTransactions(
      String productId) async {
    try {
      final response = await _supabase
          .from('product_transactions')
          .select()
          .eq('product_id', productId)
          .order('transaction_date', ascending: false);

      return response
          .map<ProductTransaction>((json) => ProductTransaction.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al obtener transacciones del producto', e);
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════
  // CATEGORÍAS
  //
  // A diferencia del resto del repositorio, estos métodos LANZAN en vez de
  // devolver null: un nombre duplicado o un borrado bloqueado tienen que
  // llegar al usuario como mensaje, no desaparecer en silencio.
  // ══════════════════════════════════════════════════════════

  /// Categorías del gimnasio actual, ordenadas como las colocó el usuario.
  ///
  /// Por defecto devuelve también las inactivas: hacen falta para resolver el
  /// nombre de un producto cuya categoría se desactivó. Usa `activeOnly` para
  /// las listas donde el usuario elige.
  Future<List<ProductCategory>> getAllCategories({bool activeOnly = false}) async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return [];

      var query =
          _supabase.from('product_categories').select().eq('gym_id', gymId);
      if (activeOnly) query = query.eq('is_active', true);

      final response = await query
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      return response
          .map<ProductCategory>((json) => ProductCategory.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al obtener categorías', e);
      return [];
    }
  }

  /// Crea una categoría. Lanza [CategoryException] si el nombre ya existe.
  Future<ProductCategory> createCategory(ProductCategory category) async {
    try {
      final response = await _supabase
          .from('product_categories')
          .insert(TenantQueryHelper.withGym(category.toJsonForInsert()))
          .select()
          .single();

      return ProductCategory.fromJson(response);
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al crear categoría', e);
      throw _mapCategoryError(e);
    }
  }

  /// Actualiza nombre, descripción, icono o estado de una categoría.
  Future<ProductCategory> updateCategory(ProductCategory category) async {
    try {
      final response = await _supabase
          .from('product_categories')
          .update(category.toJsonForUpdate())
          .eq('id', category.id)
          .select()
          .single();

      return ProductCategory.fromJson(response);
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al actualizar categoría', e);
      throw _mapCategoryError(e);
    }
  }

  /// Borrado definitivo. Solo el dueño (política RLS) y solo si no tiene
  /// productos (clave foránea con RESTRICT).
  Future<void> deleteCategory(String categoryId) async {
    try {
      final response = await _supabase
          .from('product_categories')
          .delete()
          .eq('id', categoryId)
          .select();

      // Un borrado bloqueado por RLS no lanza: simplemente no toca ninguna
      // fila. Sin esta comprobación parecería que funcionó.
      if ((response as List).isEmpty) {
        throw const CategoryException(CategoryFailure.notAllowed);
      }
    } on CategoryException {
      rethrow;
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al eliminar categoría', e);
      throw _mapCategoryError(e);
    }
  }

  /// Cuántos productos usa cada categoría, en una sola consulta.
  Future<Map<String, int>> countProductsByCategory() async {
    try {
      final branchId = TenantQueryHelper.branchIdOrNull;
      if (branchId == null) return {};

      final response = await _supabase
          .from('products')
          .select('category_id')
          .eq('branch_id', branchId);

      final counts = <String, int>{};
      for (final row in response) {
        final id = row['category_id'] as String?;
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al contar productos', e);
      return {};
    }
  }

  /// Guarda el nuevo orden de las categorías de una pasada.
  Future<void> reorderCategories(List<String> orderedIds) async {
    try {
      await _supabase.rpc(
        'reorder_product_categories',
        params: {'p_ids': orderedIds},
      );
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al reordenar categorías', e);
      throw _mapCategoryError(e);
    }
  }

  /// Traduce los códigos SQLSTATE de Postgres a un fallo que la UI entiende.
  CategoryException _mapCategoryError(Object e) {
    if (e is PostgrestException) {
      switch (e.code) {
        case '23505': // unique_violation
          return const CategoryException(CategoryFailure.duplicateName);
        case '23503': // foreign_key_violation
          return const CategoryException(CategoryFailure.hasProducts);
        case '42501': // insufficient_privilege
          return const CategoryException(CategoryFailure.notAllowed);
      }
    }
    return const CategoryException(CategoryFailure.unknown);
  }

  // Eliminar producto permanentemente
  Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al eliminar producto', e);
      return false;
    }
  }

  static const Map<String, dynamic> _emptyInventoryStats = {
    'totalProducts': 0,
    'totalStock': 0,
    'totalValue': 0.0,
    'averagePrice': 0.0,
    'lowStockCount': 0,
    'faltanteCount': 0,
  };

  // Estadísticas básicas de inventario
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      final products = await getAllProducts();

      if (products.isEmpty) return _emptyInventoryStats;

      int totalStock = 0;
      double totalValue = 0.0;
      int lowStockCount = 0;
      int faltanteCount = 0;

      for (var product in products) {
        totalStock += product.stock;
        totalValue += (product.price * product.stock);
        // El stock bajo y el faltante se cuentan aparte: antes `stock <= 5`
        // metía en el mismo saco a un producto con 3 unidades y a otro con -3,
        // que necesitan acciones distintas.
        if (product.stock < 0) {
          faltanteCount++;
        } else if (product.stock <= 5) {
          lowStockCount++;
        }
      }

      return {
        'totalProducts': products.length,
        'totalStock': totalStock,
        'totalValue': totalValue,
        'averagePrice': totalStock == 0 ? 0.0 : (totalValue / totalStock),
        'lowStockCount': lowStockCount,
        'faltanteCount': faltanteCount,
      };
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al obtener estadísticas de inventario', e);
      return _emptyInventoryStats;
    }
  }
}

/// Motivos por los que una operación sobre categorías puede fallar.
enum CategoryFailure {
  /// Ya existe una categoría con ese nombre en el gimnasio (ignora
  /// mayúsculas y espacios).
  duplicateName,

  /// La categoría todavía tiene productos asignados.
  hasProducts,

  /// La política RLS lo rechazó: solo el dueño puede borrar categorías.
  notAllowed,

  unknown,
}

class CategoryException implements Exception {
  final CategoryFailure kind;
  const CategoryException(this.kind);

  /// Mensaje listo para mostrar. [categoryName] y [productCount] enriquecen
  /// el texto cuando el llamador los conoce.
  String message({String? categoryName, int? productCount}) {
    switch (kind) {
      case CategoryFailure.duplicateName:
        return 'Ya existe una categoría con ese nombre.';
      case CategoryFailure.hasProducts:
        final nombre = categoryName == null ? 'Esta categoría' : '"$categoryName"';
        final cuantos = productCount == null
            ? 'productos asignados'
            : '$productCount producto${productCount == 1 ? '' : 's'}';
        return 'No puedes eliminar $nombre porque tiene $cuantos. '
            'Cámbialos de categoría o desactívala.';
      case CategoryFailure.notAllowed:
        return 'Solo el dueño puede eliminar categorías.';
      case CategoryFailure.unknown:
        return 'No se pudo completar la operación. Intenta de nuevo.';
    }
  }

  @override
  String toString() => 'CategoryException($kind)';
}

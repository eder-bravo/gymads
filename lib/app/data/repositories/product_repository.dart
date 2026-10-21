import 'dart:async';

import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/fallo_al_guardar.dart';
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

  /// Crea el producto. Si no se puede, lanza el motivo:
  /// [BarcodeDuplicadoException], [GuardadoFallido] (nombre repetido) o el
  /// error de conexión / [TimeoutException]. Antes devolvía null y la pantalla
  /// no decía nada: parecía que el botón no funcionaba.
  ///
  /// Idempotente: el id lo pone la app, una vez por formulario. Si un intento
  /// anterior sí se guardó pero la respuesta no llegó (mala señal), el
  /// reintento choca con su propio id y se devuelve ese producto.
  Future<Product> createProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .insert(TenantQueryHelper.withTenant(product.toJsonForInsert()))
          .select()
          .single()
          .timeout(limiteAlGuardar);

      return Product.fromJson(response);
    } catch (e) {
      final indice = restriccionUnicaViolada(e);
      if (indice != null) {
        // Cualquier repetido puede ser el propio producto de un intento
        // anterior (Postgres puede acusar al nombre antes que al id).
        final yaGuardado = await _productoPorId(product.id);
        if (yaGuardado != null) return yaGuardado;
        _lanzarRepetido(indice);
      }
      AppLogger.error('ProductRepository', 'Error al crear producto', e);
      rethrow;
    }
  }

  // Actualizar un producto existente
  //
  // El payload se arma campo a campo en vez de mandar `toJson()` entero para
  // dejar fuera `stock`: el formulario lo carga al abrirse y lo reenviaba tal
  // cual, así que editar el precio pisaba el stock con un valor viejo y
  // borraba las ventas hechas mientras la pantalla estaba abierta. El stock
  // solo se mueve por deltas, en `ajustarStock`.
  //
  // Si no se puede, lanza el motivo, igual que [createProduct].
  Future<Product> updateProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .update({
            'name': product.name,
            'price': product.price,
            'is_active': product.isActive,
            'barcode': product.barcode,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', product.id)
          .select()
          .single()
          .timeout(limiteAlGuardar);

      return Product.fromJson(response);
    } catch (e) {
      final indice = restriccionUnicaViolada(e);
      if (indice != null) _lanzarRepetido(indice);
      AppLogger.error('ProductRepository', 'Error al actualizar producto', e);
      rethrow;
    }
  }

  /// El motivo, según el índice único que se violó.
  Never _lanzarRepetido(String indice) {
    if (indice == 'idx_products_branch_barcode') {
      AppLogger.warning(
          'ProductRepository', 'El código de barras ya está en uso');
      throw const BarcodeDuplicadoException();
    }
    if (indice == 'idx_products_branch_name') {
      throw const GuardadoFallido(
          'Ya hay un producto con ese nombre. Revisa también los productos '
          'desactivados.');
    }
    throw const GuardadoFallido('Ese producto ya existe.');
  }

  Future<Product?> _productoPorId(String id) async {
    try {
      final fila = await _supabase
          .from('products')
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(limiteAlGuardar);
      return fila == null ? null : Product.fromJson(fila);
    } catch (_) {
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
      // Sale tal cual: en pantalla se dice si fue la conexión.
      rethrow;
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
      // Sale tal cual: en pantalla se dice si fue la conexión.
      rethrow;
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

  // Eliminar producto permanentemente
  Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      AppLogger.error('ProductRepository', 'Error al eliminar producto', e);
      // Sale tal cual: en pantalla se dice si fue la conexión.
      rethrow;
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

/// El código de barras que se intentó guardar ya pertenece a otro producto
/// de esta sucursal.
///
/// Tiene su propio tipo para poder decírselo al usuario con esas palabras:
/// un 23505 de Postgres en crudo no le dice nada a quien está dando de alta
/// una bebida en el mostrador.
class BarcodeDuplicadoException implements Exception {
  const BarcodeDuplicadoException();

  String get mensaje =>
      'Ese código de barras ya está asignado a otro producto.';

  @override
  String toString() => 'BarcodeDuplicadoException';
}

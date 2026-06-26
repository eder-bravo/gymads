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
      print('Error al obtener productos: $e');
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
      print('Error al obtener productos activos: $e');
      return [];
    }
  }

  // Obtener productos por categoría
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('category', category)
          .eq('is_active', true)
          .order('name', ascending: true);

      return response.map<Product>((json) => Product.fromJson(json)).toList();
    } catch (e) {
      print('Error al obtener productos por categoría: $e');
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
      print('Error al obtener productos con stock bajo: $e');
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
      print('Error al buscar productos: $e');
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
      print('Error al crear producto: $e');
      return null;
    }
  }

  // Actualizar un producto existente
  Future<Product?> updateProduct(Product product) async {
    try {
      final response = await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      print('Error al actualizar producto: $e');
      return null;
    }
  }

  // Actualizar stock de un producto
  Future<bool> updateProductStock(String productId, int newStock) async {
    try {
      await _supabase.from('products').update({
        'stock': newStock,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', productId);

      return true;
    } catch (e) {
      print('Error al actualizar stock: $e');
      return false;
    }
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
      print('Error al desactivar producto: $e');
      return false;
    }
  }

  // Registrar una transacción de producto
  Future<bool> recordTransaction(ProductTransaction transaction) async {
    try {
      await _supabase.from('product_transactions').insert(
            TenantQueryHelper.withTenant(transaction.toJson()),
          );

      // Actualizar el stock del producto según el tipo de transacción
      final product = await _supabase
          .from('products')
          .select('stock')
          .eq('id', transaction.productId)
          .single();

      int currentStock = product['stock'];
      int newStock = currentStock;

      switch (transaction.type) {
        case TransactionType.entrada:
          newStock = currentStock + transaction.quantity;
          break;
        case TransactionType.salida:
        case TransactionType.venta:
          newStock = currentStock - transaction.quantity;
          if (newStock < 0) newStock = 0;
          break;
        case TransactionType.ajuste:
          newStock = transaction.quantity; // Ajuste directo
          break;
      }

      await updateProductStock(transaction.productId, newStock);

      return true;
    } catch (e) {
      print('Error al registrar transacción: $e');
      return false;
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
      print('Error al obtener transacciones del producto: $e');
      return [];
    }
  }

  // Obtener todas las categorías de productos
  Future<List<ProductCategory>> getAllCategories() async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull ?? '';
      print('🔵 [Repo] Querying categories for gym_id: "$gymId"');
      final response = await _supabase
          .from('product_categories')
          .select()
          .eq('gym_id', gymId)
          .eq('is_active', true)
          .order('name', ascending: true);

      print('🔵 [Repo] Got ${response.length} categories from DB');
      return response
          .map<ProductCategory>((json) => ProductCategory.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error al obtener categorías: $e');
      return [];
    }
  }

  // Crear una nueva categoría
  Future<ProductCategory?> createCategory(ProductCategory category) async {
    try {
      final response = await _supabase
          .from('product_categories')
          .insert(TenantQueryHelper.withGym(category.toJson()))
          .select()
          .single();

      return ProductCategory.fromJson(response);
    } catch (e) {
      print('Error al crear categoría: $e');
      return null;
    }
  }

  // Eliminar producto permanentemente
  Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      print('Error al eliminar producto: $e');
      return false;
    }
  }

  // Estadísticas básicas de inventario
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      final products = await getAllProducts();

      if (products.isEmpty) {
        return {
          'totalProducts': 0,
          'totalStock': 0,
          'totalValue': 0.0,
          'averagePrice': 0.0,
          'lowStockCount': 0,
        };
      }

      int totalStock = 0;
      double totalValue = 0.0;
      int lowStockCount = 0;

      for (var product in products) {
        totalStock += product.stock;
        totalValue += (product.price * product.stock);
        if (product.stock <= 5) lowStockCount++;
      }

      return {
        'totalProducts': products.length,
        'totalStock': totalStock,
        'totalValue': totalValue,
        'averagePrice': products.isEmpty ? 0.0 : (totalValue / totalStock),
        'lowStockCount': lowStockCount,
      };
    } catch (e) {
      print('Error al obtener estadísticas de inventario: $e');
      return {
        'totalProducts': 0,
        'totalStock': 0,
        'totalValue': 0.0,
        'averagePrice': 0.0,
        'lowStockCount': 0,
      };
    }
  }
}

import 'package:flutter/foundation.dart';
import '../models/sale_model.dart';
import '../services/supabase_service.dart';
import '../services/tenant_query_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SaleRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Crear una nueva venta
  /// La venta se registra en la tabla 'ingresos' y las transacciones de productos se actualizan
  Future<Sale?> createSale(Sale sale) async {
    try {
      // Iniciar transacción
      final response = await _supabase
          .from('ingresos')
          .insert(TenantQueryHelper.withTenant(sale.toJson()))
          .select()
          .single();

      final createdSale = Sale.fromJson(response);

      // Registrar transacciones de productos para cada item vendido
      for (final item in sale.items) {
        await _registerProductTransaction(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          staffUser: sale.usuarioStaff,
        );

        // Actualizar stock del producto
        await _updateProductStock(item.productId, -item.quantity);
      }

      return createdSale;
    } catch (e) {
      if (kDebugMode) {
        print('Error al crear venta: $e');
      }
      return null;
    }
  }

  /// Obtener todas las ventas de productos
  Future<List<Sale>> getAllSales() async {
    try {
      final response = await _supabase
          .from('ingresos')
          .select()
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('venta_tipo', 'producto')
          .order('fecha', ascending: false);

      return response.map<Sale>((json) => Sale.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener ventas: $e');
      }
      return [];
    }
  }

  /// Obtener ventas por rango de fechas
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    try {
      final response = await _supabase
          .from('ingresos')
          .select()
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('venta_tipo', 'producto')
          .gte('fecha', start.toIso8601String())
          .lte('fecha', end.toIso8601String())
          .order('fecha', ascending: false);

      return response.map<Sale>((json) => Sale.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener ventas por fecha: $e');
      }
      return [];
    }
  }

  /// Obtener ventas del día actual
  Future<List<Sale>> getTodaySales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getSalesByDateRange(startOfDay, endOfDay);
  }

  /// Obtener estadísticas de ventas
  Future<Map<String, dynamic>> getSalesStats() async {
    try {
      // Ventas de hoy
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final todaySalesResponse = await _supabase
          .from('ingresos')
          .select('monto_final')
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('venta_tipo', 'producto')
          .gte('fecha', startOfDay.toIso8601String())
          .lte('fecha', endOfDay.toIso8601String());

      double todayTotal = 0;
      int todayCount = todaySalesResponse.length;

      for (final sale in todaySalesResponse) {
        todayTotal += (sale['monto_final'] ?? 0).toDouble();
      }

      // Ventas del mes
      final startOfMonth = DateTime(today.year, today.month, 1);
      final endOfMonth = DateTime(today.year, today.month + 1, 0, 23, 59, 59);

      final monthSalesResponse = await _supabase
          .from('ingresos')
          .select('monto_final')
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('venta_tipo', 'producto')
          .gte('fecha', startOfMonth.toIso8601String())
          .lte('fecha', endOfMonth.toIso8601String());

      double monthTotal = 0;
      int monthCount = monthSalesResponse.length;

      for (final sale in monthSalesResponse) {
        monthTotal += (sale['monto_final'] ?? 0).toDouble();
      }

      return {
        'today_total': todayTotal,
        'today_count': todayCount,
        'month_total': monthTotal,
        'month_count': monthCount,
        'average_sale': todayCount > 0 ? todayTotal / todayCount : 0,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener estadísticas de ventas: $e');
      }
      return {
        'today_total': 0.0,
        'today_count': 0,
        'month_total': 0.0,
        'month_count': 0,
        'average_sale': 0.0,
      };
    }
  }

  /// Registrar transacción de producto (salida por venta)
  Future<void> _registerProductTransaction({
    required String productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    required String staffUser,
  }) async {
    try {
      await _supabase.from('product_transactions').insert(
            TenantQueryHelper.withTenant({
              'product_id': productId,
              'product_name': productName,
              'type': 'salida',
              'quantity': quantity,
              'unit_price': unitPrice,
              'staff_user': staffUser,
              'notes': 'Venta de producto',
            }),
          );
    } catch (e) {
      if (kDebugMode) {
        print('Error al registrar transacción de producto: $e');
      }
    }
  }

  /// Actualizar stock de producto
  Future<void> _updateProductStock(String productId, int quantityChange) async {
    try {
      // Obtener stock actual
      final productResponse = await _supabase
          .from('products')
          .select('stock')
          .eq('id', productId)
          .single();

      final currentStock = productResponse['stock'] ?? 0;
      final newStock = currentStock + quantityChange;

      // Actualizar stock
      await _supabase
          .from('products')
          .update({'stock': newStock}).eq('id', productId);
    } catch (e) {
      if (kDebugMode) {
        print('Error al actualizar stock: $e');
      }
    }
  }

  /// Obtener productos más vendidos
  Future<List<Map<String, dynamic>>> getTopSellingProducts(
      {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('product_transactions')
          .select('product_id, product_name, quantity')
          .eq('branch_id', TenantQueryHelper.branchIdOrNull ?? '')
          .eq('type', 'salida')
          .order('transaction_date', ascending: false);

      // Agrupar por producto y sumar cantidades
      Map<String, Map<String, dynamic>> productSales = {};

      for (final transaction in response) {
        final productId = transaction['product_id'];
        final productName = transaction['product_name'];
        final quantity = transaction['quantity'] ?? 0;

        if (productSales.containsKey(productId)) {
          productSales[productId]!['total_sold'] += quantity;
        } else {
          productSales[productId] = {
            'product_id': productId,
            'product_name': productName,
            'total_sold': quantity,
          };
        }
      }

      // Convertir a lista y ordenar por cantidad vendida
      final sortedProducts = productSales.values.toList();
      sortedProducts.sort((a, b) => b['total_sold'].compareTo(a['total_sold']));

      return sortedProducts.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener productos más vendidos: $e');
      }
      return [];
    }
  }
}

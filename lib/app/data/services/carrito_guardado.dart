import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../models/sale_model.dart';
import 'tenant_context_service.dart';

/// Borrador local de la venta, separado por gimnasio, sucursal y usuario.
/// La cola también cubre salir y volver antes de que termine una escritura.
class CarritoGuardado {
  CarritoGuardado({
    required String gymId,
    required String userId,
    String? branchId,
  }) : _clave = 'pos_cart_${jsonEncode([gymId, branchId, userId])}';

  final String _clave;
  static Future<void> _escrituras = Future<void>.value();

  static CarritoGuardado? deSesionActual() {
    if (!Get.isRegistered<TenantContextService>()) return null;
    final perfil = TenantContextService.to.staffProfileRx.value;
    if (perfil == null) return null;
    return CarritoGuardado(
      gymId: perfil.gymId,
      userId: perfil.userId,
      branchId: perfil.branchId,
    );
  }

  Future<({List<SaleItem> items, double descuento, double impuesto})?>
      leer() async {
    await _escrituras;
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_clave);
      if (texto == null) return null;
      final datos = jsonDecode(texto) as Map<String, dynamic>;
      final items = (datos['items'] as List)
          .map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
          .toList();
      final descuento = (datos['descuento'] as num).toDouble();
      final impuesto = (datos['impuesto'] as num).toDouble();
      if (!descuento.isFinite ||
          descuento < 0 ||
          !impuesto.isFinite ||
          impuesto < 0 ||
          items.any((item) =>
              item.productId.isEmpty ||
              item.quantity <= 0 ||
              !item.unitPrice.isFinite ||
              item.unitPrice < 0)) {
        throw const FormatException('Carrito inválido');
      }
      return (
        items: items
            .map((item) => item.copyWith(quantity: item.quantity))
            .toList(),
        descuento: descuento,
        impuesto: impuesto,
      );
    } catch (e) {
      AppLogger.error('CarritoGuardado', 'No se pudo recuperar el carrito', e);
      return null;
    }
  }

  Future<void> guardar(
    List<SaleItem> items, {
    required double descuento,
    required double impuesto,
  }) {
    // Captura el borrador ahora: el controlador puede cerrarse o cambiar luego.
    final texto = items.isEmpty
        ? null
        : jsonEncode({
            'items': items.map((item) => item.toJson()).toList(),
            'descuento': descuento,
            'impuesto': impuesto,
          });
    return _escrituras = _escrituras.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final guardado = texto == null
          ? await prefs.remove(_clave)
          : await prefs.setString(_clave, texto);
      if (!guardado) throw StateError('No se pudo escribir el carrito');
    }).catchError((Object e) {
      AppLogger.error('CarritoGuardado', 'No se pudo guardar el carrito', e);
    });
  }
}

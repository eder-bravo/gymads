import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/services/supabase_service.dart';
import 'package:gymads/app/data/services/tenant_query_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio de precios fijos de abono. Viven como columnas de la tabla
/// gym-level `gyms`, junto al branding, así que comparten sus políticas RLS.
class AbonoPricesRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  // ─── Últimos precios conocidos ───
  //
  // Abonar los muestra desde el primer cuadro ("Cobrar visita · $50.00") en
  // vez de esperar la consulta: antes el botón aparecía sin precio y un
  // instante después con él. Se guardan en memoria y en el equipo (por
  // gimnasio), y cada consulta los actualiza.

  static final Map<String, AbonoPricesModel> _enMemoria = {};

  static String _clave(String gymId) => 'precios_abono_$gymId';

  /// Los últimos precios conocidos del gimnasio actual, o null si nunca se
  /// han consultado en este equipo.
  static AbonoPricesModel? get enCache {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return null;
      final memoria = _enMemoria[gymId];
      if (memoria != null) return memoria;
      final guardado = GetStorage().read<Map>(_clave(gymId));
      if (guardado == null) return null;
      return _enMemoria[gymId] =
          AbonoPricesModel.fromJson(Map<String, dynamic>.from(guardado));
    } catch (_) {
      return null;
    }
  }

  static void _recordar(String gymId, AbonoPricesModel precios) {
    _enMemoria[gymId] = precios;
    try {
      GetStorage().write(_clave(gymId), {
        ...precios.toJson(),
        'payment_mode': precios.paymentMode,
      });
    } catch (_) {
      // Sin almacenamiento (pruebas): queda en memoria.
    }
  }

  @visibleForTesting
  static void recordarParaPruebas(String gymId, AbonoPricesModel precios) =>
      _recordar(gymId, precios);

  @visibleForTesting
  static void olvidarParaPruebas() => _enMemoria.clear();

  /// Pide los precios por adelantado (al llegar a Inicio), para que Abonar
  /// abra ya con ellos. Silencioso: un error solo deja la caché como estaba.
  static Future<void> precargar() async {
    try {
      await AbonoPricesRepository().getPrices();
    } catch (_) {}
  }

  static const _columns =
      'price_day, price_week, price_month, price_year, payment_mode';

  /// Precios del gimnasio actual. Devuelve un modelo vacío si no hay contexto
  /// de gimnasio o si falla la consulta.
  Future<AbonoPricesModel> getPrices() async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return const AbonoPricesModel();

      final response = await _supabase
          .from('gyms')
          .select(_columns)
          .eq('id', gymId)
          .maybeSingle();

      final precios = response == null
          ? const AbonoPricesModel()
          : AbonoPricesModel.fromJson(response);
      _recordar(gymId, precios);
      return precios;
    } catch (e) {
      AppLogger.error(
          'AbonoPricesRepository', 'Error al obtener precios de abono', e);
      return const AbonoPricesModel();
    }
  }

  /// Guarda los cuatro precios (null borra el precio de ese periodo).
  Future<bool> savePrices(AbonoPricesModel prices) async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return false;

      await _supabase.from('gyms').update(prices.toJson()).eq('id', gymId);
      // El modo de cobro no viaja en este guardado: se conserva el conocido.
      _recordar(
          gymId,
          AbonoPricesModel(
            priceDay: prices.priceDay,
            priceWeek: prices.priceWeek,
            priceMonth: prices.priceMonth,
            priceYear: prices.priceYear,
            paymentMode: _enMemoria[gymId]?.paymentMode ?? prices.paymentMode,
          ));
      return true;
    } catch (e) {
      AppLogger.error(
          'AbonoPricesRepository', 'Error al guardar precios de abono', e);
      return false;
    }
  }

  /// Guarda el modo de cobro del gimnasio ('fijo' | 'libre') sin tocar los
  /// precios. Solo `owner_admin` puede escribirlo (política RLS de `gyms`).
  Future<bool> savePaymentMode(String mode) async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return false;

      await _supabase
          .from('gyms')
          .update({'payment_mode': mode}).eq('id', gymId);
      return true;
    } catch (e) {
      AppLogger.error(
          'AbonoPricesRepository', 'Error al guardar el modo de cobro', e);
      return false;
    }
  }
}

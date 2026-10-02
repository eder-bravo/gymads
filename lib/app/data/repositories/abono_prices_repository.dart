import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/services/supabase_service.dart';
import 'package:gymads/app/data/services/tenant_query_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio de precios fijos de abono. Viven como columnas de la tabla
/// gym-level `gyms`, junto al branding, así que comparten sus políticas RLS.
class AbonoPricesRepository {
  final SupabaseClient _supabase = SupabaseService.client;

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

      if (response == null) return const AbonoPricesModel();
      return AbonoPricesModel.fromJson(response);
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

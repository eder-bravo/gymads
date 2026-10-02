import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/models/gym_settings_model.dart';
import 'package:gymads/app/data/services/supabase_service.dart';
import 'package:gymads/app/data/services/tenant_query_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de accesos del gimnasio.
///
/// Repositorio aparte de [AbonoPricesRepository] a propósito, aunque escriban
/// en la misma tabla: aquel omite `payment_mode` en su `toJson()` para no
/// borrarlo sin querer, y meter aquí más columnas multiplicaría esa trampa.
class GymSettingsRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  static const _columns = 'registrar_salidas, hora_apertura, hora_cierre';

  /// Configuración del gimnasio actual. Devuelve los valores por defecto si
  /// no hay contexto o si la consulta falla, para que el control de accesos
  /// siga funcionando en su modo conservador (solo entradas).
  Future<GymSettingsModel> getSettings() async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return const GymSettingsModel();

      final response = await _supabase
          .from('gyms')
          .select(_columns)
          .eq('id', gymId)
          .maybeSingle();

      if (response == null) return const GymSettingsModel();
      return GymSettingsModel.fromJson(response);
    } catch (e) {
      AppLogger.error(
          'GymSettingsRepository', 'Error al obtener la configuración', e);
      return const GymSettingsModel();
    }
  }

  Future<bool> saveSettings(GymSettingsModel settings) async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return false;

      await _supabase.from('gyms').update(settings.toJson()).eq('id', gymId);
      return true;
    } catch (e) {
      AppLogger.error(
          'GymSettingsRepository', 'Error al guardar la configuración', e);
      return false;
    }
  }
}

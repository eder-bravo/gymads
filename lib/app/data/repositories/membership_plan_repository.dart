import 'package:gymads/app/data/models/membership_plan_model.dart';
import 'package:gymads/app/data/services/supabase_service.dart';
import 'package:gymads/app/data/services/tenant_query_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio de planes de abono fijo (tabla gym-level `membership_plans`).
class MembershipPlanRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Obtiene los planes activos del gimnasio, ordenados por precio.
  Future<List<MembershipPlanModel>> getPlans() async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull ?? '';
      final response = await _supabase
          .from('membership_plans')
          .select()
          .eq('gym_id', gymId)
          .eq('is_active', true)
          .order('price', ascending: true);

      return response
          .map<MembershipPlanModel>(
              (json) => MembershipPlanModel.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error al obtener planes de abono: $e');
      return [];
    }
  }

  /// Crea un nuevo plan (el gym_id lo inyecta withGym + trigger).
  Future<MembershipPlanModel?> createPlan(MembershipPlanModel plan) async {
    try {
      final response = await _supabase
          .from('membership_plans')
          .insert(TenantQueryHelper.withGym(plan.toJsonForInsert()))
          .select()
          .single();

      return MembershipPlanModel.fromJson(response);
    } catch (e) {
      print('❌ Error al crear plan de abono: $e');
      return null;
    }
  }

  /// Actualiza un plan existente.
  Future<MembershipPlanModel?> updatePlan(MembershipPlanModel plan) async {
    try {
      final response = await _supabase
          .from('membership_plans')
          .update(plan.toJsonForInsert())
          .eq('id', plan.id)
          .select()
          .single();

      return MembershipPlanModel.fromJson(response);
    } catch (e) {
      print('❌ Error al actualizar plan de abono: $e');
      return null;
    }
  }

  /// Elimina un plan permanentemente.
  Future<bool> deletePlan(String planId) async {
    try {
      await _supabase.from('membership_plans').delete().eq('id', planId);
      return true;
    } catch (e) {
      print('❌ Error al eliminar plan de abono: $e');
      return false;
    }
  }
}

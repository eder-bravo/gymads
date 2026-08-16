import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import '../models/staff_profile_model.dart';

/// Provider for fetching staff profiles from Supabase
class StaffProfileProvider {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get staff profile by auth user ID
  ///
  /// This is called after login to fetch the staff profile
  /// and determine which gym/branch the user belongs to.
  Future<StaffProfileModel?> getByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('staff_profiles')
          .select('*, gyms(name, brand_color, brand_font, created_at)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        AppLogger.warning('StaffProfileProvider', 'No staff_profile found for user');
        return null;
      }

      return StaffProfileModel.fromJson(response);
    } catch (e) {
      AppLogger.error('StaffProfileProvider', 'Error fetching staff profile', e);
      return null;
    }
  }

  /// Get staff profile by ID
  Future<StaffProfileModel?> getById(String id) async {
    try {
      final response = await _supabase
          .from('staff_profiles')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return StaffProfileModel.fromJson(response);
    } catch (e) {
      AppLogger.error('StaffProfileProvider', 'Error fetching staff profile by ID', e);
      return null;
    }
  }

  /// Get all staff profiles for a branch
  Future<List<StaffProfileModel>> getByBranch(String branchId) async {
    try {
      final response = await _supabase
          .from('staff_profiles')
          .select('*')
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => StaffProfileModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('StaffProfileProvider', 'Error fetching staff profiles by branch', e);
      return [];
    }
  }

  /// Create a new staff profile
  /// Note: This should only be done by owner_admin
  Future<StaffProfileModel?> create({
    required String userId,
    required String gymId,
    required String branchId,
    required String role,
    String? displayName,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'gym_id': gymId,
        'branch_id': branchId,
        'role': role,
        'display_name': displayName,
        'is_active': true,
      };

      final response =
          await _supabase.from('staff_profiles').insert(data).select().single();

      return StaffProfileModel.fromJson(response);
    } catch (e) {
      AppLogger.error('StaffProfileProvider', 'Error creating staff profile', e);
      return null;
    }
  }

  /// Update staff profile
  Future<bool> update(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('staff_profiles').update(updates).eq('id', id);
      return true;
    } catch (e) {
      AppLogger.error('StaffProfileProvider', 'Error updating staff profile', e);
      return false;
    }
  }

  /// Deactivate staff profile (soft delete)
  Future<bool> deactivate(String id) async {
    return update(id, {'is_active': false});
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'tenant_context_service.dart';

/// Helper class to add tenant filtering to Supabase queries
///
/// This helper ensures all queries are properly scoped to the
/// current user's gym/branch, preventing cross-tenant data access.
class TenantQueryHelper {
  /// Adds branch_id filter to a query (most common case)
  ///
  /// Use this for tables that are isolated per branch:
  /// users, ingresos, access_logs, products, product_transactions, payments
  static PostgrestFilterBuilder<T> byBranch<T>(
    PostgrestFilterBuilder<T> query,
  ) {
    final branchId = TenantContextService.to.currentBranchId;
    if (branchId == null) {
      throw StateError('No branch context - user not authenticated');
    }
    return query.eq('branch_id', branchId);
  }

  /// Adds gym_id filter to a query (for gym-level data)
  ///
  /// Use this for tables that are shared across branches:
  /// membership_types, product_categories
  static PostgrestFilterBuilder<T> byGym<T>(
    PostgrestFilterBuilder<T> query,
  ) {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) {
      throw StateError('No gym context - user not authenticated');
    }
    return query.eq('gym_id', gymId);
  }

  /// Returns tenant data map for insert operations
  ///
  /// Even though triggers auto-set these values, it's good practice
  /// to include them in the payload for clarity.
  static Map<String, dynamic> get tenantData => {
        'gym_id': TenantContextService.to.currentGymId,
        'branch_id': TenantContextService.to.currentBranchId,
      };

  /// Returns only gym_id for gym-level tables
  static Map<String, dynamic> get gymData => {
        'gym_id': TenantContextService.to.currentGymId,
      };

  /// Adds tenant data to an insert payload
  ///
  /// Usage:
  /// ```dart
  /// final data = TenantQueryHelper.withTenant({
  ///   'name': 'John Doe',
  ///   'phone': '123456789',
  /// });
  /// await supabase.from('users').insert(data);
  /// ```
  static Map<String, dynamic> withTenant(Map<String, dynamic> data) {
    return {...data, ...tenantData};
  }

  /// Adds gym_id to an insert payload (for gym-level tables)
  static Map<String, dynamic> withGym(Map<String, dynamic> data) {
    return {...data, ...gymData};
  }

  /// Validate that tenant context is available
  ///
  /// Throws StateError if user is not authenticated
  static void requireTenantContext() {
    if (TenantContextService.to.currentBranchId == null) {
      throw StateError('No tenant context - user not authenticated');
    }
  }

  /// Safely get current branch ID or null
  static String? get branchIdOrNull => TenantContextService.to.currentBranchId;

  /// Safely get current gym ID or null
  static String? get gymIdOrNull => TenantContextService.to.currentGymId;
}

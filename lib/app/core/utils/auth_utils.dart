import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUtils {
  static final _supabase = Supabase.instance.client;

  /// Obtiene el email del usuario autenticado actual
  static String? getCurrentUserEmail() {
    final user = _supabase.auth.currentUser;
    return user?.email;
  }

  /// Obtiene el ID del usuario autenticado actual
  static String? getCurrentUserId() {
    final user = _supabase.auth.currentUser;
    return user?.id;
  }

  /// Obtiene el nombre del usuario autenticado actual desde los metadatos
  static String? getCurrentUserName() {
    final user = _supabase.auth.currentUser;
    if (user?.userMetadata != null) {
      return user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
    }
    return user?.email?.split('@').first; // Fallback al email sin dominio
  }

  /// Verifica si hay un usuario autenticado
  static bool isAuthenticated() {
    return _supabase.auth.currentUser != null;
  }

  /// Obtiene la información completa del usuario actual
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Obtiene un identificador del staff actual (nombre o email)
  ///
  /// El empleado que entra con código tiene una sesión anónima: sin email y
  /// sin metadatos. Su nombre solo vive en el perfil, así que hay que mirarlo
  /// ahí antes de rendirse; si no, todo lo que registra queda como 'unknown'.
  static String getStaffIdentifier() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      AppLogger.warning('AuthUtils', 'No hay usuario autenticado');
      return 'unknown';
    }

    // Priorizar nombre completo, luego email
    final name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
    if (name != null && name.toString().isNotEmpty) {
      return name.toString();
    }

    if (user.email != null && user.email!.isNotEmpty) return user.email!;

    // Sesión anónima: el nombre está en el perfil del staff.
    if (Get.isRegistered<TenantContextService>()) {
      final displayName = TenantContextService.to.displayName;
      if (displayName != null && displayName.isNotEmpty) return displayName;
    }

    return 'unknown';
  }
}

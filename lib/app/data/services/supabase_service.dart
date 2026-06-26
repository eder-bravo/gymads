import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../providers/supabase/supabase_storage_provider.dart';

/// Servicio para gestionar las interacciones con Supabase
///
/// Este servicio proporciona métodos para:
/// - Verificar la conexión a la base de datos
/// - Proporcionar acceso al cliente de Supabase
/// - Métodos legacy de storage (en desuso)
class SupabaseService {
  /// Cliente de Supabase para operaciones personalizadas
  static SupabaseClient get client => Supabase.instance.client;

  /// Método para verificar la conexión a la base de datos Supabase
  ///
  /// Realiza comprobaciones básicas para confirmar que la conexión funciona
  /// y que la tabla 'users' es accesible
  static Future<void> testDatabaseConnection() async {
    try {
      // Verificar sesión actual
      final session = await client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        throw Exception('No hay sesión activa');
      }

      if (kDebugMode && SupabaseConfig.debugMode) {
        print('✅ Sesión activa: ${session.user.email}');
      }

      // Verificar acceso a la tabla users
      await client.from('users').select('count').limit(1).maybeSingle();

      if (kDebugMode && SupabaseConfig.debugMode) {
        print('✅ Conexión a la base de datos verificada');
      }
    } catch (e) {
      if (kDebugMode && SupabaseConfig.debugMode) {
        print('❌ Error al verificar la conexión: $e');

        if (e is PostgrestException) {
          print('  - Código: ${e.code}');
          print('  - Detalles: ${e.details}');
        }
      }
      rethrow;
    }
  }

  /// NOTA: Estos métodos se mantienen para compatibilidad durante la transición
  /// Deberían eliminarse después de migrar todas las llamadas a los nuevos proveedores

  /// Sube la foto de un usuario al bucket de Supabase (OBSOLETO)
  /// @deprecated Usar SupabaseStorageProvider.uploadUserPhoto en su lugar
  static Future<String?> uploadUserPhoto(String filePath, String userId) async {
    try {
      final File file = File(filePath);
      final provider = SupabaseStorageProvider();
      return await provider.uploadUserPhoto(file, userId);
    } catch (e) {
      if (kDebugMode) print('❌ Error en uploadUserPhoto (método obsoleto): $e');
      return null;
    }
  }

  /// Elimina una foto de usuario del bucket de Supabase (OBSOLETO)
  /// @deprecated Usar SupabaseStorageProvider.deleteUserPhoto en su lugar
  static Future<bool> deleteUserPhoto(String photoUrl) async {
    try {
      final provider = SupabaseStorageProvider();
      return await provider.deleteUserPhoto(photoUrl);
    } catch (e) {
      if (kDebugMode) print('❌ Error en deleteUserPhoto (método obsoleto): $e');
      return false;
    }
  }
}

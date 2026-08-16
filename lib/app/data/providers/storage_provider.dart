import 'dart:io';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'supabase/supabase_storage_provider.dart';

/// Proveedor abstracto para operaciones de almacenamiento
/// 
/// Esta clase actúa como intermediario entre el repositorio y el servicio específico,
/// permitiendo cambiar fácilmente la implementación (Supabase, Firebase, etc.)
class StorageProvider {
  final SupabaseStorageProvider _provider = SupabaseStorageProvider();

  /// Sube una foto de usuario al almacenamiento
  /// 
  /// @param photoFile Archivo de imagen a subir
  /// @param userId ID del usuario para identificar la foto
  /// @return URL pública de la foto o null si hubo error
  Future<String?> uploadUserPhoto(File photoFile, String userId) async {
    try {
      AppLogger.info('StorageProvider', 'Iniciando proceso de subida de foto desde StorageProvider');
      
      return await _provider.uploadUserPhoto(photoFile, userId);
    } catch (e) {
      AppLogger.error('StorageProvider', 'Error en StorageProvider.uploadUserPhoto', e);
      return null;
    }
  }

  /// Elimina una foto de usuario del almacenamiento
  /// 
  /// @param photoUrl URL completa de la foto a eliminar
  /// @return true si la eliminación fue exitosa, false en caso contrario
  Future<bool> deleteUserPhoto(String photoUrl) async {
    try {
      return await _provider.deleteUserPhoto(photoUrl);
    } catch (e) {
      AppLogger.error('StorageProvider', 'Error al eliminar la foto', e);
      return false;
    }
  }
}

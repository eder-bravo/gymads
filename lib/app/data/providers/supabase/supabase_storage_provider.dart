import 'dart:io';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/supabase_service.dart';
import '../../../core/services/image_compression_service.dart';

/// Proveedor para operaciones de almacenamiento de archivos en Supabase
/// 
/// Esta clase se encarga de:
/// - Subir archivos al bucket de Supabase
/// - Eliminar archivos del bucket de Supabase
/// - Generar URLs públicas para los archivos
class SupabaseStorageProvider {
  /// Sube un archivo al bucket de Supabase
  /// 
  /// @param file Archivo a subir
  /// @param path Ruta donde se guardará el archivo (sin nombre de archivo)
  /// @param fileName Nombre del archivo (si es null, se usará el nombre original)
  /// @return URL pública del archivo o null si hubo error
  Future<String?> uploadFile(File file, String path, {String? fileName}) async {
    try {
      if (!await file.exists()) {
        if (kDebugMode && SupabaseConfig.debugMode) {
          AppLogger.error('SupabaseStorageProvider', 'El archivo no existe');
        }
        return null;
      }
      
      // Generar nombre único si no se proporciona
      final name = fileName ?? '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      // Construir ruta completa (asegurar que termina con /)
      final fullPath = path.endsWith('/') ? '$path$name' : '$path/$name';
      
      // Leer archivo como bytes
      final bytes = await file.readAsBytes();
      
      // Subir archivo
      await SupabaseService.client.storage.from(SupabaseConfig.bucketName).uploadBinary(
        fullPath,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      
      if (kDebugMode && SupabaseConfig.debugMode) {
        AppLogger.info('SupabaseStorageProvider', 'Archivo subido correctamente');
      }
      
      // Generar URL pública
      final publicUrl = '${SupabaseConfig.storageUrl}/${SupabaseConfig.bucketName}/$fullPath';
      return publicUrl;
    } catch (e) {
      if (kDebugMode && SupabaseConfig.debugMode) {
        AppLogger.error('SupabaseStorageProvider', 'Error al subir archivo', e);
      }
      return null;
    }
  }
  
  /// Sube una foto de usuario a Supabase con compresión automática
  /// 
  /// @param photoFile Archivo de imagen a subir (será comprimido automáticamente)
  /// @param userId ID del usuario para identificar la foto
  /// @return URL pública de la foto o null si hubo error
  Future<String?> uploadUserPhoto(File photoFile, String userId) async {
    try {
      if (kDebugMode && SupabaseConfig.debugMode) {
        AppLogger.info('SupabaseStorageProvider', 'Comprimiendo y optimizando imagen para usuario');
      }

      // Comprimir y optimizar la imagen antes de subir
      final optimizedFile = await ImageCompressionService.compressAndOptimize(
        imageFile: photoFile,
        maxSize: 800, // Tamaño máximo para perfiles
        quality: 85,  // Calidad óptima
      );

      if (kDebugMode && SupabaseConfig.debugMode) {
        final originalSize = await photoFile.length();
        final optimizedSize = await optimizedFile.length();
        final reduction = ((1 - optimizedSize / originalSize) * 100).toStringAsFixed(1);
        AppLogger.info('SupabaseStorageProvider', 'Reducción de tamaño: $reduction%');
        AppLogger.info('SupabaseStorageProvider', 'Original: ${(originalSize / 1024).toStringAsFixed(2)} KB');
        AppLogger.info('SupabaseStorageProvider', 'Optimizada: ${(optimizedSize / 1024).toStringAsFixed(2)} KB');
      }

      // Subir la imagen optimizada
      final result = await uploadFile(
        optimizedFile,
        'users',
        fileName: '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Limpiar el archivo temporal optimizado
      try {
        if (await optimizedFile.exists()) {
          await optimizedFile.delete();
        }
      } catch (e) {
        AppLogger.warning('SupabaseStorageProvider', 'No se pudo eliminar archivo temporal');
      }

      // Limpiar la foto original capturada (vive en Application Documents,
      // el SO no la purga solo — hay que borrarla explícitamente).
      try {
        if (await photoFile.exists()) {
          await photoFile.delete();
        }
      } catch (e) {
        AppLogger.warning('SupabaseStorageProvider', 'No se pudo eliminar la foto original');
      }

      return result;
    } catch (e) {
      if (kDebugMode && SupabaseConfig.debugMode) {
        AppLogger.error('SupabaseStorageProvider', 'Error al procesar y subir foto de usuario', e);
      }
      return null;
    }
  }

  /// Elimina un archivo del bucket de Supabase
  /// 
  /// @param url URL completa del archivo a eliminar
  /// @return true si la eliminación fue exitosa, false en caso contrario
  Future<bool> deleteFile(String url) async {
    try {
      // Extraer la ruta relativa del archivo desde la URL
      final segments = url.split('${SupabaseConfig.bucketName}/');
      if (segments.length < 2) {
        if (kDebugMode && SupabaseConfig.debugMode) {
          AppLogger.error('SupabaseStorageProvider', 'Formato de URL inválido');
        }
        return false;
      }
      
      final filePath = segments[1];
      
      // Eliminar el archivo
      await SupabaseService.client.storage.from(SupabaseConfig.bucketName).remove([filePath]);
      
      if (kDebugMode && SupabaseConfig.debugMode) {
        AppLogger.info('SupabaseStorageProvider', 'Archivo eliminado correctamente');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode && SupabaseConfig.debugMode) {
        AppLogger.error('SupabaseStorageProvider', 'Error al eliminar archivo', e);
      }
      return false;
    }
  }
  
  /// Elimina una foto de usuario
  /// 
  /// @param photoUrl URL completa de la foto a eliminar
  /// @return true si la eliminación fue exitosa, false en caso contrario
  Future<bool> deleteUserPhoto(String photoUrl) async {
    return deleteFile(photoUrl);
  }
}

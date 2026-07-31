import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'storage_service.dart';

/// Servicio de caché de imágenes optimizado para la aplicación GymOne
/// 
/// Características:
/// - Convierte imágenes a formato WebP para mejor compresión
/// - Mantiene dos versiones: miniatura y tamaño completo
/// - Sincronización automática con Supabase Storage
/// - Transparente para el usuario final
class ImageCacheService {
  static ImageCacheService? _instance;
  static ImageCacheService get instance => _instance ??= ImageCacheService._();
  
  ImageCacheService._();
  
  // Configuración del caché
  static const int _thumbnailSize = 150; // px para miniaturas
  static const int _fullSize = 500; // px para imágenes completas
  static const int _jpegQuality = 75; // Calidad JPEG (0-100)
  static const String _cacheDirectory = 'image_cache';
  
  // Directorios de caché
  Directory? _cacheDir;
  Directory? _thumbnailDir;
  Directory? _fullSizeDir;
  
  /// Inicializar el servicio de caché
  Future<void> initialize() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${documentsDir.path}/$_cacheDirectory');
      _thumbnailDir = Directory('${_cacheDir!.path}/thumbnails');
      _fullSizeDir = Directory('${_cacheDir!.path}/fullsize');
      
      // Crear directorios si no existen
      await _cacheDir!.create(recursive: true);
      await _thumbnailDir!.create(recursive: true);
      await _fullSizeDir!.create(recursive: true);
      
      if (kDebugMode) {
        print('📁 ImageCacheService inicializado: ${_cacheDir!.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error inicializando ImageCacheService: $e');
      }
    }
  }
  
  /// Obtener imagen optimizada del usuario
  /// [userId] - ID único del usuario
  /// [photoUrl] - URL de la imagen en Supabase Storage
  /// [isThumbnail] - true para miniatura, false para tamaño completo
  /// Retorna la ruta local del archivo en caché o null si hay error
  Future<String?> getUserImage(String userId, String? photoUrl, {bool isThumbnail = false}) async {
    if (photoUrl == null || photoUrl.isEmpty) {
      if (kDebugMode) {
        print('🖼️ ImageCacheService: photoUrl vacía para usuario $userId');
      }
      return null;
    }
    
    try {
      // Verificar que el servicio esté inicializado
      if (_cacheDir == null) {
        if (kDebugMode) {
          print('🔄 ImageCacheService: Inicializando para usuario $userId');
        }
        await initialize();
      }
      
      final targetSize = isThumbnail ? _thumbnailSize : _fullSize;
      final cacheDir = isThumbnail ? _thumbnailDir! : _fullSizeDir!;
      final fileName = '${userId}_${targetSize}.jpg';
      final cachedFile = File('${cacheDir.path}/$fileName');
      
      if (kDebugMode) {
        print('🔍 ImageCacheService: Buscando ${isThumbnail ? 'miniatura' : 'imagen completa'} para $userId');
        print('   Archivo: $fileName');
        print('   URL: $photoUrl');
      }
      
      // Si existe en caché y es válido, retornarlo
      if (await cachedFile.exists()) {
        final isValid = await _isCacheValid(cachedFile, photoUrl);
        if (isValid) {
          if (kDebugMode) {
            print('✅ ImageCacheService: Imagen desde caché: $fileName');
          }
          return cachedFile.path;
        } else {
          // Caché obsoleto, eliminarlo
          await cachedFile.delete();
          if (kDebugMode) {
            print('🗑️ ImageCacheService: Caché obsoleto eliminado: $fileName');
          }
        }
      }
      
      // Descargar, optimizar y guardar en caché
      if (kDebugMode) {
        print('⬇️ ImageCacheService: Descargando imagen para $userId');
      }
      final optimizedPath = await _downloadAndOptimizeImage(
        userId, 
        photoUrl, 
        targetSize, 
        isThumbnail
      );
      
      if (optimizedPath != null && kDebugMode) {
        print('✅ ImageCacheService: Imagen optimizada guardada: $fileName');
      }
      
      return optimizedPath;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ ImageCacheService ERROR para usuario $userId: $e');
      }
      return null;
    }
  }
  
  /// Descargar imagen desde Supabase y optimizarla
  Future<String?> _downloadAndOptimizeImage(String userId, String photoUrl, int targetSize, bool isThumbnail) async {
    try {
      if (kDebugMode) {
        print('⬇️ Descargando imagen: $photoUrl');
      }

      // Bucket privado: resolver una URL firmada antes de descargar.
      // Si no se puede firmar (p. ej. path externo), usar el valor tal cual.
      final downloadUrl =
          await StorageService.instance.signedUrl(photoUrl) ?? photoUrl;

      // Descargar imagen desde Supabase
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Error descargando imagen: ${response.statusCode}');
        }
        return null;
      }
      
      // Decodificar imagen
      final originalImage = img.decodeImage(response.bodyBytes);
      if (originalImage == null) {
        if (kDebugMode) {
          print('❌ Error decodificando imagen');
        }
        return null;
      }
      
      // Redimensionar imagen manteniendo proporción
      final resizedImage = img.copyResize(
        originalImage,
        width: targetSize,
        height: targetSize,
        interpolation: img.Interpolation.cubic,
      );
      
      // Convertir a JPEG con calidad optimizada
      final jpegBytes = img.encodeJpg(resizedImage, quality: _jpegQuality);
      
      // Guardar en caché
      final cacheDir = isThumbnail ? _thumbnailDir! : _fullSizeDir!;
      final fileName = '${userId}_$targetSize.jpg';
      final cachedFile = File('${cacheDir.path}/$fileName');
      
      await cachedFile.writeAsBytes(jpegBytes);
      
      // Guardar metadatos para validación futura
      await _saveCacheMetadata(cachedFile, photoUrl);
      
      if (kDebugMode) {
        final originalSize = response.bodyBytes.length;
        final optimizedSize = jpegBytes.length;
        final reduction = ((originalSize - optimizedSize) / originalSize * 100).round();
        print('✅ Imagen optimizada: $fileName');
        print('   Original: ${(originalSize / 1024).round()}KB → Optimizada: ${(optimizedSize / 1024).round()}KB ($reduction% reducción)');
      }
      
      return cachedFile.path;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error optimizando imagen: $e');
      }
      return null;
    }
  }
  
  /// Validar si el caché es actual comparando con la URL original
  Future<bool> _isCacheValid(File cachedFile, String originalUrl) async {
    try {
      final metadataFile = File('${cachedFile.path}.meta');
      if (!await metadataFile.exists()) return false;
      
      final metadata = jsonDecode(await metadataFile.readAsString());
      final cachedUrl = metadata['url'] as String?;
      final cacheTime = DateTime.parse(metadata['timestamp'] as String);
      
      // Verificar que la URL coincida y que no sea muy antigua (24 horas)
      final isUrlMatch = cachedUrl == originalUrl;
      final isRecent = DateTime.now().difference(cacheTime).inHours < 24;
      
      return isUrlMatch && isRecent;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Guardar metadatos del caché para validación futura
  Future<void> _saveCacheMetadata(File cachedFile, String originalUrl) async {
    try {
      final metadataFile = File('${cachedFile.path}.meta');
      final metadata = {
        'url': originalUrl,
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
      };
      
      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error guardando metadatos: $e');
      }
    }
  }
  
  /// Limpiar caché antiguo (llamar periódicamente o cuando sea necesario)
  Future<void> cleanOldCache({int maxDays = 7}) async {
    try {
      if (_cacheDir == null) return;
      
      final cutoffDate = DateTime.now().subtract(Duration(days: maxDays));
      int deletedCount = 0;
      
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      if (kDebugMode) {
        print('🧹 Limpieza de caché completada: $deletedCount archivos eliminados');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error limpiando caché: $e');
      }
    }
  }
  
  /// Obtener tamaño total del caché
  Future<int> getCacheSize() async {
    try {
      if (_cacheDir == null) return 0;
      
      int totalSize = 0;
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
  
  /// Limpiar todo el caché
  Future<void> clearAllCache() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await initialize(); // Recrear directorios
        
        if (kDebugMode) {
          print('🗑️ Caché completamente limpiado');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error limpiando caché: $e');
      }
    }
  }
  
  /// Precargar imagen de usuario (útil para preparar caché)
  Future<void> preloadUserImage(String userId, String? photoUrl) async {
    if (photoUrl == null || photoUrl.isEmpty) return;
    
    try {
      // Precargar tanto miniatura como tamaño completo
      await Future.wait([
        getUserImage(userId, photoUrl, isThumbnail: true),
        getUserImage(userId, photoUrl, isThumbnail: false),
      ]);
      
      if (kDebugMode) {
        print('🚀 Imagen precargada: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error precargando imagen: $e');
      }
    }
  }
}

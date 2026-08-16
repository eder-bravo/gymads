import 'dart:io';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Servicio para comprimir y optimizar imágenes
/// Usa JPEG optimizado que es más ligero y compatible que PNG
class ImageCompressionService {
  /// Tamaño máximo para las imágenes de perfil (ancho/alto máximo)
  static const int maxImageSize = 800;
  
  /// Calidad de compresión JPEG (0-100, 85 es un buen balance)
  static const int jpegQuality = 85;
  
  /// Calidad para thumbnails
  static const int thumbnailQuality = 80;

  /// Convierte una imagen a formato JPEG optimizado con compresión
  /// 
  /// [imageFile] - Archivo de imagen original (JPG, PNG, etc.)
  /// [maxSize] - Tamaño máximo de ancho/alto (default: 800px)
  /// [quality] - Calidad de compresión 0-100 (default: 85)
  /// 
  /// Returns: Archivo JPEG comprimido y optimizado
  static Future<File> compressAndOptimize({
    required File imageFile,
    int maxSize = maxImageSize,
    int quality = jpegQuality,
  }) async {
    try {
      if (kDebugMode) {
        AppLogger.info('ImageCompressionService', 'Iniciando compresión de imagen');
        AppLogger.info('ImageCompressionService', 'Archivo original');
        final originalSize = await imageFile.length();
        AppLogger.info('ImageCompressionService', 'Tamaño archivo: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      }

      // Leer la imagen original
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decodificar la imagen
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      AppLogger.info('ImageCompressionService', 'Dimensiones originales: ${image.width}x${image.height}');

      // Redimensionar si es necesario (mantener aspecto)
      if (image.width > maxSize || image.height > maxSize) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? maxSize : null,
          height: image.height > image.width ? maxSize : null,
          interpolation: img.Interpolation.linear,
        );
        
        AppLogger.info('ImageCompressionService', 'Redimensionada a: ${image.width}x${image.height}');
      }

      // Convertir a JPEG optimizado
      final Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: quality)
      );
      
      if (kDebugMode) {
        AppLogger.info('ImageCompressionService', 'Tamaño comprimido: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
        final reduction = ((1 - compressedBytes.length / imageBytes.length) * 100);
        AppLogger.info('ImageCompressionService', 'Reducción: ${reduction.toStringAsFixed(1)}%');
      }

      // Guardar en archivo temporal
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = path.basenameWithoutExtension(imageFile.path);
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String optimizedPath = path.join(tempDir.path, '${fileName}_$timestamp.jpg');
      
      final File optimizedFile = File(optimizedPath);
      await optimizedFile.writeAsBytes(compressedBytes);

      AppLogger.info('ImageCompressionService', 'Imagen optimizada guardada');

      return optimizedFile;
    } catch (e) {
      AppLogger.error('ImageCompressionService', 'Error en compresión de imagen', e);
      rethrow;
    }
  }

  /// Convierte bytes de imagen a JPEG optimizado
  /// 
  /// Útil cuando ya tienes los bytes en memoria
  static Future<Uint8List> compressBytes({
    required Uint8List imageBytes,
    int maxSize = maxImageSize,
    int quality = jpegQuality,
  }) async {
    try {
      // Decodificar la imagen
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      // Redimensionar si es necesario
      if (image.width > maxSize || image.height > maxSize) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? maxSize : null,
          height: image.height > image.width ? maxSize : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Convertir a JPEG
      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (e) {
      AppLogger.error('ImageCompressionService', 'Error en compresión de bytes', e);
      rethrow;
    }
  }

  /// Crea una miniatura optimizada para avatares/thumbnails
  /// 
  /// Tamaño pequeño para carga ultra rápida
  static Future<Uint8List> createThumbnail({
    required File imageFile,
    int thumbnailSize = 200,
    int quality = thumbnailQuality,
  }) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      // Crear thumbnail cuadrado con crop desde el centro
      final int size = image.width < image.height ? image.width : image.height;
      final int offsetX = (image.width - size) ~/ 2;
      final int offsetY = (image.height - size) ~/ 2;

      img.Image cropped = img.copyCrop(
        image,
        x: offsetX,
        y: offsetY,
        width: size,
        height: size,
      );

      // Redimensionar a thumbnail
      img.Image thumbnail = img.copyResize(
        cropped,
        width: thumbnailSize,
        height: thumbnailSize,
        interpolation: img.Interpolation.linear,
      );

      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: quality));
    } catch (e) {
      AppLogger.error('ImageCompressionService', 'Error creando thumbnail', e);
      rethrow;
    }
  }

  /// Valida que el archivo sea una imagen válida
  static Future<bool> isValidImage(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene las dimensiones de una imagen sin cargarla completamente
  static Future<Map<String, int>?> getImageDimensions(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) return null;
      
      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      AppLogger.error('ImageCompressionService', 'Error obteniendo dimensiones', e);
      return null;
    }
  }
}


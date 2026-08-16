import 'dart:io';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? controller;
  List<CameraDescription> cameras = [];

  /// Verificar si hay cámara trasera disponible
  Future<bool> hasBackCamera() async {
    try {
      cameras = await availableCameras();
      return cameras.any(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
    } catch (e) {
      AppLogger.error('CameraService', 'Error al verificar cámaras disponibles', e);
      return false;
    }
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      
      // Buscar específicamente la cámara trasera
      final backCamera = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      ).toList();
      
      if (backCamera.isEmpty) {
        throw Exception('No se encontró cámara trasera disponible');
      }
      
      // Inicializar ÚNICAMENTE con la cámara trasera
      controller = CameraController(
        backCamera.first,
        ResolutionPreset.high,
        enableAudio: false, // No necesitamos audio para fotos
      );
      
      await controller?.initialize();
    } catch (e) {
      AppLogger.error('CameraService', 'Error al inicializar la cámara trasera', e);
      rethrow; // Re-lanzar error para que el llamador pueda manejarlo
    }
  }

  Future<File?> takePhoto() async {
    if (controller?.value.isInitialized ?? false) {
      try {
        final XFile photo = await controller!.takePicture();

        // Crear un directorio temporal para la foto
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = tempDir.path;
        final File photoFile = File(
          '$tempPath/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        // Copiar la foto al directorio temporal
        await File(photo.path).copy(photoFile.path);

        return photoFile;
      } catch (e) {
        AppLogger.error('CameraService', 'Error al tomar la foto', e);
        return null;
      }
    }
    return null;
  }

  void dispose() {
    controller?.dispose();
  }

  /// Verificar si la cámara está inicializada y lista
  bool get isInitialized => controller?.value.isInitialized ?? false;

  /// Obtener la cámara que está siendo usada (debe ser trasera)
  CameraDescription? get currentCamera {
    if (controller != null) {
      return controller!.description;
    }
    return null;
  }

  /// Verificar si la cámara actual es trasera
  bool get isBackCamera {
    final camera = currentCamera;
    return camera?.lensDirection == CameraLensDirection.back;
  }
}

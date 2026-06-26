import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../views/circular_camera_view.dart';
import '../../../core/utils/snackbar_helper.dart';

class PhotoCaptureWidget extends StatelessWidget {
  final Function(File) onPhotoTaken;
  final String? currentPhotoUrl;

  PhotoCaptureWidget({
    super.key,
    required this.onPhotoTaken,
    this.currentPhotoUrl,
    File? initialPhotoFile,
  }) {
    // Inicializar el estado reactivo con el archivo inicial si existe
    _tempImageFile = Rx<File?>(initialPhotoFile);
  }

  // Estado reactivo para la imagen temporal
  late final Rx<File?> _tempImageFile;

  Future<void> _checkAndRequestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (Get.context != null) {
        showDialog(
          context: Get.context!,
          builder: (context) => AlertDialog(
            title: const Text('Permiso de Cámara Requerido'),
            content: const Text(
              'Para tomar la foto del usuario, necesitamos acceso a la cámara.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Abrir Configuración'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    await _checkAndRequestCameraPermission();

    try {
      // Usar la vista de cámara circular
      await Get.to<File>(
        () => CircularCameraView(
          onPhotoTaken: (File imageFile) {
            _tempImageFile.value = imageFile;
            onPhotoTaken(imageFile);
            Get.back(); // Regresar automáticamente después de tomar la foto
          },
          onCancel: () {
            Get.back(); // Solo regresar sin hacer nada
          },
        ),
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      // Fallback a ImagePicker si hay problemas con la cámara nativa
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front, // Frontal por defecto
          imageQuality: 80,
        );

        if (photo != null) {
          final file = File(photo.path);
          _tempImageFile.value = file;
          onPhotoTaken(file);
        }
      } catch (fallbackError) {
        SnackbarHelper.error(
          'Error',
          'No se pudo tomar la foto. Por favor, intenta de nuevo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: _takePicture,
            child: Obx(() {
              final tempFile = _tempImageFile.value;
              return Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(75),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                ),
                child: tempFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(75),
                        child: Image.file(tempFile, fit: BoxFit.cover),
                      )
                    : currentPhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(75),
                            child: Image.network(
                              currentPhotoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Colors.grey,
                          ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Text(
              _tempImageFile.value != null || currentPhotoUrl != null
                  ? 'Toca para cambiar la foto'
                  : 'Toca para tomar una foto',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

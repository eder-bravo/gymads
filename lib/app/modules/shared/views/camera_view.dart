import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/camera_service.dart';
import '../../../../core/theme/siempre_oscuro.dart';
import '../../../core/utils/plataforma_app.dart';
import 'desktop_camera_view.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  final CameraService _cameraService = CameraService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!PlataformaApp.escritorio) _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initializeCamera();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PlataformaApp.escritorio) {
      return DesktopCameraView(
          circular: false,
          onPhotoTaken: (foto) => Get.back(result: foto),
          onCancel: () => Get.back());
    }
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SiempreOscuro(
        child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Vista previa de la cámara
            SizedBox(
              width: Get.width,
              height: Get.height,
              child: CameraPreview(_cameraService.controller!),
            ),
            // Botón de captura
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    final photo = await _cameraService.takePhoto();
                    if (photo != null) {
                      if (context.mounted) {
                        Navigator.of(context).pop(photo);
                      }
                    }
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
            // Botón de cerrar
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

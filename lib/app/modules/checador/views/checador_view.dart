import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../controllers/checador_controller.dart';
import '../../shared/widgets/welcome_screen_widget.dart';

class ChecadorView extends GetView<ChecadorController> {
  const ChecadorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Control de Acceso',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.normal,
                facing: CameraFacing.back,
                torchEnabled: false,
              ),
              onDetect: controller.onDetect,
            ),

            // Mensaje guía
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Obx(
                    () => Text(
                      controller.errorMessage.isEmpty
                          ? 'Escanea el código QR del usuario'
                          : controller.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: controller.errorMessage.isEmpty
                            ? AppColors.textPrimary
                            : Colors.red.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Indicador de carga
          Obx(
            () => controller.isLoading.value
                ? Container(
                    color: AppColors.backgroundColor.withOpacity(0.8),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Pantalla de bienvenida compartida
          Obx(
            () => WelcomeScreenWidget(
              userName: controller.userName.value,
              userPhotoUrl: controller.userPhotoUrl.value,
              daysLeft: controller.daysLeft.value,
              expirationDate: controller.expirationDate.value,
              isVisible: controller.isShowingDialog.value,
            ),
          ),
          ],
        ),
      ),
    );
  }
}

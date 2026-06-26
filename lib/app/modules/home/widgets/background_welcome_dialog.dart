import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/background_rfid_service.dart';
import '../../shared/widgets/welcome_screen_widget.dart';

/// Widget que muestra el diálogo de bienvenida cuando se escanea en el home
class BackgroundWelcomeDialog extends StatelessWidget {
  const BackgroundWelcomeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // Verificar si el servicio está disponible
    if (!Get.isRegistered<BackgroundRfidService>()) {
      return const SizedBox.shrink();
    }
    
    try {
      final service = Get.find<BackgroundRfidService>();
      
      return Obx(() {
        // Primero verificamos si debemos mostrar la pantalla de tarjeta no registrada
        if (service.showNotFoundDialog.value) {
          return WelcomeScreenWidget(
            userName: service.lastScannedUid.value, // Mostrar el UID de la tarjeta
            userPhotoUrl: '',
            daysLeft: 0,
            isVisible: true,
            isExpired: false,
            isNotFound: true,
            onRegister: () {
              service.showNotFoundDialog.value = false;
              Get.toNamed('/clientes', arguments: {'new_rfid': service.lastScannedUid.value});
            },
          );
        }

        // Si no, verificamos el diálogo de bienvenida normal
        if (!service.showWelcomeDialog.value || service.currentUser.value == null) {
          return const SizedBox.shrink();
        }
        
        final user = service.currentUser.value!;
        
        return WelcomeScreenWidget(
          userName: user.name,
          userPhotoUrl: user.photoUrl ?? '',
          daysLeft: user.daysRemaining,
          expirationDate: user.expirationDate,
          isVisible: service.showWelcomeDialog.value,
          isExpired: user.daysRemaining <= 0 || !user.isActive,
          isNotFound: false,
          onAbonar: (user.daysRemaining <= 0 || !user.isActive) ? () {
            service.showWelcomeDialog.value = false;
            Get.toNamed('/abonar', arguments: {'cliente': user});
          } : null,
          onEditar: (user.daysRemaining <= 0 || !user.isActive) ? () {
            service.showWelcomeDialog.value = false;
            // Ocultar dialog de fondo y navegar al cliente (que permitirá editar)
            Get.toNamed('/clientes', arguments: {'edit_cliente': user});
          } : null,
        );
      });
    } catch (e) {
      // Servicio no disponible
      return const SizedBox.shrink();
    }
  }
}

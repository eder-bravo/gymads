import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_pages.dart';
import '../../auth/controllers/auth_controller.dart';
import 'package:gymads/core/theme/app_colors.dart';


class HomeController extends GetxController {
  // Estado observable para controlar cuando se está creando un usuario
  final RxBool isCreatingUser = false.obs;

  // Lista observable de mensajes de estado
  final RxList<String> statusMessages = <String>[].obs;

  // Función para obtener el saludo según la hora
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return 'Buenos días';
    } else if (hour >= 12 && hour < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  @override
  void onReady() {
    super.onReady();
  }

  // Funciones para manejar las opciones del menú
  void goToCheckIns() {
    statusMessages.add('Navegando a la pantalla de Check-Ins...');
    Get.toNamed(Routes.CHECADOR);
  }

  void goToPaymentRegistration() {
    statusMessages.add('Navegando a Registro de Pagos...');
    Get.toNamed(Routes.INGRESOS);
  }

  Future<void> goToClientes() async {
    statusMessages.add('Navegando a Gestión de Clientes...');
    Get.toNamed(Routes.CLIENTES);
  }

  void goToInventario() {
    statusMessages.add('Navegando a Inventario...');
    Get.toNamed(Routes.INVENTARIO);
  }

  void goToPointOfSale() {
    statusMessages.add('Navegando a Punto de Venta...');
    Get.toNamed(Routes.POINT_OF_SALE);
  }

  void goToAbonar() {
    statusMessages.add('Navegando a Abonar...');
    Get.toNamed(Routes.ABONAR);
  }

  void goToAccessLogs() {
    statusMessages.add('Navegando a Entradas...');
    Get.toNamed(Routes.ACCESS_LOGS);
  }

  /// Limpia los mensajes de estado
  void clearMessages() {
    statusMessages.clear();
  }

  /// Cerrar sesión
  void logout() {
    Get.find<AuthController>().logout();
  }
}

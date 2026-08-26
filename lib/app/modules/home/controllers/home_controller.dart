import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/tenant_context_service.dart';
import '../../../data/services/welcome_tour_service.dart';
import '../../../routes/app_pages.dart';
import '../../auth/controllers/auth_controller.dart';

class HomeController extends GetxController {
  // Estado observable para controlar cuando se está creando un usuario
  final RxBool isCreatingUser = false.obs;

  // Lista observable de mensajes de estado
  final RxList<String> statusMessages = <String>[].obs;

  // ─── Tour de bienvenida ───
  // Las claves viven aquí y no en el build porque HomeView reconstruye sus
  // listas de módulos en cada frame; creadas ahí serían inestables.
  final keyHeader = GlobalKey();
  final keyClientes = GlobalKey();
  final keyAbonar = GlobalKey();
  final keyVender = GlobalKey();
  final keyInventario = GlobalKey();
  final keyIngresos = GlobalKey();
  final keyEntradas = GlobalKey();
  final keyConfiguracion = GlobalKey();

  bool _checkingOnboarding = false;

  List<GlobalKey> get _tourSteps => [
        keyHeader,
        keyClientes,
        keyAbonar,
        keyVender,
        keyInventario,
        keyIngresos,
        keyEntradas,
        keyConfiguracion,
      ];

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
    checkOnboarding();
  }

  /// Decide si el gimnasio necesita el asistente inicial o el tour.
  ///
  /// Un `payment_mode` nulo solo ocurre en gimnasios recién registrados: la
  /// migración dejó a todos los anteriores en 'libre'. El tour, en cambio, se
  /// dispara por la bandera local que solo escribe el asistente, de modo que
  /// los gimnasios que ya existían nunca lo ven.
  ///
  /// Es idempotente y se puede llamar en cada frame: se invoca tanto desde
  /// `onReady` como desde HomeView, porque al volver del asistente con
  /// `Get.offAllNamed` GetX puede reutilizar este controlador y entonces
  /// `onReady` ya no vuelve a dispararse.
  Future<void> checkOnboarding() async {
    if (_checkingOnboarding) return;
    _checkingOnboarding = true;
    try {
      final tenant = TenantContextService.to;
      if (tenant.currentGymId == null) return;

      // Solo el dueño puede escribir en `gyms` (política RLS), así que a nadie
      // más se le puede pedir completar el asistente.
      if (tenant.isOwnerAdmin && tenant.staffProfile?.paymentMode == null) {
        if (Get.currentRoute != Routes.ONBOARDING_PAYMENT_MODE) {
          Get.toNamed(Routes.ONBOARDING_PAYMENT_MODE);
        }
        return;
      }

      // Solo con Inicio realmente en pantalla. HomeView sigue montada debajo
      // del asistente y se reconstruye mientras este se cierra, así que sin
      // esta guarda el tour llegaría a arrancar apuntando a unos widgets que
      // `Get.offAllNamed` está a punto de destruir: se cerraría solo, sin
      // enseñar nada.
      if (Get.currentRoute != Routes.HOME) return;

      await WelcomeTourService.to.startIfPending(AppTours.home, _tourSteps);
    } finally {
      _checkingOnboarding = false;
    }
  }

  // Funciones para manejar las opciones del menú
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

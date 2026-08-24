import 'package:get/get.dart';

import '../../../data/repositories/abono_prices_repository.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../data/services/welcome_tour_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../routes/app_pages.dart';

/// Modos de cobro disponibles, tal y como se guardan en `gyms.payment_mode`.
class PaymentModes {
  PaymentModes._();
  static const fijo = 'fijo';
  static const libre = 'libre';
}

/// Asistente de configuración inicial para gimnasios recién registrados.
///
/// Solo se llega aquí cuando `gyms.payment_mode` es null, así que este
/// controlador es también el único punto donde se marca el tour de bienvenida
/// como pendiente: los gimnasios que ya existían nunca pasan por aquí y por
/// eso nunca ven el tour.
class OnboardingController extends GetxController {
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    WelcomeTourService.to.markPending();
  }

  /// "Abonos libres": se guarda al instante y se vuelve a Inicio.
  Future<void> chooseLibre() async {
    if (isSaving.value) return;
    isSaving.value = true;
    try {
      final saved = await OnboardingController.savePaymentModeAndSyncProfile(
          PaymentModes.libre);
      if (!saved) {
        SnackbarHelper.error(
            'Error', 'No se pudo guardar el modo de cobro. Intenta de nuevo.');
        return;
      }
      Get.offAllNamed(Routes.HOME);
    } finally {
      isSaving.value = false;
    }
  }

  /// "Abonos fijos": se pasa a configurar los precios. El modo NO se guarda
  /// todavía; se guarda al confirmar los precios (ver AbonoPricesController).
  /// Así, si el usuario abandona a medias, el asistente completo se repite.
  void chooseFijo() {
    Get.toNamed(Routes.ABONO_PRICES, arguments: {'fromOnboarding': true});
  }

  /// Guarda el modo en Supabase y actualiza el perfil cacheado.
  ///
  /// Refrescar la caché es imprescindible: `HomeController` decide si mostrar
  /// el asistente leyendo `staffProfile.paymentMode`, así que si se quedara en
  /// null volvería a redirigir aquí en bucle.
  ///
  /// Es estático porque el paso de precios fijos vive en otra ruta
  /// (`AbonoPricesController`) y no debe depender de que este controlador
  /// siga instanciado.
  static Future<bool> savePaymentModeAndSyncProfile(String mode) async {
    final saved = await AbonoPricesRepository().savePaymentMode(mode);
    if (!saved) return false;

    final tenant = TenantContextService.to;
    final profile = tenant.staffProfile;
    if (profile != null) {
      await tenant.setProfile(profile.copyWith(paymentMode: mode));
    }
    return true;
  }
}

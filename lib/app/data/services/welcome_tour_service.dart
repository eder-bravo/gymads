import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'tenant_context_service.dart';

/// Dueño del tour de bienvenida de la pantalla de Inicio.
///
/// Vive como servicio permanente y no como parte de `HomeController` a
/// propósito: al volver a Inicio con `Get.offAllNamed` GetX reutiliza el
/// controlador pero le invoca `onClose()` al destruir la ruta anterior, lo que
/// desregistraba el `ShowcaseView` y dejaba a `startShowCase()` sin efecto
/// (sale en silencio por su guarda interna `_mounted`). Registrándolo una sola
/// vez para toda la vida de la app, ese problema desaparece.
class WelcomeTourService extends GetxService {
  static WelcomeTourService get to => Get.find<WelcomeTourService>();

  ShowcaseView? _showcaseView;
  bool _started = false;

  /// Clave (por gimnasio) que marca el tour como pendiente. Solo la escribe el
  /// asistente de configuración inicial, así que los gimnasios que ya existían
  /// antes de esta función nunca la tienen y nunca ven el tour.
  static String _pendingKey(String gymId) => 'onboarding_tour_pending_$gymId';

  /// Debe llamarse antes de que se construya cualquier widget `Showcase`.
  WelcomeTourService init() {
    _showcaseView = ShowcaseView.register(
      enableAutoScroll: true,
      disableBarrierInteraction: true,
      onFinish: complete,
      onDismiss: (_) => complete(),
    );
    return this;
  }

  /// Marca el tour como pendiente para el gimnasio actual.
  Future<void> markPending() async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey(gymId), true);
  }

  Future<bool> isPending() async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey(gymId)) ?? false;
  }

  /// Arranca el tour si sigue pendiente. Idempotente: solo corre una vez por
  /// sesión de app.
  Future<void> startIfPending(List<GlobalKey> steps) async {
    if (_started || steps.isEmpty) return;
    if (!await isPending()) return;

    _started = true;
    // Un respiro para que los `Showcase` de Inicio terminen de registrarse
    // tras la transición de ruta.
    _showcaseView?.startShowCase(
      steps,
      delay: const Duration(milliseconds: 400),
    );
  }

  /// Se llama tanto al terminar el tour como al saltarlo.
  Future<void> complete() async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey(gymId));
  }
}

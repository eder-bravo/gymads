import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'tenant_context_service.dart';

/// Identificadores de los recorridos guiados: uno por pantalla principal.
///
/// Son los nombres con los que se guarda en disco si el recorrido sigue
/// pendiente, así que cambiarlos hace que los usuarios que ya lo vieron
/// vuelvan a verlo.
class AppTours {
  AppTours._();

  static const home = 'home';
  static const clientes = 'clientes';
  static const abonar = 'abonar';
  static const puntoDeVenta = 'punto_de_venta';
  static const inventario = 'inventario';
  static const ingresos = 'ingresos';
  static const entradas = 'entradas';
  static const configuracion = 'configuracion';

  /// Todos los recorridos que existen. El asistente inicial los marca en bloque
  /// como pendientes; a partir de ahí cada uno se da por visto por su cuenta.
  static const all = <String>[
    home,
    clientes,
    abonar,
    puntoDeVenta,
    inventario,
    ingresos,
    entradas,
    configuracion,
  ];
}

/// Dueño de los tours de bienvenida de toda la app.
///
/// Vive como servicio permanente y no dentro de cada controlador de pantalla a
/// propósito: al navegar con `Get.offAllNamed` GetX puede reutilizar un
/// controlador pero le invoca `onClose()` al destruir la ruta anterior, lo que
/// desregistraba el `ShowcaseView` y dejaba a `startShowCase()` sin efecto
/// (sale en silencio por su guarda interna `_mounted`). Registrándolo una sola
/// vez para toda la vida de la app, ese problema desaparece.
class WelcomeTourService extends GetxService {
  static WelcomeTourService get to => Get.find<WelcomeTourService>();

  ShowcaseView? _showcaseView;

  /// Recorridos ya mostrados en esta sesión de app. Evita relanzar el mismo
  /// tour al volver a entrar a la pantalla antes de que termine de guardarse
  /// que ya se vio.
  final Set<String> _startedTours = <String>{};

  /// Recorridos con un arranque en curso. Un arranque tiene `await` de por
  /// medio (leer disco, esperar a que los widgets se monten), así que sin esto
  /// dos llamadas seguidas abrirían dos esperas en paralelo.
  final Set<String> _starting = <String>{};

  /// Intentos fallidos por recorrido, para no reintentar en bucle si una
  /// pantalla nunca llega a estabilizarse.
  final Map<String, int> _attempts = <String, int>{};
  static const _maxAttempts = 3;

  /// Recorrido que se está mostrando ahora mismo. Hace falta porque los
  /// callbacks de `ShowcaseView` se registran una sola vez para todos.
  String? _activeTour;

  /// Si el recorrido en curso llegó a pintar algún paso. Distingue "el usuario
  /// lo vio" de "se cerró solo sin enseñar nada", que son cosas muy distintas
  /// a la hora de darlo por visto.
  bool _activeTourShown = false;

  /// Clave (por gimnasio y recorrido) que lo marca como pendiente. Solo las
  /// escribe el asistente de configuración inicial, así que los gimnasios que
  /// ya existían antes de esta función nunca las tienen y nunca ven los tours.
  static String _pendingKey(String gymId, String tourId) =>
      'onboarding_tour_pending_${gymId}_$tourId';

  /// Debe llamarse antes de que se construya cualquier widget `Showcase`.
  WelcomeTourService init() {
    _showcaseView = ShowcaseView.register(
      enableAutoScroll: true,
      disableBarrierInteraction: true,
      // `onStart` solo se dispara cuando el paso tiene un widget de verdad al
      // que apuntar; es la señal de que el recorrido llegó a verse.
      onStart: (_, __) => _activeTourShown = true,
      onFinish: _onFinish,
      onDismiss: (_) => _onDismiss(),
    );
    return this;
  }

  /// Marca todos los recorridos como pendientes para el gimnasio actual.
  Future<void> markPending() async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final tourId in AppTours.all) {
      await prefs.setBool(_pendingKey(gymId, tourId), true);
    }
  }

  Future<bool> isPending(String tourId) async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey(gymId, tourId)) ?? false;
  }

  /// Arranca el recorrido de una pantalla si sigue pendiente. Idempotente: se
  /// puede llamar en cada frame y solo corre una vez por sesión de app.
  ///
  /// * [tourId] - Uno de [AppTours].
  /// * [steps] - Las claves de los pasos, en el orden en que deben mostrarse.
  Future<void> startIfPending(String tourId, List<GlobalKey> steps) async {
    if (steps.isEmpty || _startedTours.contains(tourId)) return;
    if ((_attempts[tourId] ?? 0) >= _maxAttempts) return;
    // `add` devuelve false si ya estaba: un comprobar-y-marcar sin `await` de
    // por medio, para que dos llamadas seguidas (`onReady` y una
    // reconstrucción, por ejemplo) no arranquen lo mismo dos veces.
    if (!_starting.add(tourId)) return;

    try {
      if (!await isPending(tourId)) return;

      final showcaseView = _showcaseView;
      // Nunca se solapan dos recorridos: el de la pantalla que quedó atrás
      // terminaría apuntando a widgets que ya no están montados.
      if (showcaseView == null || showcaseView.isShowcaseRunning) return;

      // Si la pantalla se cerró o nunca terminó de cargar no se marca nada: el
      // recorrido queda pendiente para el próximo intento.
      if (!await _waitForTargets(showcaseView, steps)) return;
      if (showcaseView.isShowcaseRunning) return;

      _startedTours.add(tourId);
      _activeTour = tourId;
      _activeTourShown = false;
      // Un respiro para que la transición de ruta termine de asentarse antes
      // de pintar el resaltado.
      showcaseView.startShowCase(
        steps,
        delay: const Duration(milliseconds: 400),
      );
    } finally {
      _starting.remove(tourId);
    }
  }

  /// Espera a que todos los pasos estén montados en pantalla.
  ///
  /// Sin esto, en las pantallas que muestran un spinner mientras cargan sus
  /// datos el tour arrancaría apuntando a widgets que todavía no existen y se
  /// cerraría solo. Si el usuario se va de la pantalla, sus `Showcase` se
  /// desregistran y la espera acaba agotándose, que es justo lo que se quiere.
  Future<bool> _waitForTargets(
    ShowcaseView showcaseView,
    List<GlobalKey> steps,
  ) async {
    const interval = Duration(milliseconds: 200);
    const attempts = 25; // 5 s de margen para cargar
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (steps.every(showcaseView.isTargetRendered)) return true;
      await Future<void>.delayed(interval);
    }
    return false;
  }

  /// El usuario llegó al final del recorrido: solo ese queda como visto, los de
  /// las demás pantallas siguen esperando su turno.
  ///
  /// Ojo: showcaseview también llama aquí cuando un paso se queda sin widget al
  /// que apuntar y da el recorrido por terminado sin enseñar nada. Eso pasa,
  /// por ejemplo, al volver a Inicio con `Get.offAllNamed` justo mientras
  /// arrancaba el tour: la pantalla se reconstruye con claves nuevas y las
  /// viejas dejan de existir. Ese caso no cuenta como visto.
  Future<void> _onFinish() async {
    final finished = _activeTour;
    final wasShown = _activeTourShown;
    _activeTour = null;
    _activeTourShown = false;
    if (finished == null) return;

    if (!wasShown) {
      _startedTours.remove(finished);
      _attempts[finished] = (_attempts[finished] ?? 0) + 1;
      return;
    }
    await _markSeen([finished]);
  }

  /// El usuario tocó "Saltar". Cuenta como visto igual que llegar al final, y
  /// también solo para esta pantalla: saltarse la guía de Clientes no dice nada
  /// sobre la de Abonar, que el usuario todavía no ha visto.
  Future<void> _onDismiss() async {
    final dismissed = _activeTour;
    _activeTour = null;
    _activeTourShown = false;
    if (dismissed == null) return;
    await _markSeen([dismissed]);
  }

  Future<void> _markSeen(List<String> tourIds) async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final tourId in tourIds) {
      await prefs.remove(_pendingKey(gymId, tourId));
    }
  }
}

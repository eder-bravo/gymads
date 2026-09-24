import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/permissions/staff_role.dart';
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

/// Dónde se guardan los recorridos que ya vio un empleado: en su acceso
/// (`staff_accesos.tours_vistos`), no en el teléfono, y por ROL.
///
/// Su acceso es lo único estable del empleado: regenerarle el código borra su
/// perfil y su usuario, y un cambio de rol solo cambia el rol. Y se cuentan
/// por rol, no solo por pantalla: quien fue Encargado (que ve todas las
/// pantallas) y pasa a Almacén debe ver los recorridos de Almacén. Así:
/// - un código nuevo no le vuelve a mostrar nada;
/// - un rol que nunca usó le enseña los recorridos de ese rol;
/// - al regresar a un rol que ya tuvo, ya estaban vistos.
abstract class ToursDelEmpleado {
  /// Los recorridos ya vistos con el rol [rol]. Null si quien usa la app no
  /// es un empleado con acceso.
  Future<Set<String>?> vistos(String rol);

  Future<void> marcarVisto(String rol, String tourId);
}

class ToursDelEmpleadoSupabase implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async {
    final respuesta = await Supabase.instance.client
        .rpc('mis_tours_vistos', params: {'p_rol': rol});
    if (respuesta == null) return null;
    return {for (final tour in respuesta as List) tour as String};
  }

  /// Con el rol con el que se mostró: si el dueño se lo cambió justo en ese
  /// momento, cuenta el que vio.
  @override
  Future<void> marcarVisto(String rol, String tourId) =>
      Supabase.instance.client
          .rpc('marcar_tour_visto', params: {'p_tour': tourId, 'p_rol': rol});
}

/// Quién usa la app y con qué rol, para saber de dónde salen sus recorridos.
typedef SesionTour = ({
  String? gymId,
  String? perfilId,
  String rol,
  bool esEmpleado,
});

SesionTour _sesionActual() {
  final tenant = TenantContextService.to;
  return (
    gymId: tenant.currentGymId,
    perfilId: tenant.staffProfileRx.value?.id,
    rol: tenant.rol.value,
    esEmpleado: tenant.rol != StaffRole.ownerAdmin,
  );
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
  WelcomeTourService({
    ToursDelEmpleado? toursDelEmpleado,
    SesionTour Function()? sesion,
  })  : _toursDelEmpleado = toursDelEmpleado ?? ToursDelEmpleadoSupabase(),
        _sesion = sesion ?? _sesionActual;

  static WelcomeTourService get to => Get.find<WelcomeTourService>();

  final ToursDelEmpleado _toursDelEmpleado;
  final SesionTour Function() _sesion;

  /// Recorridos ya vistos por el empleado en sesión con su rol actual, leídos
  /// una vez de la base. Null mientras no se han leído.
  Set<String>? _vistosEmpleado;

  /// De quién, y con qué rol, es lo que se recuerda en memoria (recorridos
  /// iniciados, intentos y [_vistosEmpleado]).
  String? _sesionEnMemoria;

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

  /// Con qué rol se inició [_activeTour]. Al darlo por visto cuenta ese rol,
  /// no el actual: si el rol cambia justo cuando termina, el recorrido se vio
  /// con el anterior.
  String? _rolDelTour;

  /// Si el recorrido en curso llegó a pintar algún paso. Distingue "el usuario
  /// lo vio" de "se cerró solo sin enseñar nada", que son cosas muy distintas
  /// a la hora de darlo por visto.
  bool _activeTourShown = false;

  /// Clave (por gimnasio y recorrido) que marca un recorrido del DUEÑO como
  /// pendiente.
  ///
  /// La escribe el asistente de configuración inicial, al registrar el
  /// gimnasio. Los gimnasios que ya existían antes de esta función nunca la
  /// tienen y por eso su dueño nunca ve los recorridos.
  ///
  /// Vive en el disco del dispositivo. Los de los empleados no: van en su
  /// acceso, en la base ([ToursDelEmpleado]).
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

  /// Marca todos los recorridos del dueño como pendientes para el gimnasio
  /// actual.
  ///
  /// La llama el asistente de configuración inicial. Necesita que
  /// [TenantContextService] ya tenga el perfil cargado: sin `gym_id` no hay
  /// clave que escribir y sale en silencio.
  Future<void> markPending() async {
    final gymId = _sesion().gymId;
    if (gymId == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final tourId in AppTours.all) {
      await prefs.setBool(_pendingKey(gymId, tourId), true);
    }
  }

  Future<bool> isPending(String tourId) async {
    final sesion = _sesion();
    final gymId = sesion.gymId;
    if (gymId == null) return false;
    _recordarSesion(sesion);

    if (sesion.esEmpleado) {
      final vistos = await _vistosDelEmpleado(sesion.rol);
      // Sin acceso (null) o sin red no se muestra: mejor no enseñar un
      // recorrido que repetirlo. Sin red se reintenta en la siguiente visita.
      return vistos != null && !vistos.contains(tourId);
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey(gymId, tourId)) ?? false;
  }

  Future<Set<String>?> _vistosDelEmpleado(String rol) async {
    final enMemoria = _vistosEmpleado;
    if (enMemoria != null) return enMemoria;
    try {
      return _vistosEmpleado = await _toursDelEmpleado.vistos(rol);
    } catch (e) {
      AppLogger.warning('WelcomeTourService',
          'No se pudieron leer los recorridos vistos: $e');
      return null;
    }
  }

  /// Si ahora usa la app otra persona (cerró sesión y entró otra en el mismo
  /// teléfono) o la misma con otro rol, se olvida lo que se recordaba: los
  /// recorridos iniciados con el rol anterior no dicen nada de los del nuevo.
  void _recordarSesion(SesionTour sesion) {
    final clave = '${sesion.perfilId}|${sesion.rol}';
    if (clave == _sesionEnMemoria) return;
    _sesionEnMemoria = clave;
    _vistosEmpleado = null;
    _startedTours.clear();
    _attempts.clear();
  }

  /// Arranca el recorrido de una pantalla si sigue pendiente. Idempotente: se
  /// puede llamar en cada frame y solo corre una vez por sesión de app.
  ///
  /// * [tourId] - Uno de [AppTours].
  /// * [steps] - Las claves de los pasos, en el orden en que deben mostrarse.
  Future<void> startIfPending(String tourId, List<GlobalKey> steps) async {
    _recordarSesion(_sesion());
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
      _rolDelTour = _sesion().rol;
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
    final rol = _rolDelTour;
    final wasShown = _activeTourShown;
    _activeTour = null;
    _rolDelTour = null;
    _activeTourShown = false;
    if (finished == null) return;

    if (!wasShown) {
      _startedTours.remove(finished);
      _attempts[finished] = (_attempts[finished] ?? 0) + 1;
      return;
    }
    await _markSeen([finished], rol: rol);
  }

  /// El usuario tocó "Saltar". Cuenta como visto igual que llegar al final, y
  /// también solo para esta pantalla: saltarse la guía de Clientes no dice nada
  /// sobre la de Abonar, que el usuario todavía no ha visto.
  Future<void> _onDismiss() async {
    final dismissed = _activeTour;
    final rol = _rolDelTour;
    _activeTour = null;
    _rolDelTour = null;
    _activeTourShown = false;
    if (dismissed == null) return;
    await _markSeen([dismissed], rol: rol);
  }

  /// Cierra el recorrido que esté en pantalla SIN darlo por visto.
  ///
  /// Para cuando la app tiene que irse de la pantalla por su cuenta (le
  /// cambiaron el rol a quien la usa, o le retiraron el acceso): el recorrido
  /// no se terminó de ver y debe poder salir otra vez. Se suelta
  /// [_activeTour] ANTES de cerrarlo, para que `_onDismiss`/`_onFinish` no lo
  /// marquen.
  void cancelarRecorridoEnCurso() {
    final activo = _activeTour;
    if (activo == null) return;
    _activeTour = null;
    _rolDelTour = null;
    _activeTourShown = false;
    _startedTours.remove(activo);

    final showcaseView = _showcaseView;
    if (showcaseView != null && showcaseView.isShowcaseRunning) {
      showcaseView.dismiss();
    }
  }

  /// [rol]: con el que se vio (por defecto, el actual).
  Future<void> _markSeen(List<String> tourIds, {String? rol}) async {
    final sesion = _sesion();
    final gymId = sesion.gymId;
    if (gymId == null) return;

    if (sesion.esEmpleado) {
      final rolVisto = rol ?? sesion.rol;
      // Lo que se recuerda en memoria es del rol actual.
      if (rolVisto == sesion.rol) _vistosEmpleado?.addAll(tourIds);
      for (final tourId in tourIds) {
        try {
          await _toursDelEmpleado.marcarVisto(rolVisto, tourId);
        } catch (e) {
          // En esta sesión ya no se repite (queda en memoria); si no llegó a
          // la base, se volverá a ver una vez más en otra sesión.
          AppLogger.warning('WelcomeTourService',
              'No se pudo guardar el recorrido visto: $e');
        }
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    for (final tourId in tourIds) {
      await prefs.remove(_pendingKey(gymId, tourId));
    }
  }

  @visibleForTesting
  Future<void> marcarVistosParaPruebas(List<String> tourIds, {String? rol}) =>
      _markSeen(tourIds, rol: rol);
}

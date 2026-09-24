import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Las tablas cuyos cambios se escuchan (están en la publicación
/// `supabase_realtime`, migración `cambios_en_vivo`).
enum TablaEnVivo {
  clientes('users'),
  productos('products'),
  categorias('product_categories'),
  ingresos('ingresos'),
  accesos('access_logs');

  const TablaEnVivo(this.nombre);

  /// Nombre de la tabla en la base de datos.
  final String nombre;
}

/// Avisa cuando otro teléfono del gimnasio cambia algo (un cliente, un abono,
/// una venta, una entrada), para que las pantallas abiertas se recarguen
/// solas en vez de tener que refrescar a mano.
///
/// Un solo canal de Realtime por gimnasio, filtrado por `gym_id`. Los
/// cambios llegan en ráfagas (una venta toca `ingresos` y `products`), así que
/// se juntan durante [_espera] y se avisa una sola vez con todas las tablas.
///
/// Los borrados no llegan: Postgres solo manda la llave del registro
/// borrado, sin `gym_id` para filtrarlo. Se ven al siguiente cambio o al
/// refrescar.
class CambiosEnVivoService extends GetxService with WidgetsBindingObserver {
  /// [seguirSesion] en false solo para pruebas: no abre el canal.
  CambiosEnVivoService({this.seguirSesion = true});

  final bool seguirSesion;

  static const _espera = Duration(seconds: 1);

  /// Si la app estuvo en segundo plano más que esto, al volver se recarga
  /// todo: el canal pudo haberse caído y perdido cambios.
  static const _ausenciaLarga = Duration(seconds: 20);

  final _cambios = StreamController<Set<TablaEnVivo>>.broadcast();
  final _pendientes = <TablaEnVivo>{};
  Timer? _agrupar;
  RealtimeChannel? _canal;
  String? _gymDelCanal;
  bool _suscritoAntes = false;
  DateTime? _enSegundoPlanDesde;
  Worker? _alCambiarSesion;

  /// Avisos de cambios en cualquiera de [tablas]. Sin el servicio registrado
  /// (pruebas) no avisa nunca.
  static Stream<void> cambiosEn(Set<TablaEnVivo> tablas) {
    if (!Get.isRegistered<CambiosEnVivoService>()) return const Stream.empty();
    return Get.find<CambiosEnVivoService>()
        ._cambios
        .stream
        .where((cambiadas) => cambiadas.any(tablas.contains));
  }

  @override
  void onInit() {
    super.onInit();
    if (!seguirSesion) return;
    WidgetsBinding.instance.addObserver(this);
    final tenant = TenantContextService.to;
    _alCambiarSesion = ever(tenant.staffProfileRx, (_) => _abrirCanal());
    _abrirCanal();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _alCambiarSesion?.dispose();
    _agrupar?.cancel();
    _cerrarCanal();
    _cambios.close();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _enSegundoPlanDesde = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final desde = _enSegundoPlanDesde;
      _enSegundoPlanDesde = null;
      if (desde != null && DateTime.now().difference(desde) > _ausenciaLarga) {
        anotar(TablaEnVivo.values);
      }
    }
  }

  /// Abre el canal del gimnasio de la sesión; sin sesión, lo cierra. Al
  /// cambiar de cuenta se cierra el del gimnasio anterior.
  void _abrirCanal() {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == _gymDelCanal && _canal != null) return;

    _cerrarCanal();
    if (gymId == null || gymId.isEmpty) return;

    final supabase = Supabase.instance.client;
    var canal = supabase.channel('cambios-en-vivo:$gymId');
    for (final tabla in TablaEnVivo.values) {
      canal = canal.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tabla.nombre,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'gym_id',
          value: gymId,
        ),
        callback: (_) => anotar([tabla]),
      );
    }

    _gymDelCanal = gymId;
    _suscritoAntes = false;
    _canal = canal.subscribe((estado, error) {
      switch (estado) {
        case RealtimeSubscribeStatus.subscribed:
          // Al reconectarse (se fue la red, la app estuvo dormida) pudieron
          // perderse cambios: se recarga todo una vez.
          if (_suscritoAntes) anotar(TablaEnVivo.values);
          _suscritoAntes = true;
          AppLogger.info('CambiosEnVivo', 'Escuchando cambios del gimnasio');
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
          // El cliente de Realtime reintenta solo.
          AppLogger.warning(
              'CambiosEnVivo', 'Canal con problemas ($estado): $error');
        case RealtimeSubscribeStatus.closed:
          break;
      }
    });
  }

  void _cerrarCanal() {
    final canal = _canal;
    _canal = null;
    _gymDelCanal = null;
    if (canal != null) {
      unawaited(Supabase.instance.client.removeChannel(canal));
    }
  }

  /// Registra que cambiaron [tablas]; se avisa pasado [_espera], junto con lo
  /// que cambie mientras tanto.
  @visibleForTesting
  void anotar(Iterable<TablaEnVivo> tablas) {
    _pendientes.addAll(tablas);
    _agrupar ??= Timer(_espera, () {
      _agrupar = null;
      if (_pendientes.isEmpty || _cambios.isClosed) return;
      final cambiadas = Set<TablaEnVivo>.of(_pendientes);
      _pendientes.clear();
      _cambios.add(cambiadas);
    });
  }
}

/// Para controladores de pantallas que deben recargarse solas cuando otro
/// teléfono cambia sus datos.
///
/// Si llega otro aviso mientras se recarga, se vuelve a recargar al terminar
/// (una vez), en vez de encimar consultas.
mixin RecargaEnVivoMixin on GetxController {
  StreamSubscription<void>? _enVivo;
  bool _recargando = false;
  bool _otraVez = false;

  /// Llama a [recargar] cada vez que cambia alguna de [tablas]. [recargar]
  /// debe ser silenciosa: sin spinner y sin mensajes de error, porque el
  /// usuario no la pidió.
  void recargarAlCambiar(
    Set<TablaEnVivo> tablas,
    Future<void> Function() recargar,
  ) {
    _enVivo?.cancel();
    _enVivo = CambiosEnVivoService.cambiosEn(tablas).listen((_) async {
      if (_recargando) {
        _otraVez = true;
        return;
      }
      _recargando = true;
      try {
        do {
          _otraVez = false;
          await recargar();
        } while (_otraVez && !isClosed);
      } catch (e) {
        AppLogger.error(runtimeType.toString(), 'Error al recargar en vivo', e);
      } finally {
        _recargando = false;
      }
    });
  }

  @override
  void onClose() {
    _enVivo?.cancel();
    super.onClose();
  }
}

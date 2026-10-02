import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/app_logger.dart';
import 'cambios_en_vivo_service.dart';
import 'storage_service.dart';
import 'tenant_context_service.dart';

/// Las fotos de los clientes, siempre descargadas en este teléfono.
///
/// Antes cada foto se bajaba la primera vez que se veía: en los teléfonos
/// donde no se registró al cliente, el aviso del lector era esa primera vez,
/// y la foto aparecía con un parpadeo. Además, aun con la foto guardada, se
/// pedía por internet un enlace firmado antes de mostrarla.
///
/// Ahora:
/// - al abrir la sesión y cada vez que otro teléfono agrega o cambia un
///   cliente (actualización en vivo), se descargan las fotos que falten;
/// - [archivo] devuelve la foto guardada al instante, sin internet;
/// - [prepararParaMostrar] la deja decodificada en memoria (el aviso del
///   lector la pide antes de salir, para que aparezca ya con la foto).
class FotosDeClientes extends GetxService {
  FotosDeClientes({BaseCacheManager? cache})
      : _cache = cache ?? DefaultCacheManager();

  static FotosDeClientes? get to =>
      Get.isRegistered<FotosDeClientes>() ? Get.find<FotosDeClientes>() : null;

  /// El mismo caché de disco que usa `CachedNetworkImage` (misma clave:
  /// [StorageService.stableKey]), así que lo que baja uno lo usa el otro.
  final BaseCacheManager _cache;

  /// Clave estable → archivo en disco. En memoria para leerlo sin esperar.
  final Map<String, File> _archivos = {};

  /// Ancho con que se decodifican: uno solo para listas, ficha y aviso, así
  /// la foto ya preparada sirve en cualquier pantalla.
  static const anchoDecodificado = 600;

  Worker? _alCambiarSesion;
  StreamSubscription<void>? _enVivo;
  bool _sincronizando = false;
  bool _otraVuelta = false;

  @override
  void onInit() {
    super.onInit();
    if (!Get.isRegistered<TenantContextService>()) return;
    final tenant = TenantContextService.to;
    _alCambiarSesion = ever(tenant.staffProfileRx, (_) => sincronizar());
    _enVivo = CambiosEnVivoService.cambiosEn({TablaEnVivo.clientes})
        .listen((_) => sincronizar());
    unawaited(sincronizar());
  }

  @override
  void onClose() {
    _alCambiarSesion?.dispose();
    _enVivo?.cancel();
    super.onClose();
  }

  /// Para las pruebas: como si [guardada] ya estuviera descargada en [f].
  @visibleForTesting
  void registrar(String guardada, File f) {
    final clave = StorageService.instance.stableKey(guardada);
    if (clave != null) _archivos[clave] = f;
  }

  /// La foto guardada en este teléfono, o null si todavía no se descarga.
  File? archivo(String? guardada) {
    final clave = StorageService.instance.stableKey(guardada);
    return clave == null ? null : _archivos[clave];
  }

  /// La imagen con la que se dibuja [archivo]: siempre la misma, para que la
  /// preparada de antemano sea la que se usa.
  static ImageProvider proveedor(File archivo) =>
      ResizeImage(FileImage(archivo), width: anchoDecodificado);

  /// Deja la foto lista para dibujarse sin espera. La descarga si hace falta.
  /// Nunca tarda más de [limite]: si no llega, el aviso sale igual.
  Future<void> prepararParaMostrar(
    String? guardada, {
    Duration limite = const Duration(milliseconds: 700),
  }) async {
    if (guardada == null || guardada.isEmpty) return;
    try {
      await Future(() async {
        final f = archivo(guardada) ?? await _asegurar(guardada);
        final contexto = Get.context;
        if (f == null || contexto == null || !contexto.mounted) return;
        await precacheImage(proveedor(f), contexto);
      }).timeout(limite);
    } catch (_) {
      // Sin la foto a tiempo, el aviso la carga como antes.
    }
  }

  /// Descarga las fotos de los clientes del gimnasio que falten. Si llega
  /// otro cambio mientras corre, da una vuelta más al terminar.
  Future<void> sincronizar() async {
    if (_sincronizando) {
      _otraVuelta = true;
      return;
    }
    _sincronizando = true;
    try {
      do {
        _otraVuelta = false;
        await _sincronizarUnaVez();
      } while (_otraVuelta);
    } catch (e) {
      AppLogger.warning('FotosDeClientes', 'No se pudieron preparar: $e');
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _sincronizarUnaVez() async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return;

    final filas = await Supabase.instance.client
        .from('users')
        .select('photo_url')
        .eq('gym_id', gymId)
        .not('photo_url', 'is', null);
    final fotos = [
      for (final f in filas)
        if ((f['photo_url'] as String?)?.isNotEmpty ?? false)
          f['photo_url'] as String,
    ];

    // De cuatro en cuatro: sin saturar la red del gimnasio.
    for (var i = 0; i < fotos.length; i += 4) {
      await Future.wait(fotos.skip(i).take(4).map(_asegurar));
    }

    // Las de clientes que ya no existen (o fotos que se cambiaron) se quitan
    // de este teléfono.
    final vigentes = {
      for (final f in fotos) StorageService.instance.stableKey(f),
    };
    for (final clave in _archivos.keys.toList()) {
      if (vigentes.contains(clave)) continue;
      _archivos.remove(clave);
      unawaited(_cache.removeFile(clave));
    }
  }

  /// Que [guardada] esté en disco: la busca en el caché y, si no está (o es
  /// una foto nueva), la descarga.
  Future<File?> _asegurar(String guardada) async {
    final clave = StorageService.instance.stableKey(guardada);
    if (clave == null) return null;
    try {
      final enDisco = await _cache.getFileFromCache(clave);
      if (enDisco != null) return _archivos[clave] = enDisco.file;

      final url = await StorageService.instance.signedUrl(guardada);
      if (url == null) return null;
      final bajada = await _cache.downloadFile(url, key: clave);
      return _archivos[clave] = bajada.file;
    } catch (e) {
      AppLogger.warning('FotosDeClientes', 'No se pudo bajar "$clave": $e');
      return null;
    }
  }
}

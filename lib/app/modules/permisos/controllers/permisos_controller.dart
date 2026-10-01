import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/services/permisos_app.dart';
import '../../../routes/app_pages.dart';

/// La pantalla "Permisos de la app": se piden todos juntos, una vez por
/// teléfono, antes de entrar a Inicio. Desde Configuración sirve para ver cómo
/// quedaron y corregirlos.
class PermisosController extends GetxController {
  PermisosController({SolicitudPermisos? solicitud, bool? desdeConfiguracion})
      : solicitud = solicitud ?? SolicitudPermisosSistema(),
        desdeConfiguracion = desdeConfiguracion ?? _abiertaDesdeConfiguracion();

  static bool _abiertaDesdeConfiguracion() {
    final argumentos = Get.arguments;
    return argumentos is Map && argumentos['desdeConfiguracion'] == true;
  }

  final SolicitudPermisos solicitud;

  /// Abierta desde Configuración, para revisar, y no al entrar por primera
  /// vez.
  final bool desdeConfiguracion;

  final estados = <PermisoApp, EstadoPermiso>{}.obs;
  final pidiendo = false.obs;

  /// Ya se contestaron: se muestra cómo quedó cada uno. Antes de preguntar no
  /// se muestra nada, porque para el sistema "sin preguntar" y "negado" se
  /// ven igual.
  final contestado = false.obs;

  AppLifecycleListener? _alVolver;
  int _revision = 0;
  bool _saliendo = false;

  List<PermisoApp> get permisos => solicitud.permisos;

  bool get hayBloqueados => estados.values.contains(EstadoPermiso.bloqueado);

  bool get hayNegados => estados.values.contains(EstadoPermiso.denegado);

  @override
  void onInit() {
    super.onInit();
    if (desdeConfiguracion) {
      contestado.value = true;
      _leerEstados();
    }
    // Al volver de los ajustes del teléfono se ve cómo quedaron.
    _alVolver = AppLifecycleListener(onResume: () {
      if (contestado.value && !pidiendo.value) _leerEstados();
    });
  }

  @override
  void onClose() {
    _saliendo = true;
    _revision++;
    solicitud.cancelar();
    _alVolver?.dispose();
    super.onClose();
  }

  Future<void> _leerEstados() async {
    final revision = ++_revision;
    try {
      final respuesta = await solicitud.estados();
      if (!_saliendo && revision == _revision) estados.assignAll(respuesta);
    } catch (e) {
      AppLogger.warning('PermisosApp', 'No se pudieron leer los permisos: $e');
    }
  }

  Future<void> _guardarRespuesta() async {
    try {
      await PermisosApp.marcarPedidos();
    } catch (e) {
      AppLogger.warning('PermisosApp', 'No se pudo guardar la respuesta: $e');
    }
  }

  /// Pide todos; el sistema muestra sus avisos uno tras otro.
  Future<void> permitir() async {
    if (pidiendo.value || _saliendo) return;
    final revision = ++_revision;
    pidiendo.value = true;
    try {
      Map<PermisoApp, EstadoPermiso> respuesta;
      try {
        respuesta = await solicitud.pedirTodos();
      } catch (e) {
        AppLogger.warning(
            'PermisosApp', 'No se pudieron pedir los permisos: $e');
        respuesta = {
          for (final permiso in permisos) permiso: EstadoPermiso.sinDato,
        };
      }
      if (_saliendo || revision != _revision) return;
      estados.assignAll(respuesta);
      contestado.value = true;
      await _guardarRespuesta();
    } finally {
      if (!_saliendo && revision == _revision) pidiendo.value = false;
    }
  }

  /// No se insiste: la pantalla queda en Configuración, y cada permiso se
  /// sigue pidiendo donde se usa.
  Future<void> ahoraNo() async {
    if (_saliendo) return;
    _cancelar();
    await _guardarRespuesta();
    _navegar();
  }

  void continuar() {
    if (_saliendo) return;
    _cancelar();
    _navegar();
  }

  void _cancelar() {
    _saliendo = true;
    _revision++;
    solicitud.cancelar();
    pidiendo.value = false;
  }

  void _navegar() {
    if (desdeConfiguracion) {
      Get.back();
    } else {
      Get.offAllNamed(Routes.HOME);
    }
  }

  Future<void> abrirAjustes() => solicitud.abrirAjustes();
}

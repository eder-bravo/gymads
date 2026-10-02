import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

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
      if (contestado.value) _leerEstados();
    });
  }

  @override
  void onClose() {
    _alVolver?.dispose();
    super.onClose();
  }

  Future<void> _leerEstados() async =>
      estados.assignAll(await solicitud.estados());

  /// Pide todos; el sistema muestra sus avisos uno tras otro.
  Future<void> permitir() async {
    if (pidiendo.value) return;
    pidiendo.value = true;
    try {
      estados.assignAll(await solicitud.pedirTodos());
      contestado.value = true;
      await PermisosApp.marcarPedidos();
    } finally {
      pidiendo.value = false;
    }
  }

  /// No se insiste: la pantalla queda en Configuración, y cada permiso se
  /// sigue pidiendo donde se usa.
  Future<void> ahoraNo() async {
    await PermisosApp.marcarPedidos();
    continuar();
  }

  void continuar() {
    if (desdeConfiguracion) {
      Get.back();
    } else {
      Get.offAllNamed(Routes.HOME);
    }
  }

  Future<void> abrirAjustes() => solicitud.abrirAjustes();
}

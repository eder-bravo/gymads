import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/permissions/staff_role.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/staff_acceso_model.dart';
import '../../../data/repositories/staff_acceso_repository.dart';
import '../../../data/services/cambios_en_vivo_service.dart';
import '../../../data/services/tenant_context_service.dart';

/// Accesos del personal del gimnasio.
///
/// Llegan hasta aquí el dueño y el encargado: la pantalla está oculta para el
/// resto y, por debajo, tanto la política RLS de lectura como las funciones de
/// escritura exigen `staff_puede('gestionar_accesos_staff')`. Además, cada uno
/// solo puede tocar accesos con un rol por debajo del suyo, de modo que un
/// encargado no puede nombrar ni degradar a otro encargado.
///
/// Se recarga sola cuando cambia un acceso (Realtime), para que el canje de un
/// código se vea al momento: el acceso pasa de "pendiente" a "activo" sin
/// salir de la pantalla. Como respaldo, mientras haya un código sin usar se
/// revisa también cada [_revisarPendientesCada]: si el aviso de Realtime no
/// llega (red, canal caído), el canje se ve igual en unos segundos.
class StaffAccesosController extends GetxController with RecargaEnVivoMixin {
  StaffAccesosController({StaffAccesoRepository? repository})
      : _repository = repository ?? StaffAccesoRepository();

  final StaffAccesoRepository _repository;

  static const _revisarPendientesCada = Duration(seconds: 4);
  Timer? _revisarPendientes;
  Worker? _alCambiarAccesos;
  bool _revisando = false;

  final RxList<StaffAccesoModel> accesos = <StaffAccesoModel>[].obs;

  // Separadas a propósito: guardar un acceso no debe congelar la lista.
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  bool get isOwner =>
      TenantContextService.to.can(Permission.gestionarAccesosStaff);

  /// Los roles que este usuario puede entregar. El dueño nunca está: se es
  /// dueño registrando el gimnasio, no canjeando un código.
  List<StaffRole> get rolesAsignables =>
      TenantContextService.to.rolesAsignables;

  /// Si este usuario puede tocar [acceso]. La lista muestra los que no puede
  /// (para que sepa quién hay en el equipo) pero sin acciones.
  bool puedeGestionar(StaffAccesoModel acceso) =>
      TenantContextService.to.puedeGestionarRol(acceso.rol);

  @override
  void onInit() {
    super.onInit();
    load();
    recargarAlCambiar({TablaEnVivo.personal}, _recargarEnSilencio);
    _alCambiarAccesos = ever(accesos, (_) => _vigilarPendientes());
  }

  @override
  void onClose() {
    _alCambiarAccesos?.dispose();
    _revisarPendientes?.cancel();
    super.onClose();
  }

  /// Revisa la lista cada pocos segundos solo mientras haya un código
  /// pendiente; en cuanto no queda ninguno, deja de hacerlo.
  void _vigilarPendientes() {
    final hayPendientes = accesos.any((a) => a.estaPendiente);
    if (!hayPendientes) {
      _revisarPendientes?.cancel();
      _revisarPendientes = null;
      return;
    }
    _revisarPendientes ??=
        Timer.periodic(_revisarPendientesCada, (_) => _revisarSiSeUsaron());
  }

  Future<void> _revisarSiSeUsaron() async {
    // En segundo plano no: al volver, CambiosEnVivo recarga todo.
    final estado = WidgetsBinding.instance.lifecycleState;
    if (_revisando || isClosed || isLoading.value) return;
    if (estado != null && estado != AppLifecycleState.resumed) return;
    _revisando = true;
    try {
      await _recargarEnSilencio();
    } catch (e) {
      AppLogger.warning('StaffAccesosController',
          'No se pudo revisar si se usaron los códigos: $e');
    } finally {
      _revisando = false;
    }
  }

  /// Sin spinner ni mensajes: el usuario no pidió la recarga. Si falla, el
  /// mixin lo deja en el registro.
  Future<void> _recargarEnSilencio() async =>
      accesos.assignAll(await _repository.getAll());

  Future<void> load() async {
    isLoading.value = true;
    try {
      accesos.assignAll(await _repository.getAll());
    } on StaffAccesoException catch (e) {
      SnackbarHelper.error('Error', e.message());
    } catch (e) {
      AppLogger.error('StaffAccesosController', 'Error al cargar accesos', e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Crea el acceso y devuelve su id y el código en claro para mostrarlo una
  /// vez. Devuelve null si falló (el usuario ya fue avisado).
  Future<({String id, String codigo})?> crear(
      String nombre, StaffRole rol) async {
    if (isSaving.value) return null;
    isSaving.value = true;
    try {
      final creado = await _repository.crear(nombre, rol);
      // Se relee en vez de construir la fila a mano: el estado y las fechas
      // los pone la base.
      await load();
      return creado;
    } on StaffAccesoException catch (e) {
      SnackbarHelper.error('No se pudo crear', e.message());
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  /// Cambia el rol de alguien que ya está trabajando, sin regenerar su código.
  Future<bool> cambiarRol(StaffAccesoModel acceso, StaffRole rol) async {
    if (isSaving.value || rol == acceso.rol) return false;
    isSaving.value = true;
    try {
      await _repository.cambiarRol(acceso.id, rol);
      _replace(acceso.copyWith(rol: rol));
      SnackbarHelper.success('Listo', '${acceso.nombre} ahora es ${rol.label}');
      return true;
    } on StaffAccesoException catch (e) {
      SnackbarHelper.error('No se pudo cambiar el rol', e.message());
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> renombrar(StaffAccesoModel acceso, String nombre) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    try {
      await _repository.renombrar(acceso.id, nombre);
      _replace(acceso.copyWith(nombre: nombre.trim()));
      SnackbarHelper.success('Listo', 'Nombre actualizado');
      return true;
    } on StaffAccesoException catch (e) {
      SnackbarHelper.error('No se pudo guardar', e.message());
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Emite un código nuevo. El dispositivo anterior pierde el acceso.
  Future<String?> regenerarCodigo(StaffAccesoModel acceso) async {
    if (isSaving.value) return null;
    isSaving.value = true;
    try {
      final codigo = await _repository.regenerarCodigo(acceso.id);
      await load();
      return codigo;
    } on StaffAccesoException catch (e) {
      SnackbarHelper.error('No se pudo regenerar', e.message());
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> revocar(StaffAccesoModel acceso) async {
    isSaving.value = true;
    try {
      await _repository.revocar(acceso.id);
      await load();
      SnackbarHelper.success('Listo', 'Acceso revocado');
    } on StaffAccesoException catch (e) {
      SnackbarHelper.error('No se pudo revocar', e.message());
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> eliminar(StaffAccesoModel acceso) async {
    isSaving.value = true;
    try {
      await _repository.eliminar(acceso.id);
      accesos.removeWhere((a) => a.id == acceso.id);
      SnackbarHelper.success('Listo', 'Acceso eliminado');
    } on StaffAccesoException catch (e) {
      SnackbarHelper.error('No se pudo eliminar', e.message());
    } finally {
      isSaving.value = false;
    }
  }

  void _replace(StaffAccesoModel saved) {
    final index = accesos.indexWhere((a) => a.id == saved.id);
    if (index != -1) accesos[index] = saved;
    accesos.refresh();
  }
}

import 'package:get/get.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/permissions/staff_role.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/staff_acceso_model.dart';
import '../../../data/repositories/staff_acceso_repository.dart';
import '../../../data/services/tenant_context_service.dart';

/// Accesos del personal del gimnasio.
///
/// Llegan hasta aquí el dueño y el encargado: la pantalla está oculta para el
/// resto y, por debajo, tanto la política RLS de lectura como las funciones de
/// escritura exigen `staff_puede('gestionar_accesos_staff')`. Además, cada uno
/// solo puede tocar accesos con un rol por debajo del suyo, de modo que un
/// encargado no puede nombrar ni degradar a otro encargado.
class StaffAccesosController extends GetxController {
  final StaffAccesoRepository _repository = StaffAccesoRepository();

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
  }

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

  /// Crea el acceso y devuelve el código en claro para mostrarlo una vez.
  /// Devuelve null si falló (el usuario ya fue avisado).
  Future<String?> crear(String nombre, StaffRole rol) async {
    if (isSaving.value) return null;
    isSaving.value = true;
    try {
      final codigo = await _repository.crear(nombre, rol);
      // Se relee en vez de construir la fila a mano: el id, el estado y las
      // fechas los pone la base.
      await load();
      return codigo;
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

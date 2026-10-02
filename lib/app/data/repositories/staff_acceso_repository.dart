import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/permissions/staff_role.dart';
import '../../core/utils/access_code_generator.dart';
import '../../core/utils/app_logger.dart';
import '../models/staff_acceso_model.dart';
import '../services/supabase_service.dart';
import '../services/tenant_query_helper.dart';

/// Accesos del personal. Lo usan el dueño y el encargado, cada uno solo sobre
/// los roles por debajo del suyo.
///
/// Las lecturas van directas a la tabla (protegidas por RLS owner-only) y
/// todas las escrituras pasan por funciones SECURITY DEFINER, igual que el
/// resto de operaciones sensibles del proyecto.
class StaffAccesoRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Lista los accesos del gimnasio, los más nuevos primero.
  Future<List<StaffAccesoModel>> getAll() async {
    try {
      final gymId = TenantQueryHelper.gymIdOrNull;
      if (gymId == null) return [];

      final response = await _supabase
          .from('staff_accesos')
          .select('*')
          .eq('gym_id', gymId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => StaffAccesoModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('StaffAccesoRepository', 'Error al listar accesos', e);
      throw _mapError(e);
    }
  }

  /// Crea un acceso con el rol indicado y devuelve el código en claro.
  ///
  /// Es la ÚNICA vez que ese código existe fuera del dispositivo: al servidor
  /// solo viaja su hash. Si el dueño lo pierde, hay que regenerarlo.
  ///
  /// El servidor vuelve a comprobar el rol: solo se puede entregar uno por
  /// debajo del propio, así que un encargado no puede nombrar a otro.
  Future<String> crear(String nombre, StaffRole rol) async {
    try {
      final codigo = AccessCodeGenerator.generar();

      await _supabase.rpc('crear_acceso_staff', params: {
        'p_nombre': nombre.trim(),
        'p_codigo_hash': AccessCodeGenerator.hash(codigo),
        'p_role': rol.value,
      });

      return codigo;
    } catch (e) {
      AppLogger.error('StaffAccesoRepository', 'Error al crear acceso', e);
      throw _mapError(e);
    }
  }

  /// Cambia el rol de un acceso, ya sea que esté pendiente o en uso.
  ///
  /// Si el empleado ya canjeó su código, su perfil cambia con él y verá el
  /// menú nuevo en cuanto su app relea el perfil. No hace falta regenerar el
  /// código ni volver a darlo de alta.
  Future<void> cambiarRol(String accesoId, StaffRole rol) async {
    try {
      await _supabase.rpc('cambiar_rol_staff', params: {
        'p_acceso_id': accesoId,
        'p_role': rol.value,
      });
    } catch (e) {
      AppLogger.error('StaffAccesoRepository', 'Error al cambiar el rol', e);
      throw _mapError(e);
    }
  }

  /// Cambia el nombre visible del empleado.
  Future<void> renombrar(String accesoId, String nombre) async {
    try {
      await _supabase.rpc('renombrar_acceso_staff', params: {
        'p_acceso_id': accesoId,
        'p_nombre': nombre.trim(),
      });
    } catch (e) {
      AppLogger.error('StaffAccesoRepository', 'Error al renombrar acceso', e);
      throw _mapError(e);
    }
  }

  /// Emite un código nuevo y desvincula el dispositivo anterior.
  ///
  /// Es el camino para "cambié de teléfono" o "perdí el código". Devuelve el
  /// código en claro, de nuevo por única vez.
  Future<String> regenerarCodigo(String accesoId) async {
    try {
      final codigo = AccessCodeGenerator.generar();

      await _supabase.rpc('regenerar_codigo_staff', params: {
        'p_acceso_id': accesoId,
        'p_codigo_hash': AccessCodeGenerator.hash(codigo),
      });

      return codigo;
    } catch (e) {
      AppLogger.error('StaffAccesoRepository', 'Error al regenerar código', e);
      throw _mapError(e);
    }
  }

  /// Corta el acceso conservando el registro.
  Future<void> revocar(String accesoId) async {
    try {
      await _supabase.rpc('revocar_acceso_staff', params: {
        'p_acceso_id': accesoId,
      });
    } catch (e) {
      AppLogger.error('StaffAccesoRepository', 'Error al revocar acceso', e);
      throw _mapError(e);
    }
  }

  /// Elimina el acceso y la cuenta del empleado.
  Future<void> eliminar(String accesoId) async {
    try {
      await _supabase.rpc('eliminar_acceso_staff', params: {
        'p_acceso_id': accesoId,
      });
    } catch (e) {
      AppLogger.error('StaffAccesoRepository', 'Error al eliminar acceso', e);
      throw _mapError(e);
    }
  }

  /// Traduce el error de Postgres a un fallo que la UI sabe explicar.
  StaffAccesoException _mapError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();

      if (msg.contains('no autorizado')) {
        return const StaffAccesoException(StaffAccesoFailure.notAllowed);
      }
      if (msg.contains('acceso no encontrado')) {
        return const StaffAccesoException(StaffAccesoFailure.notFound);
      }
      if (msg.contains('nombre es obligatorio')) {
        return const StaffAccesoException(StaffAccesoFailure.emptyName);
      }
      if (e.code == '42501') {
        return const StaffAccesoException(StaffAccesoFailure.notAllowed);
      }
    }
    return const StaffAccesoException(StaffAccesoFailure.unknown);
  }
}

/// Motivos por los que una operación sobre accesos puede fallar.
enum StaffAccesoFailure {
  /// Falta el permiso, o el acceso tiene un rol igual o superior al propio.
  notAllowed,

  /// El acceso ya no existe o no pertenece a este gimnasio.
  notFound,

  emptyName,

  unknown,
}

class StaffAccesoException implements Exception {
  final StaffAccesoFailure kind;
  const StaffAccesoException(this.kind);

  String message() {
    switch (kind) {
      case StaffAccesoFailure.notAllowed:
        return 'No puedes gestionar ese acceso. Solo el dueño y el encargado '
            'administran al personal, y cada uno solo sobre los roles por '
            'debajo del suyo.';
      case StaffAccesoFailure.notFound:
        return 'Ese acceso ya no existe. Actualiza la lista.';
      case StaffAccesoFailure.emptyName:
        return 'Escribe el nombre del empleado.';
      case StaffAccesoFailure.unknown:
        return 'No se pudo completar la operación. Intenta de nuevo.';
    }
  }

  @override
  String toString() => 'StaffAccesoException($kind)';
}

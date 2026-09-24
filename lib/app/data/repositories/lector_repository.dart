import '../../core/utils/app_logger.dart';
import '../services/lector_red_service.dart';
import '../services/supabase_service.dart';

/// Un lector que el gimnasio tiene registrado.
class LectorRegistrado {
  const LectorRegistrado({required this.id, this.ultimaIp, this.version});

  /// MAC del aparato: su identidad aunque cambie de IP.
  final String id;
  final String? ultimaIp;
  final String? version;

  String get nombre => LectorEnRed.nombreDeId(id);

  factory LectorRegistrado.fromJson(Map<String, dynamic> json) =>
      LectorRegistrado(
        id: json['id'] as String,
        ultimaIp: json['ultima_ip'] as String?,
        version: json['version'] as String?,
      );
}

/// Qué lector tiene el gimnasio, guardado en el servidor.
///
/// Antes eso vivía solo en el teléfono que lo configuró: el de mostrador (que
/// es el que recibe los avisos), una reinstalación o un teléfono nuevo no
/// sabían que el gimnasio tenía lector. Con esto, todos lo saben y lo
/// buscan en la red por su id.
///
/// Es un espejo: quien decide a qué gimnasio pertenece un lector es el
/// aparato. Por eso aquí ningún fallo es grave: se registra y se sigue.
///
/// El gimnasio llega siempre por parámetro, no se lee de la sesión: quien
/// llama ya lo capturó, y si la sesión cambia a la mitad no se mezcla un
/// gimnasio con otro.
class LectorRepository {
  static const _tabla = 'lectores';

  /// Los lectores de [gymId]. Lista vacía si no tiene; null si no se pudo
  /// preguntar (sin conexión): no es lo mismo "no tiene" que "no sé".
  Future<List<LectorRegistrado>?> delGimnasio(String gymId) async {
    try {
      final filas = await SupabaseService.client
          .from(_tabla)
          .select('id, ultima_ip, version')
          .eq('gym_id', gymId)
          .order('visto_en', ascending: false);
      return (filas as List)
          .map((f) => LectorRegistrado.fromJson(f as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.warning('LectorRepository', 'No se pudieron leer: $e');
      return null;
    }
  }

  /// Deja [lector] registrado en [gymId], o actualiza su IP.
  ///
  /// Dar de alta es de quien administra el lector ([puedeDarDeAlta]: dueño,
  /// encargado); cualquier otro del personal solo actualiza la IP de uno ya
  /// registrado (el teléfono de mostrador que lo reencuentra en otra
  /// dirección).
  Future<void> registrar(
    LectorEnRed lector, {
    required String gymId,
    required bool puedeDarDeAlta,
  }) async {
    final id = lector.id;
    // Firmware anterior a 6.0 no dice su id: no hay con qué registrarlo.
    if (id == null || id.isEmpty) return;

    final datos = {
      'ultima_ip': lector.ip,
      'version': lector.version,
      'visto_en': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      if (puedeDarDeAlta) {
        await SupabaseService.client.from(_tabla).upsert(
            {'gym_id': gymId, 'id': id, ...datos},
            onConflict: 'gym_id,id');
      } else {
        await SupabaseService.client
            .from(_tabla)
            .update(datos)
            .eq('gym_id', gymId)
            .eq('id', id);
      }
    } catch (e) {
      AppLogger.warning('LectorRepository', 'No se pudo registrar: $e');
    }
  }

  /// Lo quita de [gymId] (al desvincularlo).
  Future<void> quitar({required String gymId, required String id}) async {
    try {
      await SupabaseService.client
          .from(_tabla)
          .delete()
          .eq('gym_id', gymId)
          .eq('id', id);
    } catch (e) {
      AppLogger.warning('LectorRepository', 'No se pudo quitar: $e');
    }
  }
}

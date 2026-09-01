import 'package:flutter/foundation.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/access_log_model.dart';
import 'tenant_query_helper.dart';

class AccessLogService {
  static final _supabase = Supabase.instance.client;

  /// Tiempo mínimo entre dos pases del mismo cliente cuando las salidas están
  /// activas. Sin esto, pasar la tarjeta dos veces seguidas por nervios
  /// registraría una salida inmediata.
  static const Duration _antirrebote = Duration(minutes: 1);

  /// Registra el acceso de un cliente y devuelve qué se registró.
  ///
  /// Con [registrarSalidas] apagado (lo normal) solo se registran entradas, y
  /// una segunda pasada el mismo día se ignora. Encendido, el pase alterna:
  /// si la última marca del día fue una entrada, la siguiente es la salida.
  ///
  /// Devuelve el tipo registrado ('entrada' o 'salida'), o null si no se
  /// registró nada — porque ya estaba marcado o por un fallo.
  static Future<String?> registerAccess({
    required String userId,
    required String userName,
    required String userNumber,
    required String method, // 'qr' o 'rfid'
    required String staffUser,
    bool registrarSalidas = false,
  }) async {
    try {
      // La jornada empieza a la 1:00 AM: alguien que entrena de noche sigue
      // contando como el mismo día de gimnasio.
      final now = DateTime.now();
      final DateTime startOfDay;
      if (now.hour < 1) {
        final yesterday = now.subtract(const Duration(days: 1));
        startOfDay =
            DateTime(yesterday.year, yesterday.month, yesterday.day, 1, 0, 0);
      } else {
        startOfDay = DateTime(now.year, now.month, now.day, 1, 0, 0);
      }
      final endOfDay = startOfDay.add(const Duration(hours: 24));

      final ultimo = await _ultimoAccesoDelDia(userId, startOfDay, endOfDay);

      final String accessType;
      if (!registrarSalidas) {
        // Modo solo entradas: una por jornada.
        if (ultimo != null) {
          AppLogger.info('AccessLogService',
              'Ya existe una entrada registrada para hoy');
          return null;
        }
        accessType = 'entrada';
      } else {
        if (ultimo != null &&
            now.difference(ultimo.accessTime) < _antirrebote) {
          AppLogger.info('AccessLogService',
              'Pase repetido dentro del margen de rebote, se ignora');
          return null;
        }
        // Alterna: tras una entrada toca la salida, y viceversa.
        accessType = ultimo?.accessType == 'entrada' ? 'salida' : 'entrada';
      }

      AppLogger.info('AccessLogService',
          'Registrando acceso (tipo: $accessType, método: $method)');

      final accessData = TenantQueryHelper.withTenant({
        'user_id': userId,
        'user_name': userName,
        'user_number': userNumber,
        'access_type': accessType,
        'method': method,
        'staff_user': staffUser,
        'access_time': now.toIso8601String(),
      });

      await _supabase.from('access_logs').insert(accessData).select();

      AppLogger.info('AccessLogService', 'Acceso registrado exitosamente');
      return accessType;
    } catch (e) {
      AppLogger.error('AccessLogService', 'Fallo al registrar el acceso', e);
      if (e is PostgrestException) {
        AppLogger.error('AccessLogService', 'Código de error de base de datos: ${e.code}');
      }
      return null;
    }
  }

  /// Última marca del cliente dentro de la jornada, para decidir si toca
  /// entrada o salida.
  ///
  /// Filtra por sucursal: sin ese filtro, la marca de otra sede haría creer
  /// que el cliente ya está dentro de esta.
  static Future<AccessLogModel?> _ultimoAccesoDelDia(
      String userId, DateTime desde, DateTime hasta) async {
    final branchId = TenantQueryHelper.branchIdOrNull;
    var query = _supabase.from('access_logs').select().eq('user_id', userId);

    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }

    final response = await query
        .gte('access_time', desde.toIso8601String())
        .lt('access_time', hasta.toIso8601String())
        .order('access_time', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;
    return AccessLogModel.fromJson(response.first);
  }

  /// Obtiene el último acceso de un usuario específico
  static Future<AccessLogModel?> getLastUserAccess(String userId) async {
    try {
      final response = await _supabase
          .from('access_logs')
          .select()
          .eq('user_id', userId)
          .order('access_time', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return AccessLogModel.fromJson(response.first);
      }

      return null;
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al obtener último acceso', e);
      return null;
    }
  }

  /// Obtiene los accesos de hoy
  static Future<List<AccessLogModel>> getTodayAccesses() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final branchId = TenantQueryHelper.branchIdOrNull;
      var query = _supabase.from('access_logs').select();

      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }

      final response = await query
          .gte('access_time', startOfDay.toIso8601String())
          .lt('access_time', endOfDay.toIso8601String())
          .order('access_time', ascending: false);

      return response
          .map<AccessLogModel>((json) => AccessLogModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al obtener accesos de hoy', e);
      return [];
    }
  }

  /// Obtiene los accesos de un usuario en un rango de fechas
  static Future<List<AccessLogModel>> getUserAccessHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.from('access_logs').select().eq('user_id', userId);

      if (startDate != null) {
        query = query.gte('access_time', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('access_time', endDate.toIso8601String());
      }

      final response =
          await query.order('access_time', ascending: false).limit(limit);

      return response
          .map<AccessLogModel>((json) => AccessLogModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al obtener historial de accesos', e);
      return [];
    }
  }

  /// Obtiene estadísticas de accesos por día
  static Future<Map<String, int>> getAccessStatsByDay({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final today = DateTime.now();
      final start = startDate ?? today.subtract(const Duration(days: 7));
      final end = endDate ?? today;

      final response = await _supabase
          .from('access_logs')
          .select('access_time, access_type')
          .gte('access_time', start.toIso8601String())
          .lte('access_time', end.toIso8601String());

      final stats = <String, int>{};

      for (final record in response) {
        final accessTime = DateTime.parse(record['access_time']);
        final dayKey =
            '${accessTime.year}-${accessTime.month.toString().padLeft(2, '0')}-${accessTime.day.toString().padLeft(2, '0')}';

        stats[dayKey] = (stats[dayKey] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al obtener estadísticas de accesos', e);
      return {};
    }
  }

  /// Verifica si un usuario está actualmente dentro del gimnasio
  static Future<bool> isUserInside(String userId) async {
    try {
      final lastAccess = await getLastUserAccess(userId);

      if (lastAccess == null) {
        return false; // Si no hay registros, no está adentro
      }

      // El usuario está adentro si su último acceso fue una entrada
      return lastAccess.accessType == 'entrada';
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al verificar si el usuario está adentro', e);
      return false;
    }
  }

  /// Obtiene todos los logs de acceso ordenados por fecha más reciente
  static Future<List<AccessLogModel>?> getAllAccessLogs({int? limit}) async {
    try {
      AppLogger.info('AccessLogService', 'Obteniendo todos los logs de acceso desde Supabase');

      final branchId = TenantQueryHelper.branchIdOrNull;
      var query = _supabase.from('access_logs').select();

      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }

      var orderedQuery = query.order('access_time', ascending: false);

      if (limit != null) {
        orderedQuery = orderedQuery.limit(limit);
      }

      final response = await orderedQuery;

      AppLogger.info('AccessLogService', 'logs obtenidos desde Supabase');

      // Parsear de forma segura cada log
      final logs = <AccessLogModel>[];
      for (final logData in response) {
        try {
          final log = AccessLogModel.fromJson(logData);
          logs.add(log);
        } catch (e) {
          AppLogger.error('AccessLogService', 'Error parseando log individual', e);
          // Continuar con los otros logs aunque uno falle
        }
      }

      AppLogger.info('AccessLogService', '${logs.length} logs parseados exitosamente');

      return logs;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('AccessLogService', 'Error al obtener logs de acceso', e);
        AppLogger.error('AccessLogService', 'Tipo de error: ${e.runtimeType}');
        if (e is PostgrestException) {
          AppLogger.error('AccessLogService', 'PostgrestException - Message: ${e.message}');
          AppLogger.error('AccessLogService', 'PostgrestException - Details: ${e.details}');
        }
      }
      return null;
    }
  }

  /// Obtiene los usuarios que están actualmente dentro del gimnasio
  static Future<List<AccessLogModel>?> getUsersCurrentlyInside() async {
    try {
      AppLogger.info('AccessLogService', 'Obteniendo usuarios actualmente dentro del gimnasio');

      // Primero intentar usar la vista SQL
      try {
        final response =
            await _supabase.from('users_currently_inside').select();

        AppLogger.info('AccessLogService', 'usuarios obtenidos desde vista SQL');

        // Convertir la respuesta de la vista a AccessLogModel
        final users = <AccessLogModel>[];
        for (final userData in response) {
          try {
            final user = AccessLogModel.fromJson({
              'id': userData['user_id']?.toString() ?? '',
              'user_id': userData['user_id']?.toString() ?? '',
              'user_name': userData['user_name']?.toString() ?? '',
              'user_number': userData['user_number']?.toString() ?? '',
              'access_type': 'entrada',
              'method': userData['entry_method']?.toString() ?? 'rfid',
              'staff_user': 'sistema',
              'access_time': userData['entry_time'],
              'created_at': userData['entry_time'],
            });
            users.add(user);
          } catch (e) {
            AppLogger.error('AccessLogService', 'Error parseando usuario dentro', e);
            }
        }

        return users;
      } catch (e) {
        AppLogger.warning('AccessLogService', 'Vista SQL no disponible, usando método alternativo');

        // Método alternativo: usar función SQL directa
        return await _getUsersInsideAlternative();
      }
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al obtener usuarios dentro', e);
      return [];
    }
  }

  /// Método alternativo para obtener usuarios dentro usando lógica de aplicación
  static Future<List<AccessLogModel>?> _getUsersInsideAlternative() async {
    try {
      AppLogger.info('AccessLogService', 'Usando método alternativo para usuarios dentro');

      // Obtener todos los logs y calcular manualmente
      final allLogs = await getAllAccessLogs();
      if (allLogs == null) return [];

      final Map<String, AccessLogModel> lastAccessByUser = {};

      // Encontrar el último acceso de cada usuario
      for (final log in allLogs) {
        if (!lastAccessByUser.containsKey(log.userId) ||
            log.accessTime.isAfter(lastAccessByUser[log.userId]!.accessTime)) {
          lastAccessByUser[log.userId] = log;
        }
      }

      // Filtrar solo los que su último acceso fue una entrada
      final usersInside = lastAccessByUser.values
          .where((log) => log.accessType == 'entrada')
          .toList();

      AppLogger.info('AccessLogService', 'usuarios dentro calculados manualmente');

      return usersInside;
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error en método alternativo', e);
      return [];
    }
  }

  /// Obtiene logs de acceso para un usuario específico
  static Future<List<AccessLogModel>?> getUserAccessLogs(String userId,
      {int? limit}) async {
    try {
      AppLogger.info('AccessLogService', 'Obteniendo logs de acceso para usuario');

      var query = _supabase
          .from('access_logs')
          .select()
          .eq('user_id', userId)
          .order('access_time', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      AppLogger.info('AccessLogService', 'logs obtenidos para el usuario');

      return response
          .map<AccessLogModel>((log) => AccessLogModel.fromJson(log))
          .toList();
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al obtener logs del usuario', e);
      return null;
    }
  }

  /// Obtiene logs de acceso filtrados por fecha
  static Future<List<AccessLogModel>?> getAccessLogsByDate(
      DateTime startDate, DateTime endDate) async {
    try {
      AppLogger.info('AccessLogService', 'Obteniendo logs entre ${startDate.toIso8601String()} y ${endDate.toIso8601String()}');

      final branchId = TenantQueryHelper.branchIdOrNull;
      var query = _supabase.from('access_logs').select();

      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }

      final response = await query
          .gte('access_time', startDate.toIso8601String())
          .lte('access_time', endDate.toIso8601String())
          .order('access_time', ascending: false);

      AppLogger.info('AccessLogService', 'logs obtenidos en el rango de fechas');

      return response
          .map<AccessLogModel>((log) => AccessLogModel.fromJson(log))
          .toList();
    } catch (e) {
      AppLogger.error('AccessLogService', 'Error al obtener logs por fecha', e);
      return null;
    }
  }
}

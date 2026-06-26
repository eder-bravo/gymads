import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/access_log_model.dart';
import 'tenant_query_helper.dart';

class AccessLogService {
  static final _supabase = Supabase.instance.client;

  /// Registra un acceso (entrada o salida) en la base de datos
  static Future<bool> registerAccess({
    required String userId,
    required String userName,
    required String userNumber,
    required String accessType, // 'entrada' o 'salida'
    required String method, // 'qr' o 'rfid'
    required String staffUser,
  }) async {
    try {
      if (kDebugMode) {
        print('📝 [AccessLogService] Iniciando registro de acceso...');
        print('   🆔 User ID: $userId');
        print('   👤 User Name: $userName');
        print('   🔢 User Number: $userNumber');
        print('   🚪 Access Type: $accessType');
        print('   📱 Method: $method');
        print('   👨‍💼 Staff User: $staffUser');
        print('   🕐 Time: ${DateTime.now().toIso8601String()}');
      }

      // Verificar si ya existe una entrada en el día actual (desde 1:00 AM)
      final now = DateTime.now();
      DateTime startOfDay;

      // Si es antes de la 1:00 AM, considerar el día anterior
      if (now.hour < 1) {
        final yesterday = now.subtract(const Duration(days: 1));
        startOfDay =
            DateTime(yesterday.year, yesterday.month, yesterday.day, 1, 0, 0);
      } else {
        startOfDay = DateTime(now.year, now.month, now.day, 1, 0, 0);
      }

      final endOfDay = startOfDay.add(const Duration(hours: 24));

      if (kDebugMode) {
        print(
            '   📅 Verificando entradas desde: ${startOfDay.toIso8601String()}');
        print('   📅 Hasta: ${endOfDay.toIso8601String()}');
      }

      // Verificar si ya hay una entrada registrada en el rango de tiempo
      final existingAccess = await _supabase
          .from('access_logs')
          .select()
          .eq('user_id', userId)
          .eq('access_type', 'entrada')
          .gte('access_time', startOfDay.toIso8601String())
          .lt('access_time', endOfDay.toIso8601String())
          .limit(1);

      if (existingAccess.isNotEmpty) {
        if (kDebugMode) {
          print(
              '⚠️ [AccessLogService] Ya existe una entrada registrada para hoy');
          print(
              '   🕐 Entrada existente: ${existingAccess.first['access_time']}');
        }
        return false; // No registrar entrada duplicada
      }

      final accessData = TenantQueryHelper.withTenant({
        'user_id': userId,
        'user_name': userName,
        'user_number': userNumber,
        'access_type': accessType,
        'method': method,
        'staff_user': staffUser,
        'access_time': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('   📦 Data to insert: $accessData');
      }

      final response =
          await _supabase.from('access_logs').insert(accessData).select();

      if (kDebugMode) {
        print(
            '✅ [AccessLogService] Respuesta de Supabase: ${response.toString()}');
        print('✅ [AccessLogService] Acceso registrado exitosamente');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AccessLogService] Error al registrar acceso: $e');
        print('❌ [AccessLogService] Tipo de error: ${e.runtimeType}');
        if (e is PostgrestException) {
          print(
              '❌ [AccessLogService] PostgrestException - Message: ${e.message}');
          print(
              '❌ [AccessLogService] PostgrestException - Details: ${e.details}');
          print('❌ [AccessLogService] PostgrestException - Hint: ${e.hint}');
          print('❌ [AccessLogService] PostgrestException - Code: ${e.code}');
        }
      }
      return false;
    }
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
      if (kDebugMode) {
        print('❌ Error al obtener último acceso: $e');
      }
      return null;
    }
  }

  /// Determina si el próximo acceso debe ser entrada o salida
  static Future<String> determineAccessType(String userId) async {
    try {
      final lastAccess = await getLastUserAccess(userId);

      if (lastAccess == null) {
        // Si no hay registros previos, el primer acceso es entrada
        return 'entrada';
      }

      // Si el último acceso fue entrada, el siguiente debe ser salida
      // Si el último acceso fue salida, el siguiente debe ser entrada
      return lastAccess.accessType == 'entrada' ? 'salida' : 'entrada';
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al determinar tipo de acceso: $e');
      }
      // En caso de error, por defecto asumimos entrada
      return 'entrada';
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
      if (kDebugMode) {
        print('❌ Error al obtener accesos de hoy: $e');
      }
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
      if (kDebugMode) {
        print('❌ Error al obtener historial de accesos: $e');
      }
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
      if (kDebugMode) {
        print('❌ Error al obtener estadísticas de accesos: $e');
      }
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
      if (kDebugMode) {
        print('❌ Error al verificar si el usuario está adentro: $e');
      }
      return false;
    }
  }

  /// Obtiene todos los logs de acceso ordenados por fecha más reciente
  static Future<List<AccessLogModel>?> getAllAccessLogs({int? limit}) async {
    try {
      if (kDebugMode) {
        print('📊 Obteniendo todos los logs de acceso desde Supabase...');
      }

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

      if (kDebugMode) {
        print('✅ ${response.length} logs obtenidos desde Supabase');
      }

      // Parsear de forma segura cada log
      final logs = <AccessLogModel>[];
      for (final logData in response) {
        try {
          final log = AccessLogModel.fromJson(logData);
          logs.add(log);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error parseando log individual: $e');
            print('   Datos problemáticos: $logData');
          }
          // Continuar con los otros logs aunque uno falle
        }
      }

      if (kDebugMode) {
        print('✅ ${logs.length} logs parseados exitosamente');
      }

      return logs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener logs de acceso: $e');
        print('❌ Tipo de error: ${e.runtimeType}');
        if (e is PostgrestException) {
          print('❌ PostgrestException - Message: ${e.message}');
          print('❌ PostgrestException - Details: ${e.details}');
        }
      }
      return null;
    }
  }

  /// Obtiene los usuarios que están actualmente dentro del gimnasio
  static Future<List<AccessLogModel>?> getUsersCurrentlyInside() async {
    try {
      if (kDebugMode) {
        print('👥 Obteniendo usuarios actualmente dentro del gimnasio...');
      }

      // Primero intentar usar la vista SQL
      try {
        final response =
            await _supabase.from('users_currently_inside').select();

        if (kDebugMode) {
          print('✅ ${response.length} usuarios obtenidos desde vista SQL');
        }

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
              'method': userData['entry_method']?.toString() ?? 'qr',
              'staff_user': 'sistema',
              'access_time': userData['entry_time'],
              'created_at': userData['entry_time'],
            });
            users.add(user);
          } catch (e) {
            if (kDebugMode) {
              print('❌ Error parseando usuario dentro: $e');
              print('   Datos problemáticos: $userData');
            }
          }
        }

        return users;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Vista SQL no disponible, usando método alternativo: $e');
        }

        // Método alternativo: usar función SQL directa
        return await _getUsersInsideAlternative();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener usuarios dentro: $e');
      }
      return [];
    }
  }

  /// Método alternativo para obtener usuarios dentro usando lógica de aplicación
  static Future<List<AccessLogModel>?> _getUsersInsideAlternative() async {
    try {
      if (kDebugMode) {
        print('🔄 Usando método alternativo para usuarios dentro...');
      }

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

      if (kDebugMode) {
        print('✅ ${usersInside.length} usuarios dentro calculados manualmente');
      }

      return usersInside;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en método alternativo: $e');
      }
      return [];
    }
  }

  /// Obtiene logs de acceso para un usuario específico
  static Future<List<AccessLogModel>?> getUserAccessLogs(String userId,
      {int? limit}) async {
    try {
      if (kDebugMode) {
        print('📋 Obteniendo logs de acceso para usuario: $userId');
      }

      var query = _supabase
          .from('access_logs')
          .select()
          .eq('user_id', userId)
          .order('access_time', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      if (kDebugMode) {
        print('✅ ${response.length} logs obtenidos para el usuario');
      }

      return response
          .map<AccessLogModel>((log) => AccessLogModel.fromJson(log))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener logs del usuario: $e');
      }
      return null;
    }
  }

  /// Obtiene logs de acceso filtrados por fecha
  static Future<List<AccessLogModel>?> getAccessLogsByDate(
      DateTime startDate, DateTime endDate) async {
    try {
      if (kDebugMode) {
        print(
            '📅 Obteniendo logs entre ${startDate.toIso8601String()} y ${endDate.toIso8601String()}');
      }

      final response = await _supabase
          .from('access_logs')
          .select()
          .gte('access_time', startDate.toIso8601String())
          .lte('access_time', endDate.toIso8601String())
          .order('access_time', ascending: false);

      if (kDebugMode) {
        print('✅ ${response.length} logs obtenidos en el rango de fechas');
      }

      return response
          .map<AccessLogModel>((log) => AccessLogModel.fromJson(log))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener logs por fecha: $e');
      }
      return null;
    }
  }
}

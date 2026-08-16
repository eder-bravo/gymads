import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/services/supabase_service.dart';
import 'package:gymads/app/data/providers/api_provider.dart';
import 'package:gymads/app/data/services/tenant_query_helper.dart';

/// Proveedor para interactuar con Supabase API
class SupabaseApiProvider extends ApiProvider {
  final String table;

  SupabaseApiProvider({required this.table}) : super(model: table);

  @override
  String get urlBase => dotenv.env['SUPABASE_URL'] ?? '';

  @override
  Future<Map<String, dynamic>> getAll({Map<String, String>? headers}) async {
    try {
      AppLogger.info('SupabaseApiProvider', 'Obteniendo todos los registros de la tabla: $table');

      final branchId = TenantQueryHelper.branchIdOrNull;
      var query = SupabaseService.client.from(table).select();

      // Apply tenant filter if branch context available
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }

      final response = await query;

      AppLogger.info('SupabaseApiProvider', 'Respuesta de Supabase (getAll): registros');

      return {
        'error': false,
        'message': 'Datos obtenidos correctamente',
        'data': response
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en getAll', e);
            return {'error': true, 'message': e.toString(), 'data': null};
    }
  }

  @override
  Future<Map<String, dynamic>> get(String id,
      {Map<String, String>? headers}) async {
    try {
      final response = await SupabaseService.client
          .from(table)
          .select()
          .eq('id', id)
          .single();

      AppLogger.info('SupabaseApiProvider', 'Respuesta de Supabase (get)');

      return {
        'error': false,
        'message': 'Datos obtenidos correctamente',
        'data': response
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en get', e);
      return {'error': true, 'message': e.toString(), 'data': null};
    }
  }

  @override
  Future<Map<String, dynamic>> add(Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    try {
      AppLogger.info('SupabaseApiProvider', 'Insertando datos en tabla $table');

      // Add tenant data to insert payload
      final tenantData = TenantQueryHelper.withTenant(data);

      final response =
          await SupabaseService.client.from(table).insert(tenantData).select();

      AppLogger.info('SupabaseApiProvider', 'Respuesta de Supabase (add)');

      if (response.isEmpty) {
        return {
          'error': true,
          'message': 'Error al insertar datos o respuesta vacía',
          'data': null
        };
      }

      return {
        'error': false,
        'message': 'Datos añadidos correctamente',
        'data': response[0]
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en add', e);
      return {'error': true, 'message': e.toString(), 'data': null};
    }
  }

  @override
  Future<Map<String, dynamic>> addDocument(String id, Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    // En Supabase no se puede especificar el ID, así que agregamos el ID al objeto data
    data['id'] = id;
    return add(data, headers: headers);
  }

  @override
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    try {
      final response = await SupabaseService.client
          .from(table)
          .update(data)
          .eq('id', id)
          .select();

      AppLogger.info('SupabaseApiProvider', 'Respuesta de Supabase (update)');

      if (response.isEmpty) {
        return {
          'error': true,
          'message': 'Error al actualizar datos o respuesta vacía',
          'data': null
        };
      }

      return {
        'error': false,
        'message': 'Datos actualizados correctamente',
        'data': response[0]
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en update', e);
      return {'error': true, 'message': e.toString(), 'data': null};
    }
  }

  @override
  Future<Map<String, dynamic>> delete(String id,
      {Map<String, String>? headers}) async {
    try {
      final response = await SupabaseService.client
          .from(table)
          .delete()
          .eq('id', id)
          .select();

      AppLogger.info('SupabaseApiProvider', 'Respuesta de Supabase (delete)');

      return {
        'error': false,
        'message': 'Datos eliminados correctamente',
        'data': response
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en delete', e);
      return {'error': true, 'message': e.toString(), 'data': null};
    }
  }

  /// Método específico para obtener un usuario por su número
  Future<Map<String, dynamic>> getUserByNumber(String userNumber) async {
    try {
      AppLogger.info('SupabaseApiProvider', 'Buscando usuario por número');

      final response = await SupabaseService.client
          .from(table)
          .select()
          .eq('user_number',
              userNumber) // Cambiar de 'userNumber' a 'user_number'
          .limit(1);

      AppLogger.info('SupabaseApiProvider', 'Respuesta de Supabase (getUserByNumber)');

      if (response.isEmpty) {
        AppLogger.info('SupabaseApiProvider', 'No se encontró usuario con número');
        return {
          'error': false,
          'message': 'Usuario no encontrado',
          'data': null
        };
      }

      return {
        'error': false,
        'message': 'Usuario encontrado',
        'data': response[0]
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en getUserByNumber', e);
      return {'error': true, 'message': e.toString(), 'data': null};
    }
  }

  /// Método específico para obtener un usuario por su tarjeta RFID
  Future<Map<String, dynamic>> getUserByRfid(String rfidUid) async {
    try {
      AppLogger.info('SupabaseApiProvider', 'Buscando usuario por RFID');

      final response = await SupabaseService.client
          .from(table)
          .select()
          .eq('rfid_card', rfidUid)
          .limit(1);

      AppLogger.info('SupabaseApiProvider', 'Respuesta de Supabase (getUserByRfid)');

      if (response.isEmpty) {
        AppLogger.info('SupabaseApiProvider', 'No se encontró usuario con RFID');
        return {
          'error': false,
          'message': 'Usuario no encontrado',
          'data': null
        };
      }

      return {
        'error': false,
        'message': 'Usuario encontrado',
        'data': response[0]
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en getUserByRfid', e);
      return {'error': true, 'message': e.toString(), 'data': null};
    }
  }

  /// Método específico para obtener usuarios con información de membresía
  Future<Map<String, dynamic>> getUsersWithMembershipInfo() async {
    try {
      AppLogger.info('SupabaseApiProvider', 'Obteniendo usuarios con información de membresía');

      // Obtener usuarios y tipos de membresía por separado para evitar problemas de JOIN
      final usersResponse = await SupabaseService.client.from('users').select();

      final membershipTypesResponse =
          await SupabaseService.client.from('membership_types').select();

      AppLogger.info('SupabaseApiProvider', 'Usuarios obtenidos');
      AppLogger.info('SupabaseApiProvider', 'Tipos de membresía obtenidos');

      // Crear un mapa de precios por tipo de membresía
      final Map<String, double> membershipPrices = {};
      for (var type in membershipTypesResponse) {
        membershipPrices[type['name'].toString().toLowerCase()] =
            (type['price'] as num).toDouble();
      }

      AppLogger.info('SupabaseApiProvider', 'Mapa de precios');

      // Procesar usuarios y agregar precio correspondiente
      final List<Map<String, dynamic>> processedUsers = [];
      for (var user in usersResponse) {
        final userMap = Map<String, dynamic>.from(user);
        final membershipType =
            (user['membership_type'] ?? 'normal').toString().toLowerCase();

        // Buscar precio en el mapa, usar 480.0 como fallback
        userMap['membership_price'] = membershipPrices[membershipType] ?? 480.0;

        processedUsers.add(userMap);
      }

      return {
        'error': false,
        'message': 'Datos obtenidos correctamente',
        'data': processedUsers
      };
    } catch (e) {
      AppLogger.error('SupabaseApiProvider', 'Error en getUsersWithMembershipInfo', e);

      // Fallback: obtener solo usuarios con precio por defecto
      try {
        final fallbackResponse =
            await SupabaseService.client.from('users').select();

        final List<Map<String, dynamic>> usersWithDefaultPrice = [];
        for (var user in fallbackResponse) {
          final userMap = Map<String, dynamic>.from(user);
          userMap['membership_price'] = 480.0;
          usersWithDefaultPrice.add(userMap);
        }

        return {
          'error': false,
          'message': 'Datos obtenidos con precio por defecto',
          'data': usersWithDefaultPrice
        };
      } catch (fallbackError) {
        return {
          'error': true,
          'message': fallbackError.toString(),
          'data': null
        };
      }
    }
  }
}

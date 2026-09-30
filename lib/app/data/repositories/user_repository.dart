import 'dart:async';
import 'dart:io';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/fallo_al_guardar.dart';
import 'package:gymads/app/data/services/supabase_service.dart';
import 'package:gymads/app/data/services/tenant_query_helper.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/providers/api_provider.dart';
import 'package:gymads/app/data/providers/storage_provider.dart';

/// Repositorio para la gestión de usuarios
/// Esta clase implementa la lógica de negocio relacionada con usuarios
/// y utiliza un ApiProvider para acceder a los datos
class UserRepository {
  final ApiProvider _apiProvider;
  final StorageProvider _storageProvider = StorageProvider();

  UserRepository(this._apiProvider);

  /// Obtiene un usuario por su ID
  Future<UserModel?> getUserById(String id) async {
    try {
      final response = await _apiProvider.get(id);
      if (response['error'] || response['data'] == null) {
        AppLogger.error('UserRepository', 'Fallo al obtener usuario por ID');
        return null;
      }

      return UserModel.fromJson(response['data']);
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al obtener usuario', e);
      return null;
    }
  }

  /// El cliente con la tarjeta [rfidUid], o null si ninguno la tiene.
  ///
  /// Si no se pudo preguntar (sin internet, el servidor no contestó) lanza
  /// [ErrorAlBuscarTarjeta]: antes devolvía null igual que "no existe", y el
  /// aviso decía "Tarjeta no registrada" a un cliente que sí lo estaba.
  Future<UserModel?> getUserByRfid(String rfidUid) async {
    // Verificar si el provider es SupabaseApiProvider para usar el método específico
    final Map<String, dynamic> response;

    if (_apiProvider.runtimeType.toString().contains('SupabaseApiProvider')) {
      final supabaseProvider = _apiProvider as dynamic;
      response = await supabaseProvider.getUserByRfid(rfidUid);
    } else {
      // Fallback para otros providers: buscar en toda la lista
      response = await _apiProvider.getAll();

      if (response['error'] == true || response['data'] is! List) {
        AppLogger.error('UserRepository', 'Respuesta inválida al buscar por RFID');
        throw const ErrorAlBuscarTarjeta();
      }

      // Buscar el usuario que coincida con el rfid_card
      for (final item in response['data'] as List) {
        if (item is Map<String, dynamic> && item['rfid_card'] == rfidUid) {
          return UserModel.fromJson(item);
        }
      }
      return null;
    }

    // Procesar respuesta del método específico
    if (response['error'] == true) {
      AppLogger.error('UserRepository', 'Fallo al buscar usuario por RFID');
      throw const ErrorAlBuscarTarjeta();
    }

    final userData = response['data'];
    if (userData == null) return null;
    if (userData is Map<String, dynamic>) {
      return UserModel.fromJson(userData);
    }

    AppLogger.error('UserRepository', 'Formato de datos inesperado al buscar por RFID');
    throw const ErrorAlBuscarTarjeta();
  }

  /// Obtiene un usuario por su número de usuario (userNumber)
  Future<UserModel?> getUserByNumber(String userNumber) async {
    try {
      // Verificar si el provider es SupabaseApiProvider para usar el método específico
      Map<String, dynamic> response;
      
      if (_apiProvider.runtimeType.toString().contains('SupabaseApiProvider')) {
        final supabaseProvider = _apiProvider as dynamic;
        response = await supabaseProvider.getUserByNumber(userNumber);
      } else {
        // Fallback para otros providers: buscar en toda la lista
        response = await _apiProvider.getAll();

        if (response['error'] == true || response['data'] == null) {
          AppLogger.error('UserRepository', 'Respuesta inválida al buscar por número');
          return null;
        }

        final data = response['data'];
        if (data is! List) {
          AppLogger.error('UserRepository', 'Formato de datos inesperado al buscar por número');
          return null;
        }

        // Buscar el usuario que coincida con el userNumber
        for (var item in data) {
          if (item is Map<String, dynamic> && item['user_number'] == userNumber) {
            return UserModel.fromJson(item);
          }
        }

        return null;
      }

      // Procesar respuesta del método específico
      if (response['error'] == true) {
        AppLogger.error('UserRepository', 'Fallo al buscar usuario por número');
        return null;
      }

      if (response['data'] == null) {
        return null;
      }

      final userData = response['data'];
      if (userData is Map<String, dynamic>) {
        return UserModel.fromJson(userData);
      }

      AppLogger.error('UserRepository', 'Formato de datos inesperado al buscar por número');
      return null;
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al buscar usuario por número', e);
      return null;
    }
  }

  /// Obtiene todos los usuarios de la sucursal actual
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _apiProvider.getAll();

      if (response['error'] || response['data'] == null) {
        AppLogger.error('UserRepository', 'Fallo al obtener la lista de usuarios');
        return [];
      }

      final data = response['data'];
      if (data is! List) {
        AppLogger.error('UserRepository', 'Formato de datos inesperado en la lista de usuarios');
        return [];
      }

      final List<UserModel> users = [];

      for (var item in data) {
        if (item is Map<String, dynamic>) {
          try {
            users.add(UserModel.fromJson(item));
          } catch (e) {
            AppLogger.error('UserRepository', 'Fallo al procesar un usuario de la lista', e);
          }
        }
      }

      return users;
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al obtener la lista de usuarios', e);
      return [];
    }
  }

  /// Crea un cliente y devuelve su id. Si no se puede, lanza una excepción
  /// con el motivo ([GuardadoFallido], [NumeroDeClienteEnUso], o el error de
  /// conexión / [TimeoutException]).
  ///
  /// - La foto es obligatoria si se tomó: si no se puede subir, el cliente NO
  ///   se crea (antes se creaba sin foto, en silencio).
  /// - Idempotente: si un intento anterior sí se guardó pero la respuesta no
  ///   llegó (mala señal) y se vuelve a intentar, el número de cliente ya
  ///   existe con ese mismo cliente: se devuelve su id en vez de fallar.
  Future<String> crearCliente(UserModel user, {File? photoFile}) async {
    String? fotoSubida;
    if (photoFile != null) {
      fotoSubida = await _subirFoto(
        photoFile,
        // Nombre provisional: el id real aún no existe.
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      user = user.copyWith(photoUrl: fotoSubida);
    }

    try {
      final fila = await SupabaseService.client
          .from('users')
          .insert(TenantQueryHelper.withTenant(user.toJson()))
          .select('id')
          .single()
          .timeout(limiteAlGuardar);
      return fila['id'] as String;
    } catch (e) {
      final indice = restriccionUnicaViolada(e);
      if (indice == 'idx_users_branch_rfid_card') {
        await _borrarFotoSuelta(fotoSubida);
        throw const GuardadoFallido('Esa tarjeta ya es de otro cliente.');
      }
      if (indice == 'idx_users_branch_user_number') {
        final existente = await _clientePorNumero(user.userNumber);
        if (existente != null && esElMismoAlta(existente, user)) {
          // Ya se había guardado; la foto de este reintento sobra.
          await _borrarFotoSuelta(fotoSubida);
          return existente.id!;
        }
        await _borrarFotoSuelta(fotoSubida);
        throw const NumeroDeClienteEnUso();
      }
      await _borrarFotoSuelta(fotoSubida);
      rethrow;
    }
  }

  /// Compatibilidad: como [crearCliente], pero null si falla.
  Future<String?> addUser(UserModel user, {File? photoFile}) async {
    try {
      return await crearCliente(user, photoFile: photoFile);
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al crear el usuario', e);
      return null;
    }
  }

  /// Sube la foto de un cliente. Si no se puede, lanza [GuardadoFallido]: sin
  /// foto no se guarda nada.
  Future<String> _subirFoto(File foto, String nombre) async {
    if (!await foto.exists()) {
      throw const GuardadoFallido(
          'La foto ya no está disponible. Vuelve a tomarla.');
    }
    String? url;
    try {
      url = await _storageProvider
          .uploadUserPhoto(foto, nombre)
          .timeout(limiteAlGuardar);
    } on TimeoutException {
      url = null;
    }
    if (url == null) {
      throw const GuardadoFallido(
          'No se pudo guardar la foto. Revisa tu conexión e intenta de nuevo.');
    }
    return url;
  }

  /// Una foto que se subió para un guardado que al final no se hizo.
  Future<void> _borrarFotoSuelta(String? url) async {
    if (url == null) return;
    try {
      await _storageProvider.deleteUserPhoto(url);
    } catch (_) {
      // Una foto huérfana no afecta a nadie.
    }
  }

  Future<UserModel?> _clientePorNumero(String numero) async {
    try {
      var consulta = SupabaseService.client
          .from('users')
          .select()
          .eq('user_number', numero);
      final branchId = TenantQueryHelper.branchIdOrNull;
      if (branchId != null) consulta = consulta.eq('branch_id', branchId);
      final fila = await consulta.maybeSingle().timeout(limiteAlGuardar);
      return fila == null ? null : UserModel.fromJson(fila);
    } catch (_) {
      return null;
    }
  }

  /// Añade un nuevo usuario (versión original que devuelve bool para compatibilidad)
  Future<bool> addUserLegacy(UserModel user, {File? photoFile}) async {
    final userId = await addUser(user, photoFile: photoFile);
    return userId != null;
  }

  /// Agrega un usuario con ID específico
  Future<bool> addUserWithId(String id, UserModel user) async {
    try {
      final response = await _apiProvider.addDocument(id, user.toJson());
      return !response['error'];
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al agregar usuario con ID específico', e);
      return false;
    }
  }

  /// Actualiza un cliente. Si no se puede, lanza una excepción con el motivo
  /// ([GuardadoFallido], o el error de conexión / [TimeoutException]).
  ///
  /// La foto solo se toca si se manda una nueva, y es obligatoria: si no se
  /// puede subir, no se guarda nada (antes se guardaba el resto con la foto
  /// vieja). `UserModel.toJson()` incluye siempre `photo_url`, y varios
  /// formularios arman el modelo sin ella, así que enviarla vacía borraba la
  /// que ya estaba guardada. Como ninguna pantalla ofrece "quitar la foto",
  /// aquí un `photo_url` vacío significa *no la cambies*, nunca *bórrala*.
  Future<void> actualizarCliente(String id, UserModel user,
      {File? photoFile}) async {
    String? fotoAnterior;
    String? fotoNueva;

    if (photoFile != null) {
      // La foto vigente se lee de la BD y no del modelo: quien llama pone
      // `photoUrl` en null al mandar una foto nueva, de modo que el modelo
      // ya no la trae.
      fotoAnterior = (await getUserById(id))?.photoUrl ?? user.photoUrl;
      // Con el id real del cliente como nombre.
      fotoNueva = await _subirFoto(photoFile, id);
      user = user.copyWith(photoUrl: fotoNueva);
    }

    final payload = user.toJson();
    final photoUrl = payload['photo_url'] as String?;
    if (photoUrl == null || photoUrl.isEmpty) {
      payload.remove('photo_url');
    }

    final List<dynamic> filas;
    try {
      filas = await SupabaseService.client
          .from('users')
          .update(payload)
          .eq('id', id)
          .select('id')
          .timeout(limiteAlGuardar);
    } catch (e) {
      await _borrarFotoSuelta(fotoNueva);
      if (restriccionUnicaViolada(e) == 'idx_users_branch_rfid_card') {
        throw const GuardadoFallido('Esa tarjeta ya es de otro cliente.');
      }
      rethrow;
    }
    if (filas.isEmpty) {
      await _borrarFotoSuelta(fotoNueva);
      throw const GuardadoFallido('No se pudo guardar el cliente.');
    }

    // La anterior se borra al final, con la nueva ya confirmada en la BD.
    // Borrándola antes, un fallo en el update dejaba al cliente sin foto y
    // apuntando a un objeto que ya no existe.
    if (fotoNueva != null &&
        fotoAnterior != null &&
        fotoAnterior.isNotEmpty &&
        fotoAnterior != fotoNueva) {
      try {
        await _storageProvider.deleteUserPhoto(fotoAnterior);
      } catch (e) {
        AppLogger.warning(
            'UserRepository', 'No se pudo eliminar la foto anterior');
        // Un objeto huérfano es preferible a fallar una actualización válida
      }
    }
  }

  /// Compatibilidad (Abonar, check-in): como [actualizarCliente], pero
  /// devuelve false si falla.
  Future<bool> updateUser(String id, UserModel user, {File? photoFile}) async {
    try {
      await actualizarCliente(id, user, photoFile: photoFile);
      return true;
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al actualizar el usuario', e);
      return false;
    }
  }

  /// Elimina un usuario por su ID
  Future<bool> deleteUser(String id) async {
    try {
      // La foto se lee ANTES del delete: después de borrar la fila ya no hay
      // forma de saber qué objeto del bucket le pertenecía (el nombre del
      // archivo no contiene el id real del usuario).
      final foto = (await getUserById(id))?.photoUrl;

      final response = await _apiProvider.delete(id);

      if (response['error']) {
        AppLogger.error('UserRepository', 'Fallo al eliminar el usuario');
        return false;
      }

      // Se borra al final, con la fila ya eliminada: si el delete fallara
      // después de quitar la foto, el cliente quedaría apuntando a un objeto
      // inexistente.
      if (foto != null && foto.isNotEmpty) {
        try {
          await _storageProvider.deleteUserPhoto(foto);
        } catch (e) {
          AppLogger.warning('UserRepository', 'No se pudo eliminar la foto del usuario');
          // Un objeto huérfano es preferible a reportar como fallida una
          // eliminación que sí se completó en la base de datos
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al eliminar el usuario', e);
      return false;
    }
  }
}

/// El número de cliente ya lo tiene OTRO cliente (no es un reintento del
/// mismo alta). Quien llama genera otro número y vuelve a intentar.
class NumeroDeClienteEnUso implements Exception {
  const NumeroDeClienteEnUso();
}

/// Si [existente] (el que ya tiene ese número) es el mismo alta que [nuevo]:
/// un intento anterior que sí se guardó aunque la respuesta no llegó.
bool esElMismoAlta(UserModel existente, UserModel nuevo) {
  String limpio(String? t) => (t ?? '').trim().toLowerCase();
  return limpio(existente.name) == limpio(nuevo.name) &&
      limpio(existente.phone) == limpio(nuevo.phone);
}

/// No se pudo saber de quién es una tarjeta (sin internet, o el servidor no
/// contestó). No es lo mismo que una tarjeta sin registrar.
class ErrorAlBuscarTarjeta implements Exception {
  const ErrorAlBuscarTarjeta();

  @override
  String toString() => 'No se pudo buscar la tarjeta';
}

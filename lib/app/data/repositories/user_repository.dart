import 'dart:io';
import 'package:gymads/app/core/utils/app_logger.dart';
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

  /// Obtiene un usuario por su tarjeta RFID
  Future<UserModel?> getUserByRfid(String rfidUid) async {
    try {
      // Verificar si el provider es SupabaseApiProvider para usar el método específico
      Map<String, dynamic> response;
      
      if (_apiProvider.runtimeType.toString().contains('SupabaseApiProvider')) {
        final supabaseProvider = _apiProvider as dynamic;
        response = await supabaseProvider.getUserByRfid(rfidUid);
      } else {
        // Fallback para otros providers: buscar en toda la lista
        response = await _apiProvider.getAll();

        if (response['error'] == true || response['data'] == null) {
          AppLogger.error('UserRepository', 'Respuesta inválida al buscar por RFID');
          return null;
        }

        final data = response['data'];
        if (data is! List) {
          AppLogger.error('UserRepository', 'Formato de datos inesperado al buscar por RFID');
          return null;
        }

        // Buscar el usuario que coincida con el rfid_card
        for (var item in data) {
          if (item is Map<String, dynamic> && item['rfid_card'] == rfidUid) {
            return UserModel.fromJson(item);
          }
        }

        return null;
      }

      // Procesar respuesta del método específico
      if (response['error'] == true) {
        AppLogger.error('UserRepository', 'Fallo al buscar usuario por RFID');
        return null;
      }

      if (response['data'] == null) {
        return null;
      }

      final userData = response['data'];
      if (userData is Map<String, dynamic>) {
        return UserModel.fromJson(userData);
      }

      AppLogger.error('UserRepository', 'Formato de datos inesperado al buscar por RFID');
      return null;
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al buscar usuario por RFID', e);
      return null;
    }
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

  /// Agrega un nuevo usuario con foto
  /// Añade un nuevo usuario y devuelve su ID si es exitoso
  Future<String?> addUser(UserModel user, {File? photoFile}) async {
    try {
      // Si se proporciona una foto, primero la subimos a Supabase
      if (photoFile != null) {
        // Verificar que el archivo existe ANTES de leer sus metadatos
        // (photoFile.length() lanza PathNotFoundException si ya no existe)
        if (!await photoFile.exists()) {
          AppLogger.warning('UserRepository', 'La foto seleccionada ya no existe, se continúa sin foto');
          // Continuamos sin foto
        } else {
          // ID temporal para la foto (se usará el ID real cuando esté disponible)
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();

          final photoUrl = await _storageProvider.uploadUserPhoto(
            photoFile,
            tempId,
          );

          if (photoUrl != null) {
            // Actualizar el modelo de usuario con la URL de la foto
            user = user.copyWith(photoUrl: photoUrl);
          } else {
            AppLogger.error('UserRepository', 'Fallo al subir la foto del usuario');
            // Continuamos con la creación del usuario aunque no se pudo subir la foto
          }
        }
      }

      final response = await _apiProvider.add(user.toJson());

      if (!response['error'] && response['data'] != null) {
        return response['data']['id'] as String;
      } else {
        AppLogger.error('UserRepository', 'Fallo al crear el usuario');
        return null;
      }
    } catch (e) {
      AppLogger.error('UserRepository', 'Fallo al crear el usuario', e);
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

  /// Actualiza un usuario existente
  ///
  /// La foto solo se toca si se manda una nueva. `UserModel.toJson()` incluye
  /// siempre `photo_url`, y varios formularios arman el modelo sin ella, así
  /// que enviarla vacía borraba la que ya estaba guardada. Como ninguna
  /// pantalla ofrece "quitar la foto", aquí un `photo_url` vacío significa
  /// *no la cambies*, nunca *bórrala*.
  Future<bool> updateUser(String id, UserModel user, {File? photoFile}) async {
    try {
      String? fotoAnterior;
      String? fotoNueva;

      if (photoFile != null) {
        // La foto vigente se lee de la BD y no del modelo: quien llama pone
        // `photoUrl` en null al mandar una foto nueva, de modo que el modelo
        // ya no la trae.
        fotoAnterior = (await getUserById(id))?.photoUrl ?? user.photoUrl;

        // Verificar que el archivo existe ANTES de leer sus metadatos
        // (photoFile.length() lanza PathNotFoundException si ya no existe)
        if (!await photoFile.exists()) {
          AppLogger.warning('UserRepository', 'La foto seleccionada ya no existe, no se actualiza la foto');
        } else {
          fotoNueva = await _storageProvider.uploadUserPhoto(
            photoFile,
            id, // Usar el ID real del usuario para la foto
          );

          if (fotoNueva != null) {
            user = user.copyWith(photoUrl: fotoNueva);
          } else {
            // El resto de la edición (nombre, teléfono…) sí se guarda; la foto
            // anterior se queda como estaba.
            AppLogger.error('UserRepository', 'Fallo al subir la nueva foto del usuario');
          }
        }
      }

      final payload = user.toJson();
      final photoUrl = payload['photo_url'] as String?;
      if (photoUrl == null || photoUrl.isEmpty) {
        payload.remove('photo_url');
      }

      final response = await _apiProvider.update(id, payload);

      if (response['error']) {
        AppLogger.error('UserRepository', 'Fallo al actualizar el usuario');
        return false;
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
          AppLogger.warning('UserRepository', 'No se pudo eliminar la foto anterior');
          // Un objeto huérfano es preferible a fallar una actualización válida
        }
      }

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

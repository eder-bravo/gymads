import 'dart:io';
import 'package:flutter/foundation.dart';
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
        if (kDebugMode) {
          print('Error al obtener usuario por ID: ${response['message']}');
        }
        return null;
      }

      return UserModel.fromJson(response['data']);
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener usuario: $e');
      }
      return null;
    }
  }

  /// Obtiene un usuario por su tarjeta RFID
  Future<UserModel?> getUserByRfid(String rfidUid) async {
    try {
      if (kDebugMode) {
        print('🔍 Buscando usuario con RFID: $rfidUid');
      }

      // Verificar si el provider es SupabaseApiProvider para usar el método específico
      Map<String, dynamic> response;
      
      if (_apiProvider.runtimeType.toString().contains('SupabaseApiProvider')) {
        final supabaseProvider = _apiProvider as dynamic;
        response = await supabaseProvider.getUserByRfid(rfidUid);
        
        if (kDebugMode) {
          print('🔍 Respuesta getUserByRfid específico: $response');
        }
      } else {
        // Fallback para otros providers: buscar en toda la lista
        response = await _apiProvider.getAll();

        if (response['error'] == true || response['data'] == null) {
          if (kDebugMode) {
            print('❌ Error en la respuesta o datos nulos');
            print('Response: $response');
          }
          return null;
        }

        final data = response['data'];
        if (data is! List) {
          if (kDebugMode) {
            print('❌ Data no es una lista');
          }
          return null;
        }

        // Buscar el usuario que coincida con el rfid_card
        for (var item in data) {
          if (item is Map<String, dynamic> && item['rfid_card'] == rfidUid) {
            if (kDebugMode) {
              print('✅ Usuario encontrado en lista por RFID. Datos: $item');
            }
            return UserModel.fromJson(item);
          }
        }

        if (kDebugMode) {
          print('❌ No se encontró ningún usuario con RFID: $rfidUid');
        }
        return null;
      }

      // Procesar respuesta del método específico
      if (response['error'] == true) {
        if (kDebugMode) {
          print('❌ Error en getUserByRfid: ${response['message']}');
        }
        return null;
      }

      if (response['data'] == null) {
        if (kDebugMode) {
          print('ℹ️ Usuario con RFID $rfidUid no encontrado');
        }
        return null;
      }

      final userData = response['data'];
      if (userData is Map<String, dynamic>) {
        if (kDebugMode) {
          print('✅ Usuario encontrado por RFID. Datos: $userData');
        }
        return UserModel.fromJson(userData);
      }

      if (kDebugMode) {
        print('❌ Formato de datos incorrecto');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener usuario por RFID: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
      return null;
    }
  }

  /// Obtiene un usuario por su número de usuario (userNumber)
  Future<UserModel?> getUserByNumber(String userNumber) async {
    try {
      if (kDebugMode) {
        print('🔍 Buscando usuario con número: $userNumber');
      }

      // Verificar si el provider es SupabaseApiProvider para usar el método específico
      Map<String, dynamic> response;
      
      if (_apiProvider.runtimeType.toString().contains('SupabaseApiProvider')) {
        final supabaseProvider = _apiProvider as dynamic;
        response = await supabaseProvider.getUserByNumber(userNumber);
        
        if (kDebugMode) {
          print('🔍 Respuesta getUserByNumber específico: $response');
        }
      } else {
        // Fallback para otros providers: buscar en toda la lista
        response = await _apiProvider.getAll();

        if (response['error'] == true || response['data'] == null) {
          if (kDebugMode) {
            print('❌ Error en la respuesta o datos nulos');
            print('Response: $response');
          }
          return null;
        }

        final data = response['data'];
        if (data is! List) {
          if (kDebugMode) {
            print('❌ Data no es una lista');
          }
          return null;
        }

        // Buscar el usuario que coincida con el userNumber
        for (var item in data) {
          if (item is Map<String, dynamic> && item['user_number'] == userNumber) {
            if (kDebugMode) {
              print('✅ Usuario encontrado en lista. Datos: $item');
            }
            return UserModel.fromJson(item);
          }
        }

        if (kDebugMode) {
          print('❌ No se encontró ningún usuario con el número: $userNumber');
        }
        return null;
      }

      // Procesar respuesta del método específico
      if (response['error'] == true) {
        if (kDebugMode) {
          print('❌ Error en getUserByNumber: ${response['message']}');
        }
        return null;
      }

      if (response['data'] == null) {
        if (kDebugMode) {
          print('ℹ️ Usuario con número $userNumber no encontrado');
        }
        return null;
      }

      final userData = response['data'];
      if (userData is Map<String, dynamic>) {
        if (kDebugMode) {
          print('✅ Usuario encontrado. Datos: $userData');
        }
        return UserModel.fromJson(userData);
      }

      if (kDebugMode) {
        print('❌ Formato de datos incorrecto');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al obtener usuario por número: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
      return null;
    }
  }

  /// Obtiene todos los usuarios disponibles con precios de membresía
  Future<List<UserModel>> getAllUsers() async {
    try {
      // Verificar si el provider es SupabaseApiProvider para usar el método especializado
      Map<String, dynamic> response;
      
      if (_apiProvider.runtimeType.toString().contains('SupabaseApiProvider')) {
        final supabaseProvider = _apiProvider as dynamic;
        response = await supabaseProvider.getUsersWithMembershipInfo();
        
        if (kDebugMode) {
          print('Respuesta getAllUsers con precios: $response');
        }
      } else {
        // Fallback para otros providers
        response = await _apiProvider.getAll();
        if (kDebugMode) {
          print('Respuesta getAll (fallback): $response');
        }
      }
      
      if (response['error'] || response['data'] == null) {
        if (kDebugMode) {
          print('Error en getAllUsers: ${response['message']}');
        }
        return [];
      }

      final data = response['data'];
      if (data is! List) {
        if (kDebugMode) {
          print('Error: Los datos no son una lista');
        }
        return [];
      }

      final List<UserModel> users = [];

      for (var item in data) {
        if (item is Map<String, dynamic>) {
          try {
            users.add(UserModel.fromJson(item));
          } catch (e) {
            if (kDebugMode) {
              print('Error al procesar usuario: $e');
              print('Datos del usuario: $item');
            }
          }
        }
      }

      return users;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener usuarios: $e');
      }
      return [];
    }
  }

  /// Agrega un nuevo usuario con foto
  /// Añade un nuevo usuario y devuelve su ID si es exitoso
  Future<String?> addUser(UserModel user, {File? photoFile}) async {
    try {
      if (kDebugMode) {
        print('👤 Iniciando proceso de creación de usuario en UserRepository');
        print('👤 Usuario: ${user.name}');
        print('👤 ¿Tiene foto? ${photoFile != null}');
      }
      
      // Si se proporciona una foto, primero la subimos a Supabase
      if (photoFile != null) {
        if (kDebugMode) {
          print('👤 Procesando foto del usuario...');
          print('👤 Ruta de la foto: ${photoFile.path}');
          print('👤 Tamaño: ${(await photoFile.length() / 1024).toStringAsFixed(2)} KB');
        }
        
        // Verificar que el archivo existe
        if (!await photoFile.exists()) {
          if (kDebugMode) {
            print('❌ ERROR: El archivo de foto no existe físicamente: ${photoFile.path}');
          }
          // Continuamos sin foto
        } else {
          // ID temporal para la foto (se usará el ID real cuando esté disponible)
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          
          final photoUrl = await _storageProvider.uploadUserPhoto(
            photoFile,
            tempId,
          );

          if (photoUrl != null) {
            if (kDebugMode) {
              print('✅ Foto subida correctamente: $photoUrl');
            }
            // Actualizar el modelo de usuario con la URL de la foto
            user = user.copyWith(photoUrl: photoUrl);
          } else {
            if (kDebugMode) {
              print('❌ Error al subir la foto del usuario');
            }
            // Continuamos con la creación del usuario aunque no se pudo subir la foto
          }
        }
      }

      if (kDebugMode) {
        print('👤 Enviando datos del usuario a la API...');
        print('👤 Datos: ${user.toJson()}');
      }
      
      final response = await _apiProvider.add(user.toJson());
      
      if (kDebugMode) {
        print('👤 Respuesta de la API: $response');
      }
      
      if (!response['error'] && response['data'] != null) {
        final String userId = response['data']['id'];
        if (kDebugMode) {
          print('✅ Usuario creado correctamente con ID: $userId');
        }
        return userId;
      } else {
        if (kDebugMode) {
          print('❌ Error al crear usuario: ${response['message']}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ERROR en UserRepository.addUser: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
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
      if (kDebugMode) {
        print('Error al agregar usuario con ID: $e');
      }
      return false;
    }
  }

  /// Actualiza un usuario existente
  Future<bool> updateUser(String id, UserModel user, {File? photoFile}) async {
    try {
      if (kDebugMode) {
        print('🔄 Iniciando actualización de usuario en UserRepository');
        print('🔄 ID: $id');
        print('🔄 Usuario: ${user.name}');
        print('🔄 ¿Tiene nueva foto? ${photoFile != null}');
      }
      
      // Si se proporciona una nueva foto, primero subirla
      if (photoFile != null) {
        if (kDebugMode) {
          print('🔄 Procesando nueva foto del usuario...');
          print('🔄 Ruta de la foto: ${photoFile.path}');
          print('🔄 Tamaño: ${(await photoFile.length() / 1024).toStringAsFixed(2)} KB');
        }
        
        // Verificar que el archivo existe
        if (!await photoFile.exists()) {
          if (kDebugMode) {
            print('❌ ERROR: El archivo de foto no existe físicamente: ${photoFile.path}');
          }
          // Continuamos sin actualizar la foto
        } else {
          final photoUrl = await _storageProvider.uploadUserPhoto(
            photoFile,
            id, // Usar el ID real del usuario para la foto
          );

          if (photoUrl != null) {
            if (kDebugMode) {
              print('✅ Nueva foto subida correctamente: $photoUrl');
            }
            
            // Si el usuario ya tenía una foto anterior, intentar eliminarla
            if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
              if (kDebugMode) {
                print('🔄 Eliminando foto anterior: ${user.photoUrl}');
              }
              
              try {
                await _storageProvider.deleteUserPhoto(user.photoUrl!);
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ No se pudo eliminar la foto anterior: $e');
                }
                // Continuamos aunque no se pueda eliminar la foto anterior
              }
            }
            
            // Actualizar el modelo de usuario con la URL de la nueva foto
            user = user.copyWith(photoUrl: photoUrl);
          } else {
            if (kDebugMode) {
              print('❌ Error al subir la nueva foto del usuario');
            }
            // Continuamos con la actualización del usuario aunque no se pudo subir la foto
          }
        }
      }

      if (kDebugMode) {
        print('🔄 Enviando datos actualizados a la API...');
        print('🔄 Datos: ${user.toJson()}');
      }
      
      final response = await _apiProvider.update(id, user.toJson());
      
      if (kDebugMode) {
        print('🔄 Respuesta de la API: $response');
      }
      
      if (!response['error']) {
        if (kDebugMode) {
          print('✅ Usuario actualizado correctamente');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ Error al actualizar usuario: ${response['message']}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ERROR en UserRepository.updateUser: $e');
        print('❌ Stack trace: ${StackTrace.current}');
      }
      return false;
    }
  }

  /// Elimina un usuario por su ID
  Future<bool> deleteUser(String id) async {
    try {
      final response = await _apiProvider.delete(id);
      return !response['error'];
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar usuario: $e');
      }
      return false;
    }
  }
}

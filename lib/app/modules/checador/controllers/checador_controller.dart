import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/image_cache_service.dart';
import '../../../data/services/rfid_reader_service.dart';
import '../../../data/services/access_log_service.dart';
import '../../../data/config/rfid_config.dart';
import '../../../core/utils/auth_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ChecadorController extends GetxController {
  final UserRepository userRepository;

  ChecadorController({required this.userRepository});

  final isShowingDialog = false.obs;
  final userName = ''.obs;
  final daysLeft = 0.obs;
  final userPhotoUrl = ''.obs;
  final membershipType = ''.obs;
  final expirationDate = Rx<DateTime?>(null);
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  
  // Variables para entradas
  final accessType = ''.obs; // Siempre 'entrada'

  // Estados de membresía para control de LEDs (igual que en RFID)
  static const String membershipActive = "ACTIVE";
  static const String membershipExpiring = "EXPIRING";
  static const String membershipExpired = "EXPIRED";
  static const String membershipNotFound = "NOT_FOUND";
  static const int expiringWarningDays = 5; // Advertir cuando quedan 5 días o menos

  @override
  void onInit() {
    super.onInit();
    _initializeImageCache();
    _precacheActiveUserImages(); // Precargar imágenes al abrir la vista
  }
  
  // Inicializar servicio de caché de imágenes
  Future<void> _initializeImageCache() async {
    try {
      await ImageCacheService.instance.initialize();
      if (kDebugMode) {
        print('✅ Servicio de caché de imágenes inicializado en checador');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error inicializando caché de imágenes: $e');
      }
    }
  }

  // Precargar imágenes de usuarios activos en segundo plano
  Future<void> _precacheActiveUserImages() async {
    try {
      if (kDebugMode) {
        print('🔄 Iniciando precarga de imágenes de usuarios activos...');
      }

      // Obtener usuarios activos (con membresía vigente)
      final activeUsers = await userRepository.getAllUsers();
      
      if (activeUsers.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No hay usuarios para precargar');
        }
        return;
      }

      // Filtrar solo usuarios activos con foto
      final usersToCache = activeUsers.where((user) {
        return user.isActive && 
               user.photoUrl != null && 
               user.photoUrl!.isNotEmpty;
      }).toList();

      if (kDebugMode) {
        print('📥 Precargando ${usersToCache.length} imágenes de usuarios activos...');
      }

      // Precargar imágenes en lotes pequeños para no saturar
      int cached = 0;
      for (final user in usersToCache) {
        try {
          await CachedNetworkImage.evictFromCache(user.photoUrl!);
          await precacheImage(
            CachedNetworkImageProvider(user.photoUrl!),
            Get.context!,
          );
          cached++;
          
          // Pausa breve entre cada imagen para no bloquear UI
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error precargando imagen de ${user.name}: $e');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Precargadas $cached/${usersToCache.length} imágenes de usuarios');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en precarga de imágenes: $e');
      }
    }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (isShowingDialog.value || isLoading.value) return;

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      String? userNumber = barcode.rawValue?.trim();
      if (userNumber == null || userNumber.isEmpty) continue;

      if (kDebugMode) {
        print('🔍 Escaneando userNumber: |$userNumber|');
      }

      isLoading.value = true;
      errorMessage.value = '';

      try {
        if (kDebugMode) {
          print('🔍 Buscando usuario en la base de datos...');
        }

        final UserModel? user = await userRepository.getUserByNumber(
          userNumber,
        );

        if (user == null) {
          if (kDebugMode) {
            print('❌ Usuario no encontrado para el número: $userNumber');
          }
          errorMessage.value = 'Usuario no registrado con número: $userNumber';
          // Reproducir sonido de acceso denegado cuando NO está registrado
          AudioService.playDeniedSound();
          
          // Enviar estado al ESP32 para LEDs rojos EN SEGUNDO PLANO
          _sendMembershipStatusToESP32(
            userNumber, 
            membershipNotFound,
            'Usuario Desconocido',
            'denied',
            'qr'
          );
          
          // Mantener el mensaje de error visible por 3 segundos
          await Future.delayed(const Duration(seconds: 3));
          errorMessage.value = '';
          continue;
        }

        if (kDebugMode) {
          print('✅ Usuario encontrado: ${user.name}');
          print('ℹ️ Estado activo: ${user.isActive}');
          print('ℹ️ Días restantes: ${user.daysRemaining}');
        }

        // Verificar si la membresía está activa
        if (!user.isActive) {
          if (kDebugMode) {
            print('⚠️ Membresía inactiva para usuario: ${user.name}');
          }
          errorMessage.value = 'Membresía inactiva para ${user.name}';
          // Reproducir sonido de acceso denegado (membresía inactiva)
          AudioService.playDeniedSound();
          
          // Enviar estado al ESP32 para LEDs rojos EN SEGUNDO PLANO
          _sendMembershipStatusToESP32(
            userNumber, 
            membershipExpired,
            user.name,
            'denied',
            'qr'
          );
          
          // Mantener el mensaje de error visible por 3 segundos
          await Future.delayed(const Duration(seconds: 3));
          errorMessage.value = '';
          continue;
        }

        // Verificar si la membresía no ha expirado
        if (user.daysRemaining <= 0) {
          if (kDebugMode) {
            print('⚠️ Membresía vencida para usuario: ${user.name}');
          }
          errorMessage.value = 'Membresía vencida para ${user.name}';
          // Reproducir sonido de acceso denegado (membresía vencida)
          AudioService.playDeniedSound();
          
          // Enviar estado al ESP32 para LEDs rojos EN SEGUNDO PLANO
          _sendMembershipStatusToESP32(
            userNumber, 
            membershipExpired,
            user.name,
            'denied',
            'qr'
          );
          
          // Mantener el mensaje de error visible por 3 segundos
          await Future.delayed(const Duration(seconds: 3));
          errorMessage.value = '';
          continue;
        }

        if (kDebugMode) {
          print('✅ Acceso autorizado para: ${user.name}');
        }

        // Precargar imagen del usuario ANTES de mostrar el diálogo
        if (user.id != null && user.photoUrl != null && user.photoUrl!.isNotEmpty) {
          try {
            await ImageCacheService.instance.getUserImage(
              user.id!, 
              user.photoUrl, 
              isThumbnail: false // Usar imagen de tamaño completo para el diálogo
            );
            if (kDebugMode) {
              print('✅ Imagen precargada para: ${user.name}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error precargando imagen: $e');
            }
          }
        }

        // Actualizar datos para mostrar
        userName.value = user.name;
        daysLeft.value = user.daysRemaining;
        userPhotoUrl.value = user.photoUrl ?? '';
        expirationDate.value = user.expirationDate;

        // Siempre es entrada (sin salidas)
        const nextAccessType = 'entrada';
        accessType.value = nextAccessType;
        
        if (kDebugMode) {
          print('🚪 Registrando entrada QR para ${user.name}');
        }

        // Reproducir sonido y mostrar bienvenida
        AudioService.playWelcomeSound();
        if (kDebugMode) {
          print('🔊 Reproduciendo sonido de bienvenida');
        }
        
        // Mostrar el diálogo de bienvenida
        isShowingDialog.value = true;
        
        // Cerrar el diálogo después de 4 segundos
        Future.delayed(const Duration(seconds: 4), () {
          isShowingDialog.value = false;
        });

        // Registrar el acceso en Supabase en segundo plano
        if (user.id != null) {
          _registerAccessInSupabase(user, nextAccessType, 'qr');
        }

        // Registrar también en el modelo del usuario (para compatibilidad)
        if (user.id != null) {
          _registerAccessInBackground(user);
        }

        // Determinar estado de membresía para LEDs y enviar en segundo plano
        String membershipStatus;
        if (user.daysRemaining <= expiringWarningDays) {
          membershipStatus = membershipExpiring; // LED amarillo
        } else {
          membershipStatus = membershipActive; // LED verde
        }

        // Enviar estado al ESP32 para control de LEDs EN SEGUNDO PLANO
        _sendMembershipStatusToESP32(userNumber, membershipStatus, user.name, nextAccessType, 'qr');
        
        // Limpiar mensaje de error al completar exitosamente
        errorMessage.value = '';
        
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error al procesar el acceso: $e');
          print('❌ Stack trace: ${StackTrace.current}');
        }
        errorMessage.value = 'Error de conexión. Intenta de nuevo.';
        
        // Mantener el mensaje de error visible por 3 segundos
        await Future.delayed(const Duration(seconds: 3));
        errorMessage.value = '';
      } finally {
        isLoading.value = false;
      }
    }
  }
  
  // Registrar acceso en segundo plano para no bloquear la UI
  void _registerAccessInBackground(UserModel user) {
    Future(() async {
      try {
        final updatedUser = user.addAccessRecord();
        if (user.id != null) {
          await userRepository.updateUser(user.id!, updatedUser);
          if (kDebugMode) {
            print('✅ Registro de acceso guardado en segundo plano para: ${user.name}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error al registrar acceso en segundo plano: $e');
        }
      }
    });
  }

  // Registrar acceso en Supabase con tabla access_logs
  void _registerAccessInSupabase(UserModel user, String accessType, String method) {
    Future(() async {
      try {
        if (user.id == null) {
          if (kDebugMode) {
            print('❌ No se puede registrar acceso: ID de usuario nulo');
          }
          return;
        }

        // Salvaguarda: nunca registrar entrada de una membresía inactiva o vencida
        if (!user.isActive || user.daysRemaining <= 0) {
          if (kDebugMode) {
            print('⛔ Registro de acceso bloqueado (membresía no válida): ${user.name}');
          }
          return;
        }

        if (kDebugMode) {
          print('🔄 Iniciando registro de acceso en Supabase...');
          print('   👤 Usuario: ${user.name} (${user.userNumber})');
          print('   🚪 Tipo: $accessType');
          print('   📱 Método: $method');
        }

        final staffUser = AuthUtils.getStaffIdentifier();
        
        if (kDebugMode) {
          print('   👨‍💼 Staff: $staffUser');
          print('   🆔 User ID: ${user.id}');
        }
        
        final success = await AccessLogService.registerAccess(
          userId: user.id!,
          userName: user.name,
          userNumber: user.userNumber,
          accessType: accessType,
          method: method,
          staffUser: staffUser,
        );

        if (success) {
          if (kDebugMode) {
            print('✅ Acceso registrado exitosamente en Supabase: ${user.name} - $accessType via $method');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ No se registró el acceso: Ya existe una entrada para hoy');
            print('   El usuario ${user.name} ya tiene una entrada registrada hoy');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Excepción al registrar acceso en Supabase: $e');
        }
      }
    });
  }

  // Enviar estado de membresía al ESP32 para control de LEDs
  void _sendMembershipStatusToESP32(
    String userNumber, 
    String status, [
    String? userName,
    String? accessType,
    String? verificationType,
  ]) {
    Future(() async {
      try {
        if (RfidConfig.isConfigured) {
          await RfidReaderService.sendMembershipStatus(
            userNumber, 
            status,
            userName: userName,
            accessType: accessType,
            verificationType: verificationType,
          );
          if (kDebugMode) {
            print('✅ Estado de membresía enviado al ESP32: $userNumber -> $status ($accessType)');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ ESP32 no configurado, no se pueden controlar LEDs');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error enviando estado al ESP32: $e');
        }
      }
    });
  }
}

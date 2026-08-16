import 'dart:async';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/rfid_reader_service.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/image_cache_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/access_log_service.dart';
import '../../../data/config/rfid_config.dart';
import '../../../core/utils/auth_utils.dart';

class RfidCheckinController extends GetxController with GetSingleTickerProviderStateMixin {
  final UserRepository userRepository;

  RfidCheckinController({required this.userRepository});
  
  // Controlador para las animaciones de onda
  late AnimationController animationController;

  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final successMessage = ''.obs;
  final rfidInput = ''.obs;
  
  // Estado de conexión del lector RFID
  final isRfidConnected = false.obs;
  final connectionStatusMessage = 'Verificando conexión...'.obs;
  
  // Datos del usuario
  final isShowingDialog = false.obs;
  final userName = ''.obs;
  final daysLeft = 0.obs;
  final userPhotoUrl = ''.obs;
  final membershipType = ''.obs;
  final expirationDate = Rx<DateTime?>(null);
  
  // Timer para verificar periódicamente la tarjeta RFID
  Timer? _rfidCheckTimer;
  
  // Timer para verificar periódicamente la conexión ESP32
  Timer? _connectionCheckTimer;
  
  @override
  void onInit() {
    super.onInit();
    
    // Inicializar servicio de caché de imágenes
    _initializeImageCache();
    
    // Precargar imágenes de usuarios activos
    _precacheActiveUserImages();
    
    // Inicializar el controlador de animación con configuración óptima para visibilidad
    animationController = AnimationController(
      vsync: this,
      // Duración más corta para ondas más dinámicas y visibles
      duration: const Duration(milliseconds: 2000),
      // Empezar con un valor seguro
      value: 0.0,
    );
    
    // Añadimos un pequeño retraso para asegurar que la UI esté completamente cargada
    Future.delayed(const Duration(milliseconds: 100), () {
      // Iniciar animación con forward y repeat para evitar problemas de inicialización
      animationController.forward(from: 0.0);
      animationController.repeat();
    });
    
    // Verificar estado de conexión del ESP32
    checkRfidConnection();
    
    // Verificar conexión cada 10 segundos
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      checkRfidConnection();
    });
    
    // Iniciar verificación periódica de RFID solo si está conectado
    startRfidChecking();
  }
  
  // Verificar conexión del ESP32
  Future<void> checkRfidConnection() async {
    try {
      connectionStatusMessage.value = 'Verificando configuración ESP32...';
      
      // Primero verificar si hay configuración
      if (!RfidConfig.isConfigured) {
        isRfidConnected.value = false;
        connectionStatusMessage.value = 'ESP32 no configurado';
        errorMessage.value = 'Se requiere configurar el ESP32 via Bluetooth primero.';
        return;
      }
      
      connectionStatusMessage.value = 'Verificando conexión con ESP32...';
      
      // Usar el servicio real de RFID para verificar la conexión
      final isConnected = await RfidReaderService.startReading();
      isRfidConnected.value = isConnected;
      
      if (isConnected) {
        connectionStatusMessage.value = 'ESP32 conectado y funcionando';
        errorMessage.value = '';
      } else {
        connectionStatusMessage.value = 'ESP32 no responde';
        errorMessage.value = 'No se puede conectar al lector RFID. Verifica la configuración via Bluetooth.';
      }
      
    } catch (e) {
      isRfidConnected.value = false;
      connectionStatusMessage.value = 'Error de conexión';
      errorMessage.value = 'Error al conectar con el ESP32: ${e.toString()}';
    }
  }
  
  void startRfidChecking() {
    _rfidCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      // Solo verificar tarjetas si el ESP32 está conectado
      if (isRfidConnected.value && !isShowingDialog.value && !isLoading.value) {
        final uid = await RfidReaderService.checkForCard();
        if (uid != null) {
          checkAccessByRfid(uid);
        }
      }
    });
  }
  
  // Reintentar conexión con el ESP32
  Future<void> retryConnection() async {
    await checkRfidConnection();
  }
  
  // Ir a configuración RFID
  void goToRfidConfiguration() {
    Get.toNamed('/configuracion');
  }

  // Controlador para el campo de entrada RFID
  final TextEditingController rfidTextController = TextEditingController();
  
  // Inicializar servicio de caché de imágenes
  Future<void> _initializeImageCache() async {
    try {
      await ImageCacheService.instance.initialize();
      AppLogger.info('RfidCheckinController', 'Servicio de caché de imágenes inicializado');
    } catch (e) {
      AppLogger.error('RfidCheckinController', 'Error inicializando caché de imágenes', e);
    }
  }

  // Precargar imágenes de usuarios activos en segundo plano
  Future<void> _precacheActiveUserImages() async {
    try {
      AppLogger.info('RfidCheckinController', 'Iniciando precarga de imágenes de usuarios activos (RFID)');

      // Obtener usuarios activos
      final activeUsers = await userRepository.getAllUsers();
      
      if (activeUsers.isEmpty) {
        AppLogger.warning('RfidCheckinController', 'No hay usuarios para precargar');
        return;
      }

      // Filtrar solo usuarios activos con foto
      final usersToCache = activeUsers.where((user) {
        return user.isActive && 
               user.photoUrl != null && 
               user.photoUrl!.isNotEmpty;
      }).toList();

      AppLogger.info('RfidCheckinController', 'Precargando imágenes de usuarios activos');

      // Precargar imágenes en lotes pequeños
      int cached = 0;
      for (final user in usersToCache) {
        try {
          // Bucket privado: firmar la URL y precachear con la misma clave estable
          // (path del objeto) que usa CachedUserImage al mostrarla.
          final signed = await StorageService.instance.signedUrl(user.photoUrl);
          final key = StorageService.instance.stableKey(user.photoUrl);
          if (signed != null && key != null) {
            await precacheImage(
              CachedNetworkImageProvider(signed, cacheKey: key),
              Get.context!,
            );
            cached++;
          }

          // Pausa breve entre cada imagen
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          AppLogger.warning('RfidCheckinController', 'Error precargando imagen');
        }
      }

      AppLogger.info('RfidCheckinController',
          'Precargadas $cached/${usersToCache.length} imágenes');
    } catch (e) {
      AppLogger.error('RfidCheckinController', 'Error en precarga de imágenes', e);
    }
  }
  
  @override
  void onClose() {
    rfidTextController.dispose();
    _rfidCheckTimer?.cancel();
    _connectionCheckTimer?.cancel();
    animationController.dispose();
    super.onClose();
  }

  // Método para verificar el acceso mediante RFID
  Future<void> checkAccessByRfid(String rfidCode) async {
    if (isLoading.value || rfidCode.isEmpty) return;
    
    isLoading.value = true;
    errorMessage.value = '';
    successMessage.value = '';
    
    try {
      AppLogger.info('RfidCheckinController', 'Verificando acceso con RFID');
      
      // Obtener todos los usuarios y filtrar por RFID
      final List<UserModel> allUsers = await userRepository.getAllUsers();
      final UserModel? user = allUsers.firstWhereOrNull(
        (user) => user.rfidCard == rfidCode
      );
      
      String membershipStatus;
      
      if (user == null) {
        // Usuario no encontrado
        membershipStatus = RfidConfig.membershipNotFound;
        errorMessage.value = 'Tarjeta RFID no registrada';
        AudioService.playDeniedSound();
        
        // Enviar estado al ESP32 para LEDs rojos
        _sendMembershipStatusToESP32(rfidCode, membershipStatus, 'Usuario Desconocido', 'denied', 'rfid');
      } else if (!user.isActive || user.daysRemaining <= 0) {
        // Membresía expirada o inactiva
        membershipStatus = RfidConfig.membershipExpired;
        errorMessage.value = user.daysRemaining <= 0 ? 'Membresía vencida' : 'Membresía inactiva';
        AudioService.playDeniedSound();
        
        // Enviar estado al ESP32 para LEDs rojos
        _sendMembershipStatusToESP32(rfidCode, membershipStatus, user.name, 'denied', 'rfid');
      } else if (user.daysRemaining <= RfidConfig.expiringWarningDays) {
        // Membresía por vencer
        membershipStatus = RfidConfig.membershipExpiring;
        
        // Siempre es entrada (sin salidas)
        const accessType = 'entrada';
        
        AppLogger.info('RfidCheckinController', 'Registrando entrada RFID');
        
        // Actualizar datos para mostrar
        userName.value = user.name;
        daysLeft.value = user.daysRemaining;
        userPhotoUrl.value = user.photoUrl ?? '';
        expirationDate.value = user.expirationDate;
        
        // Reproducir sonido y mostrar bienvenida
        AudioService.playWelcomeSound();
        successMessage.value = '¡Bienvenido(a)! Tu membresía vence pronto';
        
        // Mostrar diálogo de bienvenida
        isShowingDialog.value = true;
        
        // Cerrar la pantalla de bienvenida después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          isShowingDialog.value = false;
        });
        
        // Registrar el acceso en Supabase EN SEGUNDO PLANO
        if (user.id != null) {
          _registerAccessInSupabase(user, accessType, 'rfid');
        }
        
        // Registrar también en el modelo del usuario (para compatibilidad)
        if (user.id != null) {
          _registerAccessInBackground(user);
        }
        
        // Enviar estado de membresía al ESP32 para control de LEDs EN SEGUNDO PLANO
        _sendMembershipStatusToESP32(rfidCode, membershipStatus, user.name, accessType, 'rfid');
      } else {
        // Membresía activa
        membershipStatus = RfidConfig.membershipActive;
        
        // Siempre es entrada (sin salidas)
        const accessType = 'entrada';
        
        AppLogger.info('RfidCheckinController', 'Registrando entrada RFID');
        
        // Actualizar datos para mostrar
        userName.value = user.name;
        daysLeft.value = user.daysRemaining;
        userPhotoUrl.value = user.photoUrl ?? '';
        expirationDate.value = user.expirationDate;
        
        // Reproducir sonido y mostrar bienvenida
        AudioService.playWelcomeSound();
        successMessage.value = '¡Bienvenido(a)!';
        
        // Mostrar diálogo de bienvenida
        isShowingDialog.value = true;
                
        // Cerrar la pantalla de bienvenida después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          isShowingDialog.value = false;
        });
        
        // Registrar el acceso en Supabase EN SEGUNDO PLANO
        if (user.id != null) {
          _registerAccessInSupabase(user, accessType, 'rfid');
        }
        
        // Registrar también en el modelo del usuario (para compatibilidad)
        if (user.id != null) {
          _registerAccessInBackground(user);
        }
        
        // Enviar estado de membresía al ESP32 para control de LEDs EN SEGUNDO PLANO
        _sendMembershipStatusToESP32(rfidCode, membershipStatus, user.name, accessType, 'rfid');
      }
      
      // Si el acceso fue exitoso, manejar diálogo o pantalla de despedida
      if (membershipStatus == RfidConfig.membershipActive || membershipStatus == RfidConfig.membershipExpiring) {
        // Limpiar el campo de RFID después de un acceso exitoso
        rfidTextController.clear();
        rfidInput.value = '';
      } else {
        // Para casos de error (usuario no encontrado, membresía vencida), enviar estado de LEDs en segundo plano
        _sendMembershipStatusToESP32(rfidCode, membershipStatus);
      }
      
    } catch (e) {
      AppLogger.error('RfidCheckinController', 'Error al procesar acceso con RFID', e);
      errorMessage.value = 'Error al procesar el acceso: $e';
    } finally {
      isLoading.value = false;
    }
  }
  
  // Registrar acceso en segundo plano para no bloquear la UI
  void _registerAccessInBackground(UserModel user) {
    Future(() async {
      try {
        final updatedUser = user.addAccessRecord();
        if (user.id != null) {
          await userRepository.updateUser(user.id!, updatedUser);
          AppLogger.info('RfidCheckinController', 'Registro de acceso guardado en segundo plano');
        }
      } catch (e) {
        AppLogger.error('RfidCheckinController', 'Error al registrar acceso en segundo plano', e);
      }
    });
  }

  // Enviar estado de membresía al ESP32 para control de LEDs en segundo plano
  void _sendMembershipStatusToESP32(
    String rfidCode, 
    String status, [
    String? userName,
    String? accessType,
    String? verificationType,
  ]) {
    Future(() async {
      try {
        await RfidReaderService.sendMembershipStatus(
          rfidCode, 
          status,
          userName: userName,
          accessType: accessType,
          verificationType: verificationType,
        );
        if (kDebugMode) {
        }
      } catch (e) {
        AppLogger.error('RfidCheckinController', 'Error enviando estado al ESP32', e);
      }
    });
  }

  // Obtener la dirección IP actual del lector RFID
  String getReaderIpAddress() {
    final baseUrl = RfidConfig.baseUrl;
    
    if (baseUrl == null || baseUrl.isEmpty) {
      return 'No configurado';
    }
    
    // Extraer solo la dirección IP del formato http://192.168.1.x/api
    if (baseUrl.contains('://') && baseUrl.contains('/api')) {
      final parts = baseUrl.split('://');
      if (parts.length > 1) {
        final hostParts = parts[1].split('/');
        return hostParts[0]; // Retorna solo la parte del IP o hostname
      }
    }
    return baseUrl; // Si no se puede extraer, retornar la URL completa
  }
  
  // Actualizar la dirección IP del lector RFID
  void updateReaderIpAddress(String newIp) {
    if (newIp.isEmpty) return;
    
    // Validar y formatear la IP
    String formattedIp = newIp.trim();
    
    // Asegurarse de que tiene el formato correcto (http://IP/api)
    if (!formattedIp.startsWith('http://') && !formattedIp.startsWith('https://')) {
      formattedIp = 'http://$formattedIp';
    }
    
    // Añadir /api si no lo tiene
    if (!formattedIp.endsWith('/api')) {
      // Eliminar barra final si existe
      if (formattedIp.endsWith('/')) {
        formattedIp = formattedIp.substring(0, formattedIp.length - 1);
      }
      formattedIp = '$formattedIp/api';
    }
    
    // Actualizar la configuración usando el nuevo método
    RfidConfig.forceUpdateIP(newIp); // Usar la IP sin formato para el método interno
    
    AppLogger.info('RfidCheckinController', 'Dirección IP del lector RFID actualizada');
    
    // Reiniciar el timer para usar la nueva IP
    _rfidCheckTimer?.cancel();
    
    // Verificar conexión con la nueva IP
    checkRfidConnection();
    
    // Reiniciar checking solo si está conectado
    if (isRfidConnected.value) {
      startRfidChecking();
    }
  }

  // Registrar acceso en Supabase con tabla access_logs
  void _registerAccessInSupabase(UserModel user, String accessType, String method) {
    Future(() async {
      try {
        if (user.id == null) {
          AppLogger.error('RfidCheckinController', 'No se puede registrar acceso: ID de usuario nulo');
          return;
        }

        // Salvaguarda: nunca registrar entrada de una membresía inactiva o vencida
        if (!user.isActive || user.daysRemaining <= 0) {
          AppLogger.error('RfidCheckinController', 'Registro de acceso bloqueado (membresía no válida)');
          return;
        }

        AppLogger.info('RfidCheckinController',
            'Registrando acceso (tipo: $accessType, método: $method)');

        final staffUser = AuthUtils.getStaffIdentifier();


        final success = await AccessLogService.registerAccess(
          userId: user.id!,
          userName: user.name,
          userNumber: user.userNumber,
          accessType: accessType,
          method: method,
          staffUser: staffUser,
        );

        if (success) {
        } else {
          AppLogger.warning('RfidCheckinController', 'No se registró el acceso: Ya existe una entrada para hoy');
          AppLogger.info('RfidCheckinController', 'El usuario ya tiene una entrada registrada hoy');
        }
      } catch (e) {
        AppLogger.error('RfidCheckinController', 'Excepción al registrar acceso en Supabase', e);
      }
    });
  }
}

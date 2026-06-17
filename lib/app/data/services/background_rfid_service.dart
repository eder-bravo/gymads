import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/main.dart' show rootScaffoldMessengerKey;
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'rfid_reader_service.dart';
import 'audio_service.dart';
import 'access_log_service.dart';
import '../../core/utils/auth_utils.dart';
import '../../routes/app_pages.dart';
import '../config/rfid_config.dart';

/// Servicio global para escaneo RFID en segundo plano
/// Se ejecuta continuamente y maneja las detecciones de tarjetas
class BackgroundRfidService extends GetxService {
  // Lazy loading del UserRepository (se carga cuando se necesita)
  UserRepository get _userRepository => Get.find<UserRepository>();

  // Timer para polling del ESP32
  Timer? _pollingTimer;

  // Estado del servicio
  final isScanning = false.obs;
  final isPaused =
      false.obs; // Nuevo: indica si el servicio está pausado temporalmente
  final lastScannedUid = ''.obs;

  // Control de tiempo para evitar escaneos duplicados
  DateTime? _lastScanTime;
  String? _lastScannedCard;
  static const _scanCooldown = Duration(seconds: 3);

  // Guard para evitar peticiones concurrentes
  bool _isChecking = false;

  /// Método para mostrar notificación usando el ScaffoldMessenger global
  void _showSnackbarSafe(String title, String message, {bool isError = false}) {
    if (kDebugMode) {
      print('📢 Mostrando notificación: $title - $message');
    }

    try {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) {
        if (kDebugMode) print('❌ ScaffoldMessenger es null');
        return;
      }

      // Limpiar snackbars anteriores
      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.close_rounded : Icons.check_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor:
              isError ? const Color(0xFFE53935) : const Color(0xFF1DB954),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin:
              const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 2),
          dismissDirection: DismissDirection.horizontal,
        ),
      );

      if (kDebugMode) print('✅ SnackBar mostrado via GlobalKey');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error mostrando snackbar: $e');
      }
    }
  }

  // Usuario actual escaneado
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final showWelcomeDialog = false.obs;
  final showNotFoundDialog = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (kDebugMode) {
      print('🔄 BackgroundRfidService inicializado');
    }
    // Siempre iniciar el escaneo al instanciar el servicio
    startScanning();
  }

  /// Iniciar el escaneo en segundo plano
  Future<void> startScanning() async {
    if (isScanning.value) {
      if (kDebugMode) {
        print('⚠️ El escaneo ya está activo');
      }
      return;
    }

    isScanning.value = true;

    if (kDebugMode) {
      print('🚀 Iniciando servicio de escaneo RFID en segundo plano...');
    }

    // Cargar configuración de RFID (IP, etc) si es necesario
    await RfidConfig.loadConfig();

    // Iniciar polling cada 1.5 segundos
    _pollingTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      await _checkForCard();
    });

    if (kDebugMode) {
      print('✅ Escaneo RFID en segundo plano iniciado (polling cada 1.5s)');
    }
  }

  /// Detener el escaneo en segundo plano
  void stopScanning() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    isScanning.value = false;

    if (kDebugMode) {
      print('⏸️ Escaneo RFID en segundo plano detenido');
    }
  }

  /// Pausar temporalmente el escaneo (sin detener el timer)
  /// Usado cuando se está registrando una nueva tarjeta
  void pauseScanning() {
    if (!isScanning.value) {
      if (kDebugMode) {
        print('⚠️ No se puede pausar: el escaneo no está activo');
      }
      return;
    }

    isPaused.value = true;
    if (kDebugMode) {
      print('⏸️ Escaneo RFID pausado temporalmente');
    }
  }

  /// Reanudar el escaneo después de una pausa
  void resumeScanning() {
    if (!isScanning.value) {
      if (kDebugMode) {
        print('⚠️ No se puede reanudar: el escaneo no está activo');
      }
      return;
    }

    isPaused.value = false;
    if (kDebugMode) {
      print('▶️ Escaneo RFID reanudado');
    }
  }

  /// Verificar si hay una tarjeta disponible
  Future<void> _checkForCard() async {
    // Evitar peticiones concurrentes si la anterior no ha terminado
    if (_isChecking) return;
    _isChecking = true;

    try {
      // Si el servicio está pausado, no hacer nada
      if (isPaused.value) {
        return;
      }

      final uid = await RfidReaderService.checkForCard();

      if (uid == null || uid.isEmpty || uid == 'NO_CARD') {
        return;
      }

      if (kDebugMode) {
        print('🏷️ Tarjeta detectada: $uid');
      }

      // Verificar cooldown para evitar escaneos duplicados
      if (_shouldSkipScan(uid)) {
        if (kDebugMode) {
          print('⏭️ Escaneo omitido (cooldown): $uid');
        }
        return;
      }

      // Actualizar control de tiempo
      _lastScanTime = DateTime.now();
      _lastScannedCard = uid;
      lastScannedUid.value = uid;

      // Procesar la tarjeta
      await _processCard(uid);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en escaneo de fondo: $e');
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Verificar si debemos saltar este escaneo
  bool _shouldSkipScan(String uid) {
    if (_lastScannedCard != uid) {
      return false; // Tarjeta diferente, siempre procesar
    }

    if (_lastScanTime == null) {
      return false; // Primera vez, procesar
    }

    final timeSinceLastScan = DateTime.now().difference(_lastScanTime!);
    return timeSinceLastScan <
        _scanCooldown; // Saltar si no ha pasado el cooldown
  }

  /// Procesar la tarjeta detectada
  Future<void> _processCard(String uid) async {
    try {
      if (kDebugMode) {
        print('🏷️ Procesando tarjeta: $uid');
      }

      // Buscar usuario por RFID
      final user = await _userRepository.getUserByRfid(uid);

      if (user == null) {
        await _handleUserNotFound(uid);
        return;
      }

      if (!user.isActive) {
        await _handleInactiveUser(user);
        return;
      }

      // Usuario activo, procesar acceso
      await _handleActiveUser(user, uid);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando tarjeta: $e');
      }
    }
  }

  /// Manejar usuario no encontrado
  Future<void> _handleUserNotFound(String uid) async {
    if (kDebugMode) {
      print('❌ Usuario no encontrado: $uid');
    }

    AudioService.playDeniedSound();

    // Enviar estado al ESP32
    await RfidReaderService.sendMembershipStatus(
      uid,
      'not_found',
      userName: 'Usuario Desconocido',
      accessType: 'denied',
      verificationType: 'rfid',
    );

    // Ya no mostramos la notificación inferior (tarjetita roja) por petición del usuario

    // Mostrar pantalla completa de tarjeta no registrada
    final currentRoute = Get.currentRoute;
    if (currentRoute == Routes.HOME || currentRoute == '/') {
      showNotFoundDialog.value = true;

      // Cerrar después de 6 segundos
      await Future.delayed(const Duration(seconds: 6));
      showNotFoundDialog.value = false;
    } else {
      // Si no estamos en home, podríamos usar la notificación o un diálogo, 
      // pero el usuario especificó "pantalla completa".
      // Vamos a habilitar la pantalla completa también asumiendo que el widget está en el home
      showNotFoundDialog.value = true;
      await Future.delayed(const Duration(seconds: 6));
      showNotFoundDialog.value = false;
    }
  }

  /// Manejar usuario inactivo
  Future<void> _handleInactiveUser(UserModel user) async {
    if (kDebugMode) {
      print('⚠️ Usuario inactivo: ${user.name}');
    }

    AudioService.playDeniedSound();

    // Enviar estado al ESP32
    await RfidReaderService.sendMembershipStatus(
      user.userNumber,
      'expired',
      userName: user.name,
      accessType: 'denied',
      verificationType: 'rfid',
    );

    currentUser.value = user;

    final currentRoute = Get.currentRoute;
    if (currentRoute == Routes.HOME || currentRoute == '/') {
      // Estamos en home, mostrar diálogo completo
      showWelcomeDialog.value = true;

      // Cerrar después de 8 segundos para dar tiempo a interactuar
      await Future.delayed(const Duration(seconds: 8));
      showWelcomeDialog.value = false;
      currentUser.value = null;
    } else {
      // Mostrar notificación de denegado
      _showDeniedNotification('Membresía inactiva');
    }
  }

  /// Manejar usuario activo
  Future<void> _handleActiveUser(UserModel user, String uid) async {
    if (kDebugMode) {
      print('✅ Acceso autorizado: ${user.name}');
    }

    currentUser.value = user;

    // Determinar estado de membresía
    String membershipStatus;
    if (user.daysRemaining <= 5) {
      membershipStatus = 'expiring';
    } else {
      membershipStatus = 'active';
    }

    // Reproducir sonido
    AudioService.playWelcomeSound();

    // Enviar estado al ESP32
    await RfidReaderService.sendMembershipStatus(
      uid,
      membershipStatus,
      userName: user.name,
      accessType: 'entrada',
      verificationType: 'rfid',
    );

    // Registrar acceso en segundo plano
    _registerAccess(user);

    // Mostrar interfaz según la vista actual
    final currentRoute = Get.currentRoute;

    if (kDebugMode) {
      print('🛣️ Ruta actual: "$currentRoute"');
      print(
          '🏠 Es home: ${currentRoute == Routes.HOME || currentRoute == "/"}');
    }

    if (currentRoute == Routes.HOME || currentRoute == '/') {
      // Estamos en home, mostrar diálogo completo
      showWelcomeDialog.value = true;

      // Cerrar después de 8 segundos para dar tiempo a interactuar
      await Future.delayed(const Duration(seconds: 8));
      showWelcomeDialog.value = false;
      currentUser.value = null;
    } else {
      // Estamos en otra vista, mostrar notificación pequeña
      if (kDebugMode) {
        print('📱 Mostrando notificación para: ${user.name}');
      }
      _showSuccessNotification(user.name);
    }
  }

  /// Mostrar notificación de éxito (pequeña)
  void _showSuccessNotification(String userName) {
    _showSnackbarSafe('✅ Acceso autorizado', userName);
  }

  /// Mostrar notificación de denegado (pequeña)
  void _showDeniedNotification(String message) {
    _showSnackbarSafe('❌ Acceso denegado', message, isError: true);
  }

  /// Registrar acceso en background
  void _registerAccess(UserModel user) {
    Future(() async {
      try {
        if (user.id == null) return;

        final staffUser = AuthUtils.getStaffIdentifier();

        await AccessLogService.registerAccess(
          userId: user.id!,
          userName: user.name,
          userNumber: user.userNumber,
          accessType: 'entrada',
          method: 'rfid_background',
          staffUser: staffUser,
        );

        if (kDebugMode) {
          print('✅ Acceso registrado para: ${user.name}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error registrando acceso: $e');
        }
      }
    });
  }

  @override
  void onClose() {
    stopScanning();
    super.onClose();
  }
}

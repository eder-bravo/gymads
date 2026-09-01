import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/main.dart' show rootScaffoldMessengerKey;
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'rfid_reader_service.dart';
import 'audio_service.dart';
import 'access_log_service.dart';
import 'gym_settings_service.dart';
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
    try {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) {
        AppLogger.error('BackgroundRfidService', 'ScaffoldMessenger no disponible');
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

    } catch (e) {
      AppLogger.error('BackgroundRfidService', 'Error mostrando snackbar', e);
    }
  }

  // Usuario actual escaneado
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final showWelcomeDialog = false.obs;
  final showNotFoundDialog = false.obs;

  @override
  void onInit() {
    super.onInit();
    AppLogger.info('BackgroundRfidService', 'BackgroundRfidService inicializado');
    // Siempre iniciar el escaneo al instanciar el servicio
    startScanning();
  }

  /// Iniciar el escaneo en segundo plano
  Future<void> startScanning() async {
    if (isScanning.value) {
      AppLogger.warning('BackgroundRfidService', 'El escaneo ya está activo');
      return;
    }

    isScanning.value = true;

    AppLogger.info('BackgroundRfidService', 'Iniciando servicio de escaneo RFID en segundo plano');

    // Cargar configuración de RFID (IP, etc) si es necesario
    await RfidConfig.loadConfig();

    // Iniciar polling cada 1.5 segundos
    _pollingTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      await _checkForCard();
    });

    AppLogger.info('BackgroundRfidService', 'Escaneo RFID en segundo plano iniciado (polling cada 1.5s)');
  }

  /// Detener el escaneo en segundo plano
  void stopScanning() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    isScanning.value = false;

    AppLogger.info('BackgroundRfidService', 'Escaneo RFID en segundo plano detenido');
  }

  /// Pausar temporalmente el escaneo (sin detener el timer)
  /// Usado cuando se está registrando una nueva tarjeta
  void pauseScanning() {
    if (!isScanning.value) {
      AppLogger.warning('BackgroundRfidService', 'No se puede pausar: el escaneo no está activo');
      return;
    }

    isPaused.value = true;
    AppLogger.info('BackgroundRfidService', 'Escaneo RFID pausado temporalmente');
  }

  /// Reanudar el escaneo después de una pausa
  void resumeScanning() {
    if (!isScanning.value) {
      AppLogger.warning('BackgroundRfidService', 'No se puede reanudar: el escaneo no está activo');
      return;
    }

    isPaused.value = false;
    AppLogger.info('BackgroundRfidService', 'Escaneo RFID reanudado');
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

      AppLogger.info('BackgroundRfidService', 'Tarjeta detectada');

      // Verificar cooldown para evitar escaneos duplicados
      if (_shouldSkipScan(uid)) {
        AppLogger.info('BackgroundRfidService', 'Escaneo omitido (cooldown)');
        return;
      }

      // Actualizar control de tiempo
      _lastScanTime = DateTime.now();
      _lastScannedCard = uid;
      lastScannedUid.value = uid;

      // Procesar la tarjeta
      await _processCard(uid);
    } catch (e) {
      AppLogger.error('BackgroundRfidService', 'Error en escaneo de fondo', e);
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
      AppLogger.info('BackgroundRfidService', 'Procesando tarjeta');

      // Buscar usuario por RFID
      final user = await _userRepository.getUserByRfid(uid);

      if (user == null) {
        await _handleUserNotFound(uid);
        return;
      }

      // Membresía inactiva o vencida → acceso denegado
      if (!user.isActive || user.daysRemaining <= 0) {
        await _handleInactiveUser(user);
        return;
      }

      // Usuario activo, procesar acceso
      await _handleActiveUser(user, uid);
    } catch (e) {
      AppLogger.error('BackgroundRfidService', 'Error procesando tarjeta', e);
    }
  }

  /// Manejar usuario no encontrado
  Future<void> _handleUserNotFound(String uid) async {
    AppLogger.error('BackgroundRfidService', 'Usuario no encontrado');

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

  /// Manejar usuario inactivo o con membresía vencida
  Future<void> _handleInactiveUser(UserModel user) async {
    final bool estaVencida = user.daysRemaining <= 0;
    final String motivo =
        estaVencida ? 'Membresía vencida' : 'Membresía inactiva';

    AppLogger.warning('BackgroundRfidService', 'Acceso denegado ($motivo)');

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
      _showDeniedNotification(motivo);
    }
  }

  /// Manejar usuario activo
  Future<void> _handleActiveUser(UserModel user, String uid) async {
    AppLogger.info('BackgroundRfidService', 'Acceso autorizado');

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

    AppLogger.info('BackgroundRfidService', 'Evaluando ruta actual');
    AppLogger.info('BackgroundRfidService', 'Es home: ${currentRoute == Routes.HOME || currentRoute == "/"}');

    if (currentRoute == Routes.HOME || currentRoute == '/') {
      // Estamos en home, mostrar diálogo completo
      showWelcomeDialog.value = true;

      // Cerrar después de 8 segundos para dar tiempo a interactuar
      await Future.delayed(const Duration(seconds: 8));
      showWelcomeDialog.value = false;
      currentUser.value = null;
    } else {
      // Estamos en otra vista, mostrar notificación pequeña
      AppLogger.info('BackgroundRfidService', 'Mostrando notificación');
      _showSuccessNotification(user.name);
    }
  }

  /// Mostrar notificación de éxito (pequeña)
  void _showSuccessNotification(String userName) {
    _showSnackbarSafe('Acceso autorizado', userName);
  }

  /// Mostrar notificación de denegado (pequeña)
  void _showDeniedNotification(String message) {
    _showSnackbarSafe('Acceso denegado', message, isError: true);
  }

  /// Registrar acceso en background
  void _registerAccess(UserModel user) {
    Future(() async {
      try {
        if (user.id == null) return;

        // Salvaguarda: nunca registrar entrada de una membresía inactiva o vencida
        if (!user.isActive || user.daysRemaining <= 0) {
          AppLogger.error('BackgroundRfidService', 'Registro de acceso bloqueado (membresía no válida)');
          return;
        }

        final staffUser = AuthUtils.getStaffIdentifier();

        // El servicio decide si toca entrada o salida según lo que tenga
        // configurado el gimnasio.
        final ajustes = await GymSettingsService.current();

        final tipo = await AccessLogService.registerAccess(
          userId: user.id!,
          userName: user.name,
          userNumber: user.userNumber,
          method: 'rfid_background',
          staffUser: staffUser,
          registrarSalidas: ajustes.registrarSalidas,
        );

        AppLogger.info('BackgroundRfidService',
            tipo == null ? 'Acceso no registrado' : 'Acceso registrado: $tipo');
      } catch (e) {
        AppLogger.error('BackgroundRfidService', 'Error registrando acceso', e);
      }
    });
  }

  @override
  void onClose() {
    stopScanning();
    super.onClose();
  }
}

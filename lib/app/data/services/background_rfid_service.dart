import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/main.dart' show rootScaffoldMessengerKey;
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'rfid_reader_service.dart';
import 'supabase_service.dart';
import 'tenant_context_service.dart';
import 'audio_service.dart';
import 'access_log_service.dart';
import 'gym_settings_service.dart';
import '../../core/permissions/permissions.dart';
import '../../core/permissions/staff_role.dart';
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

  /// Si a este dispositivo le tocan los avisos del lector.
  ///
  /// El aviso es del mostrador. Antes lo recibían TODOS los dispositivos a la
  /// vez: el ESP32 responde el mismo `lastUid` a quien pregunte y no lo limpia
  /// al leerlo, así que cada app sonaba, mostraba el diálogo y además escribía
  /// su propia fila en `access_logs` por un único pase de tarjeta.
  final atiendeLector = false.obs;

  /// Por qué este dispositivo no atiende el lector, para decírselo a la
  /// persona en la pantalla del lector. Null si sí lo atiende.
  final motivoSinAvisos = RxnString();

  /// El dueño o el encargado pidieron recibir los avisos en este teléfono
  /// aunque haya alguien de mostrador.
  ///
  /// Hace falta porque "hay un mostrador activo" no significa "hay un
  /// mostrador con la app abierta": un perfil de mostrador que no está en el
  /// gimnasio dejaba a todos sin avisos.
  ///
  /// Se guarda en el teléfono y por gimnasio: es una decisión sobre este
  /// aparato, no un dato del negocio.
  final recibirAvisosAqui = false.obs;

  static String? _claveAvisosAqui() {
    final gymId = TenantContextService.to.currentGymId;
    return gymId == null ? null : 'lector_avisos_aqui_$gymId';
  }

  Future<void> _cargarPreferenciaAvisos() async {
    final clave = _claveAvisosAqui();
    if (clave == null) {
      recibirAvisosAqui.value = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    recibirAvisosAqui.value = prefs.getBool(clave) ?? false;
  }

  /// Activa o desactiva los avisos en este teléfono y lo aplica al momento,
  /// sin reiniciar la app.
  Future<void> setRecibirAvisosAqui(bool valor) async {
    final clave = _claveAvisosAqui();
    if (clave == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clave, valor);
    recibirAvisosAqui.value = valor;

    stopScanning();
    await startScanning();
  }

  /// Decide si este dispositivo atiende el lector.
  ///
  /// Respaldo deliberado: si el gimnasio todavía no tiene a nadie en
  /// mostrador, el dueño sigue recibiendo los avisos. Sin esto, un dueño que
  /// trabaja solo se quedaría sin ningún aviso.
  Future<void> resolverDestinatario() async {
    final tenant = TenantContextService.to;
    await _cargarPreferenciaAvisos();

    if (tenant.can(Permission.recibirAlertasNfc)) {
      _atender();
      return;
    }

    // Mismo permiso que abre la pantalla del lector, donde está el
    // interruptor: dueño y encargado.
    if (recibirAvisosAqui.value &&
        tenant.can(Permission.gestionarControlAccesos)) {
      _atender();
      return;
    }

    final gymId = tenant.currentGymId;
    if (tenant.rol != StaffRole.ownerAdmin || gymId == null) {
      _noAtender('Tu rol no recibe los avisos del lector.');
      return;
    }

    try {
      final filas = await SupabaseService.client
          .from('staff_profiles')
          .select('id')
          .eq('gym_id', gymId)
          .eq('role', StaffRole.mostrador.value)
          .eq('is_active', true)
          .limit(1);

      if ((filas as List).isEmpty) {
        _atender();
      } else {
        _noAtender('Los avisos los recibe el personal de mostrador.');
      }
    } catch (e) {
      // Sin respuesta se atiende igual: perder un aviso es peor que duplicarlo.
      AppLogger.warning('BackgroundRfidService',
          'No se pudo consultar el mostrador; el dueño atiende el lector');
      _atender();
    }
  }

  void _atender() {
    atiendeLector.value = true;
    motivoSinAvisos.value = null;
  }

  void _noAtender(String motivo) {
    atiendeLector.value = false;
    motivoSinAvisos.value = motivo;
  }

  /// Método para mostrar notificación usando el ScaffoldMessenger global
  void _showSnackbarSafe(String title, String message, {bool isError = false}) {
    try {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) {
        AppLogger.error(
            'BackgroundRfidService', 'ScaffoldMessenger no disponible');
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
  final lastAccessWasExit = false.obs;

  @override
  void onInit() {
    super.onInit();
    AppLogger.info(
        'BackgroundRfidService', 'BackgroundRfidService inicializado');

    // El rol decide quién atiende el lector, así que hay que reevaluarlo cada
    // vez que cambia el perfil: al entrar, al salir y si el dueño cambia el
    // rol del empleado desde su propio dispositivo.
    //
    // Se para y se vuelve a arrancar porque las dos direcciones importan: quien
    // deja de ser mostrador tiene que dejar de sondear, y quien acaba de entrar
    // como mostrador tiene que empezar sin reiniciar la app. startScanning()
    // resuelve de nuevo el destinatario y no hace nada si no le toca.
    ever(TenantContextService.to.staffProfileRx, (_) {
      stopScanning();
      startScanning();
    });

    startScanning();
  }

  /// Iniciar el escaneo en segundo plano
  Future<void> startScanning() async {
    if (isScanning.value) {
      AppLogger.warning('BackgroundRfidService', 'El escaneo ya está activo');
      return;
    }

    await resolverDestinatario();
    if (!atiendeLector.value) {
      AppLogger.info('BackgroundRfidService',
          'Este dispositivo no atiende el lector: no se inicia el escaneo');
      return;
    }

    isScanning.value = true;
    _avisoRechazo = false;
    RfidReaderService.rechazo.value = RechazoLector.ninguno;

    AppLogger.info('BackgroundRfidService',
        'Iniciando servicio de escaneo RFID en segundo plano');

    // Cargar configuración de RFID (IP, etc) si es necesario
    await RfidConfig.loadConfig();

    // Iniciar polling cada 1.5 segundos
    _pollingTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      await _checkForCard();
    });

    AppLogger.info('BackgroundRfidService',
        'Escaneo RFID en segundo plano iniciado (polling cada 1.5s)');
  }

  /// Detener el escaneo en segundo plano
  void stopScanning() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    isScanning.value = false;

    AppLogger.info(
        'BackgroundRfidService', 'Escaneo RFID en segundo plano detenido');
  }

  /// Pausar temporalmente el escaneo (sin detener el timer)
  /// Usado cuando se está registrando una nueva tarjeta
  void pauseScanning() {
    if (!isScanning.value) {
      AppLogger.warning('BackgroundRfidService',
          'No se puede pausar: el escaneo no está activo');
      return;
    }

    isPaused.value = true;
    AppLogger.info(
        'BackgroundRfidService', 'Escaneo RFID pausado temporalmente');
  }

  /// Reanudar el escaneo después de una pausa
  void resumeScanning() {
    if (!isScanning.value) {
      AppLogger.warning('BackgroundRfidService',
          'No se puede reanudar: el escaneo no está activo');
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

      // El rol pudo cambiar con el escaneo ya en marcha (el dueño contrata a
      // alguien de mostrador, o revoca un acceso).
      if (!atiendeLector.value) {
        return;
      }

      final uid = await RfidReaderService.checkForCard();

      // El lector rechazó la petición. Reintentar no sirve de nada: por
      // muchas veces que se pregunte, nunca va a contestar. Sin este corte,
      // la app martillearía el aparato cada 1,5 s para siempre, que es justo
      // el problema que la vinculación viene a cerrar.
      final rechazo = RfidReaderService.rechazo.value;
      if (rechazo != RechazoLector.ninguno) {
        stopScanning();
        _avisarRechazo(rechazo);
        return;
      }

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

  /// Si ya se avisó del rechazo. Sin esta bandera saldría una notificación
  /// cada vuelta del sondeo.
  bool _avisoRechazo = false;

  /// Avisa según el motivo real. Un lector sin vincular se arregla en dos
  /// toques desde Configuración; uno ajeno no se arregla desde aquí. Dar el
  /// mismo mensaje para ambos manda al usuario a buscar donde no es.
  void _avisarRechazo(RechazoLector motivo) {
    if (_avisoRechazo) return;
    _avisoRechazo = true;

    final sinVincular = motivo == RechazoLector.sinVincular;

    AppLogger.warning(
        'BackgroundRfidService',
        sinVincular
            ? 'Sondeo detenido: el lector no está vinculado a ningún gimnasio'
            : 'Sondeo detenido: el lector pertenece a otro gimnasio');

    _showSnackbarSafe(
      sinVincular ? 'Lector sin vincular' : 'Lector no disponible',
      sinVincular
          ? 'Vincúlalo en Configuración → Lector de tarjetas.'
          : 'Ese lector es de otro gimnasio.',
      isError: true,
    );
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

    // El registro puede ignorarse porque el acceso de hoy ya existe. Eso no
    // impide mostrar la bienvenida: solo evita crear otra fila en Supabase.
    final accessType = await _registerAccess(user) ?? 'entrada';
    lastAccessWasExit.value = accessType == 'salida';

    AudioService.playWelcomeSound();

    // Enviar estado al ESP32
    await RfidReaderService.sendMembershipStatus(
      uid,
      membershipStatus,
      userName: user.name,
      accessType: accessType,
      verificationType: 'rfid',
    );

    // Mostrar interfaz según la vista actual
    final currentRoute = Get.currentRoute;

    AppLogger.info('BackgroundRfidService', 'Evaluando ruta actual');
    AppLogger.info('BackgroundRfidService',
        'Es home: ${currentRoute == Routes.HOME || currentRoute == "/"}');

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

  /// Registra el acceso y devuelve el tipo realmente insertado.
  Future<String?> _registerAccess(UserModel user) async {
    try {
      if (user.id == null) return null;

      // Salvaguarda: nunca registrar entrada de una membresía inactiva o vencida
      if (!user.isActive || user.daysRemaining <= 0) {
        AppLogger.error('BackgroundRfidService',
            'Registro de acceso bloqueado (membresía no válida)');
        return null;
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
      return tipo;
    } catch (e) {
      AppLogger.error('BackgroundRfidService', 'Error registrando acceso', e);
      return null;
    }
  }

  @override
  void onClose() {
    stopScanning();
    super.onClose();
  }
}

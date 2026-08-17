import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/config/rfid_config.dart';
import '../../../data/services/rfid_reader_service.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../data/services/image_cache_service.dart';
import '../../../data/models/staff_profile_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../routes/app_pages.dart';

class ConfiguracionController extends GetxController {
  // Variables observables para la configuración
  final RxBool isLoading = false.obs;

  // Variables para información de cuenta (populated from TenantContextService)
  final RxString userName = ''.obs;
  final RxString userEmail = ''.obs;
  final RxString userRole = ''.obs;
  final RxString firstName = ''.obs;
  final RxString lastName = ''.obs;
  final RxString gymName = ''.obs;
  final RxString branchName = ''.obs;

  // Variables para configuración del lector RFID
  final RxBool rfidConnectionStatus = false.obs;
  final RxString connectionStatusMessage = 'Desactivado'.obs;
  final RxString esp32IpAddress = ''.obs;
  final RxBool isRfidScanning = false.obs;
  final RxBool rfidEnabled = false.obs;
  bool _rfidScanCancelled = false;

  // Variables para ESP32 con IP manual
  final RxBool esp32Connected = false.obs;
  final RxString esp32StatusMessage = 'ESP32 desconectado'.obs;

  // Variables para configuración de audio
  final RxBool soundEnabled = true.obs;
  final RxDouble soundVolume = 0.8.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserInfo();
    _loadConfiguration();
  }

  @override
  void onClose() {
    super.onClose();
  }

  // =================== USER INFO FROM SESSION ===================

  void _loadUserInfo() {
    final tenant = TenantContextService.to;
    final user = Supabase.instance.client.auth.currentUser;

    // Name
    final profile = tenant.staffProfile;
    firstName.value = profile?.firstName ?? '';
    lastName.value = profile?.lastName ?? '';
    userName.value =
        tenant.displayName ?? user?.email?.split('@').first ?? 'Usuario';
    userEmail.value = user?.email ?? '';
    userRole.value = _formatRole(profile?.role);
    gymName.value = '';
    branchName.value = '';

    // Try to load gym/branch names
    _loadGymInfo();
  }

  String _formatRole(String? role) {
    switch (role) {
      case 'owner_admin':
        return 'Dueño / Admin';
      case 'branch_staff':
        return 'Staff de Sucursal';
      default:
        return 'Admin';
    }
  }

  Future<void> _loadGymInfo() async {
    try {
      final tenant = TenantContextService.to;
      if (tenant.currentGymId != null) {
        final gymData = await Supabase.instance.client
            .from('gyms')
            .select('name')
            .eq('id', tenant.currentGymId!)
            .maybeSingle();
        if (gymData != null) {
          gymName.value = gymData['name'] as String? ?? '';
        }
      }
      if (tenant.currentBranchId != null) {
        final branchData = await Supabase.instance.client
            .from('branches')
            .select('name')
            .eq('id', tenant.currentBranchId!)
            .maybeSingle();
        if (branchData != null) {
          branchName.value = branchData['name'] as String? ?? '';
        }
      }
    } catch (e) {
      AppLogger.warning('ConfiguracionController',
          'No se pudo cargar la información del gimnasio');
    }
  }

  // =================== UPDATE GYM ===================

  Future<void> updateGymName(String value) async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) return;
    try {
      await Supabase.instance.client
          .from('gyms')
          .update({'name': value}).eq('id', gymId);
      gymName.value = value;
      // Refresh the staff profile to update cached gym name
      await _refreshTenantProfile();
      SnackbarHelper.success('¡Listo!', 'Nombre del gimnasio actualizado');
    } catch (e) {
      AppLogger.error('ConfiguracionController',
          'Fallo al actualizar el nombre del gimnasio', e);
      SnackbarHelper.error('Error', 'No se pudo actualizar el nombre');
    }
  }

  /// Renombra la sucursal actual. Solo el dueño puede hacerlo (política RLS
  /// "Owner can update their branches").
  Future<void> updateBranchName(String value) async {
    final branchId = TenantContextService.to.currentBranchId;
    if (branchId == null) return;
    try {
      await Supabase.instance.client
          .from('branches')
          .update({'name': value}).eq('id', branchId);
      branchName.value = value;
      SnackbarHelper.success('¡Listo!', 'Nombre de la sucursal actualizado');
    } catch (e) {
      AppLogger.error('ConfiguracionController',
          'Fallo al actualizar el nombre de la sucursal', e);
      SnackbarHelper.error('Error', 'No se pudo actualizar el nombre');
    }
  }

  Future<void> _refreshTenantProfile() async {
    try {
      final userId = TenantContextService.to.userId;
      if (userId == null) return;
      final response = await Supabase.instance.client
          .from('staff_profiles')
          .select('*, gyms(name, created_at)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();
      if (response != null) {
        final profile = StaffProfileModel.fromJson(response);
        await TenantContextService.to.setProfile(profile);
      }
    } catch (e) {
      AppLogger.error(
          'ConfiguracionController', 'Fallo al refrescar el perfil', e);
    }
  }

  // =================== UPDATE PROFILE ===================

  Future<void> updateFirstName(String value) async {
    await _updateProfileField('first_name', value);
    firstName.value = value;
    _refreshDisplayName();
  }

  Future<void> updateLastName(String value) async {
    await _updateProfileField('last_name', value);
    lastName.value = value;
    _refreshDisplayName();
  }

  Future<void> _updateProfileField(String field, String value) async {
    try {
      isLoading.value = true;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Build display_name
      String newFirst = field == 'first_name' ? value : firstName.value;
      String newLast = field == 'last_name' ? value : lastName.value;
      String displayName = '$newFirst $newLast'.trim();

      await Supabase.instance.client.from('staff_profiles').update({
        field: value,
        'display_name': displayName,
      }).eq('user_id', userId);

      // Refrescar el caché. Debe hacerse con el join de `gyms`, si no se
      // pierden el nombre del gimnasio y su fecha de creación.
      await _refreshTenantProfile();

      SnackbarHelper.success('Guardado', 'Información actualizada');
    } catch (e) {
      AppLogger.error(
          'ConfiguracionController', 'Fallo al actualizar el perfil', e);
      SnackbarHelper.error('Error', 'No se pudo actualizar: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _refreshDisplayName() {
    userName.value = '${firstName.value} ${lastName.value}'.trim();
  }

  // =================== MÉTODOS DE INICIALIZACIÓN ===================

  Future<void> _loadConfiguration() async {
    try {
      isLoading.value = true;

      // Cargar configuración desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Configuración de audio
      soundEnabled.value = prefs.getBool('sound_enabled') ?? true;
      soundVolume.value = prefs.getDouble('sound_volume') ?? 0.8;

      // RFID — only scan if enabled
      rfidEnabled.value = prefs.getBool('rfid_enabled') ?? false;
      if (rfidEnabled.value && !_rfidScanCancelled) {
        isRfidScanning.value = true;
        connectionStatusMessage.value = 'Buscando lector RFID...';
        await RfidConfig.loadConfig();
        isRfidScanning.value = false;
        if (!_rfidScanCancelled) {
          await _checkRfidConnection();
        }
      } else if (!rfidEnabled.value) {
        connectionStatusMessage.value = 'Desactivado';
      }
    } catch (e) {
      AppLogger.error(
          'ConfiguracionController', 'Error al cargar configuración', e);
    } finally {
      isLoading.value = false;
    }
  }

  // =================== MÉTODOS DE CONEXIÓN ESP32 ===================

  /// Conectar manualmente con IP específica
  Future<void> connectToESP32WithIP(String ipAddress,
      {bool showNotification = true}) async {
    try {
      isLoading.value = true;
      esp32StatusMessage.value = 'Conectando a $ipAddress...';

      final RegExp ipRegex = RegExp(
          r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
      if (!ipRegex.hasMatch(ipAddress)) {
        if (showNotification) {
          SnackbarHelper.error('Formato inválido',
              'La dirección IP no tiene un formato válido (ej: 192.168.1.100)');
        }
        return;
      }

      bool connected = await RfidConfig.setManualIP(ipAddress);

      if (connected) {
        esp32Connected.value = true;
        esp32IpAddress.value = ipAddress;
        esp32StatusMessage.value = 'ESP32 conectado: $ipAddress';

        if (showNotification) {
          SnackbarHelper.success(
              'Conectado', 'ESP32 conectado exitosamente a $ipAddress');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('esp32_ip_manual', ipAddress);
      } else {
        esp32Connected.value = false;
        esp32StatusMessage.value = 'No se pudo conectar a $ipAddress';

        if (showNotification) {
          SnackbarHelper.error('Error de conexión',
              'No se pudo conectar al ESP32 en $ipAddress.');
        }
      }
    } catch (e) {
      esp32Connected.value = false;
      esp32StatusMessage.value = 'Error: $e';

      if (showNotification) {
        SnackbarHelper.error('Error', 'Error al conectar: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Obtener estado del ESP32
  Future<void> getESP32Status() async {
    try {
      bool available = await RfidConfig.isESP32Available();

      if (available) {
        esp32Connected.value = true;
        esp32IpAddress.value =
            RfidConfig.getCurrentIP() ?? RfidConfig.DEFAULT_ESP32_IP;
        esp32StatusMessage.value = 'ESP32 conectado: ${esp32IpAddress.value}';
      } else {
        esp32Connected.value = false;
        esp32StatusMessage.value = 'ESP32 sin conexión WiFi';
      }
    } catch (e) {
      esp32StatusMessage.value = 'Error al obtener estado: $e';
    }
  }

  // =================== MÉTODOS DE CONFIGURACIÓN RFID ===================

  Future<void> _checkRfidConnection() async {
    try {
      final available = await RfidConfig.isESP32Available();
      rfidConnectionStatus.value = available;

      if (available) {
        connectionStatusMessage.value = 'Conectado y funcionando';
        if (RfidConfig.baseUrl != null) {
          String url = RfidConfig.baseUrl!;
          final RegExp ipRegex = RegExp(r'(\d+\.\d+\.\d+\.\d+)');
          final match = ipRegex.firstMatch(url);
          if (match != null) {
            esp32IpAddress.value = match.group(1)!;
          }
        }
      } else {
        connectionStatusMessage.value = 'Sin conexión al lector';
      }
    } catch (e) {
      rfidConnectionStatus.value = false;
      connectionStatusMessage.value = 'Error al verificar: $e';
    }
  }

  /// Probar conexión RFID (also enables RFID)
  Future<void> testRfidConnection() async {
    try {
      _rfidScanCancelled = false;
      rfidEnabled.value = true;
      isRfidScanning.value = true;
      isLoading.value = true;
      connectionStatusMessage.value = 'Buscando lector RFID...';

      // Persist enabled state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rfid_enabled', true);

      await RfidConfig.loadConfig();
      if (_rfidScanCancelled) return;

      // Real connectivity check
      connectionStatusMessage.value = 'Verificando conexión...';
      final bool isAvailable = await RfidConfig.isESP32Available();
      if (_rfidScanCancelled) return;

      if (!isAvailable) {
        rfidConnectionStatus.value = false;
        connectionStatusMessage.value = 'Sin conexión al lector';
        SnackbarHelper.error('Sin conexión',
            'No se pudo conectar al lector RFID. Verifica que esté encendido y en la misma red WiFi.');
        return;
      }

      // Device is reachable, try reading a card
      connectionStatusMessage.value = 'Probando lectura...';
      String? cardUid = await RfidReaderService.checkForCard();
      if (_rfidScanCancelled) return;

      if (cardUid != null) {
        rfidConnectionStatus.value = true;
        connectionStatusMessage.value = 'Conectado - Tarjeta detectada';
        SnackbarHelper.success('Conexión exitosa',
            'El lector RFID está funcionando correctamente');
      } else {
        rfidConnectionStatus.value = true;
        connectionStatusMessage.value = 'Conectado - Sin tarjeta';
        SnackbarHelper.info('Conexión OK',
            'El lector RFID está conectado pero no hay tarjeta presente');
      }
    } on Exception catch (e) {
      if (!_rfidScanCancelled) {
        rfidConnectionStatus.value = false;
        final msg = e.toString();
        if (msg.contains('TimeoutException') || msg.contains('timed out')) {
          connectionStatusMessage.value = 'Tiempo de espera agotado';
          SnackbarHelper.error('Timeout',
              'El lector RFID no respondió a tiempo. Verifica que esté encendido.');
        } else if (msg.contains('Connection refused') ||
            msg.contains('ECONNREFUSED')) {
          connectionStatusMessage.value = 'Conexión rechazada';
          SnackbarHelper.error('Conexión rechazada',
              'El lector RFID rechazó la conexión. Verifica la IP configurada.');
        } else if (msg.contains('Network is unreachable') ||
            msg.contains('No route to host')) {
          connectionStatusMessage.value = 'Red no disponible';
          SnackbarHelper.error('Sin red',
              'No se puede alcanzar la red del lector. Verifica tu conexión WiFi.');
        } else {
          connectionStatusMessage.value = 'Error de conexión';
          SnackbarHelper.error('Error', 'Error al conectar: $msg');
        }
      }
    } finally {
      isRfidScanning.value = false;
      isLoading.value = false;
    }
  }

  /// Cancel ongoing RFID scan / disable RFID
  void cancelRfidScan() async {
    _rfidScanCancelled = true;
    rfidEnabled.value = false;
    isRfidScanning.value = false;
    rfidConnectionStatus.value = false;
    isLoading.value = false;
    connectionStatusMessage.value = 'Desactivado';

    // Persist disabled state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rfid_enabled', false);
  }

  // =================== MÉTODOS DE CONFIGURACIÓN ===================

  /// Guardar configuración de audio
  Future<void> saveAudioConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', soundEnabled.value);
      await prefs.setDouble('sound_volume', soundVolume.value);
      SnackbarHelper.success('Guardado', 'Configuración de audio guardada');
    } catch (e) {
      SnackbarHelper.error(
          'Error', 'Error al guardar configuración de audio: $e');
    }
  }

  // =================== MÉTODOS PARA NAVEGACIÓN DE CONFIGURACIÓN ===================

  /// Abrir configuración de cuenta — navega a CuentaView
  void openAccountSettings() {
    Get.toNamed(Routes.CUENTA);
  }

  /// Abrir configuración de precios de abonos (precio fijo por periodo)
  void openAbonoPrices() {
    Get.toNamed(Routes.ABONO_PRICES);
  }

  // =================== LOGOUT ===================

  /// Cerrar sesión con confirmación
  void logout() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '¿Estás seguro que deseas cerrar la sesión?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // close dialog
              await _performLogout();
            },
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      isLoading.value = true;

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // Clear tenant context
      await TenantContextService.to.clearProfile();

      // Navigate to login
      Get.offAllNamed(Routes.LOGIN);
    } catch (e) {
      AppLogger.error('ConfiguracionController', 'Fallo al cerrar sesión', e);
      SnackbarHelper.error('Error', 'Error al cerrar sesión: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // =================== DELETE GYM & ACCOUNT ===================

  /// Delete entire gym data and owner account via Supabase RPC
  Future<void> deleteGymAndAccount() async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null) {
      SnackbarHelper.error('Error', 'No se encontró el gimnasio');
      return;
    }

    // First confirmation
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '¿Borrar todos los datos?',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Esta acción eliminará permanentemente:\n\n'
          '• Todos los clientes y membresías\n'
          '• Todo el inventario y ventas\n'
          '• Todos los registros de acceso\n'
          '• Todos los pagos e ingresos\n'
          '• El gimnasio y sus sucursales\n'
          '• Tu cuenta de usuario\n\n'
          'Esta acción NO se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Sí, borrar todo',
              style: TextStyle(
                  color: Colors.red[400], fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Second confirmation — type gym name
    final nameConfirmed = await Get.dialog<bool>(
      _ConfirmDeleteDialog(gymName: gymName.value),
    );

    if (nameConfirmed != true) return;

    // Execute deletion
    try {
      isLoading.value = true;

      await Supabase.instance.client
          .rpc('delete_gym_cascade', params: {'p_gym_id': gymId});

      // La cuenta ya no existe en el servidor: cerrar sesión para no dejar
      // el token guardado en el dispositivo.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        AppLogger.warning(
            'ConfiguracionController', 'No se pudo cerrar la sesión');
      }

      // Clear local data
      await TenantContextService.to.clearProfile();

      // Las fotos de clientes de un gimnasio borrado no deben quedar en disco
      try {
        await ImageCacheService.instance.clearAllCache();
      } catch (e) {
        AppLogger.warning('ConfiguracionController',
            'No se pudo limpiar el caché de imágenes');
      }

      // Navigate to login
      Get.offAllNamed(Routes.LOGIN);

      // Show success after navigation
      Future.delayed(const Duration(milliseconds: 500), () {
        SnackbarHelper.success(
            'Cuenta eliminada', 'Todos los datos han sido borrados');
      });
    } catch (e) {
      AppLogger.error(
          'ConfiguracionController', 'Fallo al eliminar el gimnasio', e);
      final mensaje = e.toString().contains('Only the gym owner')
          ? 'Solo el dueño del gimnasio puede borrar los datos'
          : 'No se pudieron borrar los datos. Revisa tu conexión e inténtalo de nuevo.';
      SnackbarHelper.error('Error', mensaje);
    } finally {
      isLoading.value = false;
    }
  }
}

/// Dialog that requires typing the gym name to confirm deletion
class _ConfirmDeleteDialog extends StatelessWidget {
  final String gymName;
  _ConfirmDeleteDialog({required this.gymName});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    final isMatch = false.obs;

    return Obx(() => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Confirmar eliminación',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.5),
                  children: [
                    const TextSpan(
                        text:
                            'Para confirmar, escribe el nombre de tu gimnasio:\n\n'),
                    TextSpan(
                      text: gymName,
                      style: TextStyle(
                        color: Colors.red[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Escribe el nombre aquí',
                  hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red[400]!),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                onChanged: (val) {
                  isMatch.value =
                      val.trim().toLowerCase() == gymName.trim().toLowerCase();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isMatch.value ? () => Get.back(result: true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[800],
              ),
              child: const Text('Borrar permanentemente'),
            ),
          ],
        ));
  }
}

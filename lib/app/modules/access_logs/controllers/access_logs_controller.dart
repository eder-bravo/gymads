import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/access_log_model.dart';
import '../../../data/services/access_log_service.dart';

class AccessLogsController extends GetxController {
  // Estados reactivos
  final isLoading = false.obs;
  final accessLogs = <AccessLogModel>[].obs;
  final errorMessage = ''.obs;

  // Estadísticas
  final totalEntries = 0.obs;
  final totalQrAccesses = 0.obs;
  final totalRfidAccesses = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadAccessLogs();
  }

  /// Cargar logs de acceso desde Supabase
  Future<void> loadAccessLogs() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      if (kDebugMode) {
        print('📊 Cargando logs de acceso desde Supabase...');
      }

      final logs = await AccessLogService.getAllAccessLogs();

      if (logs != null && logs.isNotEmpty) {
        accessLogs.value = logs;
        calculateStatistics();

        if (kDebugMode) {
          print('✅ ${logs.length} logs de acceso cargados exitosamente');
        }
      } else if (logs != null && logs.isEmpty) {
        // Caso donde la consulta fue exitosa pero no hay datos
        accessLogs.clear();
        errorMessage.value = '';

        if (kDebugMode) {
          print('ℹ️ No se encontraron logs de acceso en la base de datos');
        }
      } else {
        // Caso donde hubo un error en la consulta
        errorMessage.value = 'No se pudieron cargar los logs de acceso';
        accessLogs.clear();

        if (kDebugMode) {
          print('❌ Error: No se pudieron cargar los logs');
        }
      }
    } catch (e) {
      errorMessage.value = 'Error al cargar logs: ${e.toString()}';
      accessLogs.clear();

      if (kDebugMode) {
        print('❌ Excepción al cargar logs: $e');
      }

      // Mostrar snackbar de error
      SnackbarHelper.error(
          'Error', 'No se pudieron cargar los registros de acceso: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Calcular estadísticas
  void calculateStatistics() {
    final logs = accessLogs;

    totalEntries.value =
        logs.where((log) => log.accessType == 'entrada').length;
    totalQrAccesses.value = logs.where((log) => log.method == 'qr').length;
    totalRfidAccesses.value = logs.where((log) => log.method == 'rfid').length;
  }

  /// Refrescar datos
  Future<void> refreshData() async {
    await loadAccessLogs();
  }

  /// Obtener estadísticas formateadas para mostrar
  Map<String, String> getFormattedStats() {
    return {
      'totalEntries': totalEntries.value.toString(),
      'totalQr': totalQrAccesses.value.toString(),
      'totalRfid': totalRfidAccesses.value.toString(),
      'total': accessLogs.length.toString(),
    };
  }
}

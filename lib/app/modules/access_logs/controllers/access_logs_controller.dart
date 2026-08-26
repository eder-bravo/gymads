import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/screen_tour_mixin.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/access_log_model.dart';
import '../../../data/services/access_log_service.dart';
import '../../../data/services/welcome_tour_service.dart';

class AccessLogsController extends GetxController with ScreenTourMixin {
  // Estados reactivos
  final isLoading = false.obs;
  final accessLogs = <AccessLogModel>[].obs;
  final errorMessage = ''.obs;

  // Estadísticas
  final totalEntries = 0.obs;
  final totalRfidAccesses = 0.obs;

  // ─── Tour de bienvenida ───
  final keyResumen = GlobalKey();
  final keyLista = GlobalKey();

  @override
  String get tourId => AppTours.entradas;

  @override
  List<GlobalKey> get tourSteps => [keyResumen, keyLista];

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

      AppLogger.info('AccessLogsController', 'Cargando logs de acceso desde Supabase');

      final logs = await AccessLogService.getAllAccessLogs();

      if (logs != null && logs.isNotEmpty) {
        accessLogs.value = logs;
        calculateStatistics();

        AppLogger.info('AccessLogsController', '${logs.length} logs de acceso cargados exitosamente');
      } else if (logs != null && logs.isEmpty) {
        // Caso donde la consulta fue exitosa pero no hay datos
        accessLogs.clear();
        errorMessage.value = '';

        AppLogger.info('AccessLogsController', 'No se encontraron logs de acceso');
      } else {
        // Caso donde hubo un error en la consulta
        errorMessage.value = 'No se pudieron cargar los logs de acceso';
        accessLogs.clear();

        AppLogger.error('AccessLogsController', 'Error: No se pudieron cargar los logs');
      }
    } catch (e) {
      errorMessage.value = 'Error al cargar logs: ${e.toString()}';
      accessLogs.clear();

      AppLogger.error('AccessLogsController', 'Excepción al cargar logs', e);

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
      'totalRfid': totalRfidAccesses.value.toString(),
      'total': accessLogs.length.toString(),
    };
  }
}

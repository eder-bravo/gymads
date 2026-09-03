import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/hora_formato.dart';
import 'package:gymads/app/core/utils/periodo_filtro_mixin.dart';
import 'package:gymads/app/core/utils/screen_tour_mixin.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/access_log_model.dart';
import '../../../data/models/gym_settings_model.dart';
import '../../../data/services/access_log_service.dart';
import '../../../data/services/gym_settings_service.dart';
import '../../../data/services/pdf_report_service.dart';
import '../../../data/services/welcome_tour_service.dart';
import '../services/entradas_pdf_builder.dart';

class AccessLogsController extends GetxController
    with ScreenTourMixin, PeriodoFiltroMixin {
  // Estados reactivos
  final isLoading = false.obs;
  final accessLogs = <AccessLogModel>[].obs;
  final errorMessage = ''.obs;

  // Estadísticas
  final totalEntries = 0.obs;
  final totalExits = 0.obs;

  /// Horario configurado, para acotar el desglose por franja horaria.
  final Rx<GymSettingsModel> ajustes = const GymSettingsModel().obs;

  final RxBool isExportando = false.obs;

  // ─── Tour de bienvenida ───
  final keyPeriodo = GlobalKey();
  final keyResumen = GlobalKey();
  final keyLista = GlobalKey();

  @override
  String get tourId => AppTours.entradas;

  @override
  List<GlobalKey> get tourSteps => [keyPeriodo, keyResumen, keyLista];

  @override
  void onInit() {
    super.onInit();
    _cargarAjustes();
    // Abre en el día de hoy; `iniciarEnHoy` dispara la carga.
    iniciarEnHoy();
  }

  @override
  Future<void> onPeriodoChanged() => loadAccessLogs();

  Future<void> _cargarAjustes() async {
    ajustes.value = await GymSettingsService.current();
  }

  /// Cargar los accesos del periodo seleccionado
  Future<void> loadAccessLogs() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final desde = fechaInicio.value;
      final hasta = fechaFin.value;
      if (desde == null || hasta == null) return;

      final logs = await AccessLogService.getAccessLogsByDate(desde, hasta);

      if (logs == null) {
        errorMessage.value = 'No se pudieron cargar los registros';
        accessLogs.clear();
        AppLogger.error('AccessLogsController', 'Error: no se pudieron cargar los logs');
        return;
      }

      accessLogs.value = logs;
      calculateStatistics();
      AppLogger.info(
          'AccessLogsController', '${logs.length} accesos cargados');
    } catch (e) {
      errorMessage.value = 'Error al cargar registros: ${e.toString()}';
      accessLogs.clear();
      AppLogger.error('AccessLogsController', 'Excepción al cargar logs', e);
      SnackbarHelper.error(
          'Error', 'No se pudieron cargar los registros de acceso');
    } finally {
      isLoading.value = false;
    }
  }

  void calculateStatistics() {
    totalEntries.value =
        accessLogs.where((log) => log.accessType == 'entrada').length;
    totalExits.value =
        accessLogs.where((log) => log.accessType == 'salida').length;
  }

  Future<void> refreshData() async {
    await _cargarAjustes();
    await loadAccessLogs();
  }

  /// Solo las entradas: para el conteo por franja la salida no cuenta como
  /// visita, o cada cliente aparecería dos veces.
  List<AccessLogModel> get entradas =>
      accessLogs.where((log) => log.accessType == 'entrada').toList();

  /// Si el gimnasio tiene activado el registro de salidas.
  bool get muestraSalidas => ajustes.value.registrarSalidas;

  // ══════════════════════════════════════════════════════════
  // FRANJAS HORARIAS
  // ══════════════════════════════════════════════════════════

  /// Duración de cada bloque del desglose.
  static const int _horasPorFranja = 2;

  /// Entradas agrupadas en bloques de dos horas, desde la apertura hasta el
  /// cierre. Las franjas vacías se conservan para que el perfil del día se
  /// lea de un vistazo.
  ///
  /// La clave es la hora en que empieza el bloque.
  Map<int, int> get entradasPorFranja {
    final apertura = ajustes.value.horaApertura.hora;
    final bloques = (ajustes.value.horasAbierto / _horasPorFranja).ceil();

    final conteo = <int, int>{
      for (var i = 0; i < bloques; i++)
        (apertura + i * _horasPorFranja) % 24: 0,
    };

    for (final log in entradas) {
      final clave = _franjaDe(log.accessTime.hour, apertura, bloques);
      conteo[clave] = (conteo[clave] ?? 0) + 1;
    }

    return conteo;
  }

  /// A qué bloque pertenece una hora.
  ///
  /// Lo que cae fuera del horario no se descarta —una entrada antes de abrir
  /// sigue siendo una visita— sino que se suma al bloque más cercano: al
  /// primero si ocurrió poco antes de abrir, al último si fue tras cerrar.
  int _franjaDe(int hora, int apertura, int bloques) {
    final desdeApertura = (hora - apertura + 24) % 24;
    final abierto = ajustes.value.horasAbierto;

    if (desdeApertura >= abierto) {
      final faltaParaAbrir = (apertura - hora + 24) % 24;
      final desdeElCierre = desdeApertura - abierto;
      final indice = faltaParaAbrir <= desdeElCierre ? 0 : bloques - 1;
      return (apertura + indice * _horasPorFranja) % 24;
    }

    final indice = desdeApertura ~/ _horasPorFranja;
    final acotado = indice >= bloques ? bloques - 1 : indice;
    return (apertura + acotado * _horasPorFranja) % 24;
  }

  /// Hora de inicio de la franja con más entradas. Null si no hubo ninguna.
  int? get franjaPico {
    final datos = entradasPorFranja;
    if (datos.isEmpty) return null;

    int? mejor;
    var maximo = 0;
    for (final e in datos.entries) {
      if (e.value > maximo) {
        maximo = e.value;
        mejor = e.key;
      }
    }
    return maximo == 0 ? null : mejor;
  }

  /// "6 – 8 a.m." · "10 a.m. – 12 p.m."
  String etiquetaFranja(int horaInicio) {
    final fin = (horaInicio + _horasPorFranja) % 24;
    return HoraFormato.rango(horaInicio, fin);
  }

  String get franjaPicoLabel {
    final pico = franjaPico;
    return pico == null ? '—' : etiquetaFranja(pico);
  }

  /// Cuántas entradas tuvo la franja más concurrida, para escalar las barras.
  int get maximoPorFranja {
    final valores = entradasPorFranja.values;
    if (valores.isEmpty) return 0;
    return valores.reduce((a, b) => a > b ? a : b);
  }


  // ══════════════════════════════════════════════════════════
  // REPORTE EN PDF
  // ══════════════════════════════════════════════════════════

  Future<void> exportarPdf() async {
    if (isExportando.value) return;

    try {
      isExportando.value = true;

      final doc = EntradasPdfBuilder.construir(
        periodoLabel: periodoLabel,
        sufijoPeriodo: periodoSufijo,
        accesos: accessLogs,
        entradas: entradas,
        salidas: totalExits.value,
        muestraSalidas: muestraSalidas,
        porFranja: entradasPorFranja,
        franjaPico: franjaPico,
        etiquetaFranja: etiquetaFranja,
      );

      await PdfReportService.mostrarPreview(
        doc,
        titulo: 'Reporte de entradas',
        nombreArchivo: PdfReportService.nombreArchivo('entradas'),
      );
    } catch (e) {
      AppLogger.error('AccessLogsController', 'Error al generar el PDF', e);
      SnackbarHelper.error('Error', 'No se pudo generar el reporte');
    } finally {
      isExportando.value = false;
    }
  }
}

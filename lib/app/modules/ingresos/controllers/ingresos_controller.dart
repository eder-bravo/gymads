import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/periodo_filtro_mixin.dart';
import 'package:gymads/app/core/utils/screen_tour_mixin.dart';
import 'package:gymads/app/core/utils/snackbar_helper.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/pdf_report_service.dart';
import 'package:gymads/app/modules/ingresos/services/ingresos_pdf_builder.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';

class IngresosController extends GetxController
    with ScreenTourMixin, PeriodoFiltroMixin {
  final IngresoService ingresoService;

  IngresosController({required this.ingresoService});

  // Estado observable
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Datos de ingresos
  final Rx<EstadisticasIngresos> estadisticas =
      EstadisticasIngresos.empty().obs;
  final RxList<IngresoModel> ingresos = <IngresoModel>[].obs;
  final RxMap<String, double> datosGrafica = <String, double>{}.obs;

  // Todas las transacciones (sin filtro de mes) para la vista completa
  final RxList<IngresoModel> todasTransacciones = <IngresoModel>[].obs;
  final RxBool isLoadingTodas = false.obs;

  // Filtros. El periodo y su rango los aporta PeriodoFiltroMixin.
  final selectedConcepto = Rx<String?>(null);
  final selectedMetodoPago = Rx<String?>(null);

  // Tipo de gráfica
  final selectedChartType = 'barras'.obs; // 'barras', 'pastel', 'lineas'
  final List<String> chartTypes = ['barras', 'pastel', 'lineas'];

  // Opciones para filtros
  final List<String> periodos = ['dia', 'semana', 'mes'];
  final List<String> conceptos = ['registro', 'renovacion', 'producto'];
  final List<String> metodosPago = ['efectivo', 'tarjeta', 'transferencia'];

  // ─── Tour de bienvenida ───
  final keyPeriodo = GlobalKey();
  final keyTotal = GlobalKey();
  final keyVerTodas = GlobalKey();
  final keyLista = GlobalKey();

  @override
  String get tourId => AppTours.ingresos;

  @override
  List<GlobalKey> get tourSteps =>
      [keyPeriodo, keyTotal, keyVerTodas, keyLista];

  @override
  void onInit() {
    super.onInit();
    // Abre en el día de hoy: lo que se consulta a diario es lo cobrado hoy.
    // `iniciarEnHoy` fija el rango completo (00:00 a 23:59:59) y dispara la
    // carga por `onPeriodoChanged`.
    iniciarEnHoy();
  }

  @override
  Future<void> onPeriodoChanged() => refreshData();

  /// Obtiene las estadísticas de ingresos
  Future<void> fetchEstadisticas() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      AppLogger.info('IngresosController', 'Obteniendo estadísticas de ingresos');

      final stats = await ingresoService.getEstadisticas(
        fechaInicio: fechaInicio.value,
        fechaFin: fechaFin.value,
      );

      estadisticas.value = stats;
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al obtener estadísticas', e);
      errorMessage.value = 'Error al cargar estadísticas: $e';

      SnackbarHelper.error('Error', 'Error al cargar estadísticas: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Obtiene la lista de ingresos
  Future<void> fetchIngresos() async {
    try {
      AppLogger.info('IngresosController', 'Obteniendo lista de ingresos');

      final listaIngresos = await ingresoService.getIngresos(
        fechaInicio: fechaInicio.value,
        fechaFin: fechaFin.value,
        concepto: selectedConcepto.value,
        metodoPago: selectedMetodoPago.value,
        limit: 50,
      );

      ingresos.assignAll(listaIngresos);
      AppLogger.info('IngresosController', '${listaIngresos.length} ingresos obtenidos');
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al obtener ingresos', e);
      errorMessage.value = 'Error al cargar ingresos: $e';
    }
  }

  /// Obtiene todas las transacciones registradas (sin filtro de mes)
  Future<void> fetchTodasLasTransacciones() async {
    try {
      isLoadingTodas.value = true;
      AppLogger.info('IngresosController', 'Obteniendo TODAS las transacciones');

      final lista = await ingresoService.getIngresos(limit: 1000);

      todasTransacciones.assignAll(lista);
      AppLogger.info('IngresosController', '${lista.length} transacciones (todas) obtenidas');
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al obtener todas las transacciones', e);
      SnackbarHelper.error(
          'Error', 'No se pudieron cargar todas las transacciones');
    } finally {
      isLoadingTodas.value = false;
    }
  }

  /// Obtiene datos para la gráfica
  Future<void> fetchDatosGrafica() async {
    try {
      AppLogger.info('IngresosController', 'Obteniendo datos para gráfica');

      final datos = await ingresoService.getIngresosPorPeriodo(
        fechaInicio: fechaInicio.value ??
            DateTime(DateTime.now().year, DateTime.now().month, 1),
        fechaFin: fechaFin.value ?? DateTime.now(),
        agrupacion: selectedPeriodo.value,
      );

      datosGrafica.assignAll(datos);
      AppLogger.info('IngresosController', 'Datos de gráfica obtenidos: puntos');
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al obtener datos de gráfica', e);
    }
  }

  /// Actualiza el filtro de concepto
  void changeConcepto(String? concepto) {
    try {
      selectedConcepto.value = concepto;
      fetchIngresos();
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al cambiar concepto', e);
      SnackbarHelper.error('Error', 'Error al aplicar filtro: $e');
    }
  }

  /// Actualiza el filtro de método de pago
  void changeMetodoPago(String? metodoPago) {
    try {
      selectedMetodoPago.value = metodoPago;
      fetchIngresos();
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al cambiar método de pago', e);
      SnackbarHelper.error('Error', 'Error al aplicar filtro: $e');
    }
  }

  /// Recarga todos los datos
  Future<void> refreshData() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await Future.wait([
        fetchEstadisticas().catchError((e) {
          AppLogger.error('IngresosController', 'Error al refrescar estadísticas', e);
          return null;
        }),
        fetchIngresos().catchError((e) {
          AppLogger.error('IngresosController', 'Error al refrescar ingresos', e);
          return null;
        }),
        fetchDatosGrafica().catchError((e) {
          AppLogger.error('IngresosController', 'Error al refrescar datos de gráfica', e);
          return null;
        }),
      ]);
    } catch (e) {
      AppLogger.error('IngresosController', 'Error general al refrescar datos', e);
      errorMessage.value = 'Error al actualizar datos: $e';

      SnackbarHelper.error(
          'Error', 'Error al actualizar datos. Intente nuevamente.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Método público para refrescar datos desde otros módulos
  static Future<void> refreshIngresosGlobally() async {
    try {
      AppLogger.info('IngresosController', 'Iniciando refresh global de ingresos');

      // Verificar si el controlador ya está registrado
      if (Get.isRegistered<IngresosController>()) {
        final controller = Get.find<IngresosController>();
        AppLogger.info('IngresosController', 'Controlador de ingresos encontrado, refrescando datos');
        await controller.refreshData();
        AppLogger.info('IngresosController', 'Datos de ingresos actualizados globalmente');
      } else {
        AppLogger.warning('IngresosController', 'IngresosController no está registrado aún. Los datos se actualizarán cuando se navegue a la pantalla de ingresos');
      }
    } catch (e) {
      AppLogger.warning('IngresosController', 'No se pudo actualizar el controlador de ingresos');
      AppLogger.info('IngresosController', 'Error tipo: ${e.runtimeType}');
      // No lanzar excepción para no interrumpir el flujo principal
    }
  }

  /// Formatea un número como moneda
  String formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  // ══════════════════════════════════════════════════════════
  // REPORTE EN PDF
  // ══════════════════════════════════════════════════════════

  final RxBool isExportando = false.obs;

  /// Genera el reporte del periodo activo y lo abre en vista previa.
  Future<void> exportarPdf() async {
    if (isExportando.value) return;

    try {
      isExportando.value = true;

      // Se vuelve a consultar en vez de usar `ingresos`: esa lista está
      // capada a 50 para la pantalla, mientras que el total de la tarjeta
      // cubre hasta 1000. Reutilizarla daría un PDF recortado cuyo detalle no
      // cuadraría con su propio total.
      final detalle = await ingresoService.getIngresos(
        fechaInicio: fechaInicio.value,
        fechaFin: fechaFin.value,
        concepto: selectedConcepto.value,
        metodoPago: selectedMetodoPago.value,
        limit: 1000,
      );

      final doc = IngresosPdfBuilder.construir(
        periodoLabel: periodoLabel,
        totalLabel: periodoTotalLabel,
        estadisticas: estadisticas.value,
        ingresos: detalle,
      );

      await PdfReportService.mostrarPreview(
        doc,
        titulo: 'Reporte de ingresos',
        nombreArchivo: PdfReportService.nombreArchivo('ingresos'),
      );
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al generar el PDF', e);
      SnackbarHelper.error('Error', 'No se pudo generar el reporte');
    } finally {
      isExportando.value = false;
    }
  }

  /// Obtiene el color para un concepto
  Color getColorForConcepto(String concepto) {
    switch (concepto) {
      case 'nuevo_registro':
        return Colors.green;
      case 'renovacion':
        return Colors.blue;
      case 'registro':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Obtiene el color para un método de pago
  Color getColorForMetodoPago(String metodoPago) {
    switch (metodoPago) {
      case 'efectivo':
        return Colors.green;
      case 'tarjeta':
      case 'tarjeta_debito':
      case 'tarjeta_credito':
        return Colors.blue;
      case 'transferencia':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Cambia el tipo de gráfica
  void changeChartType(String chartType) {
    try {
      selectedChartType.value = chartType;
      // No es necesario recargar datos, sólo cambiar la visualización
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al cambiar tipo de gráfica', e);
      SnackbarHelper.error('Error', 'Error al cambiar tipo de gráfica: $e');
    }
  }

  /// Calcula el porcentaje de crecimiento
  double calcularPorcentajeCrecimiento(double actual, double anterior) {
    if (anterior == 0) return actual > 0 ? 100 : 0;
    return ((actual - anterior) / anterior) * 100;
  }

  /// Obtiene datos para la gráfica de tipo pie
  Map<String, double> getDatosPastel() {
    try {
      // Para la gráfica de pastel usamos los datos por concepto
      if (estadisticas.value.ingresosPorConcepto.isEmpty) {
        return {};
      }

      Map<String, double> datosFormateados = {};

      // Transformar las claves para mostrar nombres más amigables
      estadisticas.value.ingresosPorConcepto.forEach((key, value) {
        switch (key) {
          case 'registro':
            datosFormateados['Nuevo Registro'] = value;
            break;
          case 'renovacion':
            datosFormateados['Renovación'] = value;
            break;
          case 'producto':
            datosFormateados['Producto'] = value;
            break;
          default:
            datosFormateados[key.capitalize!] = value;
        }
      });

      return datosFormateados;
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al obtener datos para gráfica pie', e);
      return {};
    }
  }

  /// Obtiene datos para la gráfica de línea
  Map<String, double> getDatosLinea() {
    try {
      // Para la gráfica de línea usamos los mismos datos que las barras
      return datosGrafica;
    } catch (e) {
      AppLogger.error('IngresosController', 'Error al obtener datos para gráfica línea', e);
      return {};
    }
  }

  /// Obtiene los colores para la gráfica de pastel
  List<Color> getColoresPastel() {
    return [
      Colors.orange.shade600,
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
      Colors.amber.shade700,
      Colors.indigo.shade600,
      Colors.pink.shade600,
      Colors.cyan.shade600,
    ];
  }

  /// Calcula el total para la gráfica de pastel
  double getTotalPastel() {
    final datos = getDatosPastel();
    return datos.values.fold(0, (prev, curr) => prev + curr);
  }

  /// Lista filtrada de ingresos para mostrar
  List<IngresoModel> get ingresosFiltrados => ingresos;

  /// Indica si hay datos de ingresos
  bool get tieneIngresos => ingresos.isNotEmpty;

  /// Indica si hay datos para la gráfica
  bool get tieneDatosGrafica => datosGrafica.isNotEmpty;

  /// Total de ingresos del período actual
  double get totalIngresosActual => estadisticas.value.totalIngresos;

  /// Promedio de transacción
  double get promedioTransaccion => estadisticas.value.promedioTransaccion;

  /// Número total de transacciones
  int get totalTransacciones => estadisticas.value.totalTransacciones;
}

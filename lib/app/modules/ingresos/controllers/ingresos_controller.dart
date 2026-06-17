import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/snackbar_helper.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';

class IngresosController extends GetxController {
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

  // Filtros
  final selectedPeriodo = 'mes'.obs; // 'dia', 'semana', 'mes'
  final selectedConcepto = Rx<String?>(null);
  final selectedMetodoPago = Rx<String?>(null);
  final fechaInicio = Rx<DateTime?>(null);
  final fechaFin = Rx<DateTime?>(null);

  // Tipo de gráfica
  final selectedChartType = 'barras'.obs; // 'barras', 'pastel', 'lineas'
  final List<String> chartTypes = ['barras', 'pastel', 'lineas'];

  // Opciones para filtros
  final List<String> periodos = ['dia', 'semana', 'mes'];
  final List<String> conceptos = ['registro', 'renovacion', 'producto'];
  final List<String> metodosPago = ['efectivo', 'tarjeta', 'transferencia'];

  // Nombres de meses en español (evita depender de locale de intl)
  static const List<String> nombresMeses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const List<String> nombresMesesCortos = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  void onInit() {
    super.onInit();
    // Inicializar con el mes actual
    final now = DateTime.now();
    fechaInicio.value = DateTime(now.year, now.month, 1);
    fechaFin.value = DateTime(now.year, now.month + 1, 0);

    // Cargar datos iniciales
    fetchEstadisticas();
    fetchIngresos();
    fetchDatosGrafica();
  }

  /// Obtiene las estadísticas de ingresos
  Future<void> fetchEstadisticas() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      print('📊 Obteniendo estadísticas de ingresos...');

      final stats = await ingresoService.getEstadisticas(
        fechaInicio: fechaInicio.value,
        fechaFin: fechaFin.value,
      );

      estadisticas.value = stats;
      print(
          '✅ Estadísticas obtenidas: Total \$${stats.totalIngresos.toStringAsFixed(2)}');
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      errorMessage.value = 'Error al cargar estadísticas: $e';

      SnackbarHelper.error('Error', 'Error al cargar estadísticas: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Obtiene la lista de ingresos
  Future<void> fetchIngresos() async {
    try {
      print('📋 Obteniendo lista de ingresos...');

      final listaIngresos = await ingresoService.getIngresos(
        fechaInicio: fechaInicio.value,
        fechaFin: fechaFin.value,
        concepto: selectedConcepto.value,
        metodoPago: selectedMetodoPago.value,
        limit: 50,
      );

      ingresos.assignAll(listaIngresos);
      print('✅ ${listaIngresos.length} ingresos obtenidos');
    } catch (e) {
      print('❌ Error al obtener ingresos: $e');
      errorMessage.value = 'Error al cargar ingresos: $e';
    }
  }

  /// Obtiene datos para la gráfica
  Future<void> fetchDatosGrafica() async {
    try {
      print('📈 Obteniendo datos para gráfica...');

      final datos = await ingresoService.getIngresosPorPeriodo(
        fechaInicio: fechaInicio.value ??
            DateTime(DateTime.now().year, DateTime.now().month, 1),
        fechaFin: fechaFin.value ?? DateTime.now(),
        agrupacion: selectedPeriodo.value,
      );

      datosGrafica.assignAll(datos);
      print('✅ Datos de gráfica obtenidos: ${datos.length} puntos');
    } catch (e) {
      print('❌ Error al obtener datos de gráfica: $e');
    }
  }

  /// Actualiza el período seleccionado y recarga datos
  void changePeriodo(String nuevoPeriodo) {
    try {
      selectedPeriodo.value = nuevoPeriodo;
      final now = DateTime.now();

      switch (nuevoPeriodo) {
        case 'dia':
          fechaInicio.value = DateTime(now.year, now.month, now.day);
          fechaFin.value = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'semana':
          final inicioSemana = now.subtract(Duration(days: now.weekday - 1));
          fechaInicio.value =
              DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
          fechaFin.value = inicioSemana.add(
              const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case 'mes':
          fechaInicio.value = DateTime(now.year, now.month, 1);
          fechaFin.value = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        default:
          print('⚠️ Período no reconocido: $nuevoPeriodo');
          fechaInicio.value = DateTime(now.year, now.month, 1);
          fechaFin.value = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }

      refreshData();
    } catch (e) {
      print('❌ Error al cambiar período: $e');
      SnackbarHelper.error('Error', 'Error al cambiar período: $e');
    }
  }

  /// Actualiza el filtro de concepto
  void changeConcepto(String? concepto) {
    try {
      selectedConcepto.value = concepto;
      fetchIngresos();
    } catch (e) {
      print('❌ Error al cambiar concepto: $e');
      SnackbarHelper.error('Error', 'Error al aplicar filtro: $e');
    }
  }

  /// Actualiza el filtro de método de pago
  void changeMetodoPago(String? metodoPago) {
    try {
      selectedMetodoPago.value = metodoPago;
      fetchIngresos();
    } catch (e) {
      print('❌ Error al cambiar método de pago: $e');
      SnackbarHelper.error('Error', 'Error al aplicar filtro: $e');
    }
  }

  /// Establece un rango de fechas personalizado
  void setFechasPersonalizadas(DateTime inicio, DateTime fin) {
    fechaInicio.value = inicio;
    fechaFin.value = fin;
    refreshData();
  }

  /// Recarga todos los datos
  Future<void> refreshData() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      await Future.wait([
        fetchEstadisticas().catchError((e) {
          print('❌ Error al refrescar estadísticas: $e');
          return null;
        }),
        fetchIngresos().catchError((e) {
          print('❌ Error al refrescar ingresos: $e');
          return null;
        }),
        fetchDatosGrafica().catchError((e) {
          print('❌ Error al refrescar datos de gráfica: $e');
          return null;
        }),
      ]);
    } catch (e) {
      print('❌ Error general al refrescar datos: $e');
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
      print('🔄 Iniciando refresh global de ingresos...');

      // Verificar si el controlador ya está registrado
      if (Get.isRegistered<IngresosController>()) {
        final controller = Get.find<IngresosController>();
        print('🔄 Controlador de ingresos encontrado, refrescando datos...');
        await controller.refreshData();
        print('✅ Datos de ingresos actualizados globalmente');
      } else {
        print(
            '⚠️ IngresosController no está registrado aún. Los datos se actualizarán cuando se navegue a la pantalla de ingresos.');
      }
    } catch (e) {
      print('⚠️ No se pudo actualizar el controlador de ingresos: $e');
      print('📊 Error tipo: ${e.runtimeType}');
      // No lanzar excepción para no interrumpir el flujo principal
    }
  }

  /// Formatea un número como moneda
  String formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Etiqueta del mes seleccionado, ej: "Mayo 2026"
  String get mesSeleccionadoLabel {
    final f = fechaInicio.value ?? DateTime.now();
    return '${nombresMeses[f.month - 1]} ${f.year}';
  }

  /// Solo el nombre del mes seleccionado, ej: "mayo"
  String get nombreMesSeleccionado {
    final f = fechaInicio.value ?? DateTime.now();
    return nombresMeses[f.month - 1].toLowerCase();
  }

  /// Formatea una fecha de forma corta en español, ej: "27 may"
  String formatFechaCorta(DateTime date) {
    return '${date.day} ${nombresMesesCortos[date.month - 1]}';
  }

  /// Indica si se puede avanzar al mes siguiente (no permite meses futuros)
  bool get puedeAvanzarMes {
    final f = fechaInicio.value ?? DateTime.now();
    final now = DateTime.now();
    return f.year < now.year || (f.year == now.year && f.month < now.month);
  }

  void _setMonth(int year, int month) {
    selectedPeriodo.value = 'mes';
    fechaInicio.value = DateTime(year, month, 1);
    fechaFin.value = DateTime(year, month + 1, 0, 23, 59, 59);
    refreshData();
  }

  /// Navega al mes anterior
  void goToPreviousMonth() {
    final f = fechaInicio.value ?? DateTime.now();
    final prev = DateTime(f.year, f.month - 1, 1);
    _setMonth(prev.year, prev.month);
  }

  /// Navega al mes siguiente (si no es futuro)
  void goToNextMonth() {
    if (!puedeAvanzarMes) return;
    final f = fechaInicio.value ?? DateTime.now();
    final next = DateTime(f.year, f.month + 1, 1);
    _setMonth(next.year, next.month);
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
      print('❌ Error al cambiar tipo de gráfica: $e');
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
      print('❌ Error al obtener datos para gráfica pie: $e');
      return {};
    }
  }

  /// Obtiene datos para la gráfica de línea
  Map<String, double> getDatosLinea() {
    try {
      // Para la gráfica de línea usamos los mismos datos que las barras
      return datosGrafica;
    } catch (e) {
      print('❌ Error al obtener datos para gráfica línea: $e');
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

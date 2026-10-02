import 'package:get/get.dart';

import '../../data/services/tenant_context_service.dart';

/// Navegación por día, semana o mes para las pantallas que miran datos en el
/// tiempo (Ingresos, Entradas).
///
/// Guarda el modo activo y el rango que le corresponde, y ofrece las flechas
/// de anterior/siguiente, el salto a una fecha concreta y las etiquetas ya
/// escritas en español. El controller solo tiene que decir qué recargar,
/// implementando [onPeriodoChanged].
///
/// La navegación está acotada por los dos extremos que tienen sentido: nunca
/// al futuro, y nunca antes de que existiera la cuenta.
mixin PeriodoFiltroMixin on GetxController {
  /// Modo activo: 'dia', 'semana', 'mes', o '' para un rango a medida.
  final selectedPeriodo = 'dia'.obs;

  final fechaInicio = Rx<DateTime?>(null);
  final fechaFin = Rx<DateTime?>(null);

  /// Qué recargar cuando cambia el periodo.
  Future<void> onPeriodoChanged();

  /// Deja el rango en el día de hoy. Para llamar desde `onInit`.
  void iniciarEnHoy() => _setDia(DateTime.now());

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

  // ══════════════════════════════════════════════════════════
  // FIJAR EL RANGO
  // ══════════════════════════════════════════════════════════

  /// Lunes (00:00) de la semana que contiene [d].
  DateTime _inicioSemana(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  void _setDia(DateTime day) {
    selectedPeriodo.value = 'dia';
    fechaInicio.value = DateTime(day.year, day.month, day.day);
    fechaFin.value = DateTime(day.year, day.month, day.day, 23, 59, 59);
    onPeriodoChanged();
  }

  void _setSemana(DateTime any) {
    selectedPeriodo.value = 'semana';
    final inicio = _inicioSemana(any);
    fechaInicio.value = inicio;
    fechaFin.value = inicio
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    onPeriodoChanged();
  }

  void _setMes(int year, int month) {
    selectedPeriodo.value = 'mes';
    fechaInicio.value = DateTime(year, month, 1);
    // Día 0 del mes siguiente = último día de este.
    fechaFin.value = DateTime(year, month + 1, 0, 23, 59, 59);
    onPeriodoChanged();
  }

  /// Cambia de modo y salta al periodo que contiene hoy.
  void changePeriodo(String nuevoPeriodo) {
    final now = DateTime.now();
    switch (nuevoPeriodo) {
      case 'dia':
        _setDia(now);
      case 'semana':
        _setSemana(now);
      default:
        _setMes(now.year, now.month);
    }
  }

  void seleccionarDia(DateTime day) => _setDia(day);
  void seleccionarSemana(DateTime day) => _setSemana(day);

  /// No permite meses futuros ni anteriores a la creación de la cuenta.
  void seleccionarMes(int year, int month) {
    if (esMesFuturo(year, month)) return;
    if (esMesAnteriorACreacion(year, month)) return;
    _setMes(year, month);
  }

  /// Rango a medida. Deja [selectedPeriodo] vacío para que ningún modo
  /// aparezca resaltado.
  void setFechasPersonalizadas(DateTime inicio, DateTime fin) {
    selectedPeriodo.value = '';
    fechaInicio.value = inicio;
    fechaFin.value = fin;
    onPeriodoChanged();
  }

  // ══════════════════════════════════════════════════════════
  // NAVEGACIÓN
  // ══════════════════════════════════════════════════════════

  void goToPrevious() {
    if (!puedeRetroceder) return;
    final f = fechaInicio.value ?? DateTime.now();
    switch (selectedPeriodo.value) {
      case 'dia':
        _setDia(f.subtract(const Duration(days: 1)));
      case 'semana':
        _setSemana(f.subtract(const Duration(days: 7)));
      default:
        final prev = DateTime(f.year, f.month - 1, 1);
        _setMes(prev.year, prev.month);
    }
  }

  void goToNext() {
    if (!puedeAvanzar) return;
    final f = fechaInicio.value ?? DateTime.now();
    switch (selectedPeriodo.value) {
      case 'dia':
        _setDia(f.add(const Duration(days: 1)));
      case 'semana':
        _setSemana(f.add(const Duration(days: 7)));
      default:
        final next = DateTime(f.year, f.month + 1, 1);
        _setMes(next.year, next.month);
    }
  }

  // ══════════════════════════════════════════════════════════
  // LÍMITES
  // ══════════════════════════════════════════════════════════

  /// Primer día del mes en que se creó la cuenta. Null si no hay contexto.
  DateTime? get _mesCreacionCuenta {
    if (!Get.isRegistered<TenantContextService>()) return null;
    final created = TenantContextService.to.accountCreatedAt;
    if (created == null) return null;
    return DateTime(created.year, created.month, 1);
  }

  /// Año de creación de la cuenta, para limitar el navegador de años.
  int? get anioCreacionCuenta => _mesCreacionCuenta?.year;

  bool esMesFuturo(int year, int month) {
    final now = DateTime.now();
    return year > now.year || (year == now.year && month > now.month);
  }

  bool esMesAnteriorACreacion(int year, int month) {
    final limite = _mesCreacionCuenta;
    if (limite == null) return false;
    return DateTime(year, month, 1).isBefore(limite);
  }

  bool get puedeAvanzarMes {
    final f = fechaInicio.value ?? DateTime.now();
    final now = DateTime.now();
    return f.year < now.year || (f.year == now.year && f.month < now.month);
  }

  bool get puedeRetrocederMes {
    final limite = _mesCreacionCuenta;
    if (limite == null) return true;
    final f = fechaInicio.value ?? DateTime.now();
    return DateTime(f.year, f.month, 1).isAfter(limite);
  }

  /// En modo rango a medida ('') no hay siguiente ni anterior.
  bool get puedeAvanzar {
    final f = fechaInicio.value ?? DateTime.now();
    final now = DateTime.now();
    switch (selectedPeriodo.value) {
      case 'dia':
        final hoy = DateTime(now.year, now.month, now.day);
        return DateTime(f.year, f.month, f.day).isBefore(hoy);
      case 'semana':
        return _inicioSemana(f).isBefore(_inicioSemana(now));
      case 'mes':
        return puedeAvanzarMes;
      default:
        return false;
    }
  }

  bool get puedeRetroceder {
    switch (selectedPeriodo.value) {
      case 'mes':
        return puedeRetrocederMes;
      case 'dia':
      case 'semana':
        final limite = _mesCreacionCuenta;
        if (limite == null) return true;
        final f = fechaInicio.value ?? DateTime.now();
        return f.isAfter(limite);
      default:
        return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  // ETIQUETAS
  //
  // Escritas a mano en vez de con `intl` para no depender de que el locale
  // esté cargado.
  // ══════════════════════════════════════════════════════════

  /// Ej: "27 may 2026", "12 – 18 may", "Mayo 2026", "1 may – 15 jun".
  String get periodoLabel {
    final ini = fechaInicio.value ?? DateTime.now();
    final fin = fechaFin.value ?? DateTime.now();
    switch (selectedPeriodo.value) {
      case 'dia':
        return '${ini.day} ${nombresMesesCortos[ini.month - 1]} ${ini.year}';
      case 'semana':
        if (ini.month == fin.month) {
          return '${ini.day} – ${fin.day} ${nombresMesesCortos[ini.month - 1]}';
        }
        return '${ini.day} ${nombresMesesCortos[ini.month - 1]} – '
            '${fin.day} ${nombresMesesCortos[fin.month - 1]}';
      case 'mes':
        return '${nombresMeses[ini.month - 1]} ${ini.year}';
      default:
        return '${ini.day} ${nombresMesesCortos[ini.month - 1]} – '
            '${fin.day} ${nombresMesesCortos[fin.month - 1]}';
    }
  }

  /// "Total del día" | "Total de la semana" | "Total del mes" | "Total del periodo"
  String get periodoTotalLabel {
    switch (selectedPeriodo.value) {
      case 'dia':
        return 'Total del día';
      case 'semana':
        return 'Total de la semana';
      case 'mes':
        return 'Total del mes';
      default:
        return 'Total del periodo';
    }
  }

  /// "del día" | "de la semana" | "del mes" | "del periodo", para redactar.
  String get periodoSufijo {
    switch (selectedPeriodo.value) {
      case 'dia':
        return 'del día';
      case 'semana':
        return 'de la semana';
      case 'mes':
        return 'del mes';
      default:
        return 'del periodo';
    }
  }

  /// Ej: "Mayo 2026"
  String get mesSeleccionadoLabel {
    final f = fechaInicio.value ?? DateTime.now();
    return '${nombresMeses[f.month - 1]} ${f.year}';
  }

  /// Ej: "mayo"
  String get nombreMesSeleccionado {
    final f = fechaInicio.value ?? DateTime.now();
    return nombresMeses[f.month - 1].toLowerCase();
  }

  /// Ej: "27 may"
  String formatFechaCorta(DateTime date) =>
      '${date.day} ${nombresMesesCortos[date.month - 1]}';
}

import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/providers/ingreso_provider.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/access_log_service.dart';

/// Los números del día que Inicio muestra en escritorio: cuánto se cobró,
/// cuántas entradas hubo y cuántas membresías vencen en la semana.
///
/// Cada dato se carga por separado: si uno falla, los demás se muestran. Solo
/// se pide lo que el rol puede ver (el permiso lo decide quien llama).
class ResumenDelDia extends GetxController {
  ResumenDelDia({
    Future<double> Function()? ingresosDeHoy,
    Future<int> Function()? entradasDeHoy,
    Future<int> Function()? porVencer,
  })  : _ingresosDeHoy = ingresosDeHoy ?? _sumarIngresosDeHoy,
        _entradasDeHoy = entradasDeHoy ?? _contarEntradasDeHoy,
        _porVencer = porVencer ?? _contarPorVencer;

  final Future<double> Function() _ingresosDeHoy;
  final Future<int> Function() _entradasDeHoy;
  final Future<int> Function() _porVencer;

  /// null mientras carga o si no se pudo obtener.
  final ingresos = RxnDouble();
  final entradas = RxnInt();
  final vencen = RxnInt();
  final cargando = false.obs;

  /// Días hacia adelante que cuentan como "por vencer".
  static const diasPorVencer = 7;

  Future<void> cargar({
    required bool ingresos,
    required bool entradas,
    required bool vencen,
  }) async {
    if (cargando.value) return;
    cargando.value = true;
    await Future.wait([
      if (ingresos) _uno('ingresos', _ingresosDeHoy, this.ingresos),
      if (entradas) _uno('entradas', _entradasDeHoy, this.entradas),
      if (vencen) _uno('por vencer', _porVencer, this.vencen),
    ]);
    cargando.value = false;
  }

  Future<void> _uno<T>(
      String nombre, Future<T> Function() leer, Rx<T?> destino) async {
    try {
      destino.value = await leer();
    } catch (e) {
      AppLogger.error('ResumenDelDia', 'No se pudo cargar $nombre', e);
    }
  }

  static Future<double> _sumarIngresosDeHoy() async {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day);
    final ingresos = await IngresoProvider().getIngresos(
      fechaInicio: inicio,
      // El filtro incluye el final: un instante antes de medianoche.
      fechaFin: inicio
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1)),
      limit: 1000,
    );
    return ingresos.fold<double>(0, (suma, i) => suma + i.montoFinal);
  }

  static Future<int> _contarEntradasDeHoy() async {
    final accesos = await AccessLogService.getTodayAccesses();
    return accesos.where((a) => a.accessType == 'entrada').length;
  }

  static Future<int> _contarPorVencer() async {
    final clientes = await Get.find<UserRepository>().getAllUsers();
    return contarPorVencer(
        clientes.map((c) => (c.isActive, c.expirationDate)), DateTime.now());
  }

  /// Membresías activas que vencen de hoy a [diasPorVencer] días.
  static int contarPorVencer(
      Iterable<(bool activo, DateTime? vence)> clientes, DateTime ahora) {
    final limite = ahora.add(const Duration(days: diasPorVencer));
    return clientes
        .where((c) =>
            c.$1 &&
            c.$2 != null &&
            !c.$2!.isBefore(ahora) &&
            !c.$2!.isAfter(limite))
        .length;
  }
}

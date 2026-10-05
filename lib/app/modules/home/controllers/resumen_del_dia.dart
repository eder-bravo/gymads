import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/access_log_model.dart';
import '../../../data/models/ingreso_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/ingreso_provider.dart';
import '../../../data/repositories/abono_prices_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/access_log_service.dart';
import '../../../data/services/cambios_en_vivo_service.dart';

/// Lo que pasó hoy en el gimnasio, para Inicio en pantalla grande: los
/// cobros, las entradas y las membresías que vencen en la semana, con sus
/// totales y las listas para el panel del día.
///
/// Cada dato se carga por separado: si uno falla, los demás se muestran. Solo
/// se pide lo que el rol puede ver (el permiso lo decide quien llama).
class ResumenDelDia extends GetxController with RecargaEnVivoMixin {
  ResumenDelDia({
    Future<List<IngresoModel>> Function()? cobrosDeHoy,
    Future<List<AccessLogModel>> Function()? accesosDeHoy,
    Future<List<UserModel>> Function()? clientes,
    Future<double?> Function()? precioDelDia,
  })  : _cobrosDeHoy = cobrosDeHoy ?? _leerCobrosDeHoy,
        _accesosDeHoy = accesosDeHoy ?? AccessLogService.getTodayAccesses,
        _clientes = clientes ?? _leerClientes,
        _precioDelDia = precioDelDia ?? _leerPrecioDelDia;

  final Future<List<IngresoModel>> Function() _cobrosDeHoy;
  final Future<List<AccessLogModel>> Function() _accesosDeHoy;
  final Future<List<UserModel>> Function() _clientes;
  final Future<double?> Function() _precioDelDia;

  /// Días hacia adelante que cuentan como "por vencer".
  static const diasPorVencer = 7;

  // Totales: null mientras carga o si no se pudo obtener.
  final ingresos = RxnDouble();
  final entradas = RxnInt();
  final vencen = RxnInt();

  /// Ventas de productos de hoy (para el recuadro de Vender en tableta).
  final ventas = RxnInt();

  /// Membresías cobradas hoy (para el recuadro de Abonar en tableta).
  final abonos = RxnInt();

  /// Clientes con membresía vigente (para el recuadro de Clientes).
  final activos = RxnInt();

  // Listas del panel, de lo más reciente a lo más viejo.
  final cobros = <IngresoModel>[].obs;
  final ultimasEntradas = <AccessLogModel>[].obs;

  /// Por fecha de vencimiento: primero quien vence antes.
  final porVencer = <UserModel>[].obs;

  /// Precio de una visita de un día, para "Cobrar visita". Empieza con el
  /// último conocido: el acceso rápido no aparece sin precio y luego con él.
  final precioDia = RxnDouble(_precioConocido());

  static double? _precioConocido() {
    final precio = AbonoPricesRepository.enCache?.priceDay;
    return precio != null && precio > 0 ? precio : null;
  }

  final cargando = false.obs;

  bool _enVivo = false;

  Future<void> cargar({
    required bool ingresos,
    required bool entradas,
    required bool vencen,
    bool precio = false,
  }) async {
    if (cargando.value) return;
    cargando.value = true;
    await _cargar(ingresos, entradas, vencen, precio);
    cargando.value = false;
    // Un cobro o una entrada en otro equipo (o en el lector) aparece solo.
    if (!_enVivo) {
      _enVivo = true;
      recargarAlCambiar({
        if (ingresos) TablaEnVivo.ingresos,
        if (entradas) TablaEnVivo.accesos,
        if (vencen) TablaEnVivo.clientes,
      }, () => _cargar(ingresos, entradas, vencen, false));
    }
  }

  Future<void> _cargar(bool ingresos, bool entradas, bool vencen, bool precio) =>
      Future.wait([
        if (ingresos) _uno('cobros', _cargarCobros),
        if (entradas) _uno('entradas', _cargarEntradas),
        if (vencen) _uno('clientes', _cargarClientes),
        if (precio)
          _uno('precio', () async => precioDia.value = await _precioDelDia()),
      ]);

  Future<void> _uno(String nombre, Future<void> Function() cargar) async {
    try {
      await cargar();
    } catch (e) {
      AppLogger.error('ResumenDelDia', 'No se pudo cargar $nombre', e);
    }
  }

  Future<void> _cargarCobros() async {
    final lista = [...await _cobrosDeHoy()]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    cobros.assignAll(lista);
    ingresos.value = lista.fold<double>(0, (suma, i) => suma + i.montoFinal);
    ventas.value = lista.where((i) => i.concepto == 'producto').length;
    abonos.value = lista
        .where((i) => const {'abono', 'renovacion', 'registro', 'nuevo_registro'}
            .contains(i.concepto))
        .length;
  }

  Future<void> _cargarEntradas() async {
    final lista = (await _accesosDeHoy())
        .where((a) => a.accessType == 'entrada')
        .toList()
      ..sort((a, b) => b.accessTime.compareTo(a.accessTime));
    ultimasEntradas.assignAll(lista);
    entradas.value = lista.length;
  }

  Future<void> _cargarClientes() async {
    final ahora = DateTime.now();
    final todos = await _clientes();
    final limite = ahora.add(const Duration(days: diasPorVencer));
    final proximos = todos
        .where((c) =>
            c.isActive &&
            c.expirationDate != null &&
            !c.expirationDate!.isBefore(ahora) &&
            !c.expirationDate!.isAfter(limite))
        .toList()
      ..sort((a, b) => a.expirationDate!.compareTo(b.expirationDate!));
    porVencer.assignAll(proximos);
    vencen.value = proximos.length;
    activos.value = todos
        .where((c) =>
            c.isActive &&
            c.expirationDate != null &&
            !c.expirationDate!.isBefore(ahora))
        .length;
  }

  static Future<List<IngresoModel>> _leerCobrosDeHoy() {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day);
    return IngresoProvider().getIngresos(
      fechaInicio: inicio,
      // El filtro incluye el final: un instante antes de medianoche.
      fechaFin: inicio
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1)),
      limit: 1000,
    );
  }

  static Future<List<UserModel>> _leerClientes() =>
      Get.find<UserRepository>().getAllUsers();

  static Future<double?> _leerPrecioDelDia() async {
    final precio = (await AbonoPricesRepository().getPrices()).priceDay;
    return precio != null && precio > 0 ? precio : null;
  }
}

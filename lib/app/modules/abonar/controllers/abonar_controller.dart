import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/screen_tour_mixin.dart';
import 'package:gymads/app/core/utils/referencia_de_pago.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/ingresos/controllers/ingresos_controller.dart';
import 'dart:async';
import 'package:gymads/app/data/services/cambios_en_vivo_service.dart';

import '../vigencia.dart';

/// Qué ofrece la pantalla de éxito, según desde dónde se llegó a Abonar.
enum AlTerminarAbono {
  /// Desde el módulo Abonar o el aviso de membresía vencida del lector.
  abonarOtro,

  /// Tras registrar un cliente desde el aviso del lector.
  volverAInicio,

  /// Tras registrar un cliente en Clientes, o desde su ficha.
  volverAClientes,
}

/// El periodo con el que abre el cobro: [actual] (Meses) si tiene precio; si
/// no, el primero que lo tenga (Meses, Semanas, Días, Años). Así el precio
/// fijo no abre vacío en un gimnasio que solo cobra, por ejemplo, por día.
String periodoConPrecio(AbonoPricesModel precios, String actual) {
  if (precios.priceFor(actual) != null) return actual;
  for (final periodo in const ['Meses', 'Semanas', 'Días', 'Años']) {
    if (precios.priceFor(periodo) != null) return periodo;
  }
  return actual;
}

/// Lo que indican los argumentos de la ruta (`'alTerminar'`). Sin él,
/// [AlTerminarAbono.abonarOtro].
AlTerminarAbono alTerminarDesde(Object? argumentos) {
  if (argumentos is Map && argumentos['alTerminar'] is AlTerminarAbono) {
    return argumentos['alTerminar'] as AlTerminarAbono;
  }
  return AlTerminarAbono.abonarOtro;
}

class AbonarController extends GetxController
    with ScreenTourMixin, RecargaEnVivoMixin, ReferenciaDePago {
  final UserRepository userRepository;
  final IngresoService ingresoService;
  final AbonoPricesRepository pricesRepository;

  AbonarController({
    required this.userRepository,
    required this.ingresoService,
    required this.pricesRepository,
  });

  // Buscador
  final searchController = TextEditingController();
  final isLoadingClients = false.obs;

  /// Lo que se ve en la lista: todos los clientes, o los que casan con lo
  /// escrito en el buscador.
  final searchResults = <UserModel>[].obs;

  /// Catálogo completo, ya ordenado alfabéticamente. Se carga una vez al
  /// entrar y el buscador filtra sobre él, sin volver a la red en cada tecla.
  final _allClients = <UserModel>[];

  // Cliente seleccionado
  final Rx<UserModel?> selectedClient = Rx<UserModel?>(null);

  // Cobro: cuánto tiempo (cantidad × periodo), cuánto y cómo paga.
  final durationType = 'Meses'.obs; // Meses, Semanas, Días o Años
  final durationValue = 1.obs;

  /// Como se guarda en `metodo_pago` (efectivo, tarjeta_debito…).
  final paymentMethod = 'efectivo'.obs;

  /// Abono libre: lo que paga en total, escrito a mano.
  final montoLibreController = TextEditingController();
  final montoLibre = 0.0.obs;

  double get totalAmount => totalDelCobro(
        costoFijo: isPrecioFijo.value,
        precioPorPeriodo: configuredPrice,
        cantidad: durationValue.value,
        montoLibre: montoLibre.value,
      );

  /// Qué falta para poder cobrar, o null si ya se puede.
  String? get faltaParaCobrar => faltaParaCobrarDe(
        costoFijo: isPrecioFijo.value,
        precioPorPeriodo: configuredPrice,
        cantidad: durationValue.value,
        montoLibre: montoLibre.value,
      );

  /// "2 meses", "1 semana".
  String get periodoElegido =>
      periodoEnPalabras(durationValue.value, durationType.value);

  /// Los mismos que en Vender: débito y crédito por separado.
  final paymentMethods = metodosDePago;

  /// Si el método elegido lleva folio o referencia.
  bool get usaReferenciaPago =>
      metodosConReferencia.contains(paymentMethod.value);

  void setPaymentMethod(String metodo) {
    paymentMethod.value = metodo;
    // La referencia es de una operación concreta: no sobrevive al cambio.
    limpiarReferencia();
  }

  final durationTypes = ['Meses', 'Semanas', 'Días', 'Años'];

  // Precios fijos configurados por el gimnasio (por día, semana, mes y año)
  final Rx<AbonoPricesModel?> prices = Rx<AbonoPricesModel?>(null);

  /// Costo fijo (el precio configurado del periodo) o abono libre (se
  /// escribe lo que paga).
  final isPrecioFijo = true.obs;

  /// Si el gimnasio configuró al menos un precio: sin ninguno, solo hay
  /// abono libre.
  bool get hayCostosFijos => prices.value?.hasAnyPrice ?? false;

  /// Los periodos que se ofrecen con costo fijo: los que tienen precio, en
  /// el orden en que se suelen cobrar.
  List<String> get periodosConPrecio => [
        for (final p in const ['Meses', 'Semanas', 'Días', 'Años'])
          if ((prices.value?.priceFor(p) ?? 0) > 0) p,
      ];

  /// Precio configurado para el periodo seleccionado, si existe.
  double? get configuredPrice => prices.value?.priceFor(durationType.value);

  final isLoading = false.obs;
  final isSuccess = false.obs;

  /// El paso del cobro que está abierto: 1 cuánto tiempo, 2 cómo paga,
  /// 3 resumen. Los anteriores se ven cerrados, con lo que se eligió.
  final pasoActual = 1.obs;

  /// Cierra el paso abierto y abre el siguiente.
  void continuar() {
    if (pasoActual.value == 1 && faltaParaCobrar != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (pasoActual.value < 3) pasoActual.value++;
  }

  /// Vuelve a abrir un paso ya hecho para cambiarlo. Los de después se
  /// vuelven a confirmar con "Continuar".
  void irAPaso(int paso) {
    if (paso < pasoActual.value) pasoActual.value = paso;
  }

  // ─── Tour de bienvenida ───
  // Solo cubre la pantalla de búsqueda: el formulario de cobro no existe
  // todavía cuando arranca el tour, porque aparece al elegir un cliente.
  final keyVisita = GlobalKey();
  final keyBuscar = GlobalKey();
  final keyResultados = GlobalKey();

  @override
  String get tourId => AppTours.abonar;

  @override
  List<GlobalKey> get tourSteps => [keyVisita, keyBuscar, keyResultados];

  @override
  void onInit() {
    super.onInit();

    // Si venimos con un cliente preseleccionado
    if (Get.arguments != null && Get.arguments['cliente'] != null) {
      selectedClient.value = Get.arguments['cliente'];
    }
    alTerminar = alTerminarDesde(Get.arguments);

    // Escuchar cambios en el buscador
    searchController.addListener(_applyFilter);

    loadClients();
    // Los días restantes cambian con un abono hecho en otro teléfono.
    recargarAlCambiar(
        {TablaEnVivo.clientes}, () => loadClients(silencioso: true));

    montoLibreController.addListener(() {
      montoLibre.value = double.tryParse(montoLibreController.text) ?? 0.0;
    });

    _loadPrices();
  }

  /// Recarga la lista de clientes y los precios de abono.
  ///
  /// Los precios entran aquí a propósito: si el dueño los cambia mientras
  /// alguien tiene la pantalla abierta, seguir cobrando con los viejos es un
  /// error de dinero, no de pantalla.
  Future<void> refrescar() async {
    await Future.wait([
      loadClients(),
      _loadPrices(),
    ]);
  }

  Future<void> _loadPrices() async {
    final result = await pricesRepository.getPrices();
    prices.value = result;
    _modoInicial();
  }

  /// Cómo abre el cobro: con costo fijo si hay al menos un precio
  /// configurado, y en un periodo que lo tenga. Se puede pasar a abono libre
  /// en cada cobro.
  ///
  /// No se sigue `payment_mode`: un gimnasio que eligió "libre" en el
  /// asistente inicial y después configuró sus precios abría siempre en
  /// libre, teniendo precios que ofrecer.
  void _modoInicial() {
    final precios = prices.value;
    isPrecioFijo.value = hayCostosFijos;
    if (precios != null) {
      durationType.value = periodoConPrecio(precios, durationType.value);
    }
  }

  /// Cambia entre costo fijo y abono libre.
  void setPrecioFijo(bool fijo) {
    if (fijo == isPrecioFijo.value) return;
    if (fijo && !hayCostosFijos) return;
    isPrecioFijo.value = fijo;
    if (fijo && configuredPrice == null) {
      durationType.value = periodosConPrecio.first;
    }
  }

  void setDurationType(String type) => durationType.value = type;

  void incrementDuration() => durationValue.value++;

  void decrementDuration() {
    if (durationValue.value > 1) durationValue.value--;
  }

  @override
  void onClose() {
    searchController.dispose();
    montoLibreController.dispose();
    super.onClose();
  }

  /// Trae la lista de clientes y la deja ordenada por nombre.
  ///
  /// Se llama al entrar y al volver del formulario de cobro, para que los días
  /// restantes que se ven en la lista sean los de después del abono.
  /// [silencioso]: sin spinner ni mensajes de error (recarga automática).
  Future<void> loadClients({bool silencioso = false}) async {
    if (!silencioso) isLoadingClients.value = true;
    try {
      final all = await userRepository.getAllUsers();
      all.sort((a, b) => _sortKey(a.name).compareTo(_sortKey(b.name)));
      _allClients
        ..clear()
        ..addAll(all);
      _applyFilter();
    } catch (e) {
      AppLogger.error('AbonarController', 'Error cargando clientes', e);
      if (!silencioso) {
        _showSnackbar('Error', 'No se pudo cargar la lista de clientes',
            isError: true);
      }
    } finally {
      if (!silencioso) isLoadingClients.value = false;
    }
  }

  /// Con el buscador vacío se ven todos los clientes; ese es el estado normal
  /// de la pantalla, no un caso especial.
  void _applyFilter() {
    final query = _sortKey(searchController.text.trim());
    if (query.isEmpty) {
      searchResults.assignAll(_allClients);
      return;
    }
    searchResults.assignAll(
      _allClients.where((user) =>
          _sortKey(user.name).contains(query) || user.phone.contains(query)),
    );
  }

  /// Minúsculas y sin acentos, para que "angel" encuentre a "Ángel" y para que
  /// al ordenar no se vaya al final de la lista.
  static String _sortKey(String value) {
    const accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const plain = 'aaaaaeeeeiiiiooooouuuunc';
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().split('')) {
      final index = accents.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }
    return buffer.toString();
  }

  void selectClient(UserModel client) {
    pasoActual.value = 1;
    selectedClient.value = client;
    // Limpiar el buscador ya repuebla la lista con todos los clientes, así que
    // al volver aquí sigue estando lista.
    searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Qué pasa después del abono. Con [AlTerminarAbono.abonarOtro] se muestra
  /// la pantalla de éxito con "Abonar a otro cliente"; con los otros dos se
  /// regresa solo ([procesarAbono]). Para regresar basta con atrás: quien
  /// abrió Abonar ya dejó debajo la pantalla a la que hay que volver (Inicio
  /// o Clientes).
  AlTerminarAbono alTerminar = AlTerminarAbono.abonarOtro;

  void clearSelection() {
    selectedClient.value = null;
    paymentMethod.value = 'efectivo';
    limpiarReferencia();
    montoLibreController.clear();
    durationValue.value = 1;
    durationType.value = 'Meses';
    // El siguiente cliente vuelve a empezar con precio fijo, aunque al
    // anterior se le haya cobrado libre.
    _modoInicial();
    isSuccess.value = false;
    pasoActual.value = 1;
    loadClients();
  }

  /// Fecha desde la que se cuenta el nuevo periodo: la expiración vigente si
  /// aún no ha pasado, o hoy si la membresía ya venció.
  DateTime calculatePeriodStartDate() {
    final client = selectedClient.value;
    final now = DateTime.now();
    if (client?.expirationDate != null &&
        client!.expirationDate!.isAfter(now)) {
      return client.expirationDate!;
    }
    return now;
  }

  DateTime calculateNewExpirationDate() {
    if (selectedClient.value == null) return DateTime.now();

    final baseDate = calculatePeriodStartDate();
    final periods = durationValue.value;

    switch (durationType.value) {
      case 'Meses':
        return baseDate.add(Duration(days: periods * 30));
      case 'Semanas':
        return baseDate.add(Duration(days: periods * 7));
      case 'Días':
        return baseDate.add(Duration(days: periods));
      case 'Años':
        return baseDate.add(Duration(days: periods * 365));
      default:
        return baseDate.add(const Duration(days: 30));
    }
  }

  Future<void> procesarAbono() async {
    if (selectedClient.value == null) {
      _showSnackbar('Error', 'Debes seleccionar un cliente primero',
          isError: true);
      return;
    }

    final falta = faltaParaCobrar;
    if (falta != null) {
      _showSnackbar('Falta un dato', falta, isError: true);
      return;
    }

    final periods = durationValue.value;
    final amount = totalAmount;
    final descripcion = isPrecioFijo.value
        ? 'Abono: $periods ${durationType.value.toLowerCase()} × \$${configuredPrice!.toStringAsFixed(2)}'
        : 'Abono: $periodoElegido · \$${amount.toStringAsFixed(2)}';

    isLoading.value = true;
    try {
      final client = selectedClient.value!;
      final periodStartDate = calculatePeriodStartDate();
      final newExpirationDate = calculateNewExpirationDate();
      final now = DateTime.now();

      // Preparar modelo actualizado
      final updatedClient = client.copyWith(
        expirationDate: newExpirationDate,
        isActive: true,
        lastPaymentDate: now,
        // Remover historial viejo si era un registro "nuevo" / muy vencido
        accessHistory: client.accessHistory,
      );

      // Actualizar en base de datos
      final success =
          await userRepository.updateUser(client.id!, updatedClient);

      if (success) {
        // Registrar el Ingreso
        try {
          await ingresoService.registrarAbono(
            clienteId: client.id!,
            clienteNombre: client.name,
            monto: amount,
            metodoPago: paymentMethod.value,
            referenciaPago: usaReferenciaPago ? referenciaParaGuardar : null,
            descripcion: descripcion,
            usuarioStaff: 'Staff',
            notas: isPrecioFijo.value ? 'Costo fijo' : 'Abono libre',
            periodoInicio: periodStartDate,
            periodoFin: newExpirationDate,
          );

          if (Get.isRegistered<IngresosController>()) {
            IngresosController.refreshIngresosGlobally();
          }
        } catch (e) {
          AppLogger.error('AbonarController', 'Error registrando ingreso', e);
          // No bloqueamos el éxito si el ingreso falla
        }

        selectedClient.value = updatedClient;

        // Tras registrar a un cliente (desde el aviso del lector o desde
        // Clientes) se regresa solo a donde se empezó, sin pantalla de éxito:
        // el aviso basta.
        if (alTerminar != AlTerminarAbono.abonarOtro) {
          Get.back();
          _showSnackbar('Listo', 'Abono registrado para ${client.name}');
          return;
        }

        isSuccess.value = true;
        _showSnackbar('Éxito', 'Abono registrado correctamente');
      } else {
        _showSnackbar('Error', 'No se pudo actualizar el cliente',
            isError: true);
      }
    } catch (e) {
      _showSnackbar('Error', 'Ocurrió un error: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  void _showSnackbar(String title, String message, {bool isError = false}) {
    if (Get.context != null) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

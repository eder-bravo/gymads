import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/modules/ingresos/controllers/ingresos_controller.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/app/modules/shared/widgets/rfid_reader_animation.dart';
import 'dart:async';

class AbonarController extends GetxController {
  final UserRepository userRepository;
  final IngresoService ingresoService;
  final AbonoPricesRepository pricesRepository;
  final BackgroundRfidService? rfidService;

  AbonarController({
    required this.userRepository,
    required this.ingresoService,
    required this.pricesRepository,
    this.rfidService,
  });

  // Buscador
  final searchController = TextEditingController();
  final isSearching = false.obs;
  final searchResults = <UserModel>[].obs;
  Timer? _debounce;

  // Cliente seleccionado
  final Rx<UserModel?> selectedClient = Rx<UserModel?>(null);

  // Formulario de Abono
  final unitPriceController = TextEditingController(); // Precio por periodo
  final durationController = TextEditingController(text: '1'); // Cantidad de periodos
  final durationType = 'Meses'.obs; // Tipo de tiempo: Meses, Semanas, Días
  final paymentMethod = 'Efectivo'.obs;

  // Espejo reactivo de los campos de texto, para recalcular total y fecha en vivo
  final unitPrice = 0.0.obs;
  final durationValue = 1.obs;

  double get totalAmount => unitPrice.value * durationValue.value;

  /// Unidad en singular para etiquetas ("por mes", "por semana"...)
  String get durationUnitLabel {
    switch (durationType.value) {
      case 'Meses':
        return 'mes';
      case 'Semanas':
        return 'semana';
      case 'Días':
        return 'día';
      case 'Años':
        return 'año';
      default:
        return 'periodo';
    }
  }

  final paymentMethods = ['Efectivo', 'Tarjeta', 'Transferencia'];
  final durationTypes = ['Meses', 'Semanas', 'Días', 'Años'];

  // Precios fijos configurados por el gimnasio (por día, semana, mes y año)
  final Rx<AbonoPricesModel?> prices = Rx<AbonoPricesModel?>(null);
  final isPrecioFijo = true.obs;

  /// Precio configurado para el periodo seleccionado, si existe.
  double? get configuredPrice => prices.value?.priceFor(durationType.value);

  final isLoading = false.obs;
  final isSuccess = false.obs;
  
  // Suscripción al stream RFID
  StreamSubscription<String>? _rfidSubscription;

  @override
  void onInit() {
    super.onInit();
    
    // Si venimos con un cliente preseleccionado
    if (Get.arguments != null && Get.arguments['cliente'] != null) {
      selectedClient.value = Get.arguments['cliente'];
    }

    _setupRfidListener();

    // Escuchar cambios en el buscador
    searchController.addListener(_onSearchChanged);

    // Mantener el estado reactivo en sincronía con los campos de texto
    unitPriceController.addListener(_onUnitPriceChanged);
    durationController.addListener(_onDurationChanged);

    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final result = await pricesRepository.getPrices();
    prices.value = result;
    // Punto de partida del toggle: el modo que configuró el gimnasio. Sin modo
    // configurado se conserva la heurística anterior. En ambos casos el modo
    // fijo necesita al menos un precio para tener algo que ofrecer, y el staff
    // puede cambiarlo libremente en cada cobro.
    final mode = result.paymentMode;
    isPrecioFijo.value = mode == null
        ? result.hasAnyPrice
        : mode == 'fijo' && result.hasAnyPrice;
    applyFixedPrice();
  }

  /// Cambia entre precio fijo (tomado de la configuración) y precio libre.
  void setPrecioFijo(bool fijo) {
    isPrecioFijo.value = fijo;
    if (fijo) applyFixedPrice();
  }

  /// Cambia el periodo y, en modo fijo, recarga el precio configurado.
  void setDurationType(String type) {
    durationType.value = type;
    applyFixedPrice();
  }

  /// En modo fijo escribe el precio configurado del periodo actual en el campo
  /// (el listener del TextEditingController recalcula total y fecha).
  void applyFixedPrice() {
    if (!isPrecioFijo.value) return;
    final price = configuredPrice;
    unitPriceController.text = price == null ? '' : price.toStringAsFixed(2);
  }

  void _onUnitPriceChanged() {
    unitPrice.value = double.tryParse(unitPriceController.text) ?? 0.0;
  }

  void _onDurationChanged() {
    durationValue.value = int.tryParse(durationController.text) ?? 0;
  }

  void incrementDuration() {
    durationController.text = (durationValue.value + 1).toString();
  }

  void decrementDuration() {
    if (durationValue.value > 1) {
      durationController.text = (durationValue.value - 1).toString();
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    unitPriceController.dispose();
    durationController.dispose();
    _debounce?.cancel();
    _rfidSubscription?.cancel();
    super.onClose();
  }

  void _setupRfidListener() {
    if (rfidService != null) {
      _rfidSubscription = rfidService!.lastScannedUid.listen((rfidUid) {
        // Ignorar la auto-búsqueda para permitir que el botón manual tenga prioridad
        // Opcional: Podrías habilitar esto de nuevo si quieres ambos modos
        /*
        if (rfidUid.isNotEmpty && Get.currentRoute == '/abonar') {
          _searchByRfid(rfidUid);
        }
        */
      });
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = searchController.text.trim();
      if (query.length >= 3) {
        _searchClients(query);
      } else {
        searchResults.clear();
      }
    });
  }

  Future<void> _searchClients(String query) async {
    isSearching.value = true;
    try {
      final allUsers = await userRepository.getAllUsers();
      final results = allUsers.where((user) {
        return user.name.toLowerCase().contains(query.toLowerCase()) ||
               user.phone.contains(query);
      }).toList();
      searchResults.assignAll(results);
    } catch (e) {
      AppLogger.error('AbonarController', 'Error buscando clientes', e);
      _showSnackbar('Error', 'No se pudo buscar clientes', isError: true);
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> _searchByRfid(String rfid) async {
    isSearching.value = true;
    try {
      final allUsers = await userRepository.getAllUsers();
      final user = allUsers.firstWhereOrNull((u) => u.rfidCard == rfid);
      
      if (user != null) {
        selectClient(user);
        _showSnackbar('Éxito', 'Cliente encontrado por tarjeta RFID');
      } else {
        _showSnackbar('No encontrado', 'Tarjeta RFID no registrada', isError: true);
      }
    } catch (e) {
      AppLogger.error('AbonarController', 'Error buscando por RFID', e);
    } finally {
      isSearching.value = false;
    }
  }

  // Método manual de NFC que invoca el diálogo
  void startNfcSearch(BuildContext context) {
    Timer? pollTimer;
    BuildContext? localDialogContext;
    
    // Pausar procesamiento automático
    rfidService?.pauseScanning();

    pollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      try {
        final uid = await RfidReaderService.checkForCardSilent();
        if (uid != null && uid.isNotEmpty && uid != 'NO_CARD') {
          timer.cancel();
          if (localDialogContext != null && Navigator.canPop(localDialogContext!)) {
            Navigator.of(localDialogContext!).pop();
          } else {
            Get.back();
          }
          // Realizar la búsqueda con el UID encontrado
          _searchByRfid(uid);
        }
      } catch (e) {
        // Ignorar errores en modo silencioso
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        localDialogContext = dialogContext;
        return RfidReaderAnimation(
          isReading: true,
          onCancel: () {
            pollTimer?.cancel();
            if (Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
    ).then((_) {
      pollTimer?.cancel();
      // Reanudar procesamiento de fondo
      rfidService?.resumeScanning();
    });
  }

  void selectClient(UserModel client) {
    selectedClient.value = client;
    searchController.clear();
    searchResults.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void clearSelection() {
    selectedClient.value = null;
    unitPriceController.clear();
    durationController.text = '1';
    durationType.value = 'Meses';
    applyFixedPrice();
    isSuccess.value = false;
  }

  /// Fecha desde la que se cuenta el nuevo periodo: la expiración vigente si
  /// aún no ha pasado, o hoy si la membresía ya venció.
  DateTime calculatePeriodStartDate() {
    final client = selectedClient.value;
    final now = DateTime.now();
    if (client?.expirationDate != null && client!.expirationDate!.isAfter(now)) {
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
      _showSnackbar('Error', 'Debes seleccionar un cliente primero', isError: true);
      return;
    }

    final periods = durationValue.value;
    if (periods <= 0) {
      _showSnackbar('Error', 'Selecciona una cantidad de periodos válida', isError: true);
      return;
    }

    final precioUnitario = unitPrice.value;
    if (precioUnitario <= 0) {
      _showSnackbar(
        'Error',
        isPrecioFijo.value
            ? 'No hay precio configurado para este periodo'
            : 'Ingresa un precio unitario válido',
        isError: true,
      );
      return;
    }

    final amount = totalAmount;
    final descripcion =
        'Abono: $periods ${durationType.value.toLowerCase()} × \$${precioUnitario.toStringAsFixed(2)}';

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
      final success = await userRepository.updateUser(client.id!, updatedClient);

      if (success) {
        // Registrar el Ingreso
        try {
          await ingresoService.registrarAbono(
            clienteId: client.id!,
            clienteNombre: client.name,
            monto: amount,
            metodoPago: paymentMethod.value.toLowerCase(),
            descripcion: descripcion,
            usuarioStaff: 'Staff',
            notas: isPrecioFijo.value ? 'Abono fijo' : 'Abono libre',
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
        isSuccess.value = true;
        _showSnackbar('Éxito', 'Abono registrado correctamente');
      } else {
        _showSnackbar('Error', 'No se pudo actualizar el cliente', isError: true);
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

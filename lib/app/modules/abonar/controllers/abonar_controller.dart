import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/user_model.dart';
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
  final BackgroundRfidService? rfidService;

  AbonarController({
    required this.userRepository,
    required this.ingresoService,
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
  final amountController = TextEditingController(); // Cantidad a abonar
  final durationController = TextEditingController(text: '1'); // Cantidad de tiempo
  final durationType = 'Meses'.obs; // Tipo de tiempo: Meses, Semanas, Días
  final paymentMethod = 'Efectivo'.obs;
  
  final paymentMethods = ['Efectivo', 'Tarjeta', 'Transferencia'];
  final durationTypes = ['Meses', 'Semanas', 'Días', 'Años'];

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
  }

  void incrementDuration() {
    int current = int.tryParse(durationController.text) ?? 0;
    current++;
    durationController.text = current.toString();
    update();
  }

  void decrementDuration() {
    int current = int.tryParse(durationController.text) ?? 0;
    if (current > 1) {
      current--;
      durationController.text = current.toString();
      update();
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    amountController.dispose();
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
      print('Error buscando clientes: $e');
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
      print('Error buscando por RFID: $e');
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
    amountController.clear();
    durationController.text = '1';
    durationType.value = 'Meses';
    isSuccess.value = false;
  }

  DateTime calculateNewExpirationDate() {
    final client = selectedClient.value;
    if (client == null) return DateTime.now();

    final now = DateTime.now();
    // Iniciar desde la fecha de expiración actual si es mayor a hoy, o desde hoy.
    DateTime baseDate = now;
    if (client.expirationDate != null && client.expirationDate!.isAfter(now)) {
      baseDate = client.expirationDate!;
    }

    final durationValue = int.tryParse(durationController.text) ?? 1;

    switch (durationType.value) {
      case 'Meses':
        return baseDate.add(Duration(days: durationValue * 30));
      case 'Semanas':
        return baseDate.add(Duration(days: durationValue * 7));
      case 'Días':
        return baseDate.add(Duration(days: durationValue));
      case 'Años':
        return baseDate.add(Duration(days: durationValue * 365));
      default:
        return baseDate.add(Duration(days: 30));
    }
  }

  Future<void> procesarAbono() async {
    if (selectedClient.value == null) {
      _showSnackbar('Error', 'Debes seleccionar un cliente primero', isError: true);
      return;
    }

    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackbar('Error', 'Ingresa una cantidad válida a abonar', isError: true);
      return;
    }

    final durationValue = int.tryParse(durationController.text);
    if (durationValue == null || durationValue <= 0) {
      _showSnackbar('Error', 'Ingresa una duración válida', isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final client = selectedClient.value!;
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
          final descripcion = 'Abono: $durationValue ${durationType.value.toLowerCase()}';
          
          await ingresoService.registrarAbono(
            clienteId: client.id!,
            clienteNombre: client.name,
            monto: amount,
            metodoPago: paymentMethod.value.toLowerCase(),
            descripcion: descripcion,
            usuarioStaff: 'Staff',
            notas: 'Abono libre',
          );
          
          if (Get.isRegistered<IngresosController>()) {
             IngresosController.refreshIngresosGlobally();
          }
        } catch (e) {
          print('Error registrando ingreso: $e');
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

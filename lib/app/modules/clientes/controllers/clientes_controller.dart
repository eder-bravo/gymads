import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/image_cache_service.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/global_widgets/qr_dialog.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';

class ClientesController extends GetxController {
  final UserRepository userRepository;
  final IngresoService? ingresoService; // Opcional

  ClientesController({
    required this.userRepository,
    this.ingresoService,
  });

  // Estado observable para la lista de clientes
  final RxList<UserModel> clientes = <UserModel>[].obs;

  // Estado para búsqueda y filtrado
  final searchQuery = ''.obs;
  final selectedFilter = 'Todos'.obs;

  // Estado para el cliente seleccionado para visualizar detalles
  final Rx<UserModel?> selectedClient = Rx<UserModel?>(null);

  // Estado para indicar carga
  final RxBool isLoading = false.obs;
  // Estado observable para mensaje de error
  final RxString errorMessage = ''.obs;

  // Estado para formulario de cliente
  final nombreController = TextEditingController();
  final phoneController = TextEditingController();
  final userNumberController = TextEditingController();
  final rfidController = TextEditingController();
  final emailController = TextEditingController(); // NUEVO
  final addressController = TextEditingController(); // NUEVO

  @override
  void onInit() {
    super.onInit();
    fetchClientes();
    _initializeImageCache();
    
    // Si venimos de un redirect para editar un cliente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.arguments != null && Get.arguments['edit_cliente'] != null) {
        final client = Get.arguments['edit_cliente'];
        // Usar import relativo o absoluto en la vista, pero como estamos en el controlador y ClienteDetailView está en otra carpeta, 
        // mejor solo filtramos la lista para ese usuario
        searchQuery.value = client.name;
      }
      if (Get.arguments != null && Get.arguments['new_rfid'] != null) {
        final rfid = Get.arguments['new_rfid'];
        showAddDialog(initialRfid: rfid);
      }
    });
  }

  void _initializeImageCache() async {
    try {
      await ImageCacheService.instance.initialize();
    } catch (e) {
      print('Error inicializando caché de imágenes: $e');
    }
  }

  @override
  void onClose() {
    nombreController.dispose();
    phoneController.dispose();
    userNumberController.dispose();
    rfidController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.onClose();
  }

  void showAddDialog({String? initialRfid}) {
    clearForm();
    if (initialRfid != null) {
      rfidController.text = initialRfid;
    }

    Get.to(
      () => ClienteFormDialog(
        nombreController: nombreController,
        phoneController: phoneController,
        emailController: emailController,
        addressController: addressController,
        userNumberController: userNumberController,
        rfidController: rfidController,
        onSave: (user, photoFile) {
          addCliente(user, photoFile: photoFile);
        },
        fullScreen: true,
      ),
      fullscreenDialog: true,
    );
  }

  // Método para obtener todos los clientes
  Future<void> fetchClientes() async {
    isLoading.value = true;
    try {
      final users = await userRepository.getAllUsers();
      clientes.assignAll(users);

      // Precargar imágenes de forma diferida
      Future.delayed(const Duration(milliseconds: 500), () {
        _preloadClientImages(users);
      });
    } catch (e) {
      _showSnackbarSafe(
        'Error',
        'No se pudieron cargar los clientes: $e',
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _preloadClientImages(List<UserModel> users) async {
    try {
      final usersWithPhotos = users
          .where((user) => user.photoUrl != null && user.photoUrl!.isNotEmpty)
          .toList();

      for (int i = 0; i < usersWithPhotos.length; i += 5) {
        final batch = usersWithPhotos.skip(i).take(5);
        await Future.wait(
          batch.map((user) => _preloadUserImage(user.id!)).toList(),
          eagerError: false,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print('Error precargando imágenes de clientes: $e');
    }
  }

  Future<void> _preloadUserImage(String userId) async {
    try {
      final user = clientes.firstWhereOrNull((u) => u.id == userId);
      if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
        await ImageCacheService.instance
            .getUserImage(userId, user.photoUrl, isThumbnail: true);
      }
    } catch (e) {
      print('Error precargando imagen del usuario $userId: $e');
    }
  }

  // Método para filtrar clientes
  List<UserModel> get filteredClientes {
    if (searchQuery.isEmpty && selectedFilter.value == 'Todos') {
      return clientes;
    }

    return clientes.where((client) {
      // Aplicar filtro de texto (nombre, teléfono o número)
      bool matchesSearch = searchQuery.isEmpty ||
          client.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          client.phone.toLowerCase().contains(searchQuery.toLowerCase()) ||
          client.userNumber.toString().contains(searchQuery.toLowerCase());

      // Aplicar filtro de estado
      bool matchesFilter = selectedFilter.value == 'Todos' ||
          (selectedFilter.value == 'Activos' && client.isActive) ||
          (selectedFilter.value == 'Inactivos' && !client.isActive) ||
          (selectedFilter.value == 'Por vencer' && client.needsRenewal);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showSnackbarSafe(String title, String message, {bool isError = false}) {
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        final context = Get.context;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $message'),
              backgroundColor: isError ? Colors.red : Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('${isError ? '❌' : '✅'} $title: $message');
      }
    });
  }

  // Preparar formulario para crear
  void clearForm() {
    nombreController.clear();
    phoneController.clear();
    userNumberController.clear();
    rfidController.clear();
    emailController.clear();
    addressController.clear();

    // Generar un código alfanumérico único (ej. A1B2C3)
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    String result = '';
    do {
      result = '';
      for (int i = 0; i < 6; i++) {
        result += chars[rnd.nextInt(chars.length)];
      }
    } while (clientes.any((c) => c.userNumber == result));
    
    userNumberController.text = result;
  }

  // Preparar formulario para editar
  void setupFormForEdit(UserModel client) {
    nombreController.text = client.name;
    phoneController.text = client.phone;
    userNumberController.text = client.userNumber;
    rfidController.text = client.rfidCard ?? '';
    emailController.text = client.email ?? '';
    addressController.text = client.address ?? '';
  }

  // Método para añadir un nuevo cliente (registro simple, sin cobro aquí)
  Future<bool> addCliente(UserModel newClient, {File? photoFile}) async {
    isLoading.value = true;
    try {
      final userId = await userRepository.addUser(
        newClient,
        photoFile: photoFile,
      );

      if (userId != null) {
        await fetchClientes();
        Get.back(); // Cerrar el diálogo

        final clienteConId = newClient.copyWith(id: userId);
        // Navegar a la pantalla de Abono con el nuevo cliente seleccionado
        await Future.delayed(const Duration(milliseconds: 200));
        Get.toNamed('/abonar', arguments: {'cliente': clienteConId});

        _showSnackbarSafe('Éxito', 'Cliente agregado correctamente');
        return true;
      } else {
        _showSnackbarSafe('Error', 'No se pudo agregar el cliente', isError: true);
        return false;
      }
    } catch (e) {
      _showSnackbarSafe('Error', 'Error al agregar cliente: $e', isError: true);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Método para actualizar un cliente existente
  Future<bool> updateCliente(
    String id,
    UserModel updatedClient, {
    File? photoFile,
  }) async {
    BackgroundRfidService? rfidService;
    try {
      if (Get.isRegistered<BackgroundRfidService>()) {
        rfidService = Get.find<BackgroundRfidService>();
        rfidService.pauseScanning();
      }
    } catch (e) {
      print('⚠️ No se pudo pausar servicio RFID: $e');
    }

    isLoading.value = true;
    try {
      final success = await userRepository.updateUser(
        id,
        updatedClient,
        photoFile: photoFile,
      );
      if (success) {
        await fetchClientes();
        _showSnackbarSafe('Éxito', 'Cliente actualizado correctamente');
        return true;
      } else {
        _showSnackbarSafe('Error', 'No se pudo actualizar el cliente', isError: true);
        return false;
      }
    } catch (e) {
      _showSnackbarSafe('Error', 'Error al actualizar cliente: $e', isError: true);
      return false;
    } finally {
      isLoading.value = false;
      await Future.delayed(const Duration(milliseconds: 300));
      rfidService?.resumeScanning();
    }
  }

  // Método para eliminar un cliente
  Future<bool> deleteCliente(String id) async {
    BackgroundRfidService? rfidService;
    try {
      if (Get.isRegistered<BackgroundRfidService>()) {
        rfidService = Get.find<BackgroundRfidService>();
        rfidService.pauseScanning();
      }
    } catch (e) {
      print('⚠️ No se pudo pausar servicio RFID: $e');
    }

    isLoading.value = true;
    try {
      final success = await userRepository.deleteUser(id);
      if (success) {
        await fetchClientes();
        _showSnackbarSafe('Éxito', 'Cliente eliminado correctamente');
        return true;
      } else {
        _showSnackbarSafe('Error', 'No se pudo eliminar el cliente', isError: true);
        return false;
      }
    } catch (e) {
      _showSnackbarSafe('Error', 'Error al eliminar cliente: $e', isError: true);
      return false;
    } finally {
      isLoading.value = false;
      await Future.delayed(const Duration(milliseconds: 300));
      rfidService?.resumeScanning();
    }
  }
}

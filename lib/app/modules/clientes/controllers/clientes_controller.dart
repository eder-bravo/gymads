import 'dart:async';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/fallo_al_guardar.dart';
import 'package:gymads/app/core/utils/screen_tour_mixin.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/image_cache_service.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';
import 'package:gymads/app/data/services/cambios_en_vivo_service.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:gymads/app/routes/app_pages.dart';

class ClientesController extends GetxController
    with ScreenTourMixin, RecargaEnVivoMixin {
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

  // ─── Tour de bienvenida ───
  // Las claves viven aquí y no en el `build` de la vista para que sigan siendo
  // las mismas entre reconstrucciones.
  final keyAgregar = GlobalKey();
  final keyBuscar = GlobalKey();
  final keyLista = GlobalKey();

  @override
  String get tourId => AppTours.clientes;

  @override
  List<GlobalKey> get tourSteps => [keyAgregar, keyBuscar, keyLista];

  @override
  void onInit() {
    super.onInit();
    fetchClientes();
    // Un cliente dado de alta (o un abono) en otro teléfono aparece solo.
    recargarAlCambiar(
        {TablaEnVivo.clientes}, () => fetchClientes(silencioso: true));
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
      AppLogger.error('ClientesController', 'Error inicializando caché de imágenes', e);
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

  /// Si el cliente que se está registrando viene del aviso del lector
  /// (tarjeta no registrada): tras cobrarle se regresa a Inicio, no aquí.
  bool _registroDesdeLector = false;

  void showAddDialog({String? initialRfid}) {
    clearForm();
    // La tarjeta ya puesta solo llega desde el aviso del lector (por Inicio
    // o por el aviso pequeño "Registrar" de otras pantallas).
    _registroDesdeLector = initialRfid != null;
    if (initialRfid != null) {
      rfidController.text = initialRfid;
    }

    abrirFormulario(
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
        guardando: guardandoCliente,
        fullScreen: true,
      ),
    );
  }

  // Método para obtener todos los clientes. [silencioso]: sin spinner ni
  // mensajes de error (recarga automática).
  Future<void> fetchClientes({bool silencioso = false}) async {
    if (!silencioso) isLoading.value = true;
    try {
      final users = await userRepository.getAllUsers();
      clientes.assignAll(users);

      // Precargar imágenes de forma diferida
      Future.delayed(const Duration(milliseconds: 500), () {
        _preloadClientImages(users);
      });
    } catch (e) {
      if (silencioso) {
        AppLogger.error('ClientesController', 'Error al recargar clientes', e);
        return;
      }
      _showSnackbarSafe(
        'Error',
        'No se pudieron cargar los clientes: $e',
        isError: true,
      );
    } finally {
      if (!silencioso) isLoading.value = false;
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
      AppLogger.error('ClientesController', 'Error precargando imágenes de clientes', e);
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
      AppLogger.error('ClientesController', 'Error precargando imagen del usuario', e);
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
        AppLogger.error('ClientesController', 'No se pudo mostrar la notificación', e);
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

    userNumberController.text = _nuevoNumeroDeCliente();
  }

  /// Un código alfanumérico (ej. A1B2C3) que no tenga ningún cliente de la
  /// lista cargada.
  String _nuevoNumeroDeCliente() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    String result = '';
    do {
      result = '';
      for (int i = 0; i < 6; i++) {
        result += chars[rnd.nextInt(chars.length)];
      }
    } while (clientes.any((c) => c.userNumber == result));
    return result;
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

  /// Si hay un alta o una edición de cliente en curso. El formulario
  /// desactiva su botón y muestra "Guardando…"; además, un segundo toque no
  /// manda otro guardado: antes el segundo chocaba con el número del primero
  /// y salía "error" aunque el cliente sí se había guardado.
  final guardandoCliente = false.obs;

  // Método para añadir un nuevo cliente (registro simple, sin cobro aquí)
  Future<bool> addCliente(UserModel newClient, {File? photoFile}) async {
    if (guardandoCliente.value) return false;
    // La foto es obligatoria (el formulario ya lo pide; esto es la última
    // barrera para que no entre un cliente sin foto).
    if (photoFile == null) {
      _showSnackbarSafe('No se guardó', 'Toma la foto del cliente.',
          isError: true);
      return false;
    }
    guardandoCliente.value = true;
    try {
      UserModel guardado;
      try {
        guardado = await userRepository.crearCliente(
          newClient,
          photoFile: photoFile,
        );
      } on NumeroDeClienteEnUso {
        // Otro cliente ya tiene ese número (lo registraron en otro teléfono
        // después de cargar la lista): se le asigna otro y se intenta una vez
        // más.
        final numero = _nuevoNumeroDeCliente();
        userNumberController.text = numero;
        newClient = newClient.copyWith(userNumber: numero);
        guardado = await userRepository.crearCliente(
          newClient,
          photoFile: photoFile,
        );
      }

      Get.back(); // Cerrar el formulario
      // La lista se actualiza por detrás: esperar a recargarla entera dejaba
      // el formulario abierto sin que pasara nada en pantalla.
      unawaited(fetchClientes(silencioso: true));

      // El guardado trae la foto ya subida: sin ella, Abonar no la mostraba.
      final clienteConId = guardado;
      // Navegar a la pantalla de Abono con el nuevo cliente seleccionado
      await Future.delayed(const Duration(milliseconds: 200));
      if (_registroDesdeLector) {
        // Desde el aviso del lector se termina en Inicio: debajo de Abonar
        // queda solo Inicio, aunque el aviso saliera en otra pantalla.
        Get.offNamedUntil(
          Routes.ABONAR,
          (ruta) => ruta.settings.name == Routes.HOME,
          arguments: {
            'cliente': clienteConId,
            'alTerminar': AlTerminarAbono.volverAInicio,
          },
        );
      } else {
        Get.toNamed(Routes.ABONAR, arguments: {
          'cliente': clienteConId,
          'alTerminar': AlTerminarAbono.volverAClientes,
        });
      }

      _showSnackbarSafe('Éxito', 'Cliente agregado correctamente');
      return true;
    } catch (e) {
      AppLogger.error('ClientesController', 'No se pudo agregar el cliente', e);
      _showSnackbarSafe(
        'No se guardó',
        mensajeDeFallo(e,
            generico: 'No se pudo agregar el cliente. Intenta de nuevo.'),
        isError: true,
      );
      return false;
    } finally {
      guardandoCliente.value = false;
    }
  }

  // Método para actualizar un cliente existente. Devuelve si se guardó: el
  // formulario solo se cierra en ese caso, para no perder lo escrito.
  Future<bool> updateCliente(
    String id,
    UserModel updatedClient, {
    File? photoFile,
  }) async {
    if (guardandoCliente.value) return false;
    guardandoCliente.value = true;

    BackgroundRfidService? rfidService;
    try {
      if (Get.isRegistered<BackgroundRfidService>()) {
        rfidService = Get.find<BackgroundRfidService>();
        rfidService.pauseScanning();
      }
    } catch (e) {
      AppLogger.warning('ClientesController', 'No se pudo pausar servicio RFID');
    }

    try {
      await userRepository.actualizarCliente(
        id,
        updatedClient,
        photoFile: photoFile,
      );
      unawaited(fetchClientes(silencioso: true));
      _showSnackbarSafe('Éxito', 'Cliente actualizado correctamente');
      return true;
    } catch (e) {
      AppLogger.error('ClientesController', 'No se pudo actualizar el cliente', e);
      _showSnackbarSafe(
        'No se guardó',
        mensajeDeFallo(e,
            generico: 'No se pudo guardar el cliente. Intenta de nuevo.'),
        isError: true,
      );
      return false;
    } finally {
      guardandoCliente.value = false;
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
      AppLogger.warning('ClientesController', 'No se pudo pausar servicio RFID');
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

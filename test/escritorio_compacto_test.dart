import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera_macos/camera_macos.dart' as mac;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/services/permisos_app.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:gymads/app/modules/abonar/views/abonar_view.dart';
import 'package:gymads/app/modules/clientes/views/cliente_detail_view.dart';
import 'package:gymads/app/modules/permisos/controllers/permisos_controller.dart';
import 'package:gymads/app/modules/permisos/views/permisos_view.dart';
import 'package:gymads/app/modules/shared/views/desktop_camera_view.dart';
import 'package:gymads/app/core/permissions/staff_role.dart';
import 'package:gymads/app/data/models/staff_acceso_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import 'package:gymads/app/data/models/gym_settings_model.dart';
import 'package:gymads/app/modules/categorias/controllers/categorias_controller.dart';
import 'package:gymads/app/modules/categorias/views/categorias_view.dart';
import 'package:gymads/app/modules/staff_accesos/controllers/staff_accesos_controller.dart';
import 'package:gymads/app/modules/staff_accesos/views/staff_accesos_view.dart';
import 'package:gymads/app/modules/configuracion/controllers/abono_prices_controller.dart';
import 'package:gymads/app/modules/configuracion/views/abono_prices_view.dart';
import 'package:gymads/app/modules/onboarding/controllers/onboarding_controller.dart';
import 'package:gymads/app/modules/onboarding/views/payment_mode_view.dart';
import 'package:gymads/app/modules/abonar/views/cobrar_visita_view.dart';
import 'package:gymads/app/modules/auth/controllers/auth_controller.dart';
import 'package:gymads/app/modules/auth/controllers/register_controller.dart';
import 'package:gymads/app/modules/auth/controllers/staff_code_controller.dart';
import 'package:gymads/app/modules/auth/views/login_view.dart';
import 'package:gymads/app/modules/auth/views/register_view.dart';
import 'package:gymads/app/modules/auth/views/staff_code_view.dart';
import 'package:gymads/app/modules/auth/views/google_complete_register_view.dart';
import 'package:gymads/app/modules/auth/views/email_confirmation_view.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/modules/point_of_sale/views/point_of_sale_view.dart';
import 'package:gymads/app/modules/point_of_sale/controllers/point_of_sale_controller.dart';
import 'package:gymads/app/modules/ingresos/widgets/detalle_ingreso_sheet.dart';
import 'package:gymads/app/modules/staff_accesos/views/codigo_generado_dialog.dart';
import 'package:gymads/app/modules/categorias/views/category_form_dialog.dart';
import 'package:gymads/app/modules/inventario/views/stock_adjust_dialog.dart';
import 'package:gymads/app/modules/inventario/views/inventario_view.dart';
import 'package:gymads/app/modules/configuracion/views/agregar_lector_view.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'herramientas/resumen_de_prueba.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/data/models/access_log_model.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/models/staff_profile_model.dart';
import 'package:gymads/app/modules/home/controllers/home_controller.dart';
import 'package:gymads/app/modules/home/views/home_view.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/tema_service.dart';
import 'package:gymads/app/modules/access_logs/controllers/access_logs_controller.dart';
import 'package:gymads/app/modules/access_logs/views/access_logs_view.dart';
import 'package:gymads/app/modules/clientes/controllers/clientes_controller.dart';
import 'package:gymads/app/modules/clientes/views/clientes_view.dart';
import 'package:gymads/app/modules/ingresos/controllers/ingresos_controller.dart';
import 'package:gymads/app/modules/ingresos/views/ingresos_view.dart';
import 'package:gymads/app/modules/ingresos/views/todas_transacciones_view.dart';
import 'package:gymads/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:gymads/app/modules/configuracion/views/configuracion_view.dart';
import 'package:gymads/app/modules/configuracion/views/cuenta_view.dart';
import 'package:gymads/app/modules/configuracion/views/control_accesos_view.dart';
import 'package:gymads/app/modules/configuracion/views/lector_view.dart';
import 'package:gymads/app/modules/configuracion/views/escaner_configuracion_view.dart';
import 'package:gymads/app/modules/configuracion/views/cambiar_contrasena_view.dart';
import 'package:gymads/app/modules/inventario/controllers/inventario_controller.dart';
import 'package:gymads/app/modules/inventario/views/product_form_view.dart';
import 'package:gymads/core/theme/app_theme.dart';

class _Users implements UserRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Clientes extends ClientesController {
  _Clientes() : super(userRepository: _Users());
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

class _ServicioIngresos extends GetxService implements IngresoService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ingresos extends IngresosController {
  _Ingresos() : super(ingresoService: _ServicioIngresos());
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

class _Entradas extends AccessLogsController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

class _Configuracion extends ConfiguracionController {
  @override
  bool get tieneContrasena => true;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => true;
  @override
  Future<void> cargarEstadoLector() async {}
  @override
  Future<void> loadControlAccesos() async {}
}

class _Tenant extends GetxService implements TenantContextService {
  // Con sesión abierta: en escritorio aparece la barra lateral.
  @override
  bool get isAuthenticated => true;
  @override
  final staffProfileRx = Rx<StaffProfileModel?>(null);
  @override
  String? get currentGymId => null;
  @override
  DateTime? get accountCreatedAt => DateTime(2026);
  @override
  bool can(Permission permiso) => true;
  // El dueño: usa el abono libre sin código del encargado.
  @override
  StaffRole get rol => StaffRole.ownerAdmin;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Inicio extends HomeController {
  @override
  void onReady() {}
  @override
  Future<void> checkOnboarding() async {}
  @override
  bool can(Permission permiso) => true;
}

class _Lector extends BackgroundRfidService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Inventario extends InventarioController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => true;
}

class _Categorias extends GetxController implements CategoriasController {
  @override
  final categories = <ProductCategory>[].obs;
  @override
  final isLoading = false.obs;
  @override
  final isSaving = false.obs;
  @override
  bool get puedeGestionar => true;
  @override
  int countFor(String id) => 1234;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Personal extends GetxController implements StaffAccesosController {
  @override
  final accesos = <StaffAccesoModel>[].obs;
  @override
  final isLoading = false.obs;
  @override
  bool puedeGestionar(StaffAccesoModel acceso) => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Precios extends GetxController implements AbonoPricesController {
  @override
  final dayController = TextEditingController();
  @override
  final weekController = TextEditingController();
  @override
  final monthController = TextEditingController();
  @override
  final yearController = TextEditingController();
  @override
  final inscripcionController = TextEditingController(text: '200.00');
  @override
  bool get soloInscripcion => false;
  @override
  final hayCodigo = RxnBool(true);
  @override
  final guardandoCodigo = false.obs;
  @override
  final isLoading = false.obs;
  @override
  final isSaving = false.obs;
  @override
  bool get isOnboarding => false;
  @override
  void onClose() {
    for (final c in [
      dayController,
      weekController,
      monthController,
      yearController
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Onboarding extends OnboardingController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends GetxController implements AuthController {
  @override
  final emailController = TextEditingController();
  @override
  final passwordController = TextEditingController();
  @override
  final obscurePassword = true.obs;
  @override
  final errorMessage = RxnString();
  @override
  final isLoading = false.obs;
  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Registro extends GetxController implements RegisterController {
  @override
  final firstNameController = TextEditingController();
  @override
  final lastNameController = TextEditingController();
  @override
  final emailController = TextEditingController();
  @override
  final passwordController = TextEditingController();
  @override
  final confirmPasswordController = TextEditingController();
  @override
  final gymNameController = TextEditingController();
  @override
  final locationController = TextEditingController();
  @override
  final horaApertura = const HoraDelDia(6, 0).obs;
  @override
  final horaCierre = const HoraDelDia(22, 0).obs;
  @override
  final obscurePassword = true.obs;
  @override
  final obscureConfirmPassword = true.obs;
  @override
  final sugerenciaCorreo = RxnString();
  @override
  final errorMessage = RxnString();
  @override
  final isLoading = false.obs;
  @override
  void onClose() {
    for (final c in [
      firstNameController,
      lastNameController,
      emailController,
      passwordController,
      confirmPasswordController,
      gymNameController,
      locationController
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CodigoStaff extends GetxController implements StaffCodeController {
  @override
  final codigoController = TextEditingController();
  @override
  final errorMessage = RxnString();
  @override
  final isLoading = false.obs;
  @override
  void onClose() {
    codigoController.dispose();
    super.onClose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Venta extends PointOfSaleController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

/// Un Bluetooth que no encuentra nada: las capturas ponen el paso a mano.
class _BleFalso extends LectorBleService {
  @override
  Stream<List<LectorCercano>> buscar({
    Duration duracion = const Duration(seconds: 15),
  }) =>
      const Stream.empty();
  @override
  Future<void> detenerBusqueda() async {}
  @override
  Future<void> desconectar() async {}
}

class _Asistente extends AgregarLectorController {
  _Asistente() : super(ble: _BleFalso());
  @override
  void onReady() {}
}

/// Una pantalla vacía que abre un diálogo o una ventana al mostrarse.
class _AbreAlMostrar extends StatefulWidget {
  const _AbreAlMostrar(this.abrir);
  final void Function(BuildContext context) abrir;
  @override
  State<_AbreAlMostrar> createState() => _AbreAlMostrarState();
}

class _AbreAlMostrarState extends State<_AbreAlMostrar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.abrir(context));
  }

  @override
  Widget build(BuildContext context) =>
      const ScaffoldAdaptable(body: SizedBox.expand());
}

List<Product> _productos() => List.generate(
    6,
    (i) => Product(
          id: '$i',
          name: [
            'Agua natural 1 L',
            'Barra de proteína',
            'Toalla deportiva'
          ][i % 3],
          description: 'Presentación individual',
          categoryId: null,
          barcode: '75010000$i',
          price: 15 + i * 10,
          stock: i == 2 ? -3 : 12 + i,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ));

AgregarLectorController _asistente(PasoAgregar paso) {
  final c = Get.put<AgregarLectorController>(_Asistente());
  c.redes.assignAll(const [
    RedWifi('Gimnasio Centro', rssi: -50),
    RedWifi('Oficina', rssi: -65, seguridad: SeguridadRed.empresarial),
    RedWifi('Invitados', rssi: -80, seguridad: SeguridadRed.abierta),
  ]);
  if (paso == PasoAgregar.escribirClave) c.redElegida.value = 'Gimnasio Centro';
  if (paso == PasoAgregar.fallo) {
    c.mensaje.value =
        'El lector no respondió. Revisa que esté encendido e intenta de nuevo.';
  }
  c.paso.value = paso;
  return c;
}

IngresoModel _ingreso() => IngresoModel(
    id: '1',
    clienteNombre: 'María Fernanda González Rodríguez',
    concepto: 'renovacion',
    tipoMembresia: 'mensual',
    montoBase: 1234567.89,
    montoFinal: 1234567.89,
    metodoPago: 'transferencia',
    fecha: DateTime(2026, 10, 1),
    usuarioStaff: 'Mostrador');
ProductCategory _categoria() => ProductCategory(
    id: 'bebidas',
    name: 'Bebidas y suplementos para entrenamiento',
    description: '',
    icon: 'shopping_bag',
    sortOrder: 0,
    isActive: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

/// Categorías de sobra: los filtros no caben en una pantalla y hay que
/// desplazarlos.
List<ProductCategory> _muchasCategorias() => [
      for (final (i, nombre) in [
        'Bebidas',
        'Suplementos',
        'Barras de proteína',
        'Ropa deportiva',
        'Accesorios',
        'Toallas',
        'Guantes',
        'Cinturones',
        'Snacks',
        'Equipo de entrenamiento',
      ].indexed)
        ProductCategory(
            id: 'c$i',
            name: nombre,
            description: '',
            icon: 'shopping_bag',
            sortOrder: i,
            isActive: true,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026)),
    ];

class _RepoPrecios implements AbonoPricesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Abonar extends AbonarController {
  _Abonar()
      : super(
            userRepository: _Users(),
            ingresoService: _ServicioIngresos(),
            pricesRepository: _RepoPrecios());
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

class _SinCamaras extends mac.CameraMacOSPlatform {
  @override
  Future<List<mac.CameraMacOSDevice>> listDevices(
          {mac.CameraMacOSDeviceType? deviceType}) async =>
      [];
}

class _Solicitud implements SolicitudPermisos {
  @override
  List<PermisoApp> get permisos =>
      [PermisoApp.camara, PermisoApp.bluetooth, PermisoApp.notificaciones];
  @override
  Future<Map<PermisoApp, EstadoPermiso>> estados() async =>
      {for (final p in permisos) p: EstadoPermiso.sinDato};
  @override
  Future<Map<PermisoApp, EstadoPermiso>> pedirTodos() => estados();
  @override
  Future<void> abrirAjustes() async {}
  @override
  void cancelar() {}
}

UserModel _cliente() => UserModel(
    id: '1',
    name: 'María Fernanda González Rodríguez',
    phone: '8112345678',
    userNumber: '123',
    joinDate: DateTime(2026),
    daysRemaining: 15);

void main() {
  late ShowcaseView tour;
  late mac.CameraMacOSPlatform camaraAnterior;
  setUpAll(() {
    camaraAnterior = mac.CameraMacOSPlatform.instance;
    mac.CameraMacOSPlatform.instance = _SinCamaras();
  });
  tearDownAll(() => mac.CameraMacOSPlatform.instance = camaraAnterior);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tour = ShowcaseView.register();
    Get.put<TenantContextService>(_Tenant());
    Get.put<ConfiguracionController>(_Configuracion());
    Get.put(TemaService(leer: () => 'oscuro', guardar: (_) {}));
    Get.put<BackgroundRfidService>(_Lector());
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  final pantallas = <String, Widget Function()>{
    'Inicio': () {
      Get.put<HomeController>(_Inicio());
      Get.put(resumenDePrueba());
      return const HomeView();
    },
    'Cámara sin dispositivo': () =>
        DesktopCameraView(onPhotoTaken: (_) {}, onCancel: () {}),
    'Permisos pendientes': () {
      final c = Get.put(PermisosController(
          solicitud: _Solicitud(), desdeConfiguracion: true));
      c.estados
          .assignAll({for (final p in c.permisos) p: EstadoPermiso.sinDato});
      return const PermisosView();
    },
    'Detalle del cliente': () {
      Get.put<ClientesController>(_Clientes());
      return ClienteDetailView(cliente: _cliente());
    },
    'Abonar buscar': () {
      final c = Get.put<AbonarController>(_Abonar());
      c.searchResults.add(_cliente());
      return const AbonarView();
    },
    'Abonar con varios clientes': () {
      final c = Get.put<AbonarController>(_Abonar());
      final ahora = DateTime(2026, 10, 5);
      UserModel cliente(String nombre, DateTime? vence) => UserModel(
          id: nombre,
          name: nombre,
          phone: '8112345678',
          userNumber: '1',
          joinDate: DateTime(2026),
          expirationDate: vence);
      c.searchResults.addAll([
        cliente('Ana López', ahora.add(const Duration(days: 20))),
        cliente('Carlos Ruiz', ahora.subtract(const Duration(days: 5))),
        cliente('María Fernanda González Rodríguez', null),
        cliente('Jorge Díaz', ahora.add(const Duration(days: 2))),
        cliente('Sofía Torres', ahora.add(const Duration(days: 90))),
        cliente('Pedro Sánchez', ahora.subtract(const Duration(days: 40))),
        // Membresía "para siempre": la fecha larga no debe cortarse.
        cliente('Leo', DateTime(2126, 9, 11)),
      ]);
      return const AbonarView();
    },
    'Abonar con inscripción': () {
      final c = Get.put<AbonarController>(_Abonar());
      c.selectedClient.value = _cliente();
      c.prices.value =
          const AbonoPricesModel(priceMonth: 1500, priceInscripcion: 300);
      // En el teléfono, directo al resumen.
      c.pasoActual.value = 3;
      return const AbonarView();
    },
    'Abonar costo fijo': () {
      final c = Get.put<AbonarController>(_Abonar());
      c.selectedClient.value = _cliente();
      c.prices.value = const AbonoPricesModel(priceMonth: 1500);
      return const AbonarView();
    },
    'Abonar libre': () {
      final c = Get.put<AbonarController>(_Abonar());
      c.selectedClient.value = _cliente();
      c.isPrecioFijo.value = false;
      c.montoLibre.value = 1500;
      return const AbonarView();
    },
    'Categorías': () {
      final c = Get.put<CategoriasController>(_Categorias());
      c.categories.add(_categoria());
      return const CategoriasView();
    },
    'Personal': () {
      final c = Get.put<StaffAccesosController>(_Personal());
      c.accesos.add(StaffAccesoModel(
          id: '1',
          gymId: 'g',
          branchId: 'b',
          nombre: 'María Fernanda González Rodríguez',
          rol: StaffRole.mostrador,
          estado: 'pendiente',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026)));
      return const StaffAccesosView();
    },
    'Precios': () {
      Get.put<AbonoPricesController>(_Precios());
      return const AbonoPricesView();
    },
    'Modo de cobro': () {
      Get.put<OnboardingController>(_Onboarding());
      return const PaymentModeView();
    },
    'Visita': () {
      Get.put(
          CobrarVisitaController(precioDia: 100, registrar: (_) async => null));
      return const CobrarVisitaView();
    },
    'Login': () {
      Get.put<AuthController>(_Auth());
      return const LoginView();
    },
    'Registro': () {
      Get.put<RegisterController>(_Registro());
      return const RegisterView();
    },
    'Registro Google': () {
      Get.put<RegisterController>(_Registro());
      return const GoogleCompleteRegisterView();
    },
    'Código de personal': () {
      Get.put<StaffCodeController>(_CodigoStaff());
      return const StaffCodeView();
    },
    'Confirmar correo': () => const EmailConfirmationView(),
    'Configuración': () => const ConfiguracionView(),
    'Cuenta': () => const CuentaView(),
    'Control de accesos': () => const ControlAccesosView(),
    'Lector': () => const LectorView(),
    'Escáner': () => const EscanerConfiguracionView(),
    'Contraseña': () => CambiarContrasenaView(cambiar: (_, __) async => null),
    'Clientes': () {
      final c = Get.put<ClientesController>(_Clientes());
      c.clientes.add(UserModel(
          id: '1',
          name: 'María Fernanda González Rodríguez',
          phone: '8112345678',
          userNumber: '123',
          joinDate: DateTime(2026),
          daysRemaining: 15));
      return const ClientesView();
    },
    'Ingresos': () {
      final c = Get.put<IngresosController>(_Ingresos());
      c.ingresos.add(_ingreso());
      c.todasTransacciones.add(_ingreso());
      return const IngresosView();
    },
    'Historial completo': () {
      final c = Get.put<IngresosController>(_Ingresos());
      c.ingresos.add(_ingreso());
      c.todasTransacciones.add(_ingreso());
      return const TodasTransaccionesView();
    },
    'Inventario': () {
      final c = Get.put<InventarioController>(_Inventario());
      c.products.addAll(_productos());
      c.filterProducts();
      c.inventoryStats.assignAll(
          {'totalProducts': 6, 'totalStock': 69, 'totalValue': 2350.0});
      return const InventarioView();
    },
    'Venta con muchas categorías': () {
      final c = Get.put<PointOfSaleController>(_Venta());
      c.categories.addAll(_muchasCategorias());
      c.availableProducts.addAll(_productos());
      return const PointOfSaleView();
    },
    'Inventario con muchas categorías': () {
      final c = Get.put<InventarioController>(_Inventario());
      c.categories.addAll(_muchasCategorias());
      c.products.addAll(_productos());
      c.filterProducts();
      c.inventoryStats.assignAll(
          {'totalProducts': 6, 'totalStock': 69, 'totalValue': 2350.0});
      return const InventarioView();
    },
    'Venta': () {
      final c = Get.put<PointOfSaleController>(_Venta());
      c.availableProducts.addAll(_productos());
      c.addProductToCart(c.availableProducts.first);
      return const PointOfSaleView();
    },
    'Producto nuevo': () {
      Get.put<InventarioController>(_Inventario());
      return _AbreAlMostrar(
          (_) => abrirFormulario(() => const ProductFormView()));
    },
    'Ajuste de stock': () {
      Get.put<InventarioController>(_Inventario());
      return _AbreAlMostrar((_) => showStockAdjustDialog(_productos()[1]));
    },
    'Categoría nueva': () {
      Get.put<CategoriasController>(_Categorias());
      return _AbreAlMostrar((_) => showCategoryFormDialog());
    },
    'Código generado': () => _AbreAlMostrar((_) => showCodigoGeneradoDialog(
        nombre: 'María Fernanda', codigo: 'K7P2-9QXA', gymName: 'Gimnasio')),
    'Detalle de ingreso': () {
      Get.put<IngresosController>(_Ingresos());
      return _AbreAlMostrar(
          (context) => mostrarDetalleIngreso(context, _ingreso()));
    },
    'Asistente redes': () {
      _asistente(PasoAgregar.elegirRed);
      return const AgregarLectorView();
    },
    'Asistente contraseña': () {
      _asistente(PasoAgregar.escribirClave);
      return const AgregarLectorView();
    },
    'Asistente listo': () {
      _asistente(PasoAgregar.listo);
      return const AgregarLectorView();
    },
    'Asistente fallo': () {
      _asistente(PasoAgregar.fallo);
      return const AgregarLectorView();
    },
    'Entradas': () {
      final ctrl = Get.put<AccessLogsController>(_Entradas());
      ctrl.accessLogs.add(AccessLogModel(
          id: '1',
          userId: '1',
          userName: 'María Fernanda González Rodríguez',
          userNumber: '123',
          accessType: 'entrada',
          method: 'rfid',
          staffUser: 'Mostrador',
          accessTime: DateTime(2026, 10, 1, 10),
          createdAt: DateTime(2026, 10, 1, 10)));
      return const AccessLogsView();
    },
  };
  // Cada paso de cada recorrido existe en cada versión. Si falta uno, el
  // recorrido entero no arranca ahí: espera a que aparezca y se rinde.
  final recorridos = <String, List<GlobalKey> Function()>{
    'Inicio': () => Get.find<HomeController>().tourSteps,
    'Abonar buscar': () => Get.find<AbonarController>().tourSteps,
    'Configuración': () => Get.find<ConfiguracionController>().tourSteps,
    'Clientes': () => Get.find<ClientesController>().tourSteps,
    'Ingresos': () => Get.find<IngresosController>().tourSteps,
    'Inventario': () => Get.find<InventarioController>().tourSteps,
    'Venta': () => Get.find<PointOfSaleController>().tourSteps,
    'Entradas': () => Get.find<AccessLogsController>().tourSteps,
  };
  final versiones = <({String nombre, Size tamano, TargetPlatform plataforma})>[
    (
      nombre: 'teléfono',
      tamano: const Size(390, 844),
      plataforma: TargetPlatform.android
    ),
    (
      nombre: 'tableta acostada',
      tamano: const Size(1180, 820),
      plataforma: TargetPlatform.iOS
    ),
    (
      nombre: 'tableta de pie',
      tamano: const Size(820, 1180),
      plataforma: TargetPlatform.android
    ),
    (
      nombre: 'macOS',
      tamano: const Size(1280, 800),
      plataforma: TargetPlatform.macOS
    ),
    (
      nombre: 'Windows',
      tamano: const Size(1920, 1000),
      plataforma: TargetPlatform.windows
    ),
    (
      nombre: 'Linux',
      tamano: const Size(960, 600),
      plataforma: TargetPlatform.linux
    ),
  ];
  for (final version in versiones) {
    for (final recorrido in recorridos.entries) {
      testWidgets('recorrido de ${recorrido.key} completo en ${version.nombre}',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = version.tamano;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(GetMaterialApp(
            theme: AppTheme.oscuro,
            builder: (context, child) => VentanaEscritorio(child: child!),
            home: pantallas[recorrido.key]!()));
        await tester.pumpAndSettle();
        final pasos = recorrido.value();
        expect(pasos, isNotEmpty);
        final faltan = [
          for (var i = 0; i < pasos.length; i++)
            if (!tour.isTargetRendered(pasos[i])) i + 1,
        ];
        expect(faltan, isEmpty,
            reason: 'Pasos (1 = primero) sin su widget en pantalla');
        await tester.pumpWidget(const SizedBox());
      }, variant: TargetPlatformVariant.only(version.plataforma));
    }
  }

  testWidgets(
      'Configuración: Cuenta antes que todo, y el escáner en el '
      'recorrido', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.oscuro,
        builder: (context, child) => VentanaEscritorio(child: child!),
        home: const ConfiguracionView()));
    await tester.pumpAndSettle();
    final c = Get.find<ConfiguracionController>();
    final escaner = PlataformaApp.escanerFisico;
    expect(c.tourSteps.take(escaner ? 3 : 2), [
      c.keyCuenta,
      if (escaner) c.keyEscaner,
      c.keyApariencia,
    ]);
    expect(find.text('Escáner de códigos'),
        escaner ? findsOneWidget : findsNothing);
    if (escaner) {
      // En la rejilla, Cuenta es la primera tarjeta y el escáner va después.
      final cuenta = tester.getTopLeft(find.text('Cuenta'));
      final lector = tester.getTopLeft(find.text('Escáner de códigos'));
      expect(cuenta.dy < lector.dy || cuenta.dx < lector.dx, isTrue);
    }
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.android,
      }));

  // Inspección visual opcional: cada pantalla maximizada en 2560×1410, con
  // las sombras reales (en pruebas Flutter las dibuja como un borde negro).
  const capturas = bool.fromEnvironment('CAPTURAS_ESCRITORIO');
  if (capturas) {
    setUpAll(() async {
      final carpeta = Platform.environment['FUENTES_CAPTURA']!;
      for (final nombre in ['Roboto', 'MaterialIcons']) {
        final archivo = nombre == 'Roboto'
            ? 'Roboto-Regular.ttf'
            : 'MaterialIcons-Regular.otf';
        final loader = FontLoader(nombre)
          ..addFont(File('$carpeta/$archivo')
              .readAsBytes()
              .then(ByteData.sublistView));
        await loader.load();
      }
    });
    // Escritorio maximizado y en laptop; el celular en un teléfono común.
    // Las del celular sirven para comprobar que no cambie: se guardan en
    // build/capturas_movil/<CAPTURAS_MOVIL_CARPETA> y se comparan con
    // test/herramientas/comparar_capturas.py. Generarlas en su propia
    // ejecución (--plain-name 390): AppTheme fija la densidad con la
    // plataforma de la primera prueba que lo usa.
    const carpetaMovil = String.fromEnvironment('CAPTURAS_MOVIL_CARPETA',
        defaultValue: 'actual');
    final modos = <({String carpeta, Size tamano, TargetPlatform plataforma})>[
      (
        carpeta: 'build/capturas_escritorio/pantallas',
        tamano: const Size(2560, 1410),
        plataforma: TargetPlatform.macOS
      ),
      (
        carpeta: 'build/capturas_escritorio/laptop',
        tamano: const Size(1280, 800),
        plataforma: TargetPlatform.macOS
      ),
      (
        carpeta: 'build/capturas_movil/$carpetaMovil',
        tamano: const Size(390, 844),
        plataforma: TargetPlatform.android
      ),
      // iPad de 11" acostado y de pie. También se generan aparte
      // (--plain-name 1180 y --plain-name 820).
      (
        carpeta: 'build/capturas_tableta/horizontal',
        tamano: const Size(1180, 820),
        plataforma: TargetPlatform.iOS
      ),
      (
        carpeta: 'build/capturas_tableta/vertical',
        tamano: const Size(820, 1180),
        plataforma: TargetPlatform.iOS
      ),
      // iPad de 13" (Air M2 o Pro): --plain-name 1366 y --plain-name 1024.
      (
        carpeta: 'build/capturas_tableta/13_horizontal',
        tamano: const Size(1366, 1024),
        plataforma: TargetPlatform.iOS
      ),
      (
        carpeta: 'build/capturas_tableta/13_vertical',
        tamano: const Size(1024, 1366),
        plataforma: TargetPlatform.iOS
      ),
    ];
    for (final modo in modos) {
      for (final claro in [false, true]) {
        for (final entry in pantallas.entries) {
          testWidgets(
              'captura ${entry.key} ${claro ? 'claro' : 'oscuro'} '
              '${modo.tamano.width.toInt()}', (tester) async {
            debugDisableShadows = false;
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = modo.tamano;
            addTearDown(tester.view.reset);
            final imagen = GlobalKey();
            final tema = claro ? AppTheme.claro : AppTheme.oscuro;
            await tester.pumpWidget(GetMaterialApp(
                theme: tema.copyWith(
                  textTheme: tema.textTheme.apply(fontFamily: 'Roboto'),
                ),
                builder: (context, child) => RepaintBoundary(
                    key: imagen, child: VentanaEscritorio(child: child!)),
                home: entry.value()));
            await tester.pumpAndSettle();
            // Las imágenes (el logo de la barra lateral) se decodifican fuera
            // del reloj de prueba. Las del teléfono se dejan como su línea
            // base.
            if (modo.plataforma != TargetPlatform.android) {
              await tester.runAsync(() async {
                for (final e in find.byType(Image).evaluate()) {
                  await precacheImage((e.widget as Image).image, e);
                }
              });
              await tester.pumpAndSettle();
            }
            await tester.runAsync(() async {
              final boundary = imagen.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final img = await boundary.toImage();
              final bytes =
                  await img.toByteData(format: ui.ImageByteFormat.png);
              final carpeta = Directory(modo.carpeta);
              await carpeta.create(recursive: true);
              final nombre = entry.key.toLowerCase().replaceAll(' ', '-');
              await File(
                      '${carpeta.path}/$nombre-${claro ? 'claro' : 'oscuro'}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              img.dispose();
            });
            await tester.pumpWidget(const SizedBox());
            // Se restablece dentro de la prueba: el marco verifica que quede
            // como estaba antes de los tearDown.
            debugDisableShadows = true;
          }, variant: TargetPlatformVariant({modo.plataforma}));
        }
      }
    }
    return;
  }
  for (final entry in pantallas.entries) {
    testWidgets('${entry.key} permite reducir y ampliar con texto aumentado',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pantalla = entry.value();
      for (final escala in [1.0, 1.3, 2.0]) {
        tester.view.physicalSize = const Size(900, 600);
        await tester.pumpWidget(GetMaterialApp(
            theme: AppTheme.oscuro,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(escala)),
                child: VentanaEscritorio(child: child!)),
            home: pantalla));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${entry.key}, texto $escala');
        for (final size in [
          const Size(480, 360),
          const Size(600, 360),
          const Size(1920, 1000),
          const Size(168, 360),
          const Size(103, 360),
          const Size(480, 200),
          const Size(103, 120),
          const Size(480, 360)
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${entry.key} $size, texto $escala');
          final scroll = find.byType(Scrollable);
          if (scroll.evaluate().isNotEmpty) {
            await tester.drag(scroll.first, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${entry.key}, al desplazar');
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
        variant: const TargetPlatformVariant({
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux
        }));
  }

  testWidgets('producto conserva texto, selección y foco al reducir y ampliar',
      (tester) async {
    final ctrl = Get.put<InventarioController>(_Inventario());
    ctrl.categories.add(ProductCategory(
        id: 'bebidas',
        name: 'Bebidas y suplementos para entrenamiento',
        description: '',
        icon: 'shopping_bag',
        sortOrder: 0,
        isActive: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026)));
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.oscuro,
        builder: (_, child) => VentanaEscritorio(child: child!),
        home: const ProductFormView()));
    await tester.pumpAndSettle();
    final categoria = find.byType(DropdownButtonFormField<String>);
    await tester.tap(categoria);
    await tester.pumpAndSettle();
    await tester
        .tap(find.text('Bebidas y suplementos para entrenamiento').last);
    await tester.pumpAndSettle();
    final nombre = find.widgetWithText(TextFormField, 'Nombre del producto *');
    await tester.enterText(nombre, 'Proteína de prueba');
    final campo = tester.widget<TextFormField>(nombre).controller!;
    final foco = FocusManager.instance.primaryFocus;
    final seleccion = campo.selection;
    for (final size in [
      const Size(480, 360),
      const Size(1920, 1000),
      const Size(168, 200),
      const Size(480, 360)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(nombre).controller, same(campo));
      expect(campo.text, 'Proteína de prueba');
      expect(campo.selection, seleccion);
      expect(FocusManager.instance.primaryFocus, same(foco));
      expect(tester.state<FormFieldState<String>>(categoria).value, 'bebidas');
      if (size.width < VentanaEscritorio.minimo.width ||
          size.height < VentanaEscritorio.minimo.height) {
        await tester.ensureVisible(find.text('Guardar producto'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Guardar producto').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux
      }));

  testWidgets('Abonar permite elegir al cliente tras reducir la ventana',
      (tester) async {
    final ctrl = Get.put<AbonarController>(_Abonar());
    final cliente = _cliente();
    ctrl.searchResults.add(cliente);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final escala in [1.0, 2.0]) {
      ctrl.selectedClient.value = null;
      tester.view.physicalSize = const Size(1800, 1200);
      await tester.pumpWidget(GetMaterialApp(
          theme: AppTheme.oscuro,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: VentanaEscritorio(child: child!)),
          home: const AbonarView()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'María');
      final foco = FocusManager.instance.primaryFocus;
      tester.view.physicalSize = const Size(336, 240);
      await tester.pumpAndSettle();
      expect(ctrl.searchController.text, 'María');
      expect(FocusManager.instance.primaryFocus, same(foco));
      expect(tester.takeException(), isNull);
      // En escritorio, el cliente es una tarjeta de la rejilla.
      final tarjeta = find
          .ancestor(of: find.text(cliente.name), matching: find.byType(InkWell))
          .first;
      await tester.ensureVisible(tarjeta);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(tarjeta) + const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(ctrl.selectedClient.value, same(cliente));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(3840, 2000);
      await tester.pumpAndSettle();
      expect(ctrl.selectedClient.value, same(cliente));
      expect(tester.takeException(), isNull);
    }
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux
      }));
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:gymads/app/core/utils/material_localizations_12h.dart';
import 'package:gymads/app/bindings/initial_binding.dart';
import 'package:gymads/app/data/config/rfid_config.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/gym_settings_service.dart';
import 'package:gymads/app/data/services/image_cache_service.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/auth/controllers/auth_controller.dart';
import 'package:gymads/app/routes/app_pages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GlobalKey para acceder al ScaffoldMessenger desde cualquier parte de la app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Stores the initial route after checking session
String _initialRoute = Routes.LOGIN;

void main() async {
  // Carga las variables de entorno
  await dotenv.load(fileName: ".env");

  // Asegura la inicialización de los bindings de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize GetStorage for local caching
  await GetStorage.init();

  // Inicializa Supabase (cliente principal) - SOLO UNA VEZ
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    debug: true,
  );
  AppLogger.info('Main', 'Supabase inicializado correctamente');

  // Initialize TenantContextService
  Get.put(TenantContextService(), permanent: true);
  await TenantContextService.to.init();
  AppLogger.info('Main', 'TenantContextService inicializado');

  // Configuración de accesos (salidas y horario). Se registra sin cargar:
  // hace falta el gimnasio, que llega con la sesión.
  Get.put(GymSettingsService(), permanent: true);

  // Tour de bienvenida: debe quedar registrado antes de que se construya
  // cualquier widget Showcase de Inicio.
  Get.put(WelcomeTourService(), permanent: true).init();

  // Check for existing session
  final authController = Get.put(AuthController(), permanent: true);
  final hasSession = await authController.checkSession();

  if (hasSession) {
    AppLogger.info('Main', 'Sesión existente restaurada');
    _initialRoute = Routes.HOME;
  } else {
    AppLogger.info('Main', 'No hay sesión, mostrando login');
    _initialRoute = Routes.LOGIN;
  }

  // Inicializa y registra el servicio de caché de imágenes
  final imageCacheService = ImageCacheService.instance;
  await imageCacheService.initialize();
  Get.put(imageCacheService, permanent: true);
  AppLogger.info('Main', 'Servicio de caché de imágenes inicializado');

  // Inicializa la configuración del lector RFID SOLO si está activado
  final prefs = await SharedPreferences.getInstance();
  final rfidEnabled = prefs.getBool('rfid_enabled') ?? false;
  if (rfidEnabled) {
    await RfidConfig.loadConfig();
    AppLogger.info('Main', 'Configuración RFID cargada');
  } else {
    AppLogger.info('Main', 'RFID desactivado, omitiendo configuración');
  }

  // Registra el servicio de RFID de forma perezosa
  Get.lazyPut<BackgroundRfidService>(() => BackgroundRfidService());
  AppLogger.info('Main', 'BackgroundRfidService registrado');

  // Inicia la aplicación
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Solo inicia RFID si el usuario está autenticado Y RFID está habilitado
    if (TenantContextService.to.isAuthenticated) {
      _initRfidServiceIfEnabled();
    }
  }

  Future<void> _initRfidServiceIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final rfidEnabled = prefs.getBool('rfid_enabled') ?? false;
    if (!rfidEnabled) {
      AppLogger.info('Main', 'RFID desactivado, omitiendo servicio de escaneo');
      return;
    }

    // Inicia el servicio RFID después de que el primer frame se renderice
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AppLogger.info('Main', 'Post-frame: Iniciando servicio RFID');
      try {
        final bool connected = await RfidReaderService.startReading();
        if (connected) {
          AppLogger.info(
              'Main', 'RFID conectado. Iniciando escaneo en segundo plano');
          Get.find<BackgroundRfidService>().startScanning();
          AppLogger.info(
              'Main', 'Servicio de escaneo RFID iniciado correctamente');
        } else {
          AppLogger.warning('Main', 'No se pudo conectar al lector RFID');
        }
      } catch (e) {
        AppLogger.error('Main', 'Fallo al iniciar el servicio RFID', e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: "GymOne",
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      initialRoute: _initialRoute,
      getPages: AppPages.routes,
      initialBinding: InitialBinding(),
      locale: const Locale('es'),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        // Va primero: Flutter usa el primer delegado que soporte el idioma,
        // y este es el español con el reloj en 12 h (a.m./p.m.).
        MaterialLocalizations12h.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
    );
  }
}

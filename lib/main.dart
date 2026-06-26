import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gymads/app/bindings/initial_binding.dart';
import 'package:gymads/app/data/config/rfid_config.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/image_cache_service.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/branding_service.dart';
import 'package:gymads/app/modules/auth/controllers/auth_controller.dart';
import 'package:gymads/app/modules/clientes/services/qr_cache_service.dart';
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
  print('✅ Supabase inicializado correctamente');

  // Initialize TenantContextService
  Get.put(TenantContextService(), permanent: true);
  await TenantContextService.to.init();
  print('✅ TenantContextService inicializado');

  // Initialize BrandingService (local-first)
  Get.put(BrandingService(), permanent: true);
  await BrandingService.to.init();
  print('✅ BrandingService inicializado');

  // Check for existing session
  final authController = Get.put(AuthController(), permanent: true);
  final hasSession = await authController.checkSession();

  if (hasSession) {
    print('✅ Sesión existente restaurada');
    // Seed branding from DB if no local data exists (first login on device)
    final profile = TenantContextService.to.staffProfile;
    BrandingService.to.syncFromDb(
      dbGymName: profile?.gymName,
      dbBrandColor: profile?.brandColor,
      dbBrandFont: profile?.brandFont,
    );
    _initialRoute = Routes.HOME;
  } else {
    print('📍 No hay sesión, mostrando login');
    _initialRoute = Routes.LOGIN;
  }

  // Inicializa y registra el servicio de caché de imágenes
  final imageCacheService = ImageCacheService.instance;
  await imageCacheService.initialize();
  Get.put(imageCacheService, permanent: true);
  print('✅ Servicio de caché de imágenes inicializado');

  // Inicializa y registra el servicio de caché de QR
  final qrCacheService = QrCacheService();
  qrCacheService.initialize();
  Get.put(qrCacheService, permanent: true);
  print('✅ Servicio de caché de QR codes inicializado');

  // Inicializa la configuración del lector RFID SOLO si está activado
  final prefs = await SharedPreferences.getInstance();
  final rfidEnabled = prefs.getBool('rfid_enabled') ?? false;
  if (rfidEnabled) {
    await RfidConfig.loadConfig();
    print('✅ Configuración RFID cargada');
  } else {
    print('⏭️ RFID desactivado, omitiendo configuración');
  }

  // Registra el servicio de RFID de forma perezosa
  Get.lazyPut<BackgroundRfidService>(() => BackgroundRfidService());
  print('✅ BackgroundRfidService registrado');

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
      print('⏭️ RFID desactivado, omitiendo servicio de escaneo');
      return;
    }

    // Inicia el servicio RFID después de que el primer frame se renderice
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('⚙️ Post-frame: Iniciando servicio RFID...');
      try {
        final bool connected = await RfidReaderService.startReading();
        if (connected) {
          print('✅ RFID conectado. Iniciando escaneo en segundo plano...');
          Get.find<BackgroundRfidService>().startScanning();
          print('✅ Servicio de escaneo RFID iniciado correctamente.');
        } else {
          print('⚠️ No se pudo conectar al lector RFID.');
        }
      } catch (e, stack) {
        print('❌ ERROR al iniciar servicio RFID: $e');
        print('Stack: $stack');
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
    );
  }
}

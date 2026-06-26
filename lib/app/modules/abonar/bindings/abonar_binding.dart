import 'package:get/get.dart';
import 'package:gymads/app/data/providers/supabase/supabase_api_provider.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/providers/ingreso_provider.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import '../controllers/abonar_controller.dart';

class AbonarBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SupabaseApiProvider>(tag: 'users_provider')) {
      Get.lazyPut<SupabaseApiProvider>(
        () => SupabaseApiProvider(table: 'users'),
        tag: 'users_provider',
      );
    }

    if (!Get.isRegistered<UserRepository>()) {
      Get.lazyPut<UserRepository>(
        () => UserRepository(Get.find<SupabaseApiProvider>(tag: 'users_provider')),
      );
    }

    if (!Get.isRegistered<IngresoProvider>()) {
      Get.lazyPut<IngresoProvider>(
        () => IngresoProvider(),
      );
    }

    if (!Get.isRegistered<IngresoService>()) {
      Get.lazyPut<IngresoService>(
        () => IngresoService(
          ingresoProvider: Get.find<IngresoProvider>(),
        ),
      );
    }

    // Inyectar el controlador con dependencias
    Get.lazyPut<AbonarController>(
      () => AbonarController(
        userRepository: Get.find<UserRepository>(),
        ingresoService: Get.find<IngresoService>(),
        rfidService: Get.isRegistered<BackgroundRfidService>() 
            ? Get.find<BackgroundRfidService>() 
            : null,
      ),
    );
  }
}

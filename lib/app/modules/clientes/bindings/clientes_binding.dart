import 'package:get/get.dart';
import 'package:gymads/app/data/providers/supabase/supabase_api_provider.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/providers/ingreso_provider.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';

import '../controllers/clientes_controller.dart';

class ClientesBinding extends Bindings {
  @override
  void dependencies() {
    // Usar el provider global de users si existe, sino crear uno nuevo
    if (!Get.isRegistered<SupabaseApiProvider>(tag: 'users_provider')) {
      Get.lazyPut<SupabaseApiProvider>(
        () => SupabaseApiProvider(table: 'users'),
        tag: 'users_provider',
      );
    }

    // Inyectar el repositorio de usuarios usando el provider con tag
    Get.lazyPut<UserRepository>(
      () => UserRepository(Get.find<SupabaseApiProvider>(tag: 'users_provider')),
    );

    // Inyectar el provider de ingresos  
    Get.lazyPut<IngresoProvider>(
      () => IngresoProvider(),
    );

    // Inyectar el servicio de ingresos
    Get.lazyPut<IngresoService>(
      () => IngresoService(
        ingresoProvider: Get.find<IngresoProvider>(),
      ),
    );

    // Inyectar el controlador de clientes CON manejo de errores
    Get.lazyPut<ClientesController>(
      () {
        try {
          return ClientesController(
            userRepository: Get.find<UserRepository>(),
            ingresoService: Get.isRegistered<IngresoService>() ? Get.find<IngresoService>() : null,
          );
        } catch (e) {
          print('❌ Error creando ClientesController: $e');
          // Fallback mínimo
          return ClientesController(
            userRepository: Get.find<UserRepository>(),
            ingresoService: null,
          );
        }
      },
    );
  }
}

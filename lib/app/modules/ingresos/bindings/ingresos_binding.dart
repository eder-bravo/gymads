import 'package:get/get.dart';
import 'package:gymads/app/data/providers/ingreso_provider.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';

import '../controllers/ingresos_controller.dart';

class IngresosBinding extends Bindings {
  @override
  void dependencies() {
    // Provider
    Get.lazyPut<IngresoProvider>(
      () => IngresoProvider(),
    );

    // Service
    Get.lazyPut<IngresoService>(
      () => IngresoService(
        ingresoProvider: Get.find<IngresoProvider>(),
      ),
    );

    // Controller
    Get.lazyPut<IngresosController>(
      () => IngresosController(
        ingresoService: Get.find<IngresoService>(),
      ),
    );
  }
}

import 'package:get/get.dart';

import '../controllers/inventario_controller.dart';

class InventarioBinding extends Bindings {
  @override
  void dependencies() {
    // Inventario y el formulario de producto lo comparten. `fenix`: si una
    // sale mientras la otra sigue abierta, se vuelve a crear en vez de fallar.
    Get.lazyPut<InventarioController>(
      () => InventarioController(),
      fenix: true,
    );
  }
}

import 'package:get/get.dart';

import '../controllers/permisos_controller.dart';

class PermisosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermisosController>(() => PermisosController());
  }
}

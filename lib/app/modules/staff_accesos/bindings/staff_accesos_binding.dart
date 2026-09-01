import 'package:get/get.dart';

import '../controllers/staff_accesos_controller.dart';

class StaffAccesosBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StaffAccesosController>(() => StaffAccesosController());
  }
}

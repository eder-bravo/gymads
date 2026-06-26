import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

/// Binding for the auth module
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthController>(() => AuthController());
  }
}

import 'package:get/get.dart';

import '../modules/access_logs/bindings/access_logs_binding.dart';
import '../modules/access_logs/views/access_logs_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/register_view.dart';
import '../modules/auth/views/email_confirmation_view.dart';
import '../modules/auth/controllers/register_controller.dart';
import '../modules/checador/bindings/checador_binding.dart';
import '../modules/checador/views/checador_view.dart';
import '../modules/clientes/bindings/clientes_binding.dart';
import '../modules/clientes/views/clientes_view.dart';
import '../modules/configuracion/bindings/configuracion_binding.dart';
import '../modules/configuracion/views/configuracion_view.dart';
import '../modules/configuracion/views/cuenta_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/ingresos/bindings/ingresos_binding.dart';
import '../modules/ingresos/views/ingresos_view.dart';
import '../modules/inventario/bindings/inventario_binding.dart';
import '../modules/inventario/views/inventario_view.dart';
import '../modules/inventario/views/product_form_view.dart';
import '../modules/rfid_checkin/bindings/rfid_checkin_binding.dart';
import '../modules/rfid_checkin/views/rfid_checkin_view.dart';
import '../modules/abonar/bindings/abonar_binding.dart';
import '../modules/abonar/views/abonar_view.dart';
import '../modules/point_of_sale/bindings/point_of_sale_binding.dart';
import '../modules/point_of_sale/views/point_of_sale_view.dart';

import '../modules/auth/views/google_complete_register_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.LOGIN;

  static final routes = [
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.REGISTER,
      page: () => const RegisterView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<RegisterController>(() => RegisterController());
      }),
    ),
    GetPage(
      name: _Paths.GOOGLE_COMPLETE,
      page: () => const GoogleCompleteRegisterView(),
      binding: BindingsBuilder(() {
        // RegisterController should already be created by auth flow
        if (!Get.isRegistered<RegisterController>()) {
          Get.lazyPut<RegisterController>(() => RegisterController());
        }
      }),
    ),
    GetPage(
      name: _Paths.EMAIL_CONFIRMATION,
      page: () => const EmailConfirmationView(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.CHECADOR,
      page: () => const ChecadorView(),
      binding: ChecadorBinding(),
    ),
    GetPage(
      name: _Paths.CLIENTES,
      page: () => const ClientesView(),
      binding: ClientesBinding(),
    ),
    GetPage(
      name: _Paths.INVENTARIO,
      page: () => const InventarioView(),
      binding: InventarioBinding(),
    ),
    GetPage(
      name: _Paths.PRODUCT_FORM,
      page: () => const ProductFormView(),
      binding: InventarioBinding(),
    ),
    GetPage(
      name: _Paths.INGRESOS,
      page: () => const IngresosView(),
      binding: IngresosBinding(),
    ),
    GetPage(
      name: _Paths.RFID_CHECKIN,
      page: () => const RfidCheckinView(),
      binding: RfidCheckinBinding(),
    ),
    GetPage(
      name: _Paths.ABONAR,
      page: () => const AbonarView(),
      binding: AbonarBinding(),
    ),
    GetPage(
      name: _Paths.CONFIGURACION,
      page: () => const ConfiguracionView(),
      binding: ConfiguracionBinding(),
    ),
    GetPage(
      name: _Paths.CUENTA,
      page: () => const CuentaView(),
      binding: ConfiguracionBinding(),
    ),
    GetPage(
      name: _Paths.POINT_OF_SALE,
      page: () => const PointOfSaleView(),
      binding: PointOfSaleBinding(),
    ),
    GetPage(
      name: _Paths.ACCESS_LOGS,
      page: () => const AccessLogsView(),
      binding: AccessLogsBinding(),
    ),
  ];
}

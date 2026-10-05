import 'package:get/get.dart';

import '../controllers/abono_prices_controller.dart';
import '../controllers/configuracion_controller.dart';

class ConfiguracionBinding extends Bindings {
  @override
  void dependencies() {
    // Configuración y sus subpantallas (Cuenta, Precios, Lector…) comparten
    // estos controladores. `fenix`: si GetX los borra porque una de esas
    // pantallas terminó de salir mientras otra sigue abierta, se vuelven a
    // crear al pedirlos en vez de fallar con "not found".
    Get.lazyPut<ConfiguracionController>(
      () => ConfiguracionController(),
      fenix: true,
    );
    Get.lazyPut<AbonoPricesController>(
      () => AbonoPricesController(),
      fenix: true,
    );
  }
}

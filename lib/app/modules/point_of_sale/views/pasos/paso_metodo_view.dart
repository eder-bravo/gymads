import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/metodo_de_pago.dart';

import '../../controllers/point_of_sale_controller.dart';
import 'pantalla_de_paso.dart';
import 'paso_monto_view.dart';

/// Paso 3: solo cómo paga, en fichas grandes. Tocar una pasa al siguiente.
class PasoMetodoView extends GetView<PointOfSaleController> {
  const PasoMetodoView({super.key});

  @override
  Widget build(BuildContext context) {
    return PantallaDePaso(
      paso: 3,
      titulo: '¿Cómo paga?',
      cuerpo: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Obx(() => TotalACobrar(total: dinero(controller.finalAmount))),
          const SizedBox(height: 20),
          Obx(() => SelectorMetodoPago(
                grande: true,
                metodos: controller.paymentMethods,
                elegido: controller.selectedPaymentMethod,
                onElegir: (metodo) {
                  // Volver a tocar el mismo no borra lo ya escrito.
                  if (metodo != controller.selectedPaymentMethod) {
                    controller.setPaymentMethod(metodo);
                  }
                  Get.to<void>(() => const PasoMontoView(),
                      routeName: rutaMonto);
                },
              )),
        ],
      ),
    );
  }
}

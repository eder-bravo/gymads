import '../../../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

import '../../controllers/point_of_sale_controller.dart';
import '../../widgets/cobro.dart';
import '../../widgets/lista_carrito.dart';
import '../../widgets/resumen_totales.dart';
import 'pantalla_de_paso.dart';
import 'paso_metodo_view.dart';

/// Paso 2: la venta a pantalla completa para revisarla y corregir
/// cantidades antes de cobrar. Si se quita todo, regresa a los productos.
class PasoRevisarView extends GetView<PointOfSaleController> {
  const PasoRevisarView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return PantallaDePaso(
      paso: 2,
      titulo: 'Revisa la venta',
      cuerpo: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          AvisoFaltantes(controller: controller),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            decoration: BoxDecoration(
              color: c.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.borde),
            ),
            child: Obx(() => ListaCarrito(
                  items: controller.cartItems.toList(),
                  onCambiarCantidad: (item, cantidad) async {
                    await controller.updateCartItemQuantity(
                        item.productId, cantidad);
                    // Sin productos ya no hay nada que cobrar.
                    if (controller.cartItems.isEmpty && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                )),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.containerBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Obx(() => ResumenTotales(
                  unidades: controller.totalUnidades,
                  subtotal: controller.totalAmount,
                  descuento: controller.discountAmount,
                  total: controller.finalAmount,
                )),
          ),
        ],
      ),
      pie: Obx(() => BotonGuardar(
            texto: 'Ir a cobrar',
            icono: Icons.arrow_forward,
            onPressed: controller.cartItems.isEmpty
                ? null
                : () => Get.to<void>(() => const PasoMetodoView(),
                    routeName: rutaMetodo),
          )),
    );
  }
}

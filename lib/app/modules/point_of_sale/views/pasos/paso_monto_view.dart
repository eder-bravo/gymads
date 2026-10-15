import '../../../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/utils/referencia_de_pago.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

import '../../controllers/point_of_sale_controller.dart';
import '../../widgets/cobro.dart';
import 'pantalla_de_paso.dart';
import 'venta_lista_view.dart';

/// Paso 4: lo que pide el método elegido (con cuánto paga, o el folio) y
/// el botón para cobrar.
class PasoMontoView extends GetView<PointOfSaleController> {
  const PasoMontoView({super.key});

  String get _titulo => switch (controller.selectedPaymentMethod) {
        'efectivo' => '¿Con cuánto paga?',
        'mixto' => 'Confirma el cobro',
        _ => 'Folio del pago',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return PantallaDePaso(
      paso: 4,
      titulo: _titulo,
      cuerpo: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Obx(() => TotalACobrar(
                total: dinero(controller.finalAmount),
                detalle: nombreMetodoDePago(controller.selectedPaymentMethod),
              )),
          const SizedBox(height: 20),
          PagoSegunMetodo(controller: controller, conEtiqueta: false),
          if (controller.selectedPaymentMethod == 'mixto')
            Text(
              'Cobra el total combinando efectivo con tarjeta o '
              'transferencia.',
              style: TextStyle(color: c.textSecondary, fontSize: 15),
            ),
        ],
      ),
      pie: Obx(() {
        final falta = controller.faltaParaCobrar;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (falta != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(falta,
                    style: TextStyle(color: c.textSecondary, fontSize: 15)),
              ),
            BotonGuardar(
              texto: 'Cobrar ${dinero(controller.finalAmount)}',
              guardando: controller.isProcessingPayment,
              onPressed: falta == null ? () => _cobrar(context) : null,
            ),
          ],
        );
      }),
    );
  }

  Future<void> _cobrar(BuildContext context) async {
    final navegador = Navigator.of(context);
    if (!await controller.processSale()) return;
    // Se quitan los pasos: atrás desde "¡Listo!" lleva a los productos, no
    // a cobrar otra vez lo mismo.
    navegador.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const VentaListaView(),
        settings: const RouteSettings(name: rutaLista),
      ),
      (ruta) => !esPasoDeCobro(ruta),
    );
  }
}

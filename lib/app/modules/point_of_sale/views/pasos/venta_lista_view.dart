import '../../../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/centrado_desplazable.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

import '../../../../global_widgets/app_header.dart';
import '../../controllers/point_of_sale_controller.dart';
import '../../widgets/cobro.dart';

/// Después de cobrar en el teléfono: lo cobrado y el cambio en grande, y
/// "Nueva venta" para regresar a los productos.
class VentaListaView extends GetView<PointOfSaleController> {
  const VentaListaView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final venta = controller.ultimaVenta;
    return PopScope(
      onPopInvokedWithResult: (salio, _) {
        if (salio) controller.nuevaVenta();
      },
      child: ScaffoldAdaptable(
        conMenu: false,
        backgroundColor: c.backgroundColor,
        appBar: const GymAppBar(title: 'Venta cobrada'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CentradoDesplazable(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: venta == null
                      ? const SizedBox.shrink()
                      : VentaListaContenido(venta: venta),
                ),
              ),
            ),
            PieDeFormulario(
              child: BotonGuardar(
                texto: 'Nueva venta',
                icono: Icons.add_shopping_cart,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

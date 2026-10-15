import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/centrado_desplazable.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/core/widgets/metodo_de_pago.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/widgets/cabecera_con_lista.dart';
import '../../../core/widgets/escaner_automatico.dart';
import '../../../core/widgets/refrescable.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/point_of_sale_controller.dart';
import '../widgets/cobro.dart';
import '../widgets/ficha_producto.dart';
import '../widgets/lista_carrito.dart';
import '../widgets/resumen_totales.dart';

/// El mostrador de escritorio y tableta, como el autocobro del súper: la
/// venta (el ticket) a la izquierda, a la derecha lo que toca hacer ahora
/// (elegir productos, cómo paga, ¡Listo!) y abajo, a todo lo ancho, las
/// acciones de ese momento.
///
/// Cada acción vive en un solo lugar: los productos de la derecha solo
/// agregan; las cantidades se corrigen en la venta.
class MostradorView extends GetView<PointOfSaleController> {
  const MostradorView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return LayoutBuilder(builder: (context, limites) {
      // La venta ocupa un tercio, entre 300 y 420: de pie, en la tableta,
      // le deja a los productos dos columnas.
      final anchoVenta = (limites.maxWidth * 0.36).clamp(300.0, 420.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: anchoVenta,
                  child: TourStep(
                    tourKey: controller.keyCarrito,
                    title: 'Tu venta',
                    description: 'Lo que llevas, con sus cantidades y el '
                        'total. Abajo cobras.',
                    isLastStep: true,
                    child: const _PanelVenta(),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: c.divisor),
                const Expanded(child: _Escenario()),
              ],
            ),
          ),
          const _BarraDeAcciones(),
        ],
      );
    });
  }
}

/// El ticket: los productos de la venta y, al pie, las cuentas.
class _PanelVenta extends GetView<PointOfSaleController> {
  const _PanelVenta();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ColoredBox(
      color: c.cardBackground,
      child: Obx(() {
        final etapa = controller.etapa;
        final items = controller.cartItems.toList();
        final cobrando = etapa == EtapaVenta.cobro;
        final efectivo = controller.selectedPaymentMethod == 'efectivo';
        final recibido = controller.receivedAmount;
        final encabezado = [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              'Venta actual',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(height: 1, color: c.divisor),
        ];
        final vacia = Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_basket_outlined, size: 48, color: c.textHint),
              const SizedBox(height: 12),
              Text(
                etapa == EtapaVenta.listo
                    ? 'Escanea o elige productos para la siguiente venta'
                    : 'Escanea o elige productos para comenzar',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 15),
              ),
            ],
          ),
        );
        final lista = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListaCarrito(
            items: items,
            // Mientras se cobra no se cambia: se regresa a la venta para
            // corregirla.
            onCambiarCantidad: cobrando
                ? null
                : (item, cantidad) =>
                    controller.updateCartItemQuantity(item.productId, cantidad),
          ),
        );
        final cuentas = items.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: BoxDecoration(
                  color: c.containerBackground,
                  border: Border(top: BorderSide(color: c.divisor)),
                ),
                child: ResumenTotales(
                  unidades: controller.totalUnidades,
                  subtotal: controller.totalAmount,
                  descuento: controller.discountAmount,
                  total: controller.finalAmount,
                  recibido:
                      cobrando && efectivo && recibido > 0 ? recibido : null,
                  cambio: cobrando && efectivo && controller.changeAmount >= 0
                      ? controller.changeAmount
                      : null,
                ),
              );
        return LayoutBuilder(builder: (context, limites) {
          final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
          // Con letra grande en una ventana baja, las cuentas fijas abajo
          // no dejaban lugar a la lista: todo el panel se desplaza junto.
          if (limites.maxHeight < 400 * escala) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...encabezado,
                  if (items.isEmpty) vacia else lista,
                  if (cuentas != null) cuentas,
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...encabezado,
              Expanded(
                child: items.isEmpty
                    ? CentradoDesplazable(child: vacia)
                    : SingleChildScrollView(child: lista),
              ),
              if (cuentas != null) cuentas,
            ],
          );
        });
      }),
    );
  }
}

/// Lo de la derecha: cambia según el momento de la venta. Los productos
/// solo se esconden al cobrar (no se desmontan): el buscador conserva lo
/// escrito al regresar.
class _Escenario extends GetView<PointOfSaleController> {
  const _Escenario();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final etapa = controller.etapa;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: etapa != EtapaVenta.productos,
            child: TickerMode(
              enabled: etapa == EtapaVenta.productos,
              child: const _Productos(),
            ),
          ),
          if (etapa == EtapaVenta.cobro) const _Cobro(),
          if (etapa == EtapaVenta.listo) const _Listo(),
        ],
      );
    });
  }
}

/// El título grande de cada momento, como "Favor de escanear artículo".
class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // Ancho completo: la cabecera de los productos centra lo que no lo es.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        texto,
        style: TextStyle(
          color: c.titleColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Productos extends GetView<PointOfSaleController> {
  const _Productos();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return CabeceraConLista(
      cabecera: [
        const _Titulo('Escanea o elige un producto'),
        if (PlataformaApp.escritorio)
          TourStep(
            tourKey: controller.keyEscanear,
            isFirstStep: true,
            title: 'Escanear productos',
            description:
                'Usa tu lector: cada lectura agrega una unidad a la venta.',
            child: const AvisoEscanerAutomatico(),
          )
        // En la tableta el paso del recorrido es el de la cámara.
        else if (PlataformaApp.lectorDeTeclado)
          const AvisoEscanerAutomatico(soloTrasLeer: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TourStep(
            tourKey: controller.keyBuscar,
            title: 'Buscador',
            description: 'Busca por nombre o código.',
            child: BusquedaConEscaner(
              child: AppSearchField(
                hintText: 'Buscar productos...',
                onChanged: controller.searchProducts,
              ),
            ),
          ),
        ),
      ],
      lista: TourStep(
        tourKey: controller.keyProductos,
        title: 'Tus productos',
        description: PlataformaApp.escritorio
            ? 'Haz clic en un producto para agregarlo. Con clic derecho lo '
                'fijas arriba.'
            : 'Toca un producto para agregarlo. Déjalo presionado para '
                'fijarlo arriba.',
        child: Obx(() {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          final productos = controller.filteredProducts;
          if (productos.isEmpty) {
            return Refrescable.centrado(
              onRefresh: controller.refrescar,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: c.textSecondary),
                  const SizedBox(height: 16),
                  Text('No hay productos disponibles',
                      style: TextStyle(color: c.textSecondary)),
                ],
              ),
            );
          }
          final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
          return Refrescable(
            onRefresh: controller.refrescar,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 196 * escala.clamp(1, double.infinity),
              ),
              itemCount: productos.length,
              itemBuilder: (context, i) => _ficha(productos[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _ficha(product) => Obx(() => FichaProducto(
        producto: product,
        cantidad: controller.cartItems
                .firstWhereOrNull((i) => i.productId == product.id)
                ?.quantity ??
            0,
        fijado: controller.isPinned(product.id),
        onAgregar: () => controller.addProductToCart(product),
        onFijar: () => controller.togglePinned(product),
      ));
}

class _Cobro extends GetView<PointOfSaleController> {
  const _Cobro();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Titulo('¿Cómo paga?'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AvisoFaltantes(controller: controller),
                    Obx(() => SelectorMetodoPago(
                          grande: true,
                          metodos: controller.paymentMethods,
                          elegido: controller.selectedPaymentMethod,
                          onElegir: controller.setPaymentMethod,
                        )),
                    const SizedBox(height: 24),
                    PagoSegunMetodo(controller: controller),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Listo extends GetView<PointOfSaleController> {
  const _Listo();

  @override
  Widget build(BuildContext context) {
    final venta = controller.ultimaVenta;
    if (venta == null) return const SizedBox.shrink();
    return CentradoDesplazable(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: VentaListaContenido(venta: venta),
      ),
    );
  }
}

/// Abajo, a todo lo ancho: lo que se puede hacer en este momento. A la
/// izquierda lo secundario (vaciar, regresar); a la derecha, el botón
/// principal.
class _BarraDeAcciones extends GetView<PointOfSaleController> {
  const _BarraDeAcciones();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.cardBackground,
        border: Border(top: BorderSide(color: c.divisor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Obx(() {
            final etapa = controller.etapa;
            final vacia = controller.cartItems.isEmpty;
            final total = dinero(controller.finalAmount);
            final List<Widget> izquierda;
            final Widget principal;
            switch (etapa) {
              case EtapaVenta.productos:
                izquierda = [
                  TextButton.icon(
                    onPressed: vacia ? null : () => _vaciar(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Vaciar venta'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(0, 46),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ];
                principal = BotonGuardar(
                  texto: vacia ? 'Cobrar' : 'Cobrar $total',
                  icono: Icons.point_of_sale,
                  onPressed: vacia ? null : controller.irACobrar,
                );
              case EtapaVenta.cobro:
                final falta = controller.faltaParaCobrar;
                izquierda = [
                  TextButton.icon(
                    onPressed: controller.isProcessingPayment
                        ? null
                        : controller.regresarALaVenta,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Regresar a la venta'),
                    style: TextButton.styleFrom(
                      foregroundColor: c.textSecondary,
                      minimumSize: const Size(0, 46),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ];
                principal = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (falta != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(falta,
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 15)),
                      ),
                    BotonGuardar(
                      texto: 'Cobrar $total',
                      icono: Icons.check,
                      guardando: controller.isProcessingPayment,
                      onPressed: falta == null ? controller.processSale : null,
                    ),
                  ],
                );
              case EtapaVenta.listo:
                izquierda = const [];
                principal = BotonGuardar(
                  texto: 'Nueva venta',
                  icono: Icons.add_shopping_cart,
                  onPressed: controller.nuevaVenta,
                );
            }
            // En una fila: lo secundario a la izquierda, el botón principal
            // a la derecha. Con letra muy grande no caben: pasa a renglones,
            // todos a la derecha.
            if (MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3) {
              return Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [...izquierda, principal],
              );
            }
            return Row(
              children: [
                for (final accion in izquierda) Flexible(child: accion),
                const Spacer(),
                const SizedBox(width: 12),
                principal,
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _vaciar(BuildContext context) async {
    final unidades = controller.totalUnidades;
    final confirmado = await Get.dialog<bool>(AlertDialog(
      title: const Text('Vaciar venta'),
      content: Text(unidades == 1
          ? '¿Quitar el producto de la venta?'
          : '¿Quitar los $unidades productos de la venta?'),
      actions: [
        BotonCancelar(onPressed: () => Get.back(result: false)),
        BotonGuardar(
          texto: 'Vaciar',
          compacto: true,
          color: AppColors.error,
          onPressed: () => Get.back(result: true),
        ),
      ],
    ));
    if (confirmado == true) controller.clearCart();
  }
}

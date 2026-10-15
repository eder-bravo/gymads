import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/point_of_sale_controller.dart';
import '../../../data/models/product_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/cabecera_con_lista.dart';
import '../../../core/widgets/refrescable.dart';
import '../../../core/widgets/escaner_automatico.dart';
import '../../../core/utils/plataforma_app.dart';
import '../../../global_widgets/app_header.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import '../widgets/ficha_producto.dart';
import 'mostrador_view.dart';
import 'pasos/pantalla_de_paso.dart';
import 'pasos/paso_revisar_view.dart';

/// Vender. En escritorio y tableta, el mostrador de dos paneles
/// ([MostradorView]); en el teléfono, el cobro por pasos, cada uno en su
/// pantalla: productos (esta), revisar la venta, cómo paga, con cuánto y
/// ¡Listo!.
class PointOfSaleView extends GetView<PointOfSaleController> {
  const PointOfSaleView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final pantalla = ScaffoldAdaptable(
      anchoMaximo: 1480,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
        title: 'Punto de Venta',
        actions: [
          if (!PlataformaApp.escritorio)
            TourStep(
              tourKey: controller.keyEscanear,
              isFirstStep: true,
              title: 'Escanear productos',
              description: 'Escanea productos y se agregan solos a la venta.',
              borderRadius: 24,
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: controller.escanearAlCarrito,
                tooltip: 'Escanear productos',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refrescar,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: PlataformaApp.pantallaGrande
            ? const MostradorView()
            : _productosDelTelefono(context),
      ),
    );
    return PlataformaApp.lectorDeTeclado
        ? EscanerAutomatico(
            // Solo mientras se eligen productos (o en "¡Listo!", donde una
            // lectura empieza la venta siguiente); al cobrar, no.
            habilitado: () =>
                !controller.isLoading &&
                !controller.isProcessingPayment &&
                controller.etapa != EtapaVenta.cobro,
            alLeer: controller.agregarPorCodigo,
            codigoRegistrado: (codigo) =>
                controller.productoPorBarcode(codigo) != null,
            child: pantalla,
          )
        : pantalla;
  }

  /// Empieza el cobro: en pantalla grande el mostrador pasa a "¿Cómo
  /// paga?"; en el teléfono se abre el paso 2 (revisar la venta).
  void mostrarCobro(BuildContext context) {
    if (PlataformaApp.pantallaGrande) {
      controller.irACobrar();
      return;
    }
    if (controller.cartItems.isEmpty) return;
    Get.to<void>(() => const PasoRevisarView(), routeName: rutaRevisar);
  }

  /// Paso 1 en el teléfono: buscar y tocar productos. Abajo, fijo, lo que
  /// lleva la venta y "Continuar".
  Widget _productosDelTelefono(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CabeceraConLista(
            cabecera: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TourStep(
                  tourKey: controller.keyBuscar,
                  title: 'Buscador',
                  description: 'Busca por nombre o código.',
                  child: BusquedaConEscaner(
                      child: AppSearchField(
                    hintText: 'Buscar productos...',
                    onChanged: controller.searchProducts,
                  )),
                ),
              ),
            ],
            lista: TourStep(
              tourKey: controller.keyProductos,
              title: 'Tus productos',
              description: 'Toca un producto para agregarlo. Déjalo '
                  'presionado para fijarlo arriba.',
              child: Obx(() {
                if (controller.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }

                final products = controller.filteredProducts;

                if (products.isEmpty) {
                  return Refrescable.centrado(
                    onRefresh: controller.refrescar,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: c.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No hay productos disponibles',
                          style: TextStyle(color: c.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Refrescable(
                  onRefresh: controller.refrescar,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    // Columnas según el ancho disponible (2 en un teléfono
                    // vertical, más de lado) y alto fijo según el contenido.
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 196 *
                          (MediaQuery.textScalerOf(context).scale(14) / 14)
                              .clamp(1, double.infinity),
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) => _ficha(products[index]),
                  ),
                );
              }),
            ),
          ),
        ),
        TourStep(
          tourKey: controller.keyCarrito,
          title: 'Tu venta y cobro',
          description: 'Lo que llevas y el total. Toca "Continuar" para '
              'revisar la venta y cobrar.',
          isLastStep: true,
          child: _barraDeVenta(context),
        ),
      ],
    );
  }

  Widget _ficha(Product product) => Obx(() => FichaProducto(
        producto: product,
        cantidad: controller.cartItems
                .firstWhereOrNull((item) => item.productId == product.id)
                ?.quantity ??
            0,
        fijado: controller.isPinned(product.id),
        onAgregar: () => controller.addProductToCart(product),
        onFijar: () => controller.togglePinned(product),
      ));

  /// Abajo del paso 1: cuántos productos lleva, el total y "Continuar".
  Widget _barraDeVenta(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.cardBackground,
        boxShadow: [
          BoxShadow(
            color: c.sombra,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Obx(() {
            final unidades = controller.totalUnidades;
            final vacia = controller.cartItems.isEmpty;
            final resumen = vacia
                ? Text('Toca o escanea productos para empezar',
                    style: TextStyle(color: c.textSecondary, fontSize: 14))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          '$unidades ${unidades == 1 ? 'producto' : 'productos'}',
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 13)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dinero(controller.finalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
            final continuar = SizedBox(
              height: 48,
              child: BotonGuardar(
                texto: 'Continuar',
                compacto: true,
                icono: Icons.arrow_forward,
                onPressed: vacia ? null : () => mostrarCobro(context),
              ),
            );
            // Con letra muy grande no caben lado a lado: el botón baja, a
            // todo lo ancho.
            if (MediaQuery.textScalerOf(context).scale(14) / 14 > 1.5) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [resumen, const SizedBox(height: 8), continuar],
              );
            }
            return Row(
              children: [
                Expanded(child: resumen),
                const SizedBox(width: 12),
                continuar,
              ],
            );
          }),
        ),
      ),
    );
  }
}

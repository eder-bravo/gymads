import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/point_of_sale_controller.dart';
import '../../../data/models/product_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../core/widgets/cabecera_con_lista.dart';
import '../../../core/widgets/refrescable.dart';
import '../../../core/widgets/escaner_automatico.dart';
import '../../../core/utils/plataforma_app.dart';
import '../../../global_widgets/app_header.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/core/widgets/metodo_de_pago.dart';
import '../widgets/lista_carrito.dart';

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
              description: 'Escanea productos y se agregan solos al carrito.',
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
        child: LayoutBuilder(builder: (context, constraints) {
          final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
          final lateral = PlataformaApp.escritorio &&
              constraints.maxWidth >= 1100 * escala &&
              constraints.maxHeight >= 420;
          return Flex(
            direction: lateral ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CabeceraConLista(
                  cabecera: [
                    if (PlataformaApp.escritorio)
                      TourStep(
                        tourKey: controller.keyEscanear,
                        isFirstStep: true,
                        title: 'Escanear productos',
                        description:
                            'Usa tu lector: cada lectura agrega una unidad al carrito.',
                        child: const AvisoEscanerAutomatico(),
                      ),
                    // Barra de búsqueda
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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

                    // Filtro de categorías
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TourStep(
                        tourKey: controller.keyCategorias,
                        title: 'Categorías',
                        description: 'Filtra los productos por categoría.',
                        child: Obx(() => CategoryFilterChips(
                              categories: controller.activeCategories
                                  .map((c) => CategoryChipData(
                                        id: c.id,
                                        label: c.name,
                                        icon: CategoryIcons.resolve(c.icon),
                                      ))
                                  .toList(),
                              selectedId: controller.selectedCategoryId,
                              onSelected: controller.setSelectedCategory,
                            )),
                      ),
                    ),
                  ],
                  // Grid de productos
                  lista: TourStep(
                    tourKey: controller.keyProductos,
                    title: 'Tus productos',
                    description: PlataformaApp.escritorio
                        ? 'Haz clic en un producto para agregarlo. Con clic derecho lo fijas arriba.'
                        : 'Toca un producto para agregarlo. Déjalo presionado para fijarlo arriba.',
                    child: Obx(() {
                      if (controller.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent),
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
                          // vertical, más de lado o en tablet) y alto fijo según
                          // el contenido. Con una proporción ancho/alto, una
                          // tarjeta ancha y baja no cabía.
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 220 *
                                (MediaQuery.textScalerOf(context).scale(14) /
                                        14)
                                    .clamp(1, double.infinity),
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(context, products[index]);
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Panel inferior fijo del carrito
              SizedBox(
                width: lateral ? 380 : null,
                child: TourStep(
                  tourKey: controller.keyCarrito,
                  title: 'Carrito y cobro',
                  description:
                      'El total de la venta. Aquí eliges cómo te pagan y cobras.',
                  isLastStep: true,
                  child: _buildCartPanel(context, lateral: lateral),
                ),
              ),
            ],
          );
        }),
      ),
    );
    return PlataformaApp.escritorio
        ? EscanerAutomatico(
            habilitado: () =>
                !controller.isLoading && !controller.isProcessingPayment,
            alLeer: controller.agregarPorCodigo,
            codigoRegistrado: (codigo) =>
                controller.productoPorBarcode(codigo) != null,
            child: pantalla,
          )
        : pantalla;
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final c = context.colores;
    return Obx(() {
      final cartItem = controller.cartItems.firstWhereOrNull(
        (item) => item.productId == product.id,
      );
      final quantity = cartItem?.quantity ?? 0;
      final inCart = quantity > 0;
      final pinned = controller.isPinned(product.id);

      // Con mouse, toda la ficha agrega el producto (el botón sigue ahí) y
      // el borde se aviva al pasar por encima.
      return AlPasarMouse(
          builder: (context, encima) => GestureDetector(
                onTap: PlataformaApp.escritorio
                    ? () => controller.addProductToCart(product)
                    : null,
                // Fijar arriba es un atajo de mostrador, por eso va en la pulsación
                // larga: no estorba al toque normal, que es agregar a la venta.
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  controller.togglePinned(product);
                },
                // Con mouse, el clic derecho hace lo mismo.
                onSecondaryTap: () => controller.togglePinned(product),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: inCart
                          ? AppColors.accent
                          : AppColors.accent.withOpacity(encima ? 0.45 : 0.12),
                      width: inCart ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícono de categoría + badge de stock
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.containerBackground,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CategoryIcons.resolve(controller
                                  .categoryById[product.categoryId]?.icon),
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pinned) ...[
                                const Icon(Icons.push_pin,
                                    size: 14, color: AppColors.accent),
                                const SizedBox(width: 6),
                              ],
                              _buildStockBadge(product.stock),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Nombre
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: c.textPrimary,
                        ),
                      ),
                      const Spacer(),

                      // Precio
                      Text(
                        dinero(product.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Control de cantidad
                      _buildQuantityControl(context, product, quantity),
                    ],
                  ),
                ),
              ));
    });
  }

  Widget _buildStockBadge(int stock) {
    // Tres estados: agotado o en negativo (faltante), bajo, y normal.
    final Color color = stock <= 0
        ? AppColors.error
        : (stock <= 5 ? AppColors.warning : AppColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$stock',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildQuantityControl(
      BuildContext context, Product product, int quantity) {
    final c = context.colores;
    if (quantity == 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => controller.addProductToCart(product),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.containerBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => controller.updateCartItemQuantity(
              product.id,
              quantity - 1,
            ),
            icon: const Icon(Icons.remove, size: 18),
            tooltip: PlataformaApp.escritorio ? 'Quitar uno' : null,
            color: c.textSecondary,
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Text(
            '$quantity',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: c.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => controller.addProductToCart(product),
            icon: const Icon(Icons.add, size: 18),
            tooltip: PlataformaApp.escritorio ? 'Agregar otro' : null,
            color: AppColors.accent,
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel(BuildContext context, {bool lateral = false}) {
    final c = context.colores;
    return Obx(() {
      final unidades = controller.totalUnidades;
      final total = controller.finalAmount;
      final isEmpty = controller.cartItems.isEmpty;

      final informacion = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$unidades ${unidades == 1 ? 'producto' : 'productos'}',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 2),
          Text(dinero(total),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: c.textPrimary)),
        ],
      );
      final limpiar = IconButton(
        onPressed: controller.clearCart,
        icon: const Icon(Icons.delete_outline),
        color: c.textSecondary,
        tooltip: 'Vaciar carrito',
      );
      final cobrar = ElevatedButton(
        onPressed: () => _showPaymentDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Cobrar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );
      final resumen = isEmpty
          ? Center(
              child: Text('Selecciona productos para cobrar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 13)))
          : LayoutBuilder(builder: (context, constraints) {
              final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
              if (PlataformaApp.escritorio &&
                  constraints.maxWidth < 560 * escala) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [Expanded(child: informacion), limpiar]),
                      const SizedBox(height: 8),
                      cobrar,
                    ]);
              }
              return Row(children: [
                if (!lateral) ...[
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.shopping_bag_outlined,
                          color: AppColors.accent)),
                  const SizedBox(width: 12),
                ],
                Expanded(child: informacion),
                limpiar,
                const SizedBox(width: 4),
                cobrar,
              ]);
            });
      return Container(
        padding:
            EdgeInsets.symmetric(horizontal: 16, vertical: isEmpty ? 14 : 16),
        decoration: BoxDecoration(
          color: c.cardBackground,
          border: lateral ? Border(left: BorderSide(color: c.divisor)) : null,
          boxShadow: lateral
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: SafeArea(
          top: false,
          child: lateral
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Venta actual',
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Divider(color: c.divisor),
                    Expanded(
                      child: isEmpty
                          ? Center(
                              child: Text(
                                  'Escanea o selecciona productos para comenzar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: c.textSecondary)))
                          : SingleChildScrollView(
                              child: ListaCarrito(
                                items: controller.cartItems.toList(),
                                onCambiarCantidad: (item, cantidad) =>
                                    controller.updateCartItemQuantity(
                                        item.productId, cantidad),
                              ),
                            ),
                    ),
                    Divider(color: c.divisor),
                    const SizedBox(height: 8),
                    resumen,
                  ],
                )
              : resumen,
        ),
      );
    });
  }

  /// Campos de la hoja de cobro: más claros que el fondo y con borde, para
  /// que se vean aunque la pantalla tenga poco brillo. El relleno de antes
  /// (14,14,14) era casi igual al de la hoja (18,18,18).
  /// El relleno, el borde y el foco naranja vienen del tema, como en todos
  /// los formularios.
  InputDecoration _decoracionCampoCobro({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final c = context.colores;
    // En escritorio, ventana centrada junto al carrito lateral.
    mostrarHojaAdaptable(
      context,
      isScrollControlled: true,
      // Sin esto, de lado la hoja llega hasta debajo de la barra de estado.
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      anchoMaximo: 520,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // Desplazable: de lado, o con el teclado abierto para la referencia,
        // el resumen y los métodos de pago no caben.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              if (!PlataformaApp.escritorio) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Título
              Text(
                'Cobrar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Aviso de faltantes: el cobro sigue adelante, pero el stock de
              // estos productos quedará en negativo.
              Obx(() {
                final sinExistencias = controller.itemsSinExistencias;
                if (sinExistencias.isEmpty) return const SizedBox.shrink();
                final cuantos = sinExistencias.length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cuantos == 1
                              ? '${sinExistencias.first.productName} quedará como faltante'
                              : '$cuantos productos quedarán como faltantes',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Lo que se está cobrando, para revisarlo antes de cobrar.
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                decoration: BoxDecoration(
                  color: c.containerBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Obx(() => Column(
                      children: [
                        ListaCarrito(
                          items: controller.cartItems.toList(),
                          onCambiarCantidad: (item, cantidad) async {
                            await controller.updateCartItemQuantity(
                                item.productId, cantidad);
                            // Sin productos ya no hay nada que cobrar.
                            if (controller.cartItems.isEmpty &&
                                context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        if (controller.discountAmount > 0) ...[
                          const SizedBox(height: 8),
                          _buildSummaryRow(context, 'Descuento',
                              '-${dinero(controller.discountAmount)}'),
                        ],
                        const Divider(height: 24),
                        _buildSummaryRow(
                          context,
                          'TOTAL',
                          dinero(controller.finalAmount),
                          isBold: true,
                        ),
                      ],
                    )),
              ),
              const SizedBox(height: 20),

              // Método de pago
              Text(
                'Método de pago',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              _buildPaymentMethodChips(context),
              const SizedBox(height: 16),

              // Campo monto recibido (solo efectivo)
              Obx(() {
                if (controller.selectedPaymentMethod == 'efectivo') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monto recibido',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        style: TextStyle(color: c.textPrimary, fontSize: 18),
                        decoration: _decoracionCampoCobro(
                          hintText: 'Cuánto te entregó',
                        ).copyWith(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(
                              color: AppColors.accent, fontSize: 18),
                        ),
                        onChanged: (value) {
                          final amount = double.tryParse(value) ?? 0.0;
                          controller.setReceivedAmount(amount);
                        },
                      ),
                      if (controller.changeAmount > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Cambio: ${dinero(controller.changeAmount)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              // Folio / referencia (tarjeta y transferencia): escrita o
              // escaneada del comprobante.
              Obx(() => controller.usaReferenciaPago
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: CampoReferenciaPago(controlador: controller),
                    )
                  : const SizedBox.shrink()),

              // En escritorio, "Cancelar" y "Cobrar venta" lado a lado y a
              // la derecha, como en cualquier ventana.
              if (PlataformaApp.escritorio)
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    BotonCancelar(onPressed: () => Navigator.pop(context)),
                    Obx(() => BotonGuardar(
                          texto: 'Cobrar venta',
                          guardando: controller.isProcessingPayment,
                          onPressed: controller.canProcessSale()
                              ? () => _processSale(context)
                              : null,
                        )),
                  ],
                )
              else ...[
                // Botón procesar
                Obx(() => BotonGuardar(
                      texto: 'Cobrar venta',
                      guardando: controller.isProcessingPayment,
                      onPressed: controller.canProcessSale()
                          ? () => _processSale(context)
                          : null,
                    )),
                const SizedBox(height: 12),

                // Botón cancelar
                BotonCancelar(onPressed: () => Navigator.pop(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChips(BuildContext context) {
    return Obx(() => SelectorMetodoPago(
          metodos: controller.paymentMethods,
          elegido: controller.selectedPaymentMethod,
          onElegir: controller.setPaymentMethod,
        ));
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value,
      {bool isBold = false}) {
    final c = context.colores;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? c.textPrimary : c.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.accent : c.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  void _processSale(BuildContext context) async {
    final navigator = Navigator.of(context);
    final success = await controller.processSale();
    if (success) {
      navigator.pop(); // Cerrar modal
      SnackbarHelper.success('Éxito', 'Venta procesada correctamente');
    }
  }
}

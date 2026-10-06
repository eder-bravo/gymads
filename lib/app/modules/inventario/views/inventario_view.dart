import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/routes/app_pages.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/app/core/utils/category_icons.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/widgets/cabecera_con_lista.dart';
import '../../../core/widgets/refrescable.dart';
import '../../../core/widgets/escaner_automatico.dart';
import '../../../core/utils/plataforma_app.dart';
import '../controllers/inventario_controller.dart';
import 'product_form_view.dart';
import 'stock_adjust_dialog.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

class InventarioView extends GetView<InventarioController> {
  const InventarioView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final pantalla = ScaffoldAdaptable(
      anchoMaximo: 1200,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
        title: 'Inventario',
        actions: [
          // Va bajo `ajustarStock` y no `gestionarProductos`: mover existencias
          // también lo hace el staff de sucursal, que no puede dar de alta
          // productos ni tocar precios. El almacén sí puede (tiene ambos).
          if (!PlataformaApp.escritorio &&
              controller.can(Permission.ajustarStock))
            TourStep(
              tourKey: controller.keyEscanear,
              isFirstStep:
                  controller.esPrimerPasoDelTour(controller.keyEscanear),
              title: 'Escanear código',
              // Con un código que ya existe ajusta su stock; con uno nuevo
              // ofrece darlo de alta, pero eso solo quien puede agregar
              // productos: a los demás no se les promete.
              description: controller.can(Permission.gestionarProductos)
                  ? 'Escanea un producto para ajustar su stock o darlo de alta.'
                  : 'Escanea un producto para ajustar su stock.',
              borderRadius: 24,
              child: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear código',
                onPressed: () => _escanearParaAjustar(context),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshAll(),
            tooltip: PlataformaApp.escritorio ? 'Actualizar' : null,
          ),
          // Las categorías las ordena quien gestiona el inventario.
          if (controller.can(Permission.gestionarCategorias))
            TourStep(
              tourKey: controller.keyCategorias,
              isFirstStep:
                  controller.esPrimerPasoDelTour(controller.keyCategorias),
              title: 'Categorías',
              description: 'Agrupa tus productos por categoría.',
              borderRadius: 24,
              child: AccionDeBarra(
                texto: 'Categorías',
                icono: Icons.category_outlined,
                secundaria: true,
                onPressed: () async {
                  await Get.toNamed(Routes.CATEGORIAS);
                  controller.loadCategories();
                },
                movil: IconButton(
                  icon: const Icon(Icons.category_outlined),
                  tooltip: 'Categorías',
                  onPressed: () async {
                    await Get.toNamed(Routes.CATEGORIAS);
                    // Al volver pueden haber cambiado nombres, iconos u orden.
                    controller.loadCategories();
                  },
                ),
              ),
            ),
          // Dar de alta un producto fija su precio: es de quien gestiona el
          // inventario, no de quien solo mueve existencias.
          if (controller.can(Permission.gestionarProductos))
            TourStep(
              tourKey: controller.keyAgregar,
              title: 'Agregar producto',
              description: 'Agrega un producto con su precio y stock.',
              borderRadius: 24,
              isFirstStep:
                  controller.esPrimerPasoDelTour(controller.keyAgregar),
              child: AccionDeBarra(
                texto: 'Nuevo producto',
                icono: Icons.add,
                onPressed: () {
                  controller.resetForm();
                  abrirFormularioProducto();
                },
                movil: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    controller.resetForm();
                    abrirFormularioProducto();
                  },
                  tooltip: 'Agregar producto',
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: CabeceraConLista(
          cabecera: [
            if (PlataformaApp.escritorio &&
                controller.can(Permission.ajustarStock))
              TourStep(
                tourKey: controller.keyEscanear,
                isFirstStep:
                    controller.esPrimerPasoDelTour(controller.keyEscanear),
                title: 'Escanear código',
                description:
                    'Usa tu lector para abrir el ajuste de stock del producto.',
                child: const AvisoEscanerAutomatico(),
              )
            // En la tableta el paso del recorrido es el de la cámara.
            else if (PlataformaApp.lectorDeTeclado &&
                controller.can(Permission.ajustarStock))
              const AvisoEscanerAutomatico(soloTrasLeer: true),
            _buildStatsSection(context),
            _buildFaltantesBanner(context),
            TourStep(
              tourKey: controller.keyBuscar,
              title: 'Buscador',
              description: 'Localiza cualquier producto escribiendo su nombre.',
              isFirstStep: controller.esPrimerPasoDelTour(controller.keyBuscar),
              child: _buildSearchBar(),
            ),
            _buildCategoryFilter(),
          ],
          lista: TourStep(
            tourKey: controller.keyLista,
            title: 'Tus productos',
            description: PlataformaApp.escritorio
                ? 'Haz clic en un producto para editarlo, o en "Stock" para ajustar sus existencias.'
                : PlataformaApp.tableta
                    ? 'Toca un producto para editarlo, o "Stock" para ajustar sus existencias.'
                    : 'Toca un producto para editarlo o ajustar su stock.',
            isLastStep: controller.esUltimoPasoDelTour(controller.keyLista),
            child: _buildProductList(context),
          ),
        ),
      ),
    );
    return PlataformaApp.lectorDeTeclado
        ? EscanerAutomatico(
            habilitado: () =>
                controller.can(Permission.ajustarStock) &&
                !controller.isLoading.value,
            alLeer: (codigo) => _procesarCodigo(context, codigo),
            codigoRegistrado: (codigo) =>
                controller.productoPorBarcode(codigo) != null,
            child: pantalla,
          )
        : pantalla;
  }

  /// Escanea un código y abre el ajuste de stock de ese producto.
  ///
  /// El diálogo de ajuste ya recibe el producto resuelto, así que escanear
  /// solo sustituye al paso de buscarlo a mano en la lista.
  Future<void> _escanearParaAjustar(BuildContext context) async {
    final codigo = await controller.escanearCodigo(
      instruccion: 'Apunta al código del producto para ajustar su stock',
    );
    if (codigo == null || !context.mounted) return; // canceló
    await _procesarCodigo(context, codigo);
  }

  /// El móvil y el lector automático de escritorio usan el mismo flujo.
  Future<String?> _procesarCodigo(BuildContext context, String codigo) async {
    if (!controller.can(Permission.ajustarStock)) return null;
    final c = context.colores;

    final producto = controller.productoPorBarcode(codigo);

    if (producto != null) {
      final stock = await showStockAdjustDialog(producto);
      return stock == null
          ? 'Ajuste cancelado: ${producto.name}'
          : '${producto.name}: stock $stock';
    }

    // Código no registrado. Es lo normal la primera vez que se escanea cada
    // producto, así que en vez de un error se ofrece el siguiente paso útil:
    // darlo de alta con el código ya puesto.
    //
    // El botón de escanear va bajo `ajustarStock`, así que quien llega aquí
    // puede no tener permiso para crear productos. A esa persona solo se le
    // explica a quién pedírselo.
    final puedeAgregar = controller.can(Permission.gestionarProductos);

    final agregar = await Get.dialog<bool>(
      AlertDialog(
        scrollable: true,
        backgroundColor: c.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Código no registrado',
            style: TextStyle(color: c.textPrimary)),
        content: Text(
          puedeAgregar
              ? 'Ningún producto tiene este código. ¿Lo agregas como nuevo?\n\nSi ya existe, edítalo y escanea ahí el código.'
              : 'Ningún producto tiene este código. Pide a un encargado que lo agregue.',
          style: TextStyle(color: c.textSecondary, height: 1.35),
        ),
        actions: puedeAgregar
            ? [
                BotonCancelar(onPressed: () => Get.back(result: false)),
                BotonGuardar(
                  texto: 'Agregar producto',
                  compacto: true,
                  onPressed: () => Get.back(result: true),
                ),
              ]
            : [
                BotonGuardar(
                  texto: 'Entendido',
                  compacto: true,
                  onPressed: () => Get.back(result: false),
                ),
              ],
      ),
    );

    if (agregar != true || !context.mounted) return 'Código no registrado';

    controller.resetForm();
    abrirFormularioProducto({'barcode': codigo});
    return 'Código no registrado';
  }

  Widget _buildStatsSection(BuildContext context) {
    final c = context.colores;
    return Obx(() {
      if (controller.inventoryStats.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.all(16),
        child: ResumenAdaptable(
          children: [
            _buildStatItem(
                context,
                PlataformaApp.elegir(
                    escritorio: 'Productos', movil: 'Total Productos'),
                '${controller.inventoryStats['totalProducts'] ?? 0}'),
            _buildStatItem(
                context,
                PlataformaApp.elegir(
                    escritorio: 'Unidades en stock', movil: 'Stock Total'),
                '${controller.inventoryStats['totalStock'] ?? 0}'),
            _buildStatItem(
                context,
                PlataformaApp.elegir(
                    escritorio: 'Valor del inventario', movil: 'Valor Total'),
                dinero(controller.inventoryStats['totalValue'] ?? 0.0)),
          ],
        ),
      );
    });
  }

  /// Resumen de lo vendido sin existencias. Solo aparece si hay faltantes,
  /// para no robar espacio cuando el inventario está sano.
  Widget _buildFaltantesBanner(BuildContext context) {
    final c = context.colores;
    return Obx(() {
      if (!controller.hayFaltantes) return const SizedBox.shrink();

      final productos = controller.productosConFaltante.length;
      final unidades = controller.unidadesFaltantes;
      final valor = controller.valorFaltante;

      final filtrando = controller.soloFaltantes.value;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Deja en la lista solo lo que hay que reponer.
          onTap: controller.toggleSoloFaltantes,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(filtrando ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.error.withOpacity(filtrando ? 0.7 : 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vendidos sin existencias',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$productos ${productos == 1 ? 'producto' : 'productos'} · '
                        '$unidades ${unidades == 1 ? 'unidad' : 'unidades'} · '
                        '${dinero(valor)}',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        filtrando
                            ? PlataformaApp.escritorio
                                ? 'Haz clic para ver todos los productos'
                                : 'Toca para ver todos los productos'
                            : 'Se descontarán solas al reponer stock',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: legible(12),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  filtrando ? Icons.filter_alt : Icons.chevron_right,
                  color: AppColors.error,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final c = context.colores;
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: legible(12),
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BusquedaConEscaner(
          child: AppSearchField(
        hintText: 'Buscar productos...',
        onChanged: controller.setSearchQuery,
      )),
    );
  }

  Widget _buildCategoryFilter() {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.all(16),
        child: CategoryFilterChips(
          categories: controller.activeCategories
              .map((c) => CategoryChipData(
                    id: c.id,
                    label: c.name,
                    icon: CategoryIcons.resolve(c.icon),
                  ))
              .toList(),
          selectedId: controller.selectedCategoryId.value,
          onSelected: controller.setSelectedCategory,
        ),
      );
    });
  }

  Widget _buildProductList(BuildContext context) {
    final c = context.colores;
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
          ),
        );
      }

      // Inventario realmente vacío.
      if (controller.products.isEmpty) {
        return Refrescable.centrado(
          onRefresh: controller.refreshAll,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: 64, color: c.textSecondary),
              const SizedBox(height: 16),
              Text(
                'No hay productos registrados',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              if (controller.can(Permission.gestionarProductos))
                ElevatedButton.icon(
                  onPressed: () {
                    controller.resetForm();
                    abrirFormularioProducto();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar primer producto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: c.textPrimary,
                  ),
                ),
            ],
          ),
        );
      }

      // Hay productos, pero ninguno pasa el filtro. Antes esto no se
      // comprobaba y quedaba un hueco en blanco sin ningún mensaje.
      if (controller.filteredProducts.isEmpty) {
        final hayFiltroDeCategoria =
            controller.selectedCategoryId.value != null;
        return Refrescable.centrado(
          onRefresh: controller.refreshAll,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off,
                    size: 56, color: c.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  hayFiltroDeCategoria
                      ? 'No hay productos en esta categoría'
                      : 'Ningún producto coincide con la búsqueda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 16,
                  ),
                ),
                if (hayFiltroDeCategoria) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => controller.setSelectedCategory(null),
                    icon: const Icon(Icons.clear, color: AppColors.accent),
                    label: const Text('Ver todas',
                        style: TextStyle(color: AppColors.accent)),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return Refrescable(
        onRefresh: controller.refreshAll,
        child: ListaAdaptable(
          itemCount: controller.filteredProducts.length,
          itemBuilder: (context, index) {
            final product = controller.filteredProducts[index];
            return _buildProductCard(context, product);
          },
        ),
      );
    });
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final c = context.colores;
    if (PlataformaApp.pantallaGrande) return _fichaEscritorio(context, product);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: c.cardBackground,
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withOpacity(0.2),
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : 'P',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // El precio va en la línea del nombre, no junto al stock: abajo
        // comparte fila con los botones de ajuste y no cabían los tres.
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dinero(product.price),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.description,
              style: TextStyle(color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        product.stock > 0 ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    // En negativo el número suelto no dice nada: son unidades
                    // que ya se vendieron y hay que reponer.
                    product.stock < 0
                        ? 'Faltan ${-product.stock}'
                        : 'Stock: ${product.stock}',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Ajuste de una unidad, pegado al stock que modifica.
                _buildStockStepper(product),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: c.textSecondary),
          color: c.cardBackground,
          onSelected: (value) {
            if (value == 'edit') {
              controller.editProduct(product);
              abrirFormularioProducto({'isEditing': true});
            } else if (value == 'stock') {
              showStockAdjustDialog(product);
            } else if (value == 'deactivate') {
              controller.deactivateProduct(product.id);
            } else if (value == 'delete') {
              controller.deleteProduct(product.id);
            }
          },
          itemBuilder: (BuildContext context) => [
            // "Editar" abre el formulario con el precio. El staff no lo ve:
            // solo ajusta existencias.
            if (controller.can(Permission.gestionarProductos))
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Text('Editar', style: TextStyle(color: c.textPrimary)),
                  ],
                ),
              ),
            if (controller.can(Permission.ajustarStock))
              PopupMenuItem<String>(
                value: 'stock',
                child: Row(
                  children: [
                    const Icon(Icons.sync_alt, color: AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Text('Ajustar stock',
                        style: TextStyle(color: c.textPrimary)),
                  ],
                ),
              ),
            // Desactivar exige no tener existencias; ofrecerlo con stock solo
            // llevaba al aviso de que no se puede.
            if (product.stock <= 0 &&
                controller.can(Permission.gestionarProductos))
              PopupMenuItem<String>(
                value: 'deactivate',
                child: Row(
                  children: [
                    const Icon(Icons.visibility_off,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Text('Desactivar', style: TextStyle(color: c.textPrimary)),
                  ],
                ),
              ),
            // Siempre mostrar "Eliminar permanentemente"
            if (controller.can(Permission.gestionarProductos))
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Text('Eliminar permanentemente',
                        style: TextStyle(color: c.textPrimary)),
                  ],
                ),
              ),
          ],
        ),
        // Sin onTap: la ficha con todos los datos se quitó. Lo que se hace
        // con un producto está en el menú y en los botones de +/-.
      ),
    );
  }

  void _editar(Product product) {
    controller.editProduct(product);
    abrirFormularioProducto({'isEditing': true});
  }

  /// La ficha de escritorio: clic en ella para editar, y las acciones con
  /// texto a la vista ("Editar", "Stock"); lo que se usa poco, en "Más".
  Widget _fichaEscritorio(BuildContext context, Product product) {
    final c = context.colores;
    final puedeEditar = controller.can(Permission.gestionarProductos);
    final puedeAjustar = controller.can(Permission.ajustarStock);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: c.cardBackground,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: puedeEditar
            ? () => _editar(product)
            : puedeAjustar
                ? () => showStockAdjustDialog(product)
                : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.accent.withOpacity(0.2),
                    child: Text(
                      product.name.isNotEmpty
                          ? product.name[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                          color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: c.textPrimary)),
                        if (product.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(product.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 14)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dinero(product.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      fontSize: 18,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (product.stock > 0
                                ? AppColors.success
                                : AppColors.error)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.stock < 0
                            ? 'Faltan ${-product.stock}'
                            : 'Stock: ${product.stock}',
                        style: TextStyle(
                          color: product.stock > 0
                              ? AppColors.success
                              : AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStockStepper(product),
                  ]),
                  AccionesDeFila(
                    visibles: [
                      if (puedeEditar)
                        AccionDeFila(
                            texto: 'Editar',
                            icono: Icons.edit_outlined,
                            onPressed: () => _editar(product)),
                      if (puedeAjustar)
                        AccionDeFila(
                            texto: 'Stock',
                            icono: Icons.sync_alt,
                            onPressed: () => showStockAdjustDialog(product)),
                    ],
                    mas: [
                      if (product.stock <= 0 && puedeEditar)
                        AccionDeFila(
                            texto: 'Desactivar',
                            icono: Icons.visibility_off_outlined,
                            onPressed: () =>
                                controller.deactivateProduct(product.id)),
                      if (puedeEditar)
                        AccionDeFila(
                            texto: 'Eliminar',
                            icono: Icons.delete_outline,
                            peligrosa: true,
                            onPressed: () =>
                                controller.deleteProduct(product.id)),
                    ],
                    movil: const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botones de una unidad para corregir el stock sin abrir nada.
  Widget _buildStockStepper(Product product) {
    if (!controller.can(Permission.ajustarStock)) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(
          Icons.remove,
          AppColors.warning,
          'Quitar una unidad',
          () => controller.ajustarStock(product, -1, nota: 'Ajuste rápido'),
        ),
        _stepperButton(
          Icons.add,
          AppColors.success,
          'Agregar una unidad',
          () => controller.ajustarStock(product, 1, nota: 'Ajuste rápido'),
        ),
      ],
    );
  }

  Widget _stepperButton(
      IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

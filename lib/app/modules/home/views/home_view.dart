import 'dart:math' as math;

import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/plataforma_app.dart';
import '../../../core/widgets/menu_lateral.dart';
import '../../../core/widgets/tour_step.dart';

import '../../../data/services/pantalla_clientes.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../routes/app_pages.dart';
import '../../abonar/controllers/abonar_controller.dart';
import '../../abonar/views/cobrar_visita_view.dart';
import '../../abonar/vigencia.dart';
import '../../ingresos/widgets/detalle_ingreso_sheet.dart';
import '../controllers/home_controller.dart';
import '../controllers/resumen_del_dia.dart';
import '../widgets/background_welcome_dialog.dart';
import '../widgets/fondo_estirable.dart';

part 'inicio_tableta.dart';
part 'panel_del_dia.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  /// Se redibuja cuando cambia el perfil: si el dueño le cambia el rol a
  /// quien usa la app, el menú (y el tour de Inicio) pasan a ser los del rol
  /// nuevo sin cerrar sesión.
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      TenantContextService.to.staffProfileRx.value;
      return _pantalla(context);
    });
  }

  /// Ancho de la columna de opciones en escritorio.
  static const double _anchoContenido = 1200;

  Widget _pantalla(BuildContext context) {
    final c = context.colores;
    // `sizeOf` y no `of`: este último crea dependencia con el MediaQueryData
    // entero —`viewInsets` incluido—, así que la animación del teclado
    // reconstruía esta pantalla en cada frame aunque estuviera oculta debajo.
    final bool isTablet = !PlataformaApp.escritorio &&
        MediaQuery.sizeOf(context).shortestSide >= 600;

    // Asistente inicial / tour de bienvenida. Va aquí además de en onReady
    // porque al volver del asistente GetX puede reutilizar el controlador; la
    // comprobación es idempotente y barata una vez resuelta.
    //
    // Solo con Inicio en primer plano: esta vista sigue montada bajo las
    // pantallas que se apilan encima, y desde ahí no le toca decidir nada.
    if (Get.currentRoute == Routes.HOME) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.checkOnboarding();
      });
    }

    Widget opciones() => ContenidoEscritorio(
          anchoMaximo: _anchoContenido,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Módulos principales ───
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 20),
                child: Text(
                  'Selecciona una opción',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildMainModules(context, isTablet),

              SizedBox(height: PlataformaApp.escritorio ? 28 : 16),

              // ─── Más opciones ───
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 28 : 20),
                child: Text(
                  'Más opciones',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context, isTablet),

              const SizedBox(height: 14),
            ],
          ),
        );

    // En escritorio, la barra lateral y el panel del día. En tableta y
    // teléfono la cabecera llena la pantalla y las opciones van debajo (en
    // tableta, en una columna de 1200 como mucho).
    final Widget pantalla = _usaPanel(context)
        ? _escritorio(context)
        : ScaffoldAdaptable(
            anchoMaximo: double.infinity,
            backgroundColor: c.backgroundColor,
            extendBodyBehindAppBar: true,
            // En tableta esta barra transparente quedaba encima de la cabecera: se
            // tragaba el toque en Configuración.
            appBar: _usaBento(context)
                ? null
                : AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    // Los íconos de la barra de estado los pone el tema según el modo.
                  ),
            body: SafeArea(
              top: false,
              child: _usaBento(context)
                  // En tableta la cabecera va arriba y los números de hoy y la
                  // rejilla de módulos llenan el alto que queda.
                  ? CustomScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        SliverToBoxAdapter(
                            child: _buildHeader(context, isTablet)),
                        // El alto que queda bajo la cabecera, fijo aunque se
                        // desplace o rebote. Con poca altura o texto grande, la
                        // rejilla conserva un mínimo y se desplaza.
                        SliverLayoutBuilder(
                          builder: (context, limites) {
                            final escala =
                                MediaQuery.textScalerOf(context).scale(14) / 14;
                            final alto = (limites.viewportMainAxisExtent -
                                    limites.precedingScrollExtent -
                                    48)
                                .clamp(440.0 * escala, double.infinity);
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: SizedBox(
                                  height: alto,
                                  child: ContenidoEscritorio(
                                    anchoMaximo: _anchoContenido,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      child: _inicioTableta(context),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── Header con gradiente ───
                          _buildHeader(context, isTablet),

                          const SizedBox(height: 8),

                          opciones(),
                        ],
                      ),
                    ),
            ),
            // Diálogo de bienvenida RFID en segundo plano
          );

    // El aviso del lector (bienvenida, salida, tarjeta no registrada) va
    // ENCIMA de toda la pantalla. Antes iba en el hueco del botón flotante:
    // el Scaffold lo acomodaba como un botón, con margen abajo, y la pantalla
    // negra quedaba subida, con la X escondida bajo la barra de estado.
    return Stack(
      children: [
        pantalla,
        const Positioned.fill(child: BackgroundWelcomeDialog()),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isTablet) {
    final c = context.colores;
    final topPadding = MediaQuery.of(context).padding.top;
    // En tableta el texto se alinea con la columna de opciones.
    final margen = _usaBento(context)
        ? ((MediaQuery.sizeOf(context).width - _anchoContenido) / 2)
            .clamp(0.0, double.infinity)
        : 0.0;
    return TourStep(
      tourKey: controller.keyHeader,
      title: '¡Te damos la bienvenida!',
      description:
          'Este es tu panel principal: desde aquí llegas a todo lo del día a día.',
      borderRadius: 28,
      isFirstStep: true,
      // El fondo crece hacia arriba lo que se jala la pantalla (el rebote):
      // antes la cabecera bajaba entera y dejaba una franja vacía arriba.
      child: FondoEstirable(
        // Lo que se ve arriba al jalar: el borde de arriba del degradado.
        colorArriba: LinearGradient(
          stops: const [0.0, 0.55, 1.0],
          colors: [
            c.cabeceraDesde,
            c.cabeceraHasta,
            AppColors.brand.withOpacity(0.28),
          ],
        ),
        decoracion: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              c.cabeceraDesde,
              c.cabeceraHasta,
              AppColors.brand.withOpacity(0.28),
            ],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            (isTablet ? 32 : 24) + margen,
            topPadding + (isTablet ? 18 : 14),
            (isTablet ? 32 : 24) + margen,
            isTablet ? 16 : 14,
          ),
          child: _usaBento(context)
              ? _cabeceraTableta(context)
              : Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.dashboard_rounded,
                        color: AppColors.brand,
                        size: isTablet ? 26 : 22,
                      ),
                    ),
                    Text(
                      'Inicio',
                      style: TextStyle(
                        fontSize: isTablet ? 26 : 22,
                        fontWeight: FontWeight.w800,
                        color: c.contraste,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// La cabecera de tableta: el título, la fecha de hoy y Configuración
  /// (que en la rejilla no ocupa una tarjeta).
  Widget _cabeceraTableta(BuildContext context) {
    final c = context.colores;
    final hoy = fechaLarga(DateTime.now(), conDia: true);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.brand.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.dashboard_rounded,
              color: AppColors.brand, size: 22),
        ),
        const SizedBox(width: 14),
        // Con texto muy grande en una tableta de pie, el título se corta en
        // vez de salirse de la cabecera. Un ancho máximo y no Flexible: así la
        // fecha y Configuración siguen pegadas a la esquina derecha.
        ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.3),
          child: Text(
            'Inicio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: c.contraste,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // La fecha ocupa el espacio libre, pegada a Configuración: las dos
        // quedan al borde derecho de la rejilla.
        Expanded(
          child: Text(
            hoy[0].toUpperCase() + hoy.substring(1),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.contraste.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Hasta la mitad del ancho, al borde derecho; con texto muy grande se
        // encoge en vez de salirse de la cabecera.
        ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TourStep(
              tourKey: controller.keyConfiguracion,
              title: 'Configuración',
              description: 'Tu cuenta, precios, categorías, lector y permisos.',
              borderRadius: 14,
              isLastStep: true,
              // Con su nombre: un engrane solo no se entiende a la primera.
              child: TextButton.icon(
                onPressed: controller.goToConfiguracion,
                icon: const Icon(Icons.settings_outlined, size: 22),
                label: const Text('Configuración'),
                style: TextButton.styleFrom(
                  foregroundColor: c.contraste,
                  backgroundColor: c.contraste.withOpacity(0.08),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  ResumenDelDia _resumen() => Get.isRegistered<ResumenDelDia>()
      ? Get.find<ResumenDelDia>()
      : Get.put(ResumenDelDia());

  /// Pide lo de hoy que este rol puede ver.
  void _recargar(ResumenDelDia resumen) => resumen.cargar(
        ingresos: controller.can(Permission.verIngresos),
        entradas: controller.can(Permission.verAccesos),
        vencen: controller.can(Permission.gestionarClientes),
        precio: controller.can(Permission.cobrarAbonos),
      );

  /// Los números de hoy: cobrado, entradas y membresías por vencer. Cada uno
  /// abre su pantalla. En tableta son pasos del recorrido; en escritorio esos
  /// pasos están en la barra lateral.
  List<_DatoDeHoy> _datosDeHoy(BuildContext context, ResumenDelDia resumen,
      {required bool conPasos}) {
    final c = context.colores;
    return [
      if (controller.can(Permission.verIngresos))
        _DatoDeHoy(
          label: 'Ingresos',
          detalle: 'Cobrado hoy',
          icon: Icons.receipt_long_outlined,
          color: c.titleColor,
          valor: () {
            final v = resumen.ingresos.value;
            return v == null ? null : pesos(v);
          },
          onTap: controller.goToPaymentRegistration,
          showcaseKey: conPasos ? controller.keyIngresos : null,
          tourDescription:
              'Lo cobrado hoy. Toca para ver todos los pagos y ventas.',
        ),
      if (controller.can(Permission.verAccesos))
        _DatoDeHoy(
          label: 'Entradas',
          detalle: 'Hoy',
          icon: Icons.door_sliding_outlined,
          color: const Color(0xFF81C784),
          valor: () => resumen.entradas.value?.toString(),
          onTap: controller.goToAccessLogs,
          showcaseKey: conPasos ? controller.keyEntradas : null,
          tourDescription:
              'Cuántos entraron hoy. Toca para ver quién y a qué hora.',
        ),
      if (controller.can(Permission.gestionarClientes))
        _DatoDeHoy(
          label: 'Por vencer',
          detalle: 'Próximos ${ResumenDelDia.diasPorVencer} días',
          icon: Icons.event_busy_outlined,
          color: AppColors.warning,
          valor: () => resumen.vencen.value?.toString(),
          onTap: controller.goToClientes,
        ),
    ];
  }

  /// La rejilla de tableta con los módulos de este rol, cada uno con un dato
  /// del día, y los números de hoy arriba. Vender, el del mostrador, va
  /// primero y en grande.
  Widget _inicioTableta(BuildContext context) {
    final resumen = _resumen();
    String? cuantos(int? n, String uno, String varios) =>
        n == null ? null : (n == 1 ? uno : varios.replaceFirst('#', '$n'));
    const orden = ['Vender', 'Abonar', 'Clientes', 'Inventario'];
    final modulos = [
      for (final m in _modulos())
        switch (m.label) {
          'Vender' => m.conDato(() =>
              cuantos(resumen.ventas.value, '1 venta hoy', '# ventas hoy')),
          'Abonar' => m.conDato(() => cuantos(resumen.abonos.value,
              '1 membresía cobrada hoy', '# membresías cobradas hoy')),
          'Clientes' => m.conDato(() => cuantos(resumen.activos.value,
              '1 con membresía vigente', '# con membresía vigente')),
          _ => m,
        },
    ]..sort((a, b) => orden.indexOf(a.label).compareTo(orden.indexOf(b.label)));
    return _InicioTableta(
      modulos: modulos,
      cargando: resumen.cargando,
      recargar: () => _recargar(resumen),
      datos: _datosDeHoy(context, resumen, conPasos: true),
    );
  }

  /// Inicio de escritorio: la barra lateral (con los pasos del recorrido) y
  /// el panel del día.
  Widget _escritorio(BuildContext context) {
    final resumen = _resumen();
    return ScaffoldAdaptable(
      anchoMaximo: 1280,
      backgroundColor: context.colores.backgroundColor,
      menu: MenuLateral(pasos: _pasosDelMenu(), pasoBoton: _pasoOcultarMenu),
      body: _PanelDelDia(
        home: controller,
        resumen: resumen,
        datos: _datosDeHoy(context, resumen, conPasos: false),
        recargar: () => _recargar(resumen),
        pasoCabecera: (cabecera) => TourStep(
          tourKey: controller.keyHeader,
          title: '¡Te damos la bienvenida!',
          description: 'Este es tu panel del día. Te enseñamos lo principal '
              'en unos pasos.',
          borderRadius: 16,
          isFirstStep: true,
          child: cabecera,
        ),
      ),
    );
  }

  /// Los pasos del recorrido de Inicio en la barra lateral, en su orden.
  Map<String, PasoDelMenu> _pasosDelMenu() => {
        Routes.CLIENTES: PasoDelMenu(
          clave: controller.keyClientes,
          titulo: 'Clientes',
          descripcion: 'Tus miembros y cuándo vence su abono.',
        ),
        Routes.ABONAR: PasoDelMenu(
          clave: controller.keyAbonar,
          titulo: 'Abonar',
          descripcion: 'Cobra y renueva membresías.',
        ),
        Routes.POINT_OF_SALE: PasoDelMenu(
          clave: controller.keyVender,
          titulo: 'Vender',
          descripcion: 'Vende bebidas, suplementos y demás productos.',
        ),
        Routes.INVENTARIO: PasoDelMenu(
          clave: controller.keyInventario,
          titulo: 'Inventario',
          descripcion:
              'Administra tus productos y controla el stock disponible.',
        ),
        Routes.INGRESOS: PasoDelMenu(
          clave: controller.keyIngresos,
          titulo: 'Ingresos',
          descripcion: 'Todo lo cobrado: abonos, visitas y ventas.',
        ),
        Routes.ACCESS_LOGS: PasoDelMenu(
          clave: controller.keyEntradas,
          titulo: 'Entradas',
          descripcion: 'Quién entró y a qué hora.',
        ),
        Routes.CONFIGURACION: PasoDelMenu(
          clave: controller.keyConfiguracion,
          titulo: 'Configuración',
          descripcion: 'Tu cuenta, precios, categorías, lector y permisos.',
        ),
      };

  /// El último paso del recorrido de escritorio: el botón de la barra.
  PasoDelMenu get _pasoOcultarMenu => PasoDelMenu(
        clave: controller.keyMenu,
        titulo: 'Más espacio',
        descripcion: 'Oculta la barra para que la pantalla use todo el ancho; '
            'aquí mismo la vuelves a mostrar. Atajo: '
            '${MenuLateral.textoAtajo('B')}.',
        ultimo: true,
      );

  /// Si el rol actual puede entrar a esta entrada del menú.
  ///
  /// Los módulos que no corresponden se OCULTAN, no se muestran en gris: un
  /// candado en pantalla solo invita a pedir la llave. El permiso de cada uno
  /// está en `HomeController.permisoPorModulo`, que es la misma tabla con la
  /// que se filtran los pasos del tour.
  bool _permitido(_EntradaMenu entrada) {
    final Permission? permiso = HomeController.permisoPorModulo[entrada.label];
    // Una entrada sin permiso declarado se muestra: olvidarse de añadirlo no
    // debe esconder una función a todo el mundo en silencio.
    return permiso == null || controller.can(permiso);
  }

  // ─────────────────────────────────────────────────────────
  // MAIN MODULES (cards grandes con iconos)
  // ─────────────────────────────────────────────────────────
  /// Los módulos principales que este rol puede abrir.
  List<_ModuleItem> _modulos() => [
        _ModuleItem(
          icon: Icons.people_alt_outlined,
          label: 'Clientes',
          subtitle: 'Gestión de miembros',
          gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
          onTap: controller.goToClientes,
          showcaseKey: controller.keyClientes,
          tourDescription: 'Tus miembros y cuándo vence su abono.',
        ),
        _ModuleItem(
          icon: Icons.payments_outlined,
          label: 'Abonar',
          subtitle: 'Cobrar membresías',
          gradient: const [Color(0xFFf093fb), Color(0xFFf5576c)],
          onTap: controller.goToAbonar,
          showcaseKey: controller.keyAbonar,
          tourDescription: 'Cobra y renueva membresías.',
        ),
        _ModuleItem(
          icon: Icons.storefront_outlined,
          label: 'Vender',
          subtitle: 'Punto de venta',
          gradient: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
          onTap: controller.goToPointOfSale,
          showcaseKey: controller.keyVender,
          tourDescription: 'Vende bebidas, suplementos y demás productos.',
        ),
        _ModuleItem(
          icon: Icons.inventory_2_outlined,
          label: 'Inventario',
          subtitle: 'Productos y stock',
          gradient: const [Color(0xFF43e97b), Color(0xFF38f9d7)],
          onTap: controller.goToInventario,
          showcaseKey: controller.keyInventario,
          tourDescription:
              'Administra tus productos y controla el stock disponible.',
        ),
      ].where(_permitido).toList();

  Widget _buildMainModules(BuildContext context, bool isTablet) {
    final modules = _modulos();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      // Columnas según el ANCHO disponible (un teléfono de lado cabe en 4),
      // y alto fijo según el contenido de la tarjeta. Con una proporción
      // ancho/alto, las tarjetas angostas quedaban más bajas que su contenido.
      child: LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: PlataformaApp.escritorio
                      ? (constraints.maxWidth /
                              (220 *
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14))
                          .floor()
                          .clamp(1, 4)
                      : constraints.maxWidth >= 600
                          ? 4
                          : 2,
                  crossAxisSpacing: isTablet ? 16 : 12,
                  mainAxisSpacing: isTablet ? 16 : 12,
                  mainAxisExtent: (PlataformaApp.escritorio
                          ? 200.0
                          : isTablet
                              ? 180.0
                              : 165.0) *
                      (MediaQuery.textScalerOf(context).scale(14) / 14)
                          .clamp(1, double.infinity),
                ),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return TourStep(
                    tourKey: module.showcaseKey,
                    title: module.label,
                    description: module.tourDescription,
                    borderRadius: 20,
                    child: _ModuleCard(module: module),
                  );
                },
              )),
    );
  }

  // ─────────────────────────────────────────────────────────
  // QUICK ACTIONS (tiles horizontales)
  // ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isTablet) {
    final actions = [
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: 'Ingresos',
        subtitle: 'Historial de pagos',
        color: context.colores.titleColor,
        onTap: controller.goToPaymentRegistration,
        showcaseKey: controller.keyIngresos,
        tourDescription:
            'Consulta el historial de todos los pagos y ventas registrados.',
      ),
      _QuickAction(
        icon: Icons.door_sliding_outlined,
        label: 'Entradas',
        subtitle: 'Registro de accesos',
        color: const Color(0xFF81C784),
        onTap: controller.goToAccessLogs,
        showcaseKey: controller.keyEntradas,
        tourDescription: 'Revisa quién entró al gimnasio y a qué hora.',
      ),
    ].where(_permitido).toList()
      // Configuración va con las demás opciones, con la misma tarjeta y el
      // mismo espacio (antes iba aparte, más abajo y con otro diseño). Todos
      // los roles la ven.
      ..add(_QuickAction(
        icon: Icons.settings_outlined,
        label: 'Configuración',
        subtitle: 'Cuenta, precios y lector',
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFF546E7A)
            : const Color(0xFFB0BEC5),
        onTap: () => Get.toNamed(Routes.CONFIGURACION),
        showcaseKey: controller.keyConfiguracion,
        tourDescription: 'Tu cuenta, precios, categorías, lector y permisos.',
      ));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: LayoutBuilder(builder: (context, constraints) {
        final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columnas = PlataformaApp.escritorio
            ? (constraints.maxWidth / (300 * escala)).floor().clamp(1, 3)
            : 1;
        final ancho = (constraints.maxWidth - (columnas - 1) * 12) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map((action) => SizedBox(
                    width: ancho,
                    child: TourStep(
                      tourKey: action.showcaseKey,
                      title: action.label,
                      description: action.tourDescription,
                      borderRadius: 16,
                      isLastStep:
                          action.showcaseKey == controller.keyConfiguracion,
                      child: _QuickActionTile(action: action),
                    ),
                  ))
              .toList(),
        );
      }),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// DATA MODELS
// ═════════════════════════════════════════════════════════════

/// Lo único que necesita el filtro de permisos: la etiqueta con la que se
/// busca el permiso de la entrada en `HomeController.permisoPorModulo`.
abstract class _EntradaMenu {
  String get label;
}

class _ModuleItem implements _EntradaMenu {
  final IconData icon;
  @override
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final GlobalKey showcaseKey;
  final String tourDescription;

  /// Un dato del día para la tarjeta de tableta (null si no hay).
  final String? Function()? dato;

  const _ModuleItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    required this.showcaseKey,
    required this.tourDescription,
    this.dato,
  });

  _ModuleItem conDato(String? Function() dato) => _ModuleItem(
        icon: icon,
        label: label,
        subtitle: subtitle,
        gradient: gradient,
        onTap: onTap,
        showcaseKey: showcaseKey,
        tourDescription: tourDescription,
        dato: dato,
      );
}

class _QuickAction implements _EntradaMenu {
  final IconData icon;
  @override
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final GlobalKey showcaseKey;
  final String tourDescription;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.showcaseKey,
    required this.tourDescription,
  });
}

// ═════════════════════════════════════════════════════════════
// MODULE CARD (tarjeta principal con gradiente)
// ═════════════════════════════════════════════════════════════

class _ModuleCard extends StatefulWidget {
  final _ModuleItem module;
  const _ModuleCard({required this.module});

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _encima = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final m = widget.module;
    final isTablet = !PlataformaApp.escritorio &&
        MediaQuery.sizeOf(context).shortestSide >= 600;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            m.onTap();
          },
          onTapCancel: () => _controller.reverse(),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  m.gradient[0].withOpacity(0.15),
                  m.gradient[1].withOpacity(0.08),
                ],
              ),
              border: Border.all(
                color: m.gradient[0].withOpacity(_encima ? 0.5 : 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: m.gradient[0].withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 18 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: m.gradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: m.gradient[0].withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      m.icon,
                      color: Colors.white,
                      size:
                          PlataformaApp.escritorio ? 28 : (isTablet ? 26 : 24),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Text
                  Text(
                    m.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTablet || PlataformaApp.escritorio ? 17 : 16,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    m.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: PlataformaApp.escritorio
                          ? 12.5
                          : (isTablet ? 13 : 11),
                      color: c.textSecondary.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// QUICK ACTION TILE (fila horizontal)
// ═════════════════════════════════════════════════════════════

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final a = widget.action;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          a.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: c.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: a.color.withOpacity(_encima ? 0.4 : 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final compacto = constraints.maxWidth <
                  180 * MediaQuery.textScalerOf(context).scale(14) / 14;
              final texto = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(a.subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary.withOpacity(0.7),
                          fontWeight: FontWeight.w500)),
                ],
              );
              final icono = Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(a.icon, color: a.color, size: 24),
              );
              if (compacto) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [icono, const SizedBox(height: 12), texto],
                );
              }
              return Row(
                children: [
                  // Icon
                  icono,
                  const SizedBox(width: 16),
                  // Text
                  Expanded(
                    child: texto,
                  ),
                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: c.contraste.withOpacity(0.2),
                    size: 16,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

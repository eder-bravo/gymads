import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/services/tenant_context_service.dart';
import '../../../core/theme/app_colors.dart';
import '../utils/plataforma_app.dart';
import 'menu_lateral.dart';

/// La ventana de escritorio. Hace dos cosas:
///
/// * **Escala** toda la interfaz con el tamaño de la ventana: está diseñada
///   para [base] y, en un monitor grande o maximizada, crece en proporción
///   (hasta [escalaMaxima]) en vez de quedarse chica en medio de la pantalla.
///   Las pantallas reciben el tamaño lógico como `MediaQuery`, así que sus
///   anchos máximos y columnas siguen funcionando igual.
/// * Protege los tamaños transitorios de resize y las ventanas abiertas antes
///   de recompilar el mínimo nativo: por debajo de [minimo] se desplaza.
///
/// El árbol es el mismo con cualquier escala o tamaño: el Navigator
/// permanece montado y pantallas, diálogos, campos y foco conservan su estado.
class VentanaEscritorio extends StatelessWidget {
  const VentanaEscritorio({super.key, required this.child});

  final Widget child;
  static const minimo = Size(960, 600);
  static const base = Size(1280, 800);
  static const escalaMaxima = 1.6;

  /// Cuánto crece la interfaz en una ventana de [ventana] puntos. Va en pasos
  /// de 0.05 para no reacomodar todo en cada píxel al redimensionar.
  static double escalaPara(Size ventana) {
    final proporcion =
        math.min(ventana.width / base.width, ventana.height / base.height);
    final escalonada = (proporcion * 20 + 1e-9).floorToDouble() / 20;
    return escalonada.clamp(1.0, escalaMaxima);
  }

  @override
  Widget build(BuildContext context) {
    if (!PlataformaApp.escritorio) return child;
    return LayoutBuilder(builder: (context, limites) {
      final ancho = limites.maxWidth.clamp(minimo.width, double.infinity);
      final alto = limites.maxHeight.clamp(minimo.height, double.infinity);
      final escala = escalaPara(Size(ancho, alto));
      final logico = Size(ancho / escala, alto / escala);
      final datos = MediaQuery.of(context);
      return SingleChildScrollView(
        primary: false,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          primary: false,
          child: SizedBox(
            width: ancho,
            height: alto,
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: logico,
                child: MediaQuery(
                  data: datos.copyWith(
                    size: logico,
                    // Imágenes con la resolución de lo que de verdad ocupan.
                    devicePixelRatio: datos.devicePixelRatio * escala,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// El contenido mantiene un ancho legible al ampliar la ventana. Los márgenes
/// pertenecen a la pantalla; no se cambia el tamaño de letra ni el MediaQuery.
class ContenidoEscritorio extends StatelessWidget {
  const ContenidoEscritorio({
    super.key,
    required this.child,
    this.anchoMaximo = 1120,
  });

  final Widget child;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    if (!PlataformaApp.pantallaGrande) return child;
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Scaffold común: la barra y el fondo llenan la ventana; el cuerpo y las
/// acciones de los formularios comparten ancho y alineación.
class ScaffoldAdaptable extends StatelessWidget {
  const ScaffoldAdaptable({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset,
    this.anchoMaximo = 1120,
    this.conMenu = true,
    this.menu,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool? resizeToAvoidBottomInset;
  final double anchoMaximo;

  /// En escritorio, la barra lateral de secciones. false en pantallas de
  /// antes de entrar (permisos iniciales, modo de cobro).
  final bool conMenu;

  /// Una barra con los pasos del recorrido (solo Inicio).
  final MenuLateral? menu;

  /// Escritorio, con sesión y fuera de una ventana modal. En una ventana
  /// angosta (solo posible sin el mínimo nativo) la barra aplastaría el
  /// contenido: no se pone.
  bool _muestraMenu(BuildContext context) {
    if (!PlataformaApp.escritorio || !conMenu) return false;
    if (MediaQuery.sizeOf(context).width < 720) return false;
    if (context.dependOnInheritedWidgetOfExactType<_EnVentana>() != null) {
      return false;
    }
    try {
      return Get.isRegistered<TenantContextService>() &&
          TenantContextService.to.isAuthenticated;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantalla = _pantalla(context);
    if (!_muestraMenu(context)) return pantalla;
    final datos = MediaQuery.of(context);
    final c = context.colores;
    return CallbackShortcuts(
      bindings: MenuLateral.atajos(),
      // El foco queda en la pantalla para que los atajos funcionen sin hacer
      // clic antes.
      child: Focus(
        autofocus: true,
        // Con fondo: la línea entre la barra y el contenido es translúcida.
        child: ColoredBox(
          color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              menu ?? const MenuLateral(),
              VerticalDivider(width: 1, thickness: 1, color: c.divisor),
              Expanded(
                // El contenido mide su propia área: así sus anchos máximos y
                // márgenes se calculan sin la barra.
                child: MediaQuery(
                  data: datos.copyWith(
                    size: Size(datos.size.width - MenuLateral.ancho - 1,
                        datos.size.height),
                  ),
                  child: ConMenuLateral(child: pantalla),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pantalla(BuildContext context) => AnchoContenido(
        anchoMaximo: anchoMaximo,
        child: Scaffold(
          appBar: appBar,
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          body: body == null
              ? null
              : ContenidoEscritorio(anchoMaximo: anchoMaximo, child: body!),
          bottomNavigationBar: bottomNavigationBar == null
              ? null
              : ContenidoEscritorio(
                  anchoMaximo: anchoMaximo, child: bottomNavigationBar!),
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: _AccionEnContenido(anchoMaximo),
        ),
      );
}

/// Marca lo que va dentro de una [VentanaFormulario]: ahí no va la barra
/// lateral.
class _EnVentana extends InheritedWidget {
  const _EnVentana({required super.child});

  @override
  bool updateShouldNotify(_EnVentana oldWidget) => false;
}

class AnchoContenido extends InheritedWidget {
  const AnchoContenido({
    super.key,
    required this.anchoMaximo,
    required super.child,
  });

  final double anchoMaximo;

  static double margen(BuildContext context) {
    if (!PlataformaApp.pantallaGrande) return 0;
    final ancho = context
        .dependOnInheritedWidgetOfExactType<AnchoContenido>()
        ?.anchoMaximo;
    if (ancho == null) return 0;
    return ((MediaQuery.sizeOf(context).width - ancho) / 2)
        .clamp(0, double.infinity);
  }

  @override
  bool updateShouldNotify(AnchoContenido oldWidget) =>
      anchoMaximo != oldWidget.anchoMaximo;
}

class _AccionEnContenido extends FloatingActionButtonLocation {
  const _AccionEnContenido(this.anchoMaximo);
  final double anchoMaximo;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final offset = FloatingActionButtonLocation.endFloat.getOffset(geometry);
    if (!PlataformaApp.pantallaGrande) return offset;
    final margen = ((geometry.scaffoldSize.width - anchoMaximo) / 2)
        .clamp(0, double.infinity);
    return Offset(offset.dx - margen, offset.dy);
  }
}

/// Filas de altura natural: en escritorio, tantas tarjetas por fila como
/// quepan con al menos [anchoTarjeta] (hasta tres), sin recortar nombres o
/// información al aumentar la escala del texto.
class ListaAdaptable extends StatelessWidget {
  const ListaAdaptable({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.anchoTarjeta = 420,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final double anchoTarjeta;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columnas = PlataformaApp.pantallaGrande
              ? (constraints.maxWidth / (anchoTarjeta * escala))
                  .floor()
                  .clamp(1, 3)
              : 1;
          return ListView.builder(
            padding: padding,
            itemCount: (itemCount / columnas).ceil(),
            itemBuilder: (context, fila) {
              if (columnas == 1) return itemBuilder(context, fila);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var columna = 0; columna < columnas; columna++)
                    Expanded(
                      child: fila * columnas + columna < itemCount
                          ? itemBuilder(context, fila * columnas + columna)
                          : const SizedBox.shrink(),
                    ),
                ],
              );
            },
          );
        },
      );
}

/// Resúmenes que pasan a varias filas según el ancho y la escala del texto.
/// Cada celda conserva altura natural para que sus etiquetas puedan envolver.
class ResumenAdaptable extends StatelessWidget {
  const ResumenAdaptable(
      {super.key,
      required this.children,
      this.anchoMinimo = 160,
      this.espacio = 12});

  final List<Widget> children;
  final double anchoMinimo;
  final double espacio;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (children.isEmpty) return const SizedBox.shrink();
        final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columnas = ((constraints.maxWidth + espacio) /
                (anchoMinimo * escala + espacio))
            .floor()
            .clamp(1, children.length);
        final ancho =
            (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(spacing: espacio, runSpacing: espacio, children: [
          for (final child in children) SizedBox(width: ancho, child: child)
        ]);
      });
}

/// En fichas angostas, el detalle pasa debajo del nombre en vez de competir
/// por el ancho. Se conserva todo el texto y la altura crece con el contenido.
class FilaConDetalle extends StatelessWidget {
  const FilaConDetalle(
      {super.key,
      required this.leading,
      required this.principal,
      required this.detalle});
  final Widget leading;
  final Widget principal;
  final Widget detalle;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
        final compacta = constraints.maxWidth < 600 * escala;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
              child: compacta
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          principal,
                          const SizedBox(height: 12),
                          detalle
                        ])
                  : principal),
          if (!compacta) ...[
            const SizedBox(width: 12),
            // Importes y estados al borde derecho de la ficha, alineados de
            // una fila a otra, en vez de flotar a media fila.
            Flexible(
                child: PlataformaApp.pantallaGrande
                    ? Align(
                        alignment: AlignmentDirectional.topEnd, child: detalle)
                    : detalle)
          ],
        ]);
      });
}

/// Una ficha con sus acciones a la derecha. En pantalla grande, si no caben
/// junto al nombre (texto grande en una ventana angosta), las acciones bajan a
/// su propio renglón en vez de aplastarlo. En el teléfono, la fila de siempre.
class FichaConAcciones extends StatelessWidget {
  const FichaConAcciones({
    super.key,
    required this.datos,
    required this.acciones,
    this.anchoMinimo = 520,
  });

  /// Lo que va antes de las acciones en la fila.
  final List<Widget> datos;
  final Widget acciones;

  /// Ancho (con texto al 100 %) desde el que las acciones van en la fila.
  final double anchoMinimo;

  @override
  Widget build(BuildContext context) {
    final fila = Row(children: [...datos, acciones]);
    if (!PlataformaApp.pantallaGrande) return fila;
    return LayoutBuilder(builder: (context, limites) {
      final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (limites.maxWidth >= anchoMinimo * escala) return fila;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: datos),
          const SizedBox(height: 10),
          Align(alignment: AlignmentDirectional.centerEnd, child: acciones),
        ],
      );
    });
  }
}

/// Hoja inferior en el teléfono; en escritorio, ventana centrada de ancho
/// acotado (una hoja que sube desde el borde de un monitor queda lejos del
/// mouse y ocupa todo el ancho). El contenido es el mismo: quien lo construye
/// solo oculta el asa con [PlataformaApp.escritorio].
Future<T?> mostrarHojaAdaptable<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double anchoMaximo = 560,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  if (!PlataformaApp.pantallaGrande) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxWidth: anchoMaximo,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        // Sin asa, el título necesita aire arriba.
        padding: EdgeInsets.only(top: showDragHandle ? 16 : 0),
        child: builder(context),
      ),
    ),
  );
}

/// Formularios largos (cliente, producto, visita, acceso de personal): en el
/// teléfono, pantalla completa; en escritorio, una ventana modal sobre la
/// pantalla de la que se abrieron, que sigue a la vista detrás. La vista y su
/// forma de cerrar (`Get.back(result: ...)`) son las mismas en los dos casos.
///
/// Un clic fuera no la cierra: se perdería lo escrito.
Future<T?> abrirFormulario<T>(Widget Function() pagina) async {
  if (!PlataformaApp.pantallaGrande) {
    return await Get.to<T>(pagina, fullscreenDialog: true);
  }
  return Get.dialog<T>(VentanaFormulario(child: pagina()),
      barrierDismissible: false);
}

/// Marco de [abrirFormulario] en escritorio. La pantalla de adentro recibe
/// el tamaño de la ventana como su `MediaQuery`: así sus márgenes de
/// [ScaffoldAdaptable] y `GymAppBar` se calculan sobre la ventana y no sobre
/// el monitor.
class VentanaFormulario extends StatelessWidget {
  const VentanaFormulario({
    super.key,
    required this.child,
    this.ancho = 720,
    this.alto = 680,
  });

  final Widget child;
  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) {
    const margen = 24.0;
    final disponible = MediaQuery.sizeOf(context);
    // En tableta el teclado en pantalla le quita alto a la ventana.
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    final tamano = Size(
      math.max(0, math.min(ancho, disponible.width - margen * 2)),
      math.max(0, math.min(alto, disponible.height - teclado - margen * 2)),
    );
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(margen),
      constraints: BoxConstraints.loose(tamano),
      child: SizedBox.fromSize(
        size: tamano,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: tamano,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            // El Dialog ya sube por encima del teclado: adentro no se
            // vuelve a descontar.
            viewInsets: EdgeInsets.zero,
          ),
          // Escape cierra igual que la X (y respeta un "no salir mientras
          // guarda" de la pantalla).
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(context).maybePop(),
            },
            child: Focus(autofocus: true, child: _EnVentana(child: child)),
          ),
        ),
      ),
    );
  }
}

/// Respuesta al mouse para fichas hechas a mano (sin `InkWell`): cursor de
/// mano y un estado [encima] para resaltar el borde. En el teléfono no hay
/// mouse: [builder] recibe siempre `false`.
class AlPasarMouse extends StatefulWidget {
  const AlPasarMouse({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool encima) builder;
  final MouseCursor cursor;

  @override
  State<AlPasarMouse> createState() => _AlPasarMouseState();
}

class _AlPasarMouseState extends State<AlPasarMouse> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    if (!PlataformaApp.escritorio) return widget.builder(context, false);
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: widget.builder(context, _encima),
    );
  }
}

/// Tamaño de letra legible: en escritorio, ningún texto informativo queda por
/// debajo de 14 (ayudas, etiquetas, notas). En el teléfono no cambia.
double legible(double tamano) =>
    PlataformaApp.pantallaGrande ? math.max(tamano, 14) : tamano;

/// La acción principal de una pantalla, en su barra superior. En escritorio
/// es un botón con texto ("Nuevo cliente"); en el teléfono, [movil] tal cual.
class AccionDeBarra extends StatelessWidget {
  const AccionDeBarra({
    super.key,
    required this.texto,
    required this.icono,
    required this.onPressed,
    required this.movil,
    this.secundaria = false,
  });

  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;
  final Widget movil;

  /// Una acción de apoyo (abrir Categorías, Cobrar visita): botón de texto,
  /// sin relleno, para que la principal siga destacando.
  final bool secundaria;

  @override
  Widget build(BuildContext context) {
    if (!PlataformaApp.pantallaGrande) return movil;
    if (secundaria) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icono, size: 20),
          label: Text(texto),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 42),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icono, size: 20),
        label: Text(texto),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Una acción de una fila (editar, ajustar, eliminar…).
class AccionDeFila {
  const AccionDeFila({
    required this.texto,
    required this.icono,
    required this.onPressed,
    this.peligrosa = false,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onPressed;

  /// En rojo: eliminar, revocar, desvincular.
  final bool peligrosa;
}

/// Las acciones de una fila de lista. En escritorio las más usadas se ven
/// como botones con texto y el resto va en "Más", también con texto: nada
/// queda escondido detrás de un ⋮ que hay que adivinar. En el teléfono se
/// usa [movil] (el menú de siempre).
class AccionesDeFila extends StatelessWidget {
  const AccionesDeFila({
    super.key,
    required this.visibles,
    this.mas = const [],
    required this.movil,
  });

  final List<AccionDeFila> visibles;
  final List<AccionDeFila> mas;
  final Widget movil;

  @override
  Widget build(BuildContext context) {
    if (!PlataformaApp.pantallaGrande) return movil;
    final esquema = Theme.of(context).colorScheme;
    Color color(AccionDeFila a) =>
        a.peligrosa ? esquema.error : esquema.primary;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final a in visibles)
          TextButton.icon(
            onPressed: a.onPressed,
            icon: Icon(a.icono, size: 18),
            label: Text(a.texto),
            style: TextButton.styleFrom(
              foregroundColor: color(a),
              minimumSize: const Size(0, 40),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        if (mas.isNotEmpty)
          PopupMenuButton<int>(
            tooltip: 'Más opciones',
            onSelected: (i) => mas[i].onPressed(),
            itemBuilder: (context) => [
              for (var i = 0; i < mas.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Row(children: [
                    Icon(mas[i].icono,
                        size: 20,
                        color: mas[i].peligrosa ? esquema.error : null),
                    const SizedBox(width: 12),
                    Text(mas[i].texto,
                        style: TextStyle(
                            color: mas[i].peligrosa ? esquema.error : null)),
                  ]),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.more_horiz,
                    size: 18, color: esquema.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Más',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: esquema.onSurfaceVariant,
                    )),
              ]),
            ),
          ),
      ],
    );
  }
}

/// Botones de una pantalla en escritorio: cada uno de su ancho (mínimo 200),
/// en fila, la acción principal al final. Si no caben, bajan de renglón.
class FilaDeBotones extends StatelessWidget {
  const FilaDeBotones({
    super.key,
    required this.children,
    this.alineacion = WrapAlignment.center,
  });

  final List<Widget> children;
  final WrapAlignment alineacion;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: alineacion,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final b in children)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200),
              child: b,
            ),
        ],
      );
}

/// Estilo de botón de escritorio para [FilaDeBotones]: ancho natural, alto
/// cómodo y letra clara.
ButtonStyle estiloBotonEscritorio(
        {Color? fondo, Color? texto, bool contorno = false}) =>
    (contorno ? OutlinedButton.styleFrom : ElevatedButton.styleFrom)(
      backgroundColor: contorno ? null : fondo,
      foregroundColor: texto,
      minimumSize: const Size(200, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      elevation: 0,
    );

import 'package:flutter/material.dart';

import '../utils/plataforma_app.dart';

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
    if (!PlataformaApp.escritorio) return child;
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
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool? resizeToAvoidBottomInset;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) => AnchoContenido(
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

class AnchoContenido extends InheritedWidget {
  const AnchoContenido({
    super.key,
    required this.anchoMaximo,
    required super.child,
  });

  final double anchoMaximo;

  static double margen(BuildContext context) {
    if (!PlataformaApp.escritorio) return 0;
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
    if (!PlataformaApp.escritorio) return offset;
    final margen = ((geometry.scaffoldSize.width - anchoMaximo) / 2)
        .clamp(0, double.infinity);
    return Offset(offset.dx - margen, offset.dy);
  }
}

/// Filas de altura natural: dos tarjetas en escritorio cuando caben, sin
/// recortar nombres o información al aumentar la escala del texto.
class ListaAdaptable extends StatelessWidget {
  const ListaAdaptable({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columnas =
              PlataformaApp.escritorio && constraints.maxWidth >= 1000 * escala
                  ? 2
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

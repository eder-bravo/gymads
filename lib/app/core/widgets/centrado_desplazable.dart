import 'package:flutter/material.dart';

/// Centra [child] en el espacio disponible y, si no cabe, deja desplazarlo.
///
/// Para mensajes de "no hay nada todavía", cargas y pantallas de un solo
/// bloque. Un `Center` con una columna dentro se ve igual mientras sobre
/// altura, pero con el teléfono de lado (o el teclado abierto) la columna
/// es más alta que la pantalla y desborda.
///
/// Si además hay que poder tirar para recargar, usa `Refrescable.centrado`.
class CentradoDesplazable extends StatelessWidget {
  const CentradoDesplazable({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite
                ? (constraints.maxHeight - padding.vertical).clamp(0, double.infinity)
                : 0,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

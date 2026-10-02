import 'package:flutter/material.dart';

/// Un [child] con su fondo, que además tiene una prolongación hacia arriba,
/// fuera de la pantalla, del mismo color que su borde de arriba.
///
/// En reposo esa prolongación queda por encima de la pantalla y no se ve (el
/// área de desplazamiento recorta lo que sale por arriba). Al jalar la
/// pantalla hacia abajo (el rebote de iOS) es lo que aparece arriba, en vez de
/// un hueco vacío entre la barra de estado y la cabecera.
///
/// No depende de escuchar el desplazamiento ni de ningún estado: siempre está
/// ahí, así que no puede quedar desconectada.
class FondoEstirable extends StatelessWidget {
  const FondoEstirable({
    super.key,
    required this.decoracion,
    required this.colorArriba,
    required this.child,
  });

  /// El fondo de la cabecera (degradado, bordes, sombra).
  final BoxDecoration decoracion;

  /// Lo que se ve al jalar: el color del borde de arriba del fondo, de
  /// izquierda a derecha.
  final Gradient colorArriba;

  final Widget child;

  /// Cuánto se prolonga hacia arriba: más de lo que cualquiera jala.
  static const prolongacion = 1200.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -prolongacion,
          left: 0,
          right: 0,
          height: prolongacion + 1, // 1 px de más: sin rendija entre los dos
          child: DecoratedBox(
            key: const Key('fondo_prolongado'),
            decoration: BoxDecoration(gradient: colorArriba),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            key: const Key('fondo_estirable'),
            decoration: decoracion,
          ),
        ),
        child,
      ],
    );
  }
}

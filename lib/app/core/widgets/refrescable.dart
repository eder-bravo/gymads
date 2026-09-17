import 'package:flutter/material.dart';

/// Permite recargar una pantalla tirando de ella hacia abajo.
///
/// Existe por un detalle que se olvida fácil: `RefreshIndicator` solo reacciona
/// si su hijo se desplaza. Un mensaje de "no hay nada todavía" centrado en la
/// pantalla no tiene scroll, así que el gesto no llega y la pantalla se queda
/// sin forma de recargarse justo cuando más falta hace — que es cuando parece
/// vacía porque los datos aún no han llegado.
///
/// Dos formas de usarlo:
///
/// * El constructor normal, para listas y cuadrículas que ya se desplazan
///   solas. Les impone `AlwaysScrollableScrollPhysics` para que el tirón
///   funcione también cuando el contenido es más corto que la pantalla.
/// * [Refrescable.centrado], para los estados vacíos: mantiene el contenido
///   centrado y aun así deja tirar de él.
class Refrescable extends StatelessWidget {
  const Refrescable({
    super.key,
    required this.onRefresh,
    required this.child,
  }) : _centrado = false;

  /// Para un mensaje centrado —un estado vacío o un error— que por sí solo no
  /// se desplazaría.
  const Refrescable.centrado({
    super.key,
    required this.onRefresh,
    required this.child,
  }) : _centrado = true;

  /// Qué recargar. El indicador gira hasta que el futuro termina, así que debe
  /// completarse cuando los datos ya estén.
  final Future<void> Function() onRefresh;

  final Widget child;

  final bool _centrado;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: _centrado ? _envolverCentrado() : _imponerScroll(context),
    );
  }

  /// Un alto mínimo igual al del hueco disponible: así el contenido queda
  /// centrado como estaba, pero dentro de algo que se puede arrastrar.
  Widget _envolverCentrado() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  /// La física por defecto no deja arrastrar cuando el contenido cabe entero
  /// en la pantalla, así que una lista corta no se podría recargar. Se cambia
  /// aquí en vez de en cada `ListView`.
  ///
  /// Se parte de la física del contexto con `copyWith` y no de un
  /// `ScrollBehavior` nuevo: así se conservan el efecto de rebote de cada
  /// plataforma, la barra de desplazamiento y los dispositivos de arrastre.
  Widget _imponerScroll(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context)
          .copyWith(physics: const AlwaysScrollableScrollPhysics()),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

/// Una cabecera (resumen, buscador, filtros) encima de una lista que ocupa el
/// resto de la pantalla.
///
/// Con altura de sobra se ve como siempre: la cabecera fija arriba y la lista
/// desplazándose debajo. Con poca altura —teléfono de lado, teclado abierto—
/// la cabecera fija se comía casi todo el espacio y desbordaba. Ahí la
/// cabecera se desplaza junto con la lista: primero se va la cabecera y luego
/// sigue la lista.
///
/// [lista] debe ser un desplazable (ListView, GridView, Refrescable...) SIN
/// un `ScrollController` propio, para que se coordine con la cabecera.
class CabeceraConLista extends StatelessWidget {
  const CabeceraConLista({
    super.key,
    required this.cabecera,
    required this.lista,
    this.alturaMinima = 480,
  });

  final List<Widget> cabecera;
  final Widget lista;

  /// Por debajo de esta altura la cabecera deja de estar fija.
  final double alturaMinima;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= alturaMinima) {
          return Column(
            children: [
              ...cabecera,
              Expanded(child: lista),
            ],
          );
        }

        return NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: cabecera,
              ),
            ),
          ],
          body: lista,
        );
      },
    );
  }
}

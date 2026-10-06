import 'package:flutter/material.dart';
import '../utils/plataforma_app.dart';

/// Una cabecera (resumen, buscador, filtros) encima de una lista que ocupa el
/// resto de la pantalla.
///
/// En vertical se ve como siempre: la cabecera fija arriba y la lista
/// desplazándose debajo. Con el teléfono de lado la cabecera fija se comía
/// casi toda la altura y desbordaba; ahí la cabecera se desplaza junto con la
/// lista: primero se va la cabecera y luego sigue la lista.
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

  /// Con una pantalla más baja que esto (teléfono de lado), la cabecera deja
  /// de estar fija.
  final double alturaMinima;

  @override
  Widget build(BuildContext context) {
    // Se decide por el tamaño de la PANTALLA, no por el espacio disponible.
    // El espacio disponible cambia al abrir el teclado: la estructura saltaba
    // de Column a NestedScrollView, el campo que se estaba tocando se
    // reconstruía, perdía el foco y el teclado se cerraba (no se podía
    // escribir el precio de un abono libre, ni buscar). El tamaño de la
    // pantalla no cambia con el teclado: solo al girar el teléfono.
    final alto = MediaQuery.sizeOf(context).height;
    // En una ventana de escritorio el tamaño puede cambiar continuamente.
    // Conservar el mismo desplazable evita recrear el buscador y perder foco.
    // En tableta, igual: acostada, la cabecera de Entradas (periodo, totales
    // y la gráfica por hora) no cabía fija y se salía 84 puntos por abajo.
    if (!PlataformaApp.pantallaGrande && alto >= alturaMinima) {
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
  }
}

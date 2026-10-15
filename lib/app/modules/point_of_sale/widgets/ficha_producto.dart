import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';

/// Un producto del mostrador. Toda la ficha agrega una unidad a la venta: es
/// lo único que hace. Las cantidades se corrigen en la lista de la venta,
/// para que agregar y quitar no estén repetidos en dos lugares.
///
/// Abajo dice "Agregar" o, si ya va en la venta, cuántos lleva. La
/// pulsación larga (o el clic derecho) lo fija arriba.
class FichaProducto extends StatelessWidget {
  const FichaProducto({
    super.key,
    required this.producto,
    required this.cantidad,
    required this.fijado,
    required this.onAgregar,
    required this.onFijar,
  });

  final Product producto;

  /// Cuántas unidades lleva ya la venta.
  final int cantidad;
  final bool fijado;
  final VoidCallback onAgregar;
  final VoidCallback onFijar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final enVenta = cantidad > 0;
    return AlPasarMouse(
      builder: (context, encima) => Semantics(
        button: true,
        label: enVenta
            ? '${producto.name}, llevas $cantidad. Agregar otro'
            : 'Agregar ${producto.name}',
        excludeSemantics: true,
        child: Material(
          color: c.cardBackground,
          shadowColor: c.sombra,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: enVenta
                  ? AppColors.accent
                  : encima
                      ? AppColors.accent.withOpacity(0.45)
                      : c.borde,
              width: enVenta ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onAgregar,
            // Fijar arriba es un atajo de mostrador, por eso va en la
            // pulsación larga: no estorba al toque normal, que es agregar.
            onLongPress: () {
              HapticFeedback.mediumImpact();
              onFijar();
            },
            // Con mouse, el clic derecho hace lo mismo.
            onSecondaryTap: onFijar,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        child: const Icon(Icons.shopping_bag,
                            color: AppColors.accent, size: 20),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (fijado) ...[
                            Icon(Icons.push_pin, size: 14, color: c.titleColor),
                            const SizedBox(width: 6),
                          ],
                          _Existencias(producto.stock),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    producto.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dinero(producto.price),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: c.titleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Pie(cantidad: cantidad),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "+ Agregar" o, ya en la venta, "Llevas 2" en azul: no es otro botón,
/// es la misma ficha diciendo qué pasa al tocarla.
class _Pie extends StatelessWidget {
  const _Pie({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final enVenta = cantidad > 0;
    final color = enVenta ? Colors.white : c.titleColor;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enVenta ? AppColors.accent : c.superficie,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment:
            enVenta ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          if (!enVenta) ...[
            Icon(Icons.add, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            fit: enVenta ? FlexFit.tight : FlexFit.loose,
            child: Text(
              enVenta ? 'Llevas $cantidad' : 'Agregar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (enVenta) Icon(Icons.add, size: 18, color: color),
        ],
      ),
    );
  }
}

/// Las existencias: rojo si no hay (o está en negativo), amarillo si quedan
/// pocas.
class _Existencias extends StatelessWidget {
  const _Existencias(this.stock);

  final int stock;

  @override
  Widget build(BuildContext context) {
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
}

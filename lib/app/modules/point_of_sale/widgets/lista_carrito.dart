import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/models/sale_model.dart';

/// Los productos de la venta, uno por renglón, para revisarlos antes de
/// cobrar: cuántos van, cuánto cuesta cada uno y el subtotal.
///
/// Con letra y botones grandes, para que se lea sin lentes y se corrija con el
/// dedo sin atinarle a un botón chico. El − en la última unidad quita el
/// producto de la venta.
///
/// Sin [onCambiarCantidad] es solo para leer (mientras se cobra): sin
/// botones, con el importe de cada renglón a la derecha.
class ListaCarrito extends StatelessWidget {
  const ListaCarrito({
    super.key,
    required this.items,
    this.onCambiarCantidad,
  });

  final List<SaleItem> items;

  /// Recibe el producto y la cantidad nueva (0 = quitarlo).
  final void Function(SaleItem item, int cantidad)? onCambiarCantidad;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: c.textSecondary.withOpacity(0.15)),
          _renglon(context, items[i]),
        ],
      ],
    );
  }

  Widget _renglon(BuildContext context, SaleItem item) {
    final c = context.colores;
    final cambiar = onCambiarCantidad;
    if (cambiar == null) return _renglonFijo(context, item);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} × ${dinero(item.unitPrice)}'
                  '  =  ${dinero(item.total)}',
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _boton(
            context,
            icono: item.quantity == 1 ? Icons.delete_outline : Icons.remove,
            tooltip: item.quantity == 1 ? 'Quitar' : 'Uno menos',
            color: item.quantity == 1 ? AppColors.error : c.textPrimary,
            onPressed: () => cambiar(item, item.quantity - 1),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _boton(
            context,
            icono: Icons.add,
            tooltip: 'Uno más',
            color: AppColors.accent,
            onPressed: () => cambiar(item, item.quantity + 1),
          ),
        ],
      ),
    );
  }

  /// Mientras se cobra: cuántos, el nombre y el importe, como en un ticket.
  Widget _renglonFijo(BuildContext context, SaleItem item) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.quantity > 1)
                  Text(
                    '${dinero(item.unitPrice)} c/u',
                    style: TextStyle(color: c.textSecondary, fontSize: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Con letra grande en un panel angosto, el importe se encoge
          // antes de salirse.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: Text(
                dinero(item.total),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boton(
    BuildContext context, {
    required IconData icono,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final c = context.colores;
    return Material(
      color: c.cardBackground,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icono, size: 22),
        color: color,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}

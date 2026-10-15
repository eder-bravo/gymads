import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';

import '../../../../core/theme/app_colors.dart';

/// Las cuentas de la venta, como al pie de un ticket: subtotal, descuento,
/// el total en grande y, al cobrar en efectivo, lo recibido y el cambio.
class ResumenTotales extends StatelessWidget {
  const ResumenTotales({
    super.key,
    required this.unidades,
    required this.subtotal,
    required this.total,
    this.descuento = 0,
    this.recibido,
    this.cambio,
  });

  final int unidades;
  final double subtotal;
  final double total;
  final double descuento;

  /// Solo en efectivo, cuando ya se escribió con cuánto paga.
  final double? recibido;
  final double? cambio;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (descuento > 0) ...[
          _Renglon('Subtotal (${_piezas(unidades)})', dinero(subtotal)),
          _Renglon('Descuento', '-${dinero(descuento)}'),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  if (descuento <= 0)
                    Text(_piezas(unidades),
                        style: TextStyle(color: c.textSecondary, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  dinero(total),
                  style: TextStyle(
                    color: c.titleColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (recibido != null) ...[
          const SizedBox(height: 8),
          Divider(height: 1, color: c.divisor),
          const SizedBox(height: 8),
          _Renglon('Recibido', dinero(recibido!)),
          if (cambio != null)
            _Renglon('Cambio', dinero(cambio!), color: AppColors.success),
        ],
      ],
    );
  }

  static String _piezas(int n) => n == 1 ? '1 producto' : '$n productos';
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.etiqueta, this.valor, {this.color});

  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final destacado = color != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(etiqueta,
                style: TextStyle(
                  color: destacado ? color : c.textSecondary,
                  fontSize: 15,
                  fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
                )),
          ),
          const SizedBox(width: 12),
          Text(valor,
              style: TextStyle(
                color: color ?? c.textPrimary,
                fontSize: destacado ? 18 : 15,
                fontWeight: destacado ? FontWeight.bold : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

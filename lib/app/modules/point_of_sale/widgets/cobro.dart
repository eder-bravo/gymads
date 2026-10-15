import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/metodo_de_pago.dart';
import 'package:gymads/app/core/utils/referencia_de_pago.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/point_of_sale_controller.dart';

/// Lo que se pide según cómo paga: con cuánto (efectivo), el folio
/// (tarjeta y transferencia) o nada (mixto). Lo comparten el cobro de
/// escritorio y el paso 4 del teléfono.
class PagoSegunMetodo extends StatelessWidget {
  const PagoSegunMetodo(
      {super.key, required this.controller, this.conEtiqueta = true});

  final PointOfSaleController controller;

  /// Sin "¿Con cuánto paga?" cuando ya es el título de la pantalla.
  final bool conEtiqueta;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.selectedPaymentMethod == 'efectivo') {
        return CampoEfectivo(controller: controller, conEtiqueta: conEtiqueta);
      }
      if (controller.usaReferenciaPago) {
        return CampoReferenciaPago(controlador: controller);
      }
      return const SizedBox.shrink();
    });
  }
}

/// "¿Con cuánto paga?": el campo, los montos rápidos (exacto y los billetes
/// que siguen) y el cambio en grande.
class CampoEfectivo extends StatefulWidget {
  const CampoEfectivo(
      {super.key, required this.controller, this.conEtiqueta = true});

  final PointOfSaleController controller;
  final bool conEtiqueta;

  @override
  State<CampoEfectivo> createState() => _CampoEfectivoState();
}

class _CampoEfectivoState extends State<CampoEfectivo> {
  late final _texto = TextEditingController(text: _comoTexto(_recibido));

  double get _recibido => widget.controller.receivedAmount;

  static String _comoTexto(double monto) {
    if (monto <= 0) return '';
    return monto == monto.roundToDouble()
        ? monto.toStringAsFixed(0)
        : monto.toStringAsFixed(2);
  }

  void _elegir(double monto) {
    _texto.text = _comoTexto(monto);
    _texto.selection = TextSelection.collapsed(offset: _texto.text.length);
    widget.controller.setReceivedAmount(monto);
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.conEtiqueta) ...[
          Text('¿Con cuánto paga?',
              style: TextStyle(color: c.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _texto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'Cuánto te entregó',
            hintStyle: TextStyle(
                color: c.textHint, fontSize: 18, fontWeight: FontWeight.normal),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixText: '\$ ',
            prefixStyle: TextStyle(
              color: c.titleColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          onChanged: (valor) =>
              controller.setReceivedAmount(double.tryParse(valor) ?? 0),
        ),
        const SizedBox(height: 12),
        Obx(() => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, monto) in controller.montosRapidos.indexed)
                  _MontoRapido(
                    texto: i == 0 ? 'Exacto' : dinero(monto),
                    elegido: controller.receivedAmount == monto,
                    onPressed: () => _elegir(monto),
                  ),
              ],
            )),
        Obx(() {
          final recibido = controller.receivedAmount;
          if (recibido <= 0) return const SizedBox.shrink();
          final cambio = controller.changeAmount;
          final falta = cambio < -0.004;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (falta ? AppColors.error : AppColors.success)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    falta ? Icons.error_outline : Icons.payments_outlined,
                    color: falta ? AppColors.error : AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  // "Cambio" o "Faltan": cortos, sin encogerse; el importe
                  // toma el resto, pegado a la derecha.
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      falta ? 'Faltan' : 'Cambio',
                      style: TextStyle(
                        color: falta ? AppColors.error : AppColors.success,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        dinero(cambio.abs()),
                        style: TextStyle(
                          color: falta ? AppColors.error : AppColors.success,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MontoRapido extends StatelessWidget {
  const _MontoRapido({
    required this.texto,
    required this.elegido,
    required this.onPressed,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      selected: elegido,
      child: Material(
        color: elegido ? AppColors.accent : c.containerBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  texto,
                  style: TextStyle(
                    color: elegido ? Colors.white : c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Si algún producto quedará en negativo (el cobro sigue adelante).
class AvisoFaltantes extends StatelessWidget {
  const AvisoFaltantes({super.key, required this.controller});

  final PointOfSaleController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sinExistencias = controller.itemsSinExistencias;
      if (sinExistencias.isEmpty) return const SizedBox.shrink();
      final cuantos = sinExistencias.length;
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cuantos == 1
                    ? '${sinExistencias.first.productName} quedará como faltante'
                    : '$cuantos productos quedarán como faltantes',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// "¡Listo!": la palomita, lo cobrado y el cambio en grande, como al
/// terminar un abono.
class VentaListaContenido extends StatelessWidget {
  const VentaListaContenido({super.key, required this.venta});

  final VentaTerminada venta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final como = venta.metodo == 'mixto'
        ? 'con pago mixto'
        : 'en ${nombreMetodoDePago(venta.metodo).toLowerCase()}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 88, color: AppColors.success),
        const SizedBox(height: 20),
        Text(
          '¡Listo!',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: c.titleColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cobraste ${dinero(venta.total)} $como.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, color: c.textSecondary),
        ),
        if (venta.cambio > 0) ...[
          const SizedBox(height: 28),
          Text('Entrega de cambio',
              style: TextStyle(fontSize: 16, color: c.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              dinero(venta.cambio),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

import '../../../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/widgets/formulario.dart';

import '../../../../global_widgets/app_header.dart';
import '../../widgets/indicador_pasos.dart';

/// Nombres de las rutas del cobro en el teléfono: al terminar se quitan
/// todas de una vez y queda "¡Listo!" sobre los productos.
const rutaRevisar = '/venta/revisar';
const rutaMetodo = '/venta/metodo';
const rutaMonto = '/venta/monto';
const rutaLista = '/venta/lista';

bool esPasoDeCobro(Route<dynamic> ruta) =>
    (ruta.settings.name ?? '').startsWith('/venta/');

/// Una pantalla del cobro en el teléfono: la barra con "Paso N de 4" arriba,
/// lo de ese paso en medio y un solo botón principal abajo. Atrás regresa al
/// paso anterior sin perder nada.
class PantallaDePaso extends StatelessWidget {
  const PantallaDePaso({
    super.key,
    required this.paso,
    required this.titulo,
    required this.cuerpo,
    this.pie,
  });

  final int paso;
  final String titulo;
  final Widget cuerpo;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      conMenu: false,
      backgroundColor: c.backgroundColor,
      appBar: const GymAppBar(title: 'Cobrar'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IndicadorPasos(paso: paso, titulo: titulo),
          Expanded(child: cuerpo),
          if (pie != null) PieDeFormulario(child: pie!),
        ],
      ),
    );
  }
}

/// El total en grande, arriba de los pasos de pago, con cómo paga si ya
/// se eligió.
class TotalACobrar extends StatelessWidget {
  const TotalACobrar({super.key, required this.total, this.detalle});

  final String total;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borde),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total a cobrar',
                    style: TextStyle(color: c.textSecondary, fontSize: 15)),
                if (detalle != null)
                  Text(detalle!,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                total,
                style: TextStyle(
                  color: c.titleColor,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

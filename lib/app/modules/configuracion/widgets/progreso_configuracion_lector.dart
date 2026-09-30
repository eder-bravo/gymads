import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/agregar_lector_controller.dart';

/// El lector no informa un porcentaje. El avance entre hitos es estimado;
/// el 100% se reserva para la confirmación por red y el guardado completos.
class ProgresoConfiguracionLector extends StatelessWidget {
  const ProgresoConfiguracionLector({
    super.key,
    required this.paso,
    this.esperandoRespuesta = false,
    this.guardando = false,
  });

  final PasoAgregar paso;
  final bool esperandoRespuesta;
  final bool guardando;

  @override
  Widget build(BuildContext context) {
    // Al elegir la red o escribir, el espacio se reserva para los campos y
    // el teclado. El porcentaje acompaña las esperas y el resultado final.
    if (paso == PasoAgregar.fallo ||
        paso == PasoAgregar.elegirRed ||
        paso == PasoAgregar.escribirClave) {
      return const SizedBox.shrink();
    }
    final c = context.colores;
    final (double desde, double hasta, int segundos) = switch (paso) {
      PasoAgregar.buscando => (5, 15, 15),
      PasoAgregar.preparando => (20, 30, 15),
      PasoAgregar.elegirRed => (35, 35, 0),
      PasoAgregar.escribirClave => (40, 40, 0),
      PasoAgregar.conectando =>
        esperandoRespuesta ? (55, 90, 75) : (45, 55, 15),
      PasoAgregar.comprobando => guardando ? (95, 95, 0) : (90, 95, 35),
      PasoAgregar.listo => (100, 100, 0),
      PasoAgregar.fallo => (0, 0, 0),
    };
    final listo = paso == PasoAgregar.listo;
    final color = listo ? AppColors.success : AppColors.accent;

    return TweenAnimationBuilder<double>(
      key: ValueKey((paso, esperandoRespuesta, guardando)),
      tween: Tween(begin: desde, end: hasta),
      duration: Duration(seconds: segundos),
      builder: (context, avance, _) {
        final porcentaje = avance.floor();
        return Semantics(
          label: listo
              ? 'Configuración completada, 100 por ciento'
              : 'Avance estimado, $porcentaje por ciento',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                '$porcentaje%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: avance / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: c.divisor,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                listo ? 'Configuración completada' : 'Avance estimado',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}

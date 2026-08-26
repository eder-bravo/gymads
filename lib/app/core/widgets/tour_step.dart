import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/theme/app_colors.dart';

/// Un paso del tour de bienvenida.
///
/// Envuelve al widget destacado con la burbuja explicativa y su flecha. Es el
/// único sitio donde se define el aspecto del tour: colores, tipografías y
/// botones ("Saltar", "Anterior", "Siguiente") salen iguales en todas las
/// pantallas porque todas pasan por aquí.
///
/// El recorrido al que pertenece el paso no se declara aquí sino en el orden
/// de las claves que la pantalla le pasa a
/// `WelcomeTourService.startIfPending()`.
class TourStep extends StatelessWidget {
  /// Identifica el paso dentro del recorrido. Tiene que ser estable entre
  /// reconstrucciones, así que vive en el controlador de la pantalla y nunca
  /// se crea dentro de un `build`.
  final GlobalKey tourKey;

  final String title;
  final String description;

  /// Radio del hueco que resalta al widget. Conviene igualarlo al del propio
  /// widget para que el recorte no desentone.
  final double borderRadius;

  /// En el primer paso no hay a dónde volver y en el último no queda nada por
  /// saltar; los botones se omiten en consecuencia.
  final bool isFirstStep;
  final bool isLastStep;

  final Widget child;

  const TourStep({
    super.key,
    required this.tourKey,
    required this.title,
    required this.description,
    required this.child,
    this.borderRadius = 16,
    this.isFirstStep = false,
    this.isLastStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <TooltipActionButton>[
      // En el último paso no tiene sentido saltar: ya no queda nada por ver.
      if (!isLastStep)
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          name: 'Saltar',
          backgroundColor: Colors.transparent,
          textStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      // En el primer paso no hay a dónde volver.
      if (!isFirstStep)
        TooltipActionButton(
          type: TooltipDefaultActionType.previous,
          name: 'Anterior',
          backgroundColor: Colors.white.withOpacity(0.08),
          textStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      TooltipActionButton(
        // `next` en el último paso ya termina el tour por sí solo (según la
        // API de showcaseview); solo cambia la etiqueta para que lo diga.
        type: TooltipDefaultActionType.next,
        name: isLastStep ? 'Entendido' : 'Siguiente',
        backgroundColor: AppColors.brand,
        textStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];

    return Showcase(
      key: tourKey,
      title: title,
      description: description,
      tooltipBackgroundColor: AppColors.cardBackground,
      textColor: AppColors.textPrimary,
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      descTextStyle: TextStyle(
        fontSize: 13,
        height: 1.35,
        color: AppColors.textSecondary.withOpacity(0.85),
      ),
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      tooltipBorderRadius: BorderRadius.circular(16),
      targetBorderRadius: BorderRadius.circular(borderRadius),
      targetPadding: const EdgeInsets.all(6),
      // Sin esto, tocar el elemento resaltado dispararía su acción real (abrir
      // un módulo, agregar un cliente…) en vez de avanzar el tour.
      disableDefaultTargetGestures: true,
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.spaceBetween,
        position: TooltipActionPosition.inside,
        gapBetweenContentAndAction: 14,
      ),
      tooltipActions: actions,
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/services/welcome_tour_service.dart';
import '../utils/plataforma_app.dart';

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
    final c = context.colores;
    final actions = <TooltipActionButton>[
      // En el último paso no tiene sentido saltar: ya no queda nada por ver.
      if (!isLastStep)
        TooltipActionButton(
          type: TooltipDefaultActionType.skip,
          // En computadora, Esc también salta.
          name: PlataformaApp.escritorio ? 'Saltar (Esc)' : 'Saltar',
          backgroundColor: Colors.transparent,
          textStyle: TextStyle(
            color: c.textSecondary.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      // En el primer paso no hay a dónde volver.
      if (!isFirstStep)
        TooltipActionButton(
          type: TooltipDefaultActionType.previous,
          name: 'Anterior',
          backgroundColor: c.contraste.withOpacity(0.08),
          textStyle: TextStyle(
            color: c.textPrimary,
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
      tooltipBackgroundColor: c.cardBackground,
      textColor: c.textPrimary,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      descTextStyle: TextStyle(
        fontSize: 13,
        height: 1.35,
        color: c.textSecondary.withOpacity(0.85),
      ),
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      tooltipBorderRadius: BorderRadius.circular(16),
      targetBorderRadius: BorderRadius.circular(borderRadius),
      targetPadding: const EdgeInsets.all(6),
      // La zona resaltada atrapa los toques y los arrastres, y tocarla no
      // hace nada: el tour se maneja solo con sus botones.
      //
      // Antes estaba `disableDefaultTargetGestures: true`, que NO bloquea: deja
      // pasar los gestos por el hueco del resaltado a la pantalla de abajo.
      // Arrastrando sobre una lista o una tarjeta resaltada, la pantalla se
      // desplazaba a mitad del tour (y un toque podía abrir el módulo).
      disposeOnTap: false,
      onTargetClick: () {},
      tooltipActionConfig: const TooltipActionConfig(
        alignment: MainAxisAlignment.spaceBetween,
        position: TooltipActionPosition.inside,
        gapBetweenContentAndAction: 14,
      ),
      tooltipActions: actions,
      child: _DondeEstaElPaso(
        paso: tourKey,
        child: _bloqueoDuranteElTour(),
      ),
    );
  }

  /// Mientras hay un recorrido en pantalla, el elemento resaltado no recibe
  /// gestos y sus arrastres no llegan a la pantalla: queda fija hasta que el
  /// tour termina o se salta.
  ///
  /// Hace falta porque showcaseview deja un hueco sobre lo resaltado (y lo
  /// envuelve en una región "transparente"): los toques y arrastres pasaban a
  /// la pantalla de abajo, y se podía desplazar a mitad del tour.
  /// - `AbsorbPointer`: el elemento (una lista, una tarjeta) no reacciona.
  /// - El `GestureDetector` de fuera se queda con los arrastres antes que la
  ///   pantalla que lo contiene (el detector más interno gana).
  /// Siempre están en el árbol (solo se activan): así el elemento no se
  /// reconstruye ni pierde su estado al empezar o terminar el tour.
  Widget _bloqueoDuranteElTour() {
    return ValueListenableBuilder<bool>(
      valueListenable: WelcomeTourService.recorridoEnCurso,
      child: child,
      builder: (context, enCurso, hijo) => PopScope(
        // Se registra en la ruta, también si el paso está fuera de pantalla.
        // Bloquea Atrás de Android y el gesto desde el borde de iOS/GetX.
        canPop: !enCurso,
        child: GestureDetector(
          behavior:
              enCurso ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
          onVerticalDragStart: enCurso ? (_) {} : null,
          onHorizontalDragStart: enCurso ? (_) {} : null,
          child: AbsorbPointer(absorbing: enCurso, child: hijo),
        ),
      ),
    );
  }
}

/// Le dice a [WelcomeTourService] en qué pantalla quedó el paso, para que no
/// arranque su recorrido si hay otra pantalla encima.
class _DondeEstaElPaso extends StatefulWidget {
  const _DondeEstaElPaso({required this.paso, required this.child});

  final GlobalKey paso;
  final Widget child;

  @override
  State<_DondeEstaElPaso> createState() => _DondeEstaElPasoState();
}

class _DondeEstaElPasoState extends State<_DondeEstaElPaso> {
  @override
  void initState() {
    super.initState();
    WelcomeTourService.pasoMontado(widget.paso, context);
  }

  @override
  void didUpdateWidget(_DondeEstaElPaso anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.paso != widget.paso) {
      WelcomeTourService.pasoDesmontado(anterior.paso, context);
      WelcomeTourService.pasoMontado(widget.paso, context);
    }
  }

  @override
  void dispose() {
    WelcomeTourService.pasoDesmontado(widget.paso, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

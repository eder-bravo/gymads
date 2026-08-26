import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/services/welcome_tour_service.dart';

/// Añade el tour de bienvenida a la pantalla de un módulo.
///
/// El controlador solo declara qué recorrido es y en qué orden van sus pasos;
/// del resto (si toca mostrarlo, cuándo y cómo se ve) se encargan
/// [WelcomeTourService] y `TourStep`.
///
/// Se engancha a `onReady` y no a `onInit` porque los widgets `Showcase` se
/// registran al construirse: en `onInit` la pantalla todavía no existe.
mixin ScreenTourMixin on GetxController {
  /// Uno de [AppTours].
  String get tourId;

  /// Las claves de los pasos, en el orden en que deben mostrarse. Deben ser
  /// campos del controlador: creadas dentro de un `build` cambiarían en cada
  /// frame y el tour no encontraría a qué apuntar.
  List<GlobalKey> get tourSteps;

  @override
  void onReady() {
    super.onReady();
    WelcomeTourService.to.startIfPending(tourId, tourSteps);
  }
}

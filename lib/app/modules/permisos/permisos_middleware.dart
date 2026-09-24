import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/services/permisos_app.dart';
import '../../routes/app_pages.dart';

/// Antes de Inicio, la primera vez en este teléfono, la pantalla de permisos.
///
/// Va en la ruta de Inicio y no en cada entrada (login, código de staff,
/// registro, asistente inicial, sesión ya abierta): todas terminan ahí.
class PermisosMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) => destinoAntesDeInicio();
}

/// La ruta a la que hay que ir en vez de Inicio, o null si ninguna.
RouteSettings? destinoAntesDeInicio() => PermisosApp.yaSePidieron
    ? null
    : const RouteSettings(name: Routes.PERMISOS);

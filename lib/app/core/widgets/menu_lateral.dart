import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/services/tenant_context_service.dart';
import '../../routes/app_pages.dart';
import '../permissions/permissions.dart';
import 'tour_step.dart';

/// Una sección de la barra lateral de escritorio.
class SeccionDelMenu {
  const SeccionDelMenu({
    required this.ruta,
    required this.etiqueta,
    required this.icono,
    required this.color,
    this.permiso,
  });

  final String ruta;
  final String etiqueta;
  final IconData icono;
  final Color color;

  /// Sin permiso, la sección no aparece (igual que en Inicio del teléfono).
  final Permission? permiso;
}

/// Marca las pantallas que llevan la barra lateral: ahí la pantalla principal
/// de cada sección no necesita flecha atrás.
class ConMenuLateral extends InheritedWidget {
  const ConMenuLateral({super.key, required super.child});

  static bool en(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConMenuLateral>() != null;

  @override
  bool updateShouldNotify(ConMenuLateral oldWidget) => false;
}

/// Un paso del recorrido de bienvenida que apunta a una sección del menú.
/// Solo Inicio los pasa: las claves no pueden repetirse en dos pantallas.
class PasoDelMenu {
  const PasoDelMenu({
    required this.clave,
    required this.titulo,
    required this.descripcion,
    this.ultimo = false,
  });

  final GlobalKey clave;
  final String titulo;
  final String descripcion;
  final bool ultimo;
}

/// La barra lateral de escritorio: siempre a la vista, con el nombre de cada
/// sección y la actual resaltada. Va dentro de cada pantalla (no por encima
/// del navegador), así los diálogos la cubren y los recorridos la encuentran.
///
/// Al cambiar de sección se vuelve a Inicio y se abre la nueva encima: Inicio
/// queda siempre debajo, que es donde se muestran los avisos del lector.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key, this.pasos = const {}});

  /// Pasos del recorrido de Inicio, por ruta de la sección.
  final Map<String, PasoDelMenu> pasos;

  static const ancho = 232.0;

  /// Ancho de la franja que queda cuando el menú está oculto.
  static const anchoRiel = 64.0;

  // ─── Ocultar el menú ───
  //
  // La barra se puede ocultar para dar todo el ancho al contenido. Queda una
  // franja angosta con los íconos de las secciones y el botón para volver a
  // mostrarla. Se recuerda entre una sesión y otra.

  static const _claveOculto = 'menu_lateral_oculto';

  /// Si el menú está oculto. Compartido: todas las pantallas lo siguen.
  static final oculto = ValueNotifier<bool>(false);

  static bool _recordar = false;

  /// Lee lo que se eligió la última vez. Va en `main()`, después de iniciar
  /// el almacenamiento: sin esa llamada (en las pruebas) el menú no lee ni
  /// guarda nada.
  static void cargarPreferencia() {
    _recordar = true;
    oculto.value = GetStorage().read<bool>(_claveOculto) ?? false;
  }

  /// Oculta o muestra el menú, y lo recuerda.
  static void alternar() {
    oculto.value = !oculto.value;
    if (_recordar) GetStorage().write(_claveOculto, oculto.value);
  }

  /// Lo muestra sin cambiar lo que la persona eligió: el recorrido de
  /// bienvenida señala las secciones del menú y necesita verlas.
  static void mostrarParaRecorrido() => oculto.value = false;

  static const secciones = [
    SeccionDelMenu(
      ruta: Routes.HOME,
      etiqueta: 'Inicio',
      icono: Icons.dashboard_outlined,
      color: AppColors.brand,
    ),
    SeccionDelMenu(
      ruta: Routes.CLIENTES,
      etiqueta: 'Clientes',
      icono: Icons.people_alt_outlined,
      color: Color(0xFF667eea),
      permiso: Permission.gestionarClientes,
    ),
    SeccionDelMenu(
      ruta: Routes.ABONAR,
      etiqueta: 'Abonar',
      icono: Icons.payments_outlined,
      color: Color(0xFFf5576c),
      permiso: Permission.cobrarAbonos,
    ),
    SeccionDelMenu(
      ruta: Routes.POINT_OF_SALE,
      etiqueta: 'Vender',
      icono: Icons.storefront_outlined,
      color: Color(0xFF4facfe),
      permiso: Permission.vender,
    ),
    SeccionDelMenu(
      ruta: Routes.INVENTARIO,
      etiqueta: 'Inventario',
      icono: Icons.inventory_2_outlined,
      color: Color(0xFF43e97b),
      permiso: Permission.verInventario,
    ),
    SeccionDelMenu(
      ruta: Routes.INGRESOS,
      etiqueta: 'Ingresos',
      icono: Icons.receipt_long_outlined,
      color: AppColors.accent,
      permiso: Permission.verIngresos,
    ),
    SeccionDelMenu(
      ruta: Routes.ACCESS_LOGS,
      etiqueta: 'Entradas',
      icono: Icons.door_sliding_outlined,
      color: Color(0xFF81C784),
      permiso: Permission.verAccesos,
    ),
  ];

  static const configuracion = SeccionDelMenu(
    ruta: Routes.CONFIGURACION,
    etiqueta: 'Configuración',
    icono: Icons.settings_outlined,
    color: Color(0xFF90A4AE),
  );

  /// La sección a la que pertenece una ruta ("/inventario/categorias" es de
  /// Inventario). null para pantallas sin nombre de sección.
  static String? seccionDe(String? ruta) {
    if (ruta == null) return null;
    for (final s in [...secciones, configuracion]) {
      if (ruta == s.ruta || ruta.startsWith('${s.ruta}/')) return s.ruta;
    }
    return null;
  }

  /// Si [ruta] es la pantalla principal de una sección (sin flecha atrás).
  static bool esRaiz(String? ruta) =>
      ruta != null && [...secciones, configuracion].any((s) => s.ruta == ruta);

  /// Lleva la pila de pantallas (se registra en `navigatorObservers`).
  static final observador = _ObservadorDeSecciones();

  /// La sección de [ruta]. Una pantalla de detalle (sin nombre de sección)
  /// marca la sección de la que se abrió: la más cercana debajo en la pila.
  static String seccionDeRuta(Route<dynamic>? ruta) {
    final propia = seccionDe(ruta?.settings.name);
    if (propia != null) return propia;
    if (ruta == null) return Routes.HOME;
    final pila = _ObservadorDeSecciones.pila;
    for (var i = pila.indexOf(ruta) - 1; i >= 0; i--) {
      final debajo = seccionDe(pila[i].settings.name);
      if (debajo != null) return debajo;
    }
    return Routes.HOME;
  }

  /// Las secciones que este rol puede abrir.
  static List<SeccionDelMenu> visibles() => [
        for (final s in secciones)
          if (s.permiso == null || _puede(s.permiso!)) s,
      ];

  static bool _puede(Permission permiso) {
    try {
      return TenantContextService.to.can(permiso);
    } catch (_) {
      return false;
    }
  }

  /// Va a [ruta]: regresa a Inicio y abre la sección encima.
  ///
  /// Si la sección ya está abierta y se está en una de sus subpantallas
  /// (Cuenta dentro de Configuración), solo se regresa a ella. Cerrar todo y
  /// abrir otra igual dejaba a las dos a la vez durante la transición, y la
  /// que salía se llevaba el controlador que compartían con la nueva.
  static void ir(String ruta) {
    if (Get.currentRoute == ruta) return;
    if (ruta != Routes.HOME && _ObservadorDeSecciones.estaAbierta(ruta)) {
      Get.until((r) => r.settings.name == ruta);
      return;
    }
    Get.until((r) => r.settings.name == Routes.HOME || r.isFirst);
    if (ruta != Routes.HOME) {
      Get.toNamed(ruta);
    } else if (Get.currentRoute != Routes.HOME) {
      Get.offAllNamed(Routes.HOME);
    }
  }

  static bool get _esMac => defaultTargetPlatform == TargetPlatform.macOS;

  /// "⌘1" en macOS, "Ctrl+1" en Windows.
  static String textoAtajo(String tecla) => _esMac ? '⌘$tecla' : 'Ctrl+$tecla';

  static SingleActivator atajo(LogicalKeyboardKey tecla) =>
      SingleActivator(tecla, meta: _esMac, control: !_esMac);

  static const _digitos = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// ⌘/Ctrl + número abre cada sección en orden y ⌘/Ctrl + coma,
  /// Configuración, como en las apps de escritorio.
  static Map<ShortcutActivator, VoidCallback> atajos() {
    final visibles = MenuLateral.visibles();
    return {
      for (var i = 0; i < visibles.length && i < _digitos.length; i++)
        atajo(_digitos[i]): () => ir(visibles[i].ruta),
      atajo(LogicalKeyboardKey.comma): () => ir(configuracion.ruta),
      atajo(LogicalKeyboardKey.keyB): alternar,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final actual = seccionDeRuta(ModalRoute.of(context));
    final visibles = MenuLateral.visibles();

    Widget item(SeccionDelMenu s, String? atajo) {
      final fila = _ItemDelMenu(
        seccion: s,
        seleccionada: s.ruta == actual,
        atajo: atajo,
      );
      final paso = pasos[s.ruta];
      if (paso == null) return fila;
      return TourStep(
        tourKey: paso.clave,
        title: paso.titulo,
        description: paso.descripcion,
        borderRadius: 12,
        isLastStep: paso.ultimo,
        child: fila,
      );
    }

    return Material(
      color: c.cardBackground,
      child: SizedBox(
        width: ancho,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                child: Row(
                  children: [
                    // El logo de la app, el mismo del inicio de sesión.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo_app.png',
                        width: 40,
                        height: 40,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'GymOne',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    // Arriba, junto al logo, como en las apps de Mac: en el
                    // mismo lugar con el menú abierto y oculto.
                    const BotonDelMenu(),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < visibles.length; i++)
                      item(visibles[i],
                          i < _digitos.length ? textoAtajo('${i + 1}') : null),
                  ],
                ),
              ),
              Divider(height: 1, color: c.divisor),
              Padding(
                padding: const EdgeInsets.all(12),
                child: item(configuracion, textoAtajo(',')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El menú oculto: una franja con los íconos de las secciones (cada uno con
/// su nombre al pasar el mouse) y el botón para volver a mostrarlo.
class RielDelMenu extends StatelessWidget {
  const RielDelMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final actual = MenuLateral.seccionDeRuta(ModalRoute.of(context));
    Widget icono(SeccionDelMenu s) {
      final seleccionada = s.ruta == actual;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: s.etiqueta,
          child: Semantics(
            label: s.etiqueta,
            selected: seleccionada,
            button: true,
            child: Material(
              color: seleccionada
                  ? AppColors.accent.withOpacity(0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => MenuLateral.ir(s.ruta),
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(seleccionada ? 0.25 : 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(s.icono, size: 20, color: s.color),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: c.cardBackground,
      child: SizedBox(
        width: MenuLateral.anchoRiel,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // El mismo botón, en el mismo lugar que con el menú abierto.
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 20, 8, 16),
                child: Center(child: BotonDelMenu()),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final s in MenuLateral.visibles()) icono(s),
                  ],
                ),
              ),
              Divider(height: 1, color: c.divisor),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: icono(MenuLateral.configuracion),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oculta o muestra el menú: el ícono de panel lateral de las apps de Mac,
/// con su nombre al pasar el mouse.
class BotonDelMenu extends StatelessWidget {
  const BotonDelMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ValueListenableBuilder<bool>(
      valueListenable: MenuLateral.oculto,
      builder: (context, oculto, _) => IconButton(
        onPressed: MenuLateral.alternar,
        tooltip: '${oculto ? 'Mostrar' : 'Ocultar'} menú '
            '(${MenuLateral.textoAtajo('B')})',
        icon: const Icon(Icons.view_sidebar_outlined),
        iconSize: 22,
        color: c.textSecondary,
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _ItemDelMenu extends StatelessWidget {
  const _ItemDelMenu({
    required this.seccion,
    required this.seleccionada,
    required this.atajo,
  });

  final SeccionDelMenu seccion;
  final bool seleccionada;
  final String? atajo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final s = seccion;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        selected: seleccionada,
        button: true,
        child: Material(
          color: seleccionada
              ? AppColors.accent.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => MenuLateral.ir(s.ruta),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: s.color.withOpacity(seleccionada ? 0.25 : 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s.icono, size: 20, color: s.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: seleccionada ? AppColors.accent : c.textPrimary,
                        fontSize: 15,
                        fontWeight:
                            seleccionada ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  // Con texto grande el atajo se encoge: el nombre va primero.
                  if (atajo != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 52),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          atajo!,
                          style: TextStyle(
                            color: c.textSecondary.withOpacity(0.7),
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObservadorDeSecciones extends NavigatorObserver {
  static final pila = <Route<dynamic>>[];

  /// Si hay una pantalla con ese nombre abierta en el navegador. Solo cuentan
  /// las activas: las de pruebas o navegadores ya desmontados no.
  static bool estaAbierta(String ruta) =>
      pila.any((r) => r.isActive && r.settings.name == ruta);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pila.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pila.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pila.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : pila.indexOf(oldRoute);
    if (newRoute == null) {
      if (i >= 0) pila.removeAt(i);
    } else if (i >= 0) {
      pila[i] = newRoute;
    } else {
      pila.add(newRoute);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/plataforma_app.dart';

/// Piezas comunes de los formularios, para que todos se vean igual: el mismo
/// botón para guardar, los mismos títulos de sección y la misma nota de campos
/// obligatorios. Los campos toman su estilo del tema (`inputDecorationTheme`).

/// El botón de la acción principal de un formulario.
///
/// Mientras [guardando] está desactivado y dice "Guardando…": un segundo toque
/// no manda otro guardado. En pantalla completa del teléfono ocupa todo el
/// ancho; en escritorio toma el ancho de su texto (mínimo 200), y en un
/// diálogo va [compacto], junto a "Cancelar".
///
/// En computadora, el [compacto] de un diálogo también se pulsa con Enter
/// ([EnterConfirma]).
class BotonGuardar extends StatelessWidget {
  const BotonGuardar({
    super.key,
    required this.texto,
    required this.onPressed,
    this.guardando = false,
    this.compacto = false,
    this.icono,
    this.color,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool guardando;
  final bool compacto;
  final IconData? icono;

  /// Otro color para la acción: `AppColors.error` en las peligrosas
  /// (eliminar, desvincular). Por defecto, naranja.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // El botón es naranja (o rojo) en los dos modos: lo de adentro, blanco.
    final etiqueta = guardando
        ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 10),
              Text('Guardando…'),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
            ],
          );

    final fondo = color ?? AppColors.accent;
    final boton = ElevatedButton(
      onPressed: guardando ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: fondo,
        foregroundColor: Colors.white,
        disabledBackgroundColor: fondo.withOpacity(0.5),
        disabledForegroundColor: Colors.white.withOpacity(0.85),
        minimumSize: compacto
            ? const Size(0, 44)
            : PlataformaApp.pantallaGrande
                ? const Size(200, 46)
                : const Size.fromHeight(48),
        padding: EdgeInsets.symmetric(horizontal: compacto ? 18 : 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      child: etiqueta,
    );
    if (!compacto || !PlataformaApp.escritorio) return boton;
    return _EnterConfirma(
        alConfirmar: guardando ? null : onPressed, child: boton);
  }
}

/// En computadora, Enter pulsa el botón principal del diálogo de enfrente
/// (el [BotonGuardar] compacto: Eliminar, Autorizar, Entendido, Guardar…).
/// Solo en diálogos: los formularios grandes (Guardar cliente) y las
/// pantallas (Cobrar) siguen pidiendo clic.
///
/// Se respeta lo que Enter ya hace: con un botón enfocado (llegando con Tab)
/// lo pulsa a él, en un campo de varias líneas hace un renglón nuevo y en un
/// campo que pasa al siguiente o envía por su cuenta, hace eso. Tampoco
/// confirma el Enter con el que un lector de códigos cierra una lectura (el
/// código llega de golpe, tecla tras tecla en milisegundos).
abstract final class EnterConfirma {
  static final _botones = <_EnterConfirmaState>[];

  /// Teclas seguidas, cada una a menos de [_rapida] de la anterior.
  static int _rafaga = 0;
  static Duration? _ultimaTecla;
  static const _rapida = Duration(milliseconds: 60);

  static void _registrar(_EnterConfirmaState boton) {
    if (_botones.isEmpty) FocusManager.instance.addLateKeyEventHandler(tecla);
    _botones.add(boton);
  }

  static void _quitar(_EnterConfirmaState boton) {
    _botones.remove(boton);
    if (_botones.isEmpty) {
      FocusManager.instance.removeLateKeyEventHandler(tecla);
      _rafaga = 0;
      _ultimaTecla = null;
    }
  }

  @visibleForTesting
  static KeyEventResult tecla(KeyEvent evento) {
    if (evento is! KeyDownEvent || evento.synthesized) {
      return KeyEventResult.ignored;
    }
    final seguida =
        _ultimaTecla != null && evento.timeStamp - _ultimaTecla! <= _rapida;
    final previas = seguida ? _rafaga : 0;
    final esEnter = evento.logicalKey == LogicalKeyboardKey.enter ||
        evento.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!esEnter) {
      _rafaga = previas + 1;
      _ultimaTecla = evento.timeStamp;
      return KeyEventResult.ignored;
    }
    _rafaga = 0;
    _ultimaTecla = null;
    // El Enter final de un lector de códigos.
    if (previas >= 3) return KeyEventResult.ignored;

    final teclado = HardwareKeyboard.instance;
    if (teclado.isMetaPressed ||
        teclado.isControlPressed ||
        teclado.isAltPressed ||
        teclado.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final campo = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>()
        ?.widget;
    if (campo != null &&
        (campo.maxLines != 1 ||
            campo.onSubmitted != null ||
            campo.textInputAction == TextInputAction.next)) {
      return KeyEventResult.ignored;
    }
    // Con más de uno a la vista no se adivina cuál: se queda en clic.
    final listos = [
      for (final b in _botones)
        if (b.listo) b
    ];
    if (listos.length != 1) return KeyEventResult.ignored;
    listos.single.widget.alConfirmar!();
    return KeyEventResult.handled;
  }
}

class _EnterConfirma extends StatefulWidget {
  const _EnterConfirma({required this.alConfirmar, required this.child});

  /// Null mientras está desactivado o guardando.
  final VoidCallback? alConfirmar;
  final Widget child;

  @override
  State<_EnterConfirma> createState() => _EnterConfirmaState();
}

class _EnterConfirmaState extends State<_EnterConfirma> {
  ModalRoute<Object?>? _ruta;

  /// Activo y en el diálogo de enfrente.
  bool get listo {
    final ruta = _ruta;
    return mounted &&
        widget.alConfirmar != null &&
        ruta is PopupRoute &&
        ruta.isCurrent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ruta = ModalRoute.of(context);
  }

  @override
  void initState() {
    super.initState();
    EnterConfirma._registrar(this);
  }

  @override
  void dispose() {
    EnterConfirma._quitar(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// El botón fijo al pie de un formulario de pantalla completa
/// (`Scaffold.bottomNavigationBar`), con su margen y la zona segura.
///
/// Sube con el teclado: el `bottomNavigationBar` de un Scaffold se queda
/// abajo, y el botón quedaba escondido detrás del teclado (el numérico del
/// iPhone ni siquiera tiene tecla para cerrarse), así que no había cómo
/// guardar.
///
/// En escritorio la acción va a la derecha, como en las ventanas del sistema,
/// en vez de una barra que cruza toda la pantalla.
class PieDeFormulario extends StatelessWidget {
  const PieDeFormulario({super.key, required this.child, this.alCancelar});

  final Widget child;

  /// En escritorio pone "Cancelar" a la izquierda del botón principal (en
  /// el teléfono se sale con la X o el gesto de atrás, como siempre).
  final VoidCallback? alCancelar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: _pie(c),
    );
  }

  Widget _pie(ColoresTema c) {
    return Container(
      decoration: BoxDecoration(
        color: c.backgroundColor,
        border: Border(
          top: BorderSide(color: c.divisor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: PlataformaApp.pantallaGrande
              ? Align(
                  alignment: Alignment.centerRight,
                  heightFactor: 1,
                  // Wrap y no Row: con texto grande, "Cancelar" sube a su
                  // propio renglón en vez de salirse de la ventana.
                  child: alCancelar == null
                      ? child
                      : Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            BotonCancelar(onPressed: alCancelar),
                            child,
                          ],
                        ),
                )
              : child,
        ),
      ),
    );
  }
}

/// "Cancelar" de un diálogo: texto gris, al lado de [BotonGuardar] compacto.
class BotonCancelar extends StatelessWidget {
  const BotonCancelar({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c.textSecondary,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: const Text('Cancelar'),
    );
  }
}

/// El título de un grupo de campos ("Datos del cliente", "Qué podrá hacer").
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.detalle});

  final String texto;

  /// Una línea de ayuda debajo, más tenue.
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 2),
            Text(
              detalle!,
              style: TextStyle(
                color: c.textSecondary.withOpacity(0.85),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "* Obligatorio", bajo los campos que lo llevan en la etiqueta.
class NotaObligatorio extends StatelessWidget {
  const NotaObligatorio({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Text(
      '* Obligatorio',
      style: TextStyle(
        color: c.textSecondary.withOpacity(0.85),
        fontSize: 12,
      ),
    );
  }
}

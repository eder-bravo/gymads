import 'package:flutter/material.dart';

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
    return ElevatedButton(
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
  }
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

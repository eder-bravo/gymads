import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Piezas comunes de los formularios, para que todos se vean igual: el mismo
/// botón para guardar, los mismos títulos de sección y la misma nota de campos
/// obligatorios. Los campos toman su estilo del tema (`inputDecorationTheme`).

/// El botón de la acción principal de un formulario.
///
/// Mientras [guardando] está desactivado y dice "Guardando…": un segundo toque
/// no manda otro guardado. En pantalla completa ocupa todo el ancho; en un
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
        minimumSize:
            compacto ? const Size(0, 44) : const Size.fromHeight(48),
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
class PieDeFormulario extends StatelessWidget {
  const PieDeFormulario({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: child,
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
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 2),
            Text(
              detalle!,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.85),
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
    return Text(
      '* Obligatorio',
      style: TextStyle(
        color: AppColors.textSecondary.withOpacity(0.85),
        fontSize: 12,
      ),
    );
  }
}

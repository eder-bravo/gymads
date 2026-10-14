import 'package:flutter/material.dart';
import 'package:gymads/core/theme/app_colors.dart';
import '../core/utils/plataforma_app.dart';
import '../core/widgets/diseno_escritorio.dart';
import '../core/widgets/menu_lateral.dart';

/// AppBar estándar de la aplicación.
///
/// Único lugar donde se define el estilo del header: título alineado a la
/// izquierda, fondo y colores del tema (`appBarTheme`, en claro u oscuro) y
/// sin sombra. Al ir en el `appBar` del Scaffold queda fijo: el contenido hace scroll debajo sin moverlo.
class GymAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const GymAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final margen = AnchoContenido.margen(context);
    // En pantalla grande las acciones llevan texto: con letra muy grande en
    // una ventana angosta se encogen antes que salirse de la barra.
    final acciones = actions == null ||
            actions!.isEmpty ||
            !PlataformaApp.pantallaGrande
        ? actions
        : [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.sizeOf(context).width - margen * 2) * 0.7,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ),
            ),
          ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margen),
      child: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        titleSpacing: 16,
        leading: leading,
        // En escritorio la barra lateral lleva de una sección a otra: la
        // pantalla principal de cada sección no necesita flecha atrás.
        automaticallyImplyLeading: !(ConMenuLateral.en(context) &&
            MenuLateral.esRaiz(ModalRoute.of(context)?.settings.name)),
        actions: acciones,
        bottom: bottom,
      ),
    );
  }
}

/// Campo de búsqueda estándar de la aplicación.
///
/// Mismos colores y forma en todas las vistas que tengan buscador.
class AppSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  const AppSearchField({
    super.key,
    required this.hintText,
    this.onChanged,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        // Relleno, borde y foco como todos los campos (tema); solo más
        // redondeado, porque es un buscador.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

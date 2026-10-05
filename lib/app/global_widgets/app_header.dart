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

/// Datos de un chip de categoría. Tipo de transporte propio para que este
/// archivo siga siendo genérico y no dependa de los modelos de producto.
class CategoryChipData {
  final String id;
  final String label;
  final IconData icon;

  const CategoryChipData({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Filtro de categorías estándar de la aplicación (chips horizontales).
///
/// Diseño base tomado de Inventario: mismos colores, forma y comportamiento
/// en cualquier vista que necesite filtrar una lista por categoría.
///
/// El chip "Todas" vale `null`, no un texto: antes era el literal 'Todas' y
/// una categoría llamada así rompía el filtro para siempre. Como `null` no
/// puede ser un id, la colisión ya es imposible.
class CategoryFilterChips extends StatelessWidget {
  final List<CategoryChipData> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final String allLabel;
  final IconData allIcon;

  const CategoryFilterChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.allLabel = 'Todas',
    this.allIcon = Icons.apps,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final items = <CategoryChipData>[
      CategoryChipData(id: '', label: allLabel, icon: allIcon),
      ...categories,
    ];

    // Una fila que se desplaza de lado; en pantalla grande con barra visible,
    // rueda y arrastre del mouse para llegar a las categorías que no caben.
    return FilaDesplazable(
      children: items.map((item) {
        final isAll = item.id.isEmpty;
        final isSelected = isAll ? selectedId == null : selectedId == item.id;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: FilterChip(
            avatar: Icon(
              item.icon,
              size: 18,
              color: isSelected ? c.textPrimary : c.textSecondary,
            ),
            label: Text(
              item.label,
              style: TextStyle(
                color: isSelected ? c.textPrimary : c.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            // Sin esto Material sustituye el avatar por una palomita al
            // seleccionar, y el icono desaparece justo al mirarlo.
            showCheckmark: false,
            onSelected: (_) => onSelected(isAll ? null : item.id),
            backgroundColor: c.cardBackground,
            selectedColor: AppColors.accent,
            side: BorderSide(
              color: isSelected
                  ? AppColors.accent
                  : AppColors.accent.withOpacity(0.3),
              width: 1.5,
            ),
            elevation: isSelected ? 4 : 1,
            shadowColor: AppColors.accent.withOpacity(0.3),
          ),
        );
      }).toList(),
    );
  }
}

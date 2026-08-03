import 'package:flutter/material.dart';
import 'package:gymads/core/theme/app_colors.dart';

/// AppBar estándar de la aplicación.
///
/// Único lugar donde se define el estilo del header: título alineado a la
/// izquierda, fondo [AppColors.primary] y sin sombra. Al ir en el `appBar`
/// del Scaffold queda fijo: el contenido hace scroll debajo sin moverlo.
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
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: false,
      titleSpacing: 16,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: leading,
      actions: actions,
      bottom: bottom,
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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textHint),
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.containerBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// Filtro de categorías estándar de la aplicación (chips horizontales).
///
/// Diseño base tomado de Inventario: mismos colores, forma y comportamiento
/// en cualquier vista que necesite filtrar una lista por categoría.
class CategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  final String allLabel;

  const CategoryFilterChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.allLabel = 'Todas',
  });

  @override
  Widget build(BuildContext context) {
    final items = [allLabel, ...categories];
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items.map((category) {
          final isSelected = selected == category;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onSelected(category),
              backgroundColor: AppColors.cardBackground,
              selectedColor: AppColors.accent,
              checkmarkColor: AppColors.textPrimary,
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
      ),
    );
  }
}

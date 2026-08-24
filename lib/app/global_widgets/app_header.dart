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
    final items = <CategoryChipData>[
      CategoryChipData(id: '', label: allLabel, icon: allIcon),
      ...categories,
    ];

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items.map((item) {
          final isAll = item.id.isEmpty;
          final isSelected = isAll ? selectedId == null : selectedId == item.id;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                item.icon,
                size: 18,
                color:
                    isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              label: Text(
                item.label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              // Sin esto Material sustituye el avatar por una palomita al
              // seleccionar, y el icono desaparece justo al mirarlo.
              showCheckmark: false,
              onSelected: (_) => onSelected(isAll ? null : item.id),
              backgroundColor: AppColors.cardBackground,
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
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../core/utils/category_icons.dart';

/// Rejilla de iconos disponibles para una categoría.
///
/// Los 16 iconos caben en tres filas, así que no hace falta buscador ni
/// scroll propio.
class CategoryIconPicker extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onSelected;

  const CategoryIconPicker({
    super.key,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CategoryIcons.keys.map((key) {
        final isSelected = key == selectedKey;
        return Tooltip(
          message: CategoryIcons.labelFor(key),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onSelected(key),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.containerBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              child: Icon(
                CategoryIcons.resolve(key),
                size: 22,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

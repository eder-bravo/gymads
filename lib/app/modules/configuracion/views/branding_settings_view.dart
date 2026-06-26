import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../data/services/branding_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/configuracion_controller.dart';

/// Full-screen branding settings with live preview
class BrandingSettingsView extends StatelessWidget {
  BrandingSettingsView({super.key});

  final nameController =
      TextEditingController(text: BrandingService.to.gymTitle.value);
  final selectedColor = BrandingService.to.brandColorHex.value.obs;
  final selectedFont = BrandingService.to.brandFontName.value.obs;
  final gymNameText = BrandingService.to.gymTitle.value.obs;

  final presetColors = const [
    '#10D5E8',
    '#FF5733',
    '#FFC300',
    '#28B463',
    '#8E44AD',
    '#3498DB',
    '#E74C3C',
    '#F39C12',
    '#1ABC9C',
    '#E91E63',
  ];

  final fontOptions = const [
    'Default',
    'Bebas Neue',
    'Oswald',
    'Montserrat',
    'Poppins',
    'Righteous',
  ];

  @override
  Widget build(BuildContext context) {
    // Mirror text field changes reactively
    nameController.addListener(() {
      gymNameText.value = nameController.text;
    });

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Personalizar Aplicación',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: AppColors.titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned live preview
          _buildPreview(),
          const SizedBox(height: 16),

          // Scrollable form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Obx(() {
      final text = gymNameText.value.isNotEmpty
          ? gymNameText.value.toUpperCase()
          : 'TU GIMNASIO';
      final color = BrandingService.parseHex(selectedColor.value);
      final fontName = selectedFont.value;
      final multiplier = BrandingService.fontSizeMultiplier(fontName);

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VISTA PREVIA',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: BrandingService.fontStyleFor(
                  fontName,
                  fontSize: 32 * multiplier,
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Powered by GYMONE',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.3),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(Icons.brush, color: AppColors.titleColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Marca',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gym Name
          const Text('Nombre del Gimnasio',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ej: Gold\'s Gym',
              hintStyle: TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.store,
                  color: AppColors.textSecondary, size: 20),
            ),
          ),
          const SizedBox(height: 24),

          // Color Picker
          const Text('Color de Marca',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Obx(() => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presetColors.map((hex) {
                  final isSelected = selectedColor.value == hex;
                  final color = BrandingService.parseHex(hex);
                  return GestureDetector(
                    onTap: () => selectedColor.value = hex,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              )),
          const SizedBox(height: 24),

          // Font Picker
          const Text('Tipografía',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Obx(() {
            final currentFont = selectedFont.value;
            return Wrap(
              spacing: 8,
              runSpacing: 10,
              children: fontOptions.map((font) {
                final isSelected = currentFont == font;
                return GestureDetector(
                  onTap: () => selectedFont.value = font,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.titleColor.withOpacity(0.2)
                          : AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.titleColor
                            : AppColors.textHint.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      font,
                      style: BrandingService.fontStyleFor(
                        font,
                        fontSize: 13,
                        color: isSelected
                            ? AppColors.titleColor
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  void _save() {
    final controller = Get.find<ConfiguracionController>();

    final newName = nameController.text.trim();
    final newColor = selectedColor.value;
    final newFont = selectedFont.value;

    // Always save all values to local storage
    if (newName.isNotEmpty) {
      BrandingService.to.setGymTitle(newName);
      controller.gymName.value = newName;
    }
    BrandingService.to.setBrandColor(newColor);
    controller.brandColor.value = newColor;
    BrandingService.to.setBrandFont(newFont);

    // Single DB backup with all values
    controller.backupBranding(
      name: newName.isNotEmpty ? newName : null,
      color: newColor,
      font: newFont,
    );

    SnackbarHelper.success('¡Listo!', 'Personalización guardada');
    Get.back();
  }
}

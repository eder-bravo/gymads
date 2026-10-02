import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Los temas de la app: [claro] y [oscuro]. Salen del mismo [_construir], así
/// que comparten formas, radios y tipografía; solo cambian los colores
/// ([ColoresTema]). `GetMaterialApp` recibe los dos y elige según el modo
/// guardado en `TemaService` (por defecto, el del teléfono).
class AppTheme {
  static final ThemeData claro = _construir(Brightness.light, ColoresTema.claro);
  static final ThemeData oscuro =
      _construir(Brightness.dark, ColoresTema.oscuro);

  static ThemeData _construir(Brightness brillo, ColoresTema c) {
    final esOscuro = brillo == Brightness.dark;
    final esquema = ColorScheme(
      brightness: brillo,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: c.cardBackground,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerHighest: c.containerBackground,
      outline: c.borde,
      outlineVariant: c.divisor,
    );
    // Íconos de la barra de estado que se lean sobre el fondo.
    final barraDeEstado = (esOscuro
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent);

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: c.backgroundColor,
      canvasColor: c.backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: c.backgroundColor,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: barraDeEstado,
      ),
      cardTheme: CardThemeData(
        color: c.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.cardBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: c.textSecondary, fontSize: 15),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.cardBackground,
        modalBackgroundColor: c.cardBackground,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: c.borde,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.cardBackground,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: c.textPrimary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: c.divisor, thickness: 0.5),
      iconTheme: IconThemeData(color: c.textPrimary),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((estados) =>
            estados.contains(WidgetState.selected)
                ? Colors.white
                : c.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((estados) =>
            estados.contains(WidgetState.selected) ? AppColors.accent : null),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((estados) =>
            estados.contains(WidgetState.selected) ? AppColors.accent : null),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((estados) =>
            estados.contains(WidgetState.selected)
                ? AppColors.accent
                : c.textSecondary),
      ),
      // Los selectores de fecha y hora antes necesitaban un tema oscuro
      // propio en cada pantalla; ahora lo toman de aquí, en los dos modos.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.cardBackground,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: c.textPrimary,
        // Banda del rango translúcida para que inicio y fin resalten.
        rangeSelectionBackgroundColor: AppColors.accent.withOpacity(0.25),
        rangePickerBackgroundColor: c.backgroundColor,
        rangePickerHeaderForegroundColor: c.textPrimary,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.cardBackground,
      ),
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: campos(c),
      textSelectionTheme: seleccion,
      extensions: [c],
    );
  }

  /// Un solo estilo de campo para toda la app: relleno sutil, borde tenue,
  /// foco azul y la etiqueta en el color de texto secundario del modo
  /// (con el tema de Flutter por defecto salía casi invisible).
  static InputDecorationTheme campos(ColoresTema c) => InputDecorationTheme(
        filled: true,
        fillColor: c.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.borde),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.divisor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: c.textHint.withOpacity(0.6)),
        labelStyle: TextStyle(color: c.textSecondary),
        floatingLabelStyle: TextStyle(
          color: c.titleColor,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        errorStyle: const TextStyle(color: AppColors.error),
      );

  static TextSelectionThemeData get seleccion => TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withOpacity(0.35),
        selectionHandleColor: AppColors.accent,
      );
}

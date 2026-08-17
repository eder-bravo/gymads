import 'package:flutter/material.dart';

/// Clase de colores de la aplicación
class AppColors {
  /// Color de fondo principal para todas las vistas
  static const Color backgroundColor = Color.fromARGB(255, 27, 27, 27);

  /// Colores principales de la aplicación
  static const Color primary = backgroundColor;
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);

  /// Color de acento de la marca (header de Inicio)
  static const Color brand = Color(0xFF10D5E8);

  /// Colores secundarios para acentos y detalles
  static const Color accent = Color(0xFFFF6F00);
  static const Color accentLight = Color(0xFFFFB74D);

  /// Colores para tarjetas y contenedores sobre el fondo oscuro
  static const Color cardBackground = Color.fromARGB(255, 18, 18, 18);
  static const Color containerBackground = Color.fromARGB(255, 14, 14, 14);

  /// Colores para estados (éxito, error, advertencia, info)
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  /// Colores para textos
  static const Color textPrimary = Color.fromARGB(255, 210, 210, 210);
  static const Color textSecondary = Color.fromARGB(255, 192, 192, 192);
  static const Color textHint = Color(0xFFBDBDBD);

  /// Color para títulos y subtítulos
  static const Color titleColor = Color.fromARGB(255, 255, 145, 90);

  /// Color para elementos deshabilitados
  static const Color disabled = Color.fromARGB(255, 21, 14, 14);
}

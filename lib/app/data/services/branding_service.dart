import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

/// Service for local-first gym branding (title + color)
///
/// Stores branding locally in GetStorage for instant reactivity.
/// DB is used only as backup (sync on login, save on change).
class BrandingService extends GetxService {
  static BrandingService get to => Get.find<BrandingService>();

  final _storage = GetStorage();
  static const String _gymTitleKey = 'branding_gym_title';
  static const String _brandColorKey = 'branding_brand_color';
  static const String _brandFontKey = 'branding_brand_font';

  // Reactive values — UI widgets bind to these
  final RxString gymTitle = 'GYMONE'.obs;
  final RxString brandColorHex = '#10D5E8'.obs;
  final RxString brandFontName = 'Default'.obs;

  /// Initialize service (loads from local storage)
  Future<BrandingService> init() async {
    gymTitle.value = _storage.read(_gymTitleKey) ?? 'GYMONE';
    brandColorHex.value = _storage.read(_brandColorKey) ?? '#10D5E8';
    brandFontName.value = _storage.read(_brandFontKey) ?? 'Default';
    return this;
  }

  /// Sync branding from DB values (called after login)
  ///
  /// Only overwrites local if local hasn't been customized
  /// or if `force` is true (first login on new device).
  void syncFromDb(
      {String? dbGymName,
      String? dbBrandColor,
      String? dbBrandFont,
      bool force = false}) {
    final hasLocalTitle = _storage.hasData(_gymTitleKey);
    final hasLocalColor = _storage.hasData(_brandColorKey);
    final hasLocalFont = _storage.hasData(_brandFontKey);

    // Gym name
    if (force || !hasLocalTitle) {
      if (dbGymName != null && dbGymName.isNotEmpty) {
        gymTitle.value = dbGymName;
        _storage.write(_gymTitleKey, dbGymName);
      }
    }

    // Brand color — always write on force, use default if DB is null
    if (force || !hasLocalColor) {
      final color = (dbBrandColor != null && dbBrandColor.isNotEmpty)
          ? dbBrandColor
          : '#10D5E8';
      brandColorHex.value = color;
      _storage.write(_brandColorKey, color);
    }

    // Brand font — always write on force, use default if DB is null
    if (force || !hasLocalFont) {
      final font = (dbBrandFont != null &&
              dbBrandFont.isNotEmpty &&
              dbBrandFont != 'default')
          ? dbBrandFont
          : 'Default';
      brandFontName.value = font;
      _storage.write(_brandFontKey, font);
    }
  }

  /// Update gym title (local + returns new value for DB backup)
  void setGymTitle(String title) {
    gymTitle.value = title;
    _storage.write(_gymTitleKey, title);
  }

  /// Update brand color (local + returns new value for DB backup)
  void setBrandColor(String hex) {
    brandColorHex.value = hex;
    _storage.write(_brandColorKey, hex);
  }

  /// Update brand font
  void setBrandFont(String font) {
    brandFontName.value = font;
    _storage.write(_brandFontKey, font);
  }

  /// Clear all branding data (call on logout)
  void clearBranding() {
    gymTitle.value = 'GYMONE';
    brandColorHex.value = '#10D5E8';
    brandFontName.value = 'Default';
    _storage.remove(_gymTitleKey);
    _storage.remove(_brandColorKey);
    _storage.remove(_brandFontKey);
  }

  /// Parse the current brand color hex to a Flutter Color
  Color get brandColor {
    try {
      final hex = brandColorHex.value.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10D5E8);
    }
  }

  /// Parse any hex string to Color
  static Color parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF10D5E8);
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10D5E8);
    }
  }

  /// Clear branding on logout
  void clear() {
    gymTitle.value = 'GYMONE';
    brandColorHex.value = '#10D5E8';
    brandFontName.value = 'Default';
    // Don't clear storage — keep branding across logouts for login screen
  }

  /// Get a TextStyle for the current brand font
  TextStyle getFontStyle({
    double fontSize = 14,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0,
  }) {
    return fontStyleFor(
      brandFontName.value,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  /// Get a TextStyle for a specific font name
  static TextStyle fontStyleFor(
    String fontName, {
    double fontSize = 14,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0,
  }) {
    switch (fontName) {
      case 'Bebas Neue':
        return GoogleFonts.bebasNeue(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing);
      case 'Oswald':
        return GoogleFonts.oswald(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing);
      case 'Montserrat':
        return GoogleFonts.montserrat(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing);
      case 'Poppins':
        return GoogleFonts.poppins(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing);
      case 'Righteous':
        return GoogleFonts.righteous(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing);
      default:
        return TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            letterSpacing: letterSpacing);
    }
  }

  /// Returns a multiplier to normalize visual height across fonts.
  /// Taller fonts get a smaller multiplier so they appear visually
  /// the same size as shorter fonts.
  static double fontSizeMultiplier(String fontName) {
    switch (fontName) {
      case 'Bebas Neue':
        return 0.85;
      case 'Oswald':
        return 0.90;
      case 'Righteous':
        return 0.88;
      case 'Montserrat':
        return 1.0;
      case 'Poppins':
        return 0.95;
      default:
        return 1.0;
    }
  }
}

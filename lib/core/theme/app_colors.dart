import 'package:flutter/material.dart';

/// Los colores que NO cambian con el modo claro u oscuro: la marca y los
/// estados. Los que sí cambian (fondo, tarjetas, textos, bordes) están en
/// [ColoresTema] y se leen del tema con `context.colores`.
class AppColors {
  /// Color de acento de la marca (header de Inicio)
  static const Color brand = Color(0xFF10D5E8);

  /// El naranja de la marca: botones, foco de los campos, selección.
  static const Color accent = Color(0xFFFF6F00);
  static const Color accentLight = Color(0xFFFFB74D);

  /// Colores para estados (éxito, error, advertencia, info)
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
}

/// Los colores que dependen del modo claro u oscuro. Van en el tema
/// (`ThemeData.extensions`), así que cada pantalla que los lee con
/// `context.colores` se redibuja sola cuando cambia el modo.
///
/// Los nombres son los que tenían en `AppColors` cuando la app solo era
/// oscura; [oscuro] conserva exactamente esos valores.
@immutable
class ColoresTema extends ThemeExtension<ColoresTema> {
  const ColoresTema({
    required this.backgroundColor,
    required this.cardBackground,
    required this.containerBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.titleColor,
    required this.disabled,
    required this.contraste,
    required this.superficie,
    required this.borde,
    required this.divisor,
    required this.cabeceraDesde,
    required this.cabeceraHasta,
    required this.fondoAcceso,
    required this.tarjetaAcceso,
    required this.sombra,
  });

  /// El fondo de las pantallas.
  final Color backgroundColor;

  /// Tarjetas y diálogos.
  final Color cardBackground;

  /// Contenedores dentro de una tarjeta (chips, cuadros de totales).
  final Color containerBackground;

  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  /// Títulos destacados (naranja).
  final Color titleColor;

  /// Elementos deshabilitados, líneas y bordes tenues.
  final Color disabled;

  /// Texto o ícono de máximo contraste sobre el fondo: blanco en oscuro,
  /// casi negro en claro.
  final Color contraste;

  /// Relleno sutil sobre el fondo (campos, botones secundarios).
  final Color superficie;

  /// Borde de campos y tarjetas.
  final Color borde;

  /// Líneas separadoras.
  final Color divisor;

  /// El degradado de la cabecera de Inicio.
  final Color cabeceraDesde;
  final Color cabeceraHasta;

  /// El fondo de las pantallas de acceso (inicio de sesión, registro, código
  /// de staff).
  final LinearGradient fondoAcceso;

  /// La tarjeta de las pantallas de acceso: translúcida sobre el degradado
  /// oscuro, blanca y sólida en claro (translúcida, la sombra se veía a
  /// través y la volvía gris).
  final Color tarjetaAcceso;

  /// Sombra de tarjetas: en claro, mucho más suave.
  final Color sombra;

  /// El de siempre: los valores con los que se diseñó la app.
  static const oscuro = ColoresTema(
    backgroundColor: Color.fromARGB(255, 27, 27, 27),
    cardBackground: Color.fromARGB(255, 18, 18, 18),
    containerBackground: Color.fromARGB(255, 14, 14, 14),
    textPrimary: Color.fromARGB(255, 210, 210, 210),
    textSecondary: Color.fromARGB(255, 192, 192, 192),
    textHint: Color(0xFFBDBDBD),
    titleColor: Color.fromARGB(255, 255, 145, 90),
    disabled: Color.fromARGB(255, 21, 14, 14),
    contraste: Colors.white,
    superficie: Color(0x0FFFFFFF), // blanco 6 %
    borde: Color(0x2EFFFFFF), // blanco 18 %
    divisor: Color(0x14FFFFFF), // blanco 8 %
    cabeceraDesde: Color(0xFF11151F),
    cabeceraHasta: Color(0xFF1A2332),
    fondoAcceso: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
    ),
    tarjetaAcceso: Color(0x0DFFFFFF), // blanco 5 %
    sombra: Color(0x33000000), // negro 20 %
  );

  /// Fondo gris muy claro con tarjetas blancas; el naranja de la marca se
  /// mantiene y los títulos van en un naranja más oscuro para leerse sobre
  /// blanco.
  static const claro = ColoresTema(
    backgroundColor: Color(0xFFF4F4F5),
    cardBackground: Color(0xFFFFFFFF),
    containerBackground: Color(0xFFECECEE),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF5F6368),
    textHint: Color(0xFF8A8A8E),
    titleColor: Color(0xFFD84315),
    disabled: Color(0xFFE0E0E0),
    contraste: Color(0xFF111111),
    superficie: Color(0x0A000000), // negro 4 %
    borde: Color(0x1F000000), // negro 12 %
    divisor: Color(0x14000000), // negro 8 %
    cabeceraDesde: Color(0xFFFFFFFF),
    cabeceraHasta: Color(0xFFEAF1F7),
    fondoAcceso: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFF1F4F9), Color(0xFFE3EBF5)],
    ),
    tarjetaAcceso: Color(0xFFFFFFFF),
    sombra: Color(0x14000000), // negro 8 %
  );

  @override
  ColoresTema copyWith({
    Color? backgroundColor,
    Color? cardBackground,
    Color? containerBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? titleColor,
    Color? disabled,
    Color? contraste,
    Color? superficie,
    Color? borde,
    Color? divisor,
    Color? cabeceraDesde,
    Color? cabeceraHasta,
    LinearGradient? fondoAcceso,
    Color? tarjetaAcceso,
    Color? sombra,
  }) {
    return ColoresTema(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cardBackground: cardBackground ?? this.cardBackground,
      containerBackground: containerBackground ?? this.containerBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      titleColor: titleColor ?? this.titleColor,
      disabled: disabled ?? this.disabled,
      contraste: contraste ?? this.contraste,
      superficie: superficie ?? this.superficie,
      borde: borde ?? this.borde,
      divisor: divisor ?? this.divisor,
      cabeceraDesde: cabeceraDesde ?? this.cabeceraDesde,
      cabeceraHasta: cabeceraHasta ?? this.cabeceraHasta,
      fondoAcceso: fondoAcceso ?? this.fondoAcceso,
      tarjetaAcceso: tarjetaAcceso ?? this.tarjetaAcceso,
      sombra: sombra ?? this.sombra,
    );
  }

  /// Para que el cambio de modo se anime en vez de saltar.
  @override
  ColoresTema lerp(ColoresTema? other, double t) {
    if (other == null) return this;
    Color mezcla(Color a, Color b) => Color.lerp(a, b, t)!;
    return ColoresTema(
      backgroundColor: mezcla(backgroundColor, other.backgroundColor),
      cardBackground: mezcla(cardBackground, other.cardBackground),
      containerBackground:
          mezcla(containerBackground, other.containerBackground),
      textPrimary: mezcla(textPrimary, other.textPrimary),
      textSecondary: mezcla(textSecondary, other.textSecondary),
      textHint: mezcla(textHint, other.textHint),
      titleColor: mezcla(titleColor, other.titleColor),
      disabled: mezcla(disabled, other.disabled),
      contraste: mezcla(contraste, other.contraste),
      superficie: mezcla(superficie, other.superficie),
      borde: mezcla(borde, other.borde),
      divisor: mezcla(divisor, other.divisor),
      cabeceraDesde: mezcla(cabeceraDesde, other.cabeceraDesde),
      cabeceraHasta: mezcla(cabeceraHasta, other.cabeceraHasta),
      fondoAcceso: LinearGradient.lerp(fondoAcceso, other.fondoAcceso, t)!,
      tarjetaAcceso: mezcla(tarjetaAcceso, other.tarjetaAcceso),
      sombra: mezcla(sombra, other.sombra),
    );
  }
}

/// `context.colores.textPrimary`: los colores del modo actual. Leerlos así
/// (y no guardarlos en una constante) es lo que hace que la pantalla cambie
/// cuando cambia el modo.
extension ColoresDelContexto on BuildContext {
  ColoresTema get colores =>
      Theme.of(this).extension<ColoresTema>() ?? ColoresTema.oscuro;
}

import 'package:flutter/material.dart';

/// Iconos disponibles para las categorías de producto.
///
/// La base guarda una **clave corta** (`'bebidas'`), nunca el `codePoint` del
/// icono. El motivo es el `--tree-shake-icons` de Flutter, activo por defecto
/// en `flutter build`: analiza estáticamente los literales `const IconData(...)`
/// y elimina de la fuente todo glifo que no vea referenciado. Un
/// `IconData(codePointDeLaBase, fontFamily: 'MaterialIcons')` construido en
/// tiempo de ejecución es invisible a ese análisis, así que en debug se ve bien
/// y en release salen cuadritos o el glifo equivocado. Con un mapa `const` de
/// `Icons.*` los glifos quedan referenciados y sobreviven.
///
/// Por la misma razón se usa `Icons.*` y no `material_design_icons_flutter`:
/// los `MdiIcons` son getters, no literales constantes.
///
/// Añadir un icono es editar este mapa. No requiere migración: la columna
/// `icon` no tiene CHECK y las claves desconocidas caen al respaldo.
class CategoryIcons {
  CategoryIcons._();

  /// Clave usada cuando la categoría no tiene icono o guarda uno desconocido.
  static const String fallbackKey = 'otros';

  /// Clave -> icono. Debe ser `const` para sobrevivir al tree-shaking.
  static const Map<String, IconData> options = {
    'suplementos': Icons.fitness_center,
    'proteina': Icons.blender,
    'bebidas': Icons.local_drink,
    'agua': Icons.water_drop,
    'energia': Icons.bolt,
    'snacks': Icons.cookie,
    'comida': Icons.restaurant,
    'toallas': Icons.dry_cleaning,
    'ropa': Icons.checkroom,
    'calzado': Icons.directions_run,
    'accesorios': Icons.watch,
    'guantes': Icons.back_hand,
    'mochilas': Icons.backpack,
    'equipamiento': Icons.sports_gymnastics,
    'higiene': Icons.soap,
    'otros': Icons.category,
  };

  /// Etiquetas en español para el selector de iconos.
  static const Map<String, String> labels = {
    'suplementos': 'Suplementos',
    'proteina': 'Proteína',
    'bebidas': 'Bebidas',
    'agua': 'Agua',
    'energia': 'Energía',
    'snacks': 'Snacks',
    'comida': 'Comida',
    'toallas': 'Toallas',
    'ropa': 'Ropa',
    'calzado': 'Calzado',
    'accesorios': 'Accesorios',
    'guantes': 'Guantes',
    'mochilas': 'Mochilas',
    'equipamiento': 'Equipamiento',
    'higiene': 'Higiene',
    'otros': 'Otros',
  };

  /// Icono de una clave, con respaldo seguro si viene nula o desconocida.
  static IconData resolve(String? key) => options[key] ?? options[fallbackKey]!;

  static String labelFor(String key) => labels[key] ?? key;

  static List<String> get keys => options.keys.toList();
}

/// Separar el nombre completo que llega de Google en nombres y apellidos.
///
/// Google solo da el nombre completo en una cadena ("Eder Gael Blanco
/// Alejandre"), así que se sigue la costumbre de dos apellidos: las dos
/// últimas palabras son los apellidos y lo demás son los nombres. Con dos
/// palabras, una es nombre y otra apellido.
///
/// Las partículas (de, del, la, los…) van pegadas a la palabra que les sigue,
/// para que "María de la Cruz López" quede como "María" / "de la Cruz López".
library;

const _particulas = <String>{
  'de', 'del', 'la', 'las', 'los', 'y', 'san', 'santa', 'van', 'von', 'da',
  'di', 'do', 'dos',
};

/// El nombre completo partido en (nombres, apellidos).
({String nombres, String apellidos}) separarNombreCompleto(String? completo) {
  final palabras = (completo ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  // Cada grupo es una palabra con las partículas que la anteceden.
  final grupos = <String>[];
  final pendientes = <String>[];
  for (final palabra in palabras) {
    pendientes.add(palabra);
    if (!_particulas.contains(palabra.toLowerCase())) {
      grupos.add(pendientes.join(' '));
      pendientes.clear();
    }
  }
  if (pendientes.isNotEmpty) {
    if (grupos.isEmpty) {
      grupos.add(pendientes.join(' '));
    } else {
      grupos[grupos.length - 1] += ' ${pendientes.join(' ')}';
    }
  }

  if (grupos.isEmpty) return (nombres: '', apellidos: '');
  if (grupos.length == 1) return (nombres: grupos.first, apellidos: '');

  final cuantosApellidos = grupos.length >= 3 ? 2 : 1;
  final corte = grupos.length - cuantosApellidos;
  return (
    nombres: grupos.sublist(0, corte).join(' '),
    apellidos: grupos.sublist(corte).join(' '),
  );
}

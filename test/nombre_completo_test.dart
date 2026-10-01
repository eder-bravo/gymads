import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/nombre_completo.dart';

void main() {
  void espera(String? completo, String nombres, String apellidos) {
    final r = separarNombreCompleto(completo);
    expect(r.nombres, nombres, reason: 'nombres de "$completo"');
    expect(r.apellidos, apellidos, reason: 'apellidos de "$completo"');
  }

  test('dos nombres y dos apellidos', () {
    espera('Eder Gael Blanco Alejandre', 'Eder Gael', 'Blanco Alejandre');
  });

  test('un nombre y un apellido', () {
    espera('Eder Blanco', 'Eder', 'Blanco');
  });

  test('un nombre y dos apellidos', () {
    espera('Juan Pérez García', 'Juan', 'Pérez García');
  });

  test('tres nombres y dos apellidos', () {
    espera('Ana María Luisa Pérez López', 'Ana María Luisa', 'Pérez López');
  });

  test('las partículas van con el apellido o nombre que les sigue', () {
    espera('María de la Cruz López', 'María', 'de la Cruz López');
    espera('José de Jesús Pérez López', 'José de Jesús', 'Pérez López');
    espera('Luis del Río', 'Luis', 'del Río');
  });

  test('una sola palabra, vacío o nulo', () {
    espera('Eder', 'Eder', '');
    espera('', '', '');
    espera(null, '', '');
  });

  test('espacios de más', () {
    espera('  Eder   Gael  Blanco Alejandre ', 'Eder Gael', 'Blanco Alejandre');
  });
}

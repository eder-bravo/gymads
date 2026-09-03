import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/hora_formato.dart';

void main() {
  group('completa', () {
    test('mañana y tarde', () {
      expect(HoraFormato.completa(6, 0), '6:00 a.m.');
      expect(HoraFormato.completa(9, 5), '9:05 a.m.');
      expect(HoraFormato.completa(13, 30), '1:30 p.m.');
      expect(HoraFormato.completa(22, 0), '10:00 p.m.');
    });

    test('medianoche son las 12 a.m., no las 0', () {
      expect(HoraFormato.completa(0, 0), '12:00 a.m.');
      expect(HoraFormato.completa(0, 45), '12:45 a.m.');
    });

    test('mediodía son las 12 p.m., no las 0', () {
      expect(HoraFormato.completa(12, 0), '12:00 p.m.');
      expect(HoraFormato.completa(12, 30), '12:30 p.m.');
    });

    test('las 23 son las 11 p.m.', () {
      expect(HoraFormato.completa(23, 59), '11:59 p.m.');
    });

    test('los minutos van siempre con dos cifras', () {
      expect(HoraFormato.completa(7, 5), '7:05 a.m.');
    });
  });

  group('enPunto', () {
    test('omite los minutos', () {
      expect(HoraFormato.enPunto(6), '6 a.m.');
      expect(HoraFormato.enPunto(20), '8 p.m.');
      expect(HoraFormato.enPunto(0), '12 a.m.');
      expect(HoraFormato.enPunto(12), '12 p.m.');
    });
  });

  group('rango', () {
    test('dice el sufijo una sola vez si ambas caen en la misma mitad', () {
      expect(HoraFormato.rango(6, 8), '6 – 8 a.m.');
      expect(HoraFormato.rango(18, 20), '6 – 8 p.m.');
    });

    test('lo repite cuando cruzan el mediodía', () {
      expect(HoraFormato.rango(10, 12), '10 a.m. – 12 p.m.');
    });

    test('lo repite cuando cruzan la medianoche', () {
      expect(HoraFormato.rango(22, 0), '10 p.m. – 12 a.m.');
    });
  });

  group('deFecha y fechaYHora', () {
    test('toma la hora del momento', () {
      expect(HoraFormato.deFecha(DateTime(2026, 9, 1, 18, 7)), '6:07 p.m.');
    });

    test('la fecha corta lleva día y mes con dos cifras', () {
      expect(
        HoraFormato.fechaYHora(DateTime(2026, 9, 1, 8, 15)),
        '01/09 8:15 a.m.',
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/confirmador_codigo.dart';

void main() {
  final inicio = DateTime(2026, 9, 24, 12);
  DateTime ms(int milisegundos) =>
      inicio.add(Duration(milliseconds: milisegundos));

  group('Confirmar la lectura', () {
    test('se acepta hasta leerlo igual 3 veces', () {
      final c = ConfirmadorCodigo();
      expect(c.registrar('7503002196526', ahora: ms(0)), isNull);
      expect(c.registrar('7503002196526', ahora: ms(100)), isNull);
      expect(c.registrar('7503002196526', ahora: ms(200)), '7503002196526');
    });

    test('una lectura cambiada suelta no se acepta', () {
      // Lo que pasaba: el mismo envase, un cuadro con números cambiados.
      final c = ConfirmadorCodigo();
      expect(c.registrar('7503002196526', ahora: ms(0)), isNull);
      expect(c.registrar('2544002796526', ahora: ms(100)), isNull);
      expect(c.registrar('7503002196526', ahora: ms(200)), isNull);
      expect(c.registrar('8503062726526', ahora: ms(300)), isNull);
      // La buena se confirma; las cambiadas nunca llegaron a 3.
      expect(c.registrar('7503002196526', ahora: ms(400)), '7503002196526');
    });

    test('lecturas muy separadas no suman', () {
      final c = ConfirmadorCodigo();
      c.registrar('7501791666152', ahora: ms(0));
      c.registrar('7501791666152', ahora: ms(100));
      expect(c.registrar('7501791666152', ahora: ms(3000)), isNull);
    });

    test('los códigos sin verificador piden más lecturas', () {
      final c = ConfirmadorCodigo();
      for (var i = 0; i < 3; i++) {
        expect(
            c.registrar('12345678', necesarias: 4, ahora: ms(i * 100)), isNull);
      }
      expect(
          c.registrar('12345678', necesarias: 4, ahora: ms(300)), '12345678');
    });

    test('tras confirmar empieza de cero', () {
      final c = ConfirmadorCodigo();
      for (var i = 0; i < 3; i++) {
        c.registrar('7501791666152', ahora: ms(i * 100));
      }
      expect(c.registrar('7501791666152', ahora: ms(300)), isNull);
    });
  });

  group('Dígito verificador', () {
    test('EAN-13 de productos reales', () {
      expect(digitoVerificadorValido('7501791666152'), isTrue);
      expect(digitoVerificadorValido('4318012620632'), isTrue);
      expect(digitoVerificadorValido('7501791666153'), isFalse);
    });

    test('EAN-8 y UPC-A', () {
      expect(digitoVerificadorValido('96385074'), isTrue); // EAN-8
      expect(digitoVerificadorValido('036000291452'), isTrue); // UPC-A
      expect(digitoVerificadorValido('036000291453'), isFalse);
    });

    test('lo que no es un EAN/UPC no pasa', () {
      expect(digitoVerificadorValido('ABC123456789'), isFalse);
      expect(digitoVerificadorValido('12345'), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/avisos_sistema_service.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';

void main() {
  group('Notificación de un pase', () {
    test('entrada, con los días que le quedan', () {
      final a = avisoDePase(ResultadoPase.entrada,
          nombre: 'María López', diasRestantes: 20);
      expect(a.titulo, 'María López entró');
      expect(a.cuerpo, 'Le quedan 20 días');
    });

    test('salida', () {
      final a = avisoDePase(ResultadoPase.salida,
          nombre: 'María López', diasRestantes: 1);
      expect(a.titulo, 'María López salió');
      expect(a.cuerpo, 'Le queda 1 día');
    });

    test('membresía vencida o inactiva', () {
      final vencida = avisoDePase(ResultadoPase.vencida, nombre: 'Juan');
      expect(vencida.titulo, 'Acceso denegado: Juan');
      expect(vencida.cuerpo, 'Membresía vencida');

      final inactiva = avisoDePase(ResultadoPase.inactiva, nombre: 'Juan');
      expect(inactiva.cuerpo, 'Membresía inactiva');
    });

    test('tarjeta no registrada: sin el número de la tarjeta', () {
      final a = avisoDePase(ResultadoPase.noRegistrada, nombre: 'EA7F8005');
      expect(a.titulo, 'Tarjeta no registrada');
      expect(a.cuerpo, 'Regístrala en Clientes para darle acceso');
      expect('${a.titulo} ${a.cuerpo}', isNot(contains('EA7F8005')));
    });

    test('sin nombre no queda un hueco', () {
      expect(avisoDePase(ResultadoPase.entrada, nombre: '  ').titulo,
          'Cliente entró');
    });
  });

  group('Pases atrasados (ocurridos con la app congelada)', () {
    final ahora = DateTime(2026, 9, 24, 8, 0, 0);

    test('uno de hace 2 s se avisa como siempre', () {
      expect(
          esPaseAtrasado(ahora.subtract(const Duration(seconds: 2)),
              ahora: ahora),
          isFalse);
    });

    test('uno de hace 20 s ya no: se registra sin aviso', () {
      expect(
          esPaseAtrasado(ahora.subtract(const Duration(seconds: 20)),
              ahora: ahora),
          isTrue);
    });
  });
}

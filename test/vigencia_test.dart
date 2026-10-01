import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/modules/abonar/vigencia.dart';

UserModel _cliente({DateTime? vence, bool activo = true}) => UserModel(
      name: 'Juan Pérez',
      phone: '+520000000000',
      joinDate: DateTime(2026, 1, 1),
      userNumber: '1',
      expirationDate: vence,
      isActive: activo,
    );

void main() {
  final hoy = DateTime(2026, 10, 1, 10);

  group('fechaLarga', () {
    test('día y mes en palabras', () {
      expect(fechaLarga(DateTime(2026, 12, 15), hoy: hoy), '15 de diciembre');
    });

    test('con el día de la semana', () {
      // El 15 de diciembre de 2026 es martes.
      expect(fechaLarga(DateTime(2026, 12, 15), conDia: true, hoy: hoy),
          'martes 15 de diciembre');
    });

    test('el año solo si no es el de hoy', () {
      expect(fechaLarga(DateTime(2027, 1, 3), hoy: hoy), '3 de enero de 2027');
    });
  });

  test('periodoEnPalabras: singular y plural', () {
    expect(periodoEnPalabras(1, 'Meses'), '1 mes');
    expect(periodoEnPalabras(2, 'Meses'), '2 meses');
    expect(periodoEnPalabras(1, 'Días'), '1 día');
    expect(periodoEnPalabras(3, 'Semanas'), '3 semanas');
    expect(periodoEnPalabras(1, 'Años'), '1 año');
  });

  test('pesos: sin centavos si es redondo', () {
    expect(pesos(1000), '\$1,000');
    expect(pesos(1000.5), '\$1,000.50');
  });

  group('situacionDe', () {
    test('sin vencimiento: cliente nuevo', () {
      final s = situacionDe(_cliente(), hoy);
      expect(s.texto, 'Cliente nuevo');
      expect(s.vencido, isFalse);
    });

    test('vigente: pagado hasta y días que le quedan', () {
      final s = situacionDe(_cliente(vence: DateTime(2026, 10, 6)), hoy);
      expect(s.texto, 'Pagado hasta el 6 de octubre');
      expect(s.detalle, 'Le quedan 5 días');
      expect(s.vencido, isFalse);
    });

    test('vigente un día', () {
      final s = situacionDe(_cliente(vence: DateTime(2026, 10, 2, 8)), hoy);
      expect(s.detalle, 'Le queda 1 día');
    });

    test('vencido', () {
      final s = situacionDe(_cliente(vence: DateTime(2026, 9, 28)), hoy);
      expect(s.texto, 'Venció el 28 de septiembre');
      expect(s.vencido, isTrue);
    });

    test('inactivo cuenta como vencido', () {
      final s = situacionDe(
          _cliente(vence: DateTime(2026, 12, 1), activo: false), hoy);
      expect(s.vencido, isTrue);
    });
  });

  group('cobro', () {
    test('costo fijo: precio por cantidad', () {
      expect(
          totalDelCobro(
              costoFijo: true,
              precioPorPeriodo: 500,
              cantidad: 2,
              montoLibre: 0),
          1000);
    });

    test('abono libre: lo escrito es el total', () {
      expect(
          totalDelCobro(
              costoFijo: false,
              precioPorPeriodo: 500,
              cantidad: 2,
              montoLibre: 800),
          800);
    });

    test('qué falta para cobrar', () {
      expect(
          faltaParaCobrarDe(
              costoFijo: true,
              precioPorPeriodo: null,
              cantidad: 1,
              montoLibre: 0),
          'Elige cuánto tiempo paga');
      expect(
          faltaParaCobrarDe(
              costoFijo: false,
              precioPorPeriodo: null,
              cantidad: 1,
              montoLibre: 0),
          'Escribe cuánto paga');
      expect(
          faltaParaCobrarDe(
              costoFijo: true,
              precioPorPeriodo: 500,
              cantidad: 1,
              montoLibre: 0),
          isNull);
    });
  });
}

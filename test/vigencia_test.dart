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

    test('resumida (tableta y escritorio): lo largo en meses o años', () {
      String queda(DateTime vence) =>
          situacionDe(_cliente(vence: vence), hoy, resumida: true).detalle!;
      // Hasta 60 días, en días, como siempre.
      expect(queda(DateTime(2026, 10, 6)), 'Le quedan 5 días');
      expect(queda(DateTime(2026, 11, 30)), 'Le quedan 60 días');
      // Después, meses y días exactos.
      expect(queda(DateTime(2026, 12, 30)), 'Le quedan 2 meses y 29 días');
      expect(queda(DateTime(2027, 1, 1)), 'Le quedan 3 meses');
      expect(queda(DateTime(2027, 1, 2)), 'Le quedan 3 meses y 1 día');
      expect(queda(DateTime(2027, 9, 30)), 'Le quedan 11 meses y 29 días');
      // Desde dos años, en años.
      expect(queda(DateTime(2028, 10, 1)), 'Le quedan 2 años');
      expect(queda(DateTime(2126, 9, 11)), 'Le quedan más de 99 años');
      // Sin resumir (teléfono), igual que antes.
      expect(situacionDe(_cliente(vence: DateTime(2126, 9, 11)), hoy).detalle,
          'Le quedan 36503 días');
    });

    test('meses y días alrededor de fin de mes y cambio de horario', () {
      expect(loQueLeQueda(DateTime(2026, 1, 31), DateTime(2026, 4, 1), 60),
          'Le quedan 60 días');
      expect(loQueLeQueda(DateTime(2026, 1, 31), DateTime(2026, 4, 5), 64),
          'Le quedan 2 meses y 5 días');
      expect(loQueLeQueda(DateTime(2026, 3, 1), DateTime(2026, 6, 1), 92),
          'Le quedan 3 meses');
      expect(loQueLeQueda(DateTime(2026, 7, 1), DateTime(2026, 8, 31), 61),
          'Le quedan 1 mes y 30 días');
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

    test('la inscripción se suma al abono, con costo fijo y con libre', () {
      expect(
          totalDelCobro(
              costoFijo: true,
              precioPorPeriodo: 500,
              cantidad: 1,
              montoLibre: 0,
              inscripcion: 200),
          700);
      expect(
          totalDelCobro(
              costoFijo: false,
              precioPorPeriodo: null,
              cantidad: 2,
              montoLibre: 300,
              inscripcion: 200),
          800);
    });

    test('abono libre: el precio escrito se multiplica por la cantidad', () {
      expect(
          totalDelCobro(
              costoFijo: false,
              precioPorPeriodo: 500,
              cantidad: 2,
              montoLibre: 800),
          1600);
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
          'Escribe el precio por periodo');
      expect(
          faltaParaCobrarDe(
              costoFijo: true,
              precioPorPeriodo: 500,
              cantidad: 1,
              montoLibre: 0),
          isNull);
    });
  });

  group('Vencimiento por calendario (meses y años)', () {
    DateTime f(int a, int m, int d) => DateTime(a, m, d, 10, 30);
    test('el mismo día del mes siguiente, no 30 días', () {
      expect(sumarPeriodo(f(2026, 10, 6), 'Meses', 1), f(2026, 11, 6));
      expect(sumarPeriodo(f(2026, 10, 6), 'Meses', 3), f(2027, 1, 6));
      expect(sumarPeriodo(f(2026, 10, 6), 'Años', 2), f(2028, 10, 6));
    });

    test('si el mes es más corto, el último día', () {
      expect(sumarPeriodo(f(2027, 1, 31), 'Meses', 1), f(2027, 2, 28));
      expect(sumarPeriodo(f(2028, 1, 31), 'Meses', 1), f(2028, 2, 29));
      expect(sumarPeriodo(f(2026, 10, 31), 'Meses', 1), f(2026, 11, 30));
      // De una vez, no mes por mes: no se queda en el 28.
      expect(sumarPeriodo(f(2027, 1, 31), 'Meses', 2), f(2027, 3, 31));
    });

    test('29 de febrero: al año siguiente, el 28', () {
      expect(sumarPeriodo(f(2028, 2, 29), 'Años', 1), f(2029, 2, 28));
      expect(sumarPeriodo(f(2028, 2, 29), 'Años', 4), f(2032, 2, 29));
      expect(sumarPeriodo(f(2028, 2, 29), 'Meses', 12), f(2029, 2, 28));
    });

    test('semanas y días siguen sumando días', () {
      expect(sumarPeriodo(f(2026, 10, 6), 'Semanas', 2), f(2026, 10, 20));
      expect(sumarPeriodo(f(2026, 10, 6), 'Días', 30), f(2026, 11, 5));
    });

    test('conserva la hora y si la fecha es UTC', () {
      final utc = DateTime.utc(2026, 10, 6, 23, 15);
      final r = sumarPeriodo(utc, 'Meses', 1);
      expect(r.isUtc, isTrue);
      expect(r, DateTime.utc(2026, 11, 6, 23, 15));
    });

    test('lo que le queda cuenta los meses igual que el cobro', () {
      expect(loQueLeQueda(DateTime(2027, 1, 31), DateTime(2027, 3, 31), 59),
          'Le quedan 59 días');
      expect(loQueLeQueda(DateTime(2026, 10, 6), DateTime(2027, 1, 6), 92),
          'Le quedan 3 meses');
      expect(loQueLeQueda(DateTime(2026, 10, 31), DateTime(2027, 1, 30), 91),
          'Le quedan 2 meses y 30 días');
    });
  });
}

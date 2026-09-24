import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';

void main() {
  group('Después del abono', () {
    test('desde el módulo Abonar (sin argumentos): abonar a otro cliente', () {
      expect(alTerminarDesde(null), AlTerminarAbono.abonarOtro);
    });

    test('desde el aviso de vencida (solo el cliente): abonar a otro', () {
      expect(
          alTerminarDesde({'cliente': Object()}), AlTerminarAbono.abonarOtro);
    });

    test('tras registrar desde el lector: volver al inicio', () {
      expect(
        alTerminarDesde({
          'cliente': Object(),
          'alTerminar': AlTerminarAbono.volverAInicio,
        }),
        AlTerminarAbono.volverAInicio,
      );
    });

    test('tras registrar en Clientes: volver a clientes', () {
      expect(
        alTerminarDesde({'alTerminar': AlTerminarAbono.volverAClientes}),
        AlTerminarAbono.volverAClientes,
      );
    });
  });

  group('Periodo con el que abre el cobro', () {
    test('con precio por mes, abre en meses', () {
      const precios = AbonoPricesModel(priceMonth: 1000, priceDay: 50);
      expect(periodoConPrecio(precios, 'Meses'), 'Meses');
    });

    test('sin precio por mes, abre en el primero que tenga precio', () {
      const precios = AbonoPricesModel(priceDay: 50);
      expect(periodoConPrecio(precios, 'Meses'), 'Días');
    });

    test('sin ningún precio, se queda como estaba', () {
      expect(periodoConPrecio(const AbonoPricesModel(), 'Meses'), 'Meses');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/access_code_generator.dart';

void main() {
  group('codigoDesdeQr', () {
    test('el QR del acceso: el código tal cual', () {
      expect(AccessCodeGenerator.codigoDesdeQr('ABCD-EFGH'), 'ABCD-EFGH');
      expect(AccessCodeGenerator.codigoDesdeQr('  abcdefgh\n'), 'ABCD-EFGH');
    });

    test('un código recién generado siempre se lee de vuelta', () {
      for (var i = 0; i < 50; i++) {
        final codigo = AccessCodeGenerator.generar();
        expect(AccessCodeGenerator.codigoDesdeQr(codigo), codigo);
      }
    });

    test('el mensaje completo que se comparte', () {
      const mensaje = 'Hola María, este es tu código para entrar a Gym '
          'Fuerte:\n\nKP7M-Q2XA\n\nAbre la app, toca "Entrar como staff" y '
          'escanea el QR o escribe el código. Solo funciona una vez.';
      expect(AccessCodeGenerator.codigoDesdeQr(mensaje), 'KP7M-Q2XA');
    });

    test('un QR que no es un código de acceso', () {
      expect(AccessCodeGenerator.codigoDesdeQr(''), isNull);
      expect(AccessCodeGenerator.codigoDesdeQr('7501234567890'), isNull);
      expect(AccessCodeGenerator.codigoDesdeQr('Hola, ¿cómo estás?'), isNull);
      // Con letras que el código nunca usa (I, O, 0, 1).
      expect(AccessCodeGenerator.codigoDesdeQr('ABCD-EFG1'), isNull);
    });
  });
}

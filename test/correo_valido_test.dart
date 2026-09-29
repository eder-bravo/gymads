import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/correo_valido.dart';

void main() {
  group('Correo al registrarse', () {
    test('acepta proveedores reales y correos de escuela o gobierno', () {
      for (final c in [
        'juan@gmail.com',
        'Ana.Perez@Outlook.com',
        'x@hotmail.com',
        'x@hotmail.com.mx',
        'y@yahoo.com.mx',
        'z@icloud.com',
        'alumno@uni.edu.mx',
        'a@itesm.edu',
        'b@sat.gob.mx',
      ]) {
        expect(validarCorreoDeRegistro(c), isNull, reason: c);
      }
    });

    test('rechaza todo lo demás, sin depender de una lista de temporales', () {
      for (final c in [
        'gebiwah224@hudzer.com', // temporal que ninguna lista conocía
        'a@mailinator.com',
        'b@10minutemail.com',
        'contacto@migym.com',
        'a@gmail.com.evil.com', // engaña con el nombre, pero no es gmail
        'a@fakeedu.com',
        'a@edu.mx.com',
      ]) {
        expect(validarCorreoDeRegistro(c), mensajeCorreoNoPermitido,
            reason: c);
      }
    });

    test('rechaza lo que no es un correo', () {
      expect(validarCorreoDeRegistro(''), 'El correo es requerido');
      for (final c in ['juan', 'juan@', '@gmail.com', 'juan@gmail', 'a b@x.com']) {
        expect(validarCorreoDeRegistro(c), 'Ingresa un correo válido',
            reason: c);
      }
    });
  });

  group('Sugerencia de correo', () {
    test('corrige errores de dedo en el dominio', () {
      expect(sugerenciaDeCorreo('juan@gmial.com'), 'juan@gmail.com');
      expect(sugerenciaDeCorreo('ana@hotmial.com'), 'ana@hotmail.com');
      expect(sugerenciaDeCorreo('x@outlok.com'), 'x@outlook.com');
      expect(sugerenciaDeCorreo('x@gmail.con'), 'x@gmail.com');
    });

    test('no sugiere nada si el correo se ve bien', () {
      expect(sugerenciaDeCorreo('juan@gmail.com'), isNull);
      expect(sugerenciaDeCorreo('juan'), isNull);
    });
  });
}

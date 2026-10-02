import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/fallo_al_guardar.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const generico = 'No se pudo guardar el producto. Intenta de nuevo.';

UserModel cliente(String nombre, String telefono) => UserModel(
      name: nombre,
      phone: telefono,
      joinDate: DateTime(2026, 9, 26),
      userNumber: 'A1B2C3',
    );

void main() {
  group('Mensaje al fallar un guardado (sin términos técnicos)', () {
    test('tardó demasiado', () {
      final m = mensajeDeFallo(TimeoutException('x'), generico: generico);
      expect(m, contains('No se pudo completar el guardado'));
      expect(m, contains('Revisa tu conexión'));
    });

    test('sin internet', () {
      for (final e in [
        const SocketException('Failed host lookup: supabase.co'),
        http.ClientException('Connection closed before full header'),
        Exception('ClientException: SocketException: Network is unreachable'),
      ]) {
        expect(mensajeDeFallo(e, generico: generico),
            startsWith('No hay conexión a internet'),
            reason: '$e');
      }
    });

    test('un motivo conocido se dice tal cual', () {
      expect(
          mensajeDeFallo(
              const GuardadoFallido('Esa tarjeta ya es de otro cliente.'),
              generico: generico),
          'Esa tarjeta ya es de otro cliente.');
    });

    test('lo demás, el mensaje genérico', () {
      expect(mensajeDeFallo(StateError('x'), generico: generico), generico);
    });

    test('ningún mensaje habla de servidor, red ni base de datos', () {
      for (final e in [
        TimeoutException('x'),
        const SocketException('x'),
        StateError('x'),
      ]) {
        final m = mensajeDeFallo(e, generico: generico).toLowerCase();
        for (final tecnico in ['servidor', 'base de datos', 'error de red']) {
          expect(m, isNot(contains(tecnico)));
        }
      }
    });
  });

  group('Qué dato se repitió', () {
    test('lee el índice único de la violación', () {
      const e = PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"idx_users_branch_rfid_card"',
        code: '23505',
      );
      expect(restriccionUnicaViolada(e), 'idx_users_branch_rfid_card');
    });

    test('otro error de la base no es un repetido', () {
      const e = PostgrestException(message: 'permission denied', code: '42501');
      expect(restriccionUnicaViolada(e), isNull);
      expect(restriccionUnicaViolada(TimeoutException('x')), isNull);
    });
  });

  group('Número de cliente repetido', () {
    test('mismo nombre y teléfono: es el alta de un intento anterior', () {
      expect(
          esElMismoAlta(cliente('María López', '+525512345678'),
              cliente(' maría lópez ', '+525512345678')),
          isTrue);
    });

    test('otro cliente: hay que asignar otro número', () {
      expect(
          esElMismoAlta(cliente('Juan', '+525500000000'),
              cliente('María López', '+525512345678')),
          isFalse);
    });
  });
}

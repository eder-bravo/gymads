import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/providers/api_provider.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:gymads/app/data/services/regreso_del_lector.dart';

/// Lo que contesta el lector en cada vuelta (null = no contesta).
Future<LectorEnRed?> Function(int) respuestas(List<LectorEnRed?> lista) {
  return (intento) async =>
      intento < lista.length ? lista[intento] : lista.last;
}

const _trabajando = LectorEnRed(ip: '192.168.1.40', claimed: true, mine: true);
const _ofreciendose = LectorEnRed(
    ip: '192.168.1.40', claimed: true, mine: true, modoConfig: true);
const _ajeno = LectorEnRed(ip: '192.168.1.41', claimed: true);

/// Un reloj que avanza [paso] cada vez que se consulta.
DateTime Function() reloj({Duration paso = const Duration(seconds: 3)}) {
  var t = DateTime(2026, 9, 30, 10);
  return () => t = t.add(paso);
}

/// Hace pasar la búsqueda por la de Supabase (el repositorio la reconoce por
/// el nombre).
class _FakeSupabaseApiProvider extends ApiProvider {
  _FakeSupabaseApiProvider(this.respuesta) : super(model: 'users');

  final Map<String, dynamic> respuesta;

  Future<Map<String, dynamic>> getUserByRfid(String uid) async => respuesta;

  @override
  String get urlBase => '';

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Al salir de "Cambiar WiFi" sin cambiarlo', () {
    test('si ya volvió a trabajar normal, listo (no se le pide nada)',
        () async {
      var pedidos = 0;
      final lector = await esperarRegresoDelLector(
        buscar: respuestas([null, null, _trabajando]),
        terminar: (_) async {
          pedidos++;
          return true;
        },
        pausa: Duration.zero,
      );
      expect(lector, _trabajando);
      expect(pedidos, 0);
    });

    test('si sigue ofreciéndose por Bluetooth, se le pide terminar UNA vez y '
        'se espera a que vuelva normal', () async {
      var pedidos = 0;
      final lector = await esperarRegresoDelLector(
        // Aparece aún en modo configuración, se reinicia (no contesta) y
        // vuelve trabajando.
        buscar: respuestas(
            [null, _ofreciendose, _ofreciendose, null, null, _trabajando]),
        terminar: (_) async {
          pedidos++;
          return true;
        },
        pausa: Duration.zero,
      );
      expect(lector, _trabajando);
      expect(pedidos, 1);
    });

    test('si no contesta al pedido de terminar, se le vuelve a pedir',
        () async {
      var pedidos = 0;
      final lector = await esperarRegresoDelLector(
        // Ofreciéndose, su WiFi contesta a medias: el primer pedido se
        // pierde, el segundo llega y se reinicia.
        buscar: respuestas(
            [_ofreciendose, _ofreciendose, _ofreciendose, null, _trabajando]),
        terminar: (_) async => ++pedidos == 1 ? null : true,
        pausa: Duration.zero,
      );
      expect(lector, _trabajando);
      expect(pedidos, 2);
    });

    test('con un firmware que no sabe terminar, basta con que esté en la red',
        () async {
      final lector = await esperarRegresoDelLector(
        buscar: respuestas([_ofreciendose]),
        terminar: (_) async => false,
        pausa: Duration.zero,
      );
      expect(lector, _ofreciendose);
    });

    test('un lector de otro gimnasio no cuenta', () async {
      final lector = await esperarRegresoDelLector(
        buscar: respuestas([_ajeno]),
        terminar: (_) async => true,
        pausa: Duration.zero,
        limite: const Duration(seconds: 10),
        ahora: reloj(),
      );
      expect(lector, isNull);
    });

    test('si no aparece en el tiempo límite, null (entonces "no aparece")',
        () async {
      var vueltas = 0;
      final lector = await esperarRegresoDelLector(
        buscar: (_) async {
          vueltas++;
          return null;
        },
        terminar: (_) async => true,
        pausa: Duration.zero,
        limite: const Duration(seconds: 30),
        ahora: reloj(),
      );
      expect(lector, isNull);
      expect(vueltas, greaterThan(1), reason: 'lo sigue buscando un rato');
    });

    test('si al final solo se le vio ofreciéndose, se da por conectado',
        () async {
      final lector = await esperarRegresoDelLector(
        buscar: respuestas([_ofreciendose]),
        terminar: (_) async => true,
        pausa: Duration.zero,
        limite: const Duration(seconds: 10),
        ahora: reloj(),
      );
      expect(lector, _ofreciendose);
    });

    test('deja de buscar si ya no hace falta (se cerró la pantalla)',
        () async {
      var vueltas = 0;
      final lector = await esperarRegresoDelLector(
        buscar: (_) async {
          vueltas++;
          return null;
        },
        terminar: (_) async => true,
        seguir: () => vueltas < 2,
        pausa: Duration.zero,
      );
      expect(lector, isNull);
      expect(vueltas, 2);
    });
  });

  group('Buscar al cliente de una tarjeta', () {
    test('sin internet NO es "tarjeta no registrada": avisa el error',
        () async {
      final repo = UserRepository(_FakeSupabaseApiProvider(
          {'error': true, 'message': 'SocketException', 'data': null}));
      expect(() => repo.getUserByRfid('EA7F8005'),
          throwsA(isA<ErrorAlBuscarTarjeta>()));
    });

    test('una tarjeta que nadie tiene sí es null', () async {
      final repo = UserRepository(_FakeSupabaseApiProvider(
          {'error': false, 'message': 'Usuario no encontrado', 'data': null}));
      expect(await repo.getUserByRfid('EA7F8005'), isNull);
    });
  });
}

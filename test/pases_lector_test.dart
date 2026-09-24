import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/app/modules/shared/widgets/welcome_screen_widget.dart';

/// Solo las tarjetas de los pases nuevos, en orden.
List<String> uids(List<PaseLector> pases) => [for (final p in pases) p.uid];

RespuestaLecturas respuesta(int seq, List<(int, String, int)> pases) =>
    RespuestaLecturas(
      seq: seq,
      lecturas: [
        for (final (s, uid, hace) in pases)
          PaseLector(seq: s, uid: uid, haceMs: hace),
      ],
    );

void main() {
  group('Pases del lector', () {
    test('al empezar a escuchar no se procesan pases viejos', () {
      final seg = SeguimientoPases();
      expect(seg.desde, 0);
      expect(
          seg.nuevos(respuesta(5, [(4, 'VIEJA', 60000), (5, 'VIEJA2', 30000)])),
          isEmpty);
      expect(seg.desde, 5);
    });

    test('dos tarjetas seguidas se procesan las dos, en orden', () {
      final seg = SeguimientoPases()..nuevos(respuesta(5, []));
      final tarjetas = seg.nuevos(respuesta(7, [(7, 'B', 100), (6, 'A', 900)]));
      expect(uids(tarjetas), ['A', 'B']);
      // Con cuánto hace de cada uno se sabe su hora real.
      expect(tarjetas.first.haceMs, 900);
      expect(seg.desde, 7);
    });

    test('un pase no se procesa dos veces', () {
      final seg = SeguimientoPases()..nuevos(respuesta(5, []));
      expect(uids(seg.nuevos(respuesta(6, [(6, 'A', 100)]))), ['A']);
      // El lector lo vuelve a mandar (se pidió desde un número anterior).
      expect(seg.nuevos(respuesta(6, [(6, 'A', 700)])), isEmpty);
    });

    test('un pase que ocurrió entre dos consultas no se pierde', () {
      final seg = SeguimientoPases()..nuevos(respuesta(10, []));
      // La tarjeta se acercó y se retiró antes de la siguiente consulta: con
      // /api/uid se habría perdido; aquí queda registrada.
      expect(
          uids(seg.nuevos(respuesta(11, [(11, 'RAPIDA', 1500)]))), ['RAPIDA']);
    });

    test('si el lector se reinicia, se recupera solo lo reciente', () {
      final seg = SeguimientoPases()..nuevos(respuesta(40, []));

      // Tras reiniciar, el lector cuenta desde 1: el número bajó.
      expect(seg.nuevos(respuesta(2, [])), isEmpty);
      expect(seg.desde, 0);

      final tarjetas =
          seg.nuevos(respuesta(2, [(1, 'VIEJA', 25000), (2, 'RECIENTE', 800)]));
      expect(uids(tarjetas), ['RECIENTE']);
      expect(seg.desde, 2);
    });

    test('reiniciar olvida lo visto (p. ej. al reanudar tras una pausa)', () {
      final seg = SeguimientoPases()..nuevos(respuesta(3, []));
      seg.reiniciar();
      expect(seg.nuevos(respuesta(4, [(4, 'DURANTE_PAUSA', 500)])), isEmpty);
    });

    test('lee la respuesta del firmware', () {
      final r = RespuestaLecturas.fromJson({
        'seq': 18,
        'lecturas': [
          {'seq': 17, 'uid': 'EA7F8005', 'hace_ms': 830},
        ],
      });
      expect(r.seq, 18);
      expect(r.lecturas.single.uid, 'EA7F8005');
      expect(r.lecturas.single.haceMs, 830);
    });
  });

  group('Aviso al pasar la tarjeta', () {
    Future<int Function()> mostrar(WidgetTester tester) async {
      var cerrado = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WelcomeScreenWidget(
            userName: 'María',
            userPhotoUrl: '',
            daysLeft: 20,
            isVisible: true,
            onClose: () => cerrado++,
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 2));
      return () => cerrado;
    }

    testWidgets('tiene una X para cerrarlo', (tester) async {
      final cerrado = await mostrar(tester);
      final x = find.byTooltip('Cerrar');
      expect(find.descendant(of: x, matching: find.byIcon(Icons.close)),
          findsOneWidget);
      await tester.tap(x);
      expect(cerrado(), 1);
    });

    testWidgets('también se cierra tocando en cualquier parte', (tester) async {
      final cerrado = await mostrar(tester);
      await tester.tapAt(const Offset(40, 400));
      expect(cerrado(), 1);
    });
  });
}

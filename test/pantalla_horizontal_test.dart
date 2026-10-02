import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/cabecera_con_lista.dart';
import 'package:gymads/app/core/widgets/centrado_desplazable.dart';
import 'package:gymads/app/modules/shared/widgets/welcome_screen_widget.dart';
import 'package:gymads/app/modules/staff_accesos/views/codigo_generado_dialog.dart';

/// Un iPhone de lado: 844 x 390 puntos. Si algo desborda, Flutter lanza la
/// excepción "A RenderFlex overflowed" y la prueba falla.
const _deLado = Size(844, 390);
const _vertical = Size(390, 844);

Future<void> _pantalla(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump(const Duration(seconds: 2));
}

Widget _cabeceraAlta() => Column(
      children: List.generate(
        4,
        (i) => SizedBox(height: 90, child: Text('Cabecera $i')),
      ),
    );

void main() {
  group('CabeceraConLista', () {
    testWidgets('de lado no desborda aunque la cabecera sea más alta que la '
        'pantalla', (tester) async {
      await _pantalla(
        tester,
        _deLado,
        CabeceraConLista(
          cabecera: [_cabeceraAlta()],
          lista: ListView.builder(
            itemCount: 50,
            itemBuilder: (_, i) => ListTile(title: Text('Fila $i')),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      // La cabecera se va con el desplazamiento y aparece la lista.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Cabecera 0'), findsNothing);
      expect(find.textContaining('Fila'), findsWidgets);
    });

    testWidgets('en vertical la cabecera queda fija', (tester) async {
      await _pantalla(
        tester,
        _vertical,
        CabeceraConLista(
          cabecera: [_cabeceraAlta()],
          lista: ListView.builder(
            itemCount: 50,
            itemBuilder: (_, i) => ListTile(title: Text('Fila $i')),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(NestedScrollView), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Cabecera 0'), findsOneWidget);
    });
  });

  testWidgets('CentradoDesplazable no desborda de lado', (tester) async {
    await _pantalla(
      tester,
      _deLado,
      CentradoDesplazable(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: List.generate(
            6,
            (i) => SizedBox(height: 80, child: Text('Bloque $i')),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('Bienvenida al pasar la tarjeta', () {
    for (final caso in {
      'bienvenida': const WelcomeScreenWidget(
        userName: 'María Fernanda González',
        userPhotoUrl: '',
        daysLeft: 12,
        isVisible: true,
      ),
      'vencida': WelcomeScreenWidget(
        userName: 'María Fernanda González',
        userPhotoUrl: '',
        daysLeft: 0,
        isVisible: true,
        isExpired: true,
        onAbonar: () {},
        onEditar: () {},
      ),
      'no registrada': WelcomeScreenWidget(
        userName: '',
        userPhotoUrl: '',
        daysLeft: 0,
        isVisible: true,
        isNotFound: true,
        onRegister: () {},
      ),
    }.entries) {
      testWidgets('${caso.key}: de lado no desborda', (tester) async {
        await _pantalla(tester, _deLado, caso.value);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('Código generado para el personal: de lado no desborda',
      (tester) async {
    tester.view.physicalSize = _deLado * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));

    showCodigoGeneradoDialog(
      nombre: 'María Fernanda',
      codigo: 'ABCD-1234',
      gymName: 'Gimnasio de prueba',
    );
    await tester.pumpAndSettle();

    expect(find.text('ABCD-1234'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

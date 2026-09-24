import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:gymads/app/modules/configuracion/views/agregar_lector_view.dart';

/// Un Bluetooth que no encuentra nada: la prueba pone las redes a mano.
class _BleFalso extends LectorBleService {
  @override
  Stream<List<LectorCercano>> buscar({
    Duration duracion = const Duration(seconds: 15),
  }) =>
      const Stream.empty();

  @override
  Future<void> detenerBusqueda() async {}

  @override
  Future<void> desconectar() async {}
}

void main() {
  const campoClave = Key('campo_clave_wifi');
  const textoLista = 'Toca la red del gimnasio.';

  late AgregarLectorController controller;

  Future<void> abrirEnLista(WidgetTester tester) async {
    controller = Get.put(AgregarLectorController(ble: _BleFalso()));
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Get.to(() => const AgregarLectorView()),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Como si el lector ya hubiera mandado las redes que ve.
    controller.redes.assignAll(const [
      RedWifi('Gym', rssi: -50),
      RedWifi('Oficina', rssi: -65, seguridad: SeguridadRed.empresarial),
      RedWifi('Invitados', rssi: -70, seguridad: SeguridadRed.abierta),
    ]);
    controller.mensaje.value = null;
    controller.paso.value = PasoAgregar.elegirRed;
    await tester.pumpAndSettle();
  }

  tearDown(Get.reset);

  testWidgets('la lista va sola: tocar una red lleva a su contraseña',
      (tester) async {
    await abrirEnLista(tester);
    expect(find.text(textoLista), findsOneWidget);
    expect(find.byKey(campoClave), findsNothing);

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();

    expect(controller.paso.value, PasoAgregar.escribirClave);
    expect(find.byKey(campoClave), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget); // el nombre de la red elegida
    expect(find.text(textoLista), findsNothing);
  });

  testWidgets('"Cambiar de red" regresa a la lista', (tester) async {
    await abrirEnLista(tester);
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cambiar de red'));
    await tester.pumpAndSettle();

    expect(find.text(textoLista), findsOneWidget);
    expect(find.byKey(campoClave), findsNothing);
    expect(controller.redElegida.value, isNull);
  });

  testWidgets('atrás en la contraseña regresa a la lista sin cerrar; '
      'atrás en la lista sí cierra', (tester) async {
    await abrirEnLista(tester);
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AgregarLectorView), findsOneWidget);
    expect(find.text(textoLista), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AgregarLectorView), findsNothing);
  });

  testWidgets('una red que el lector no puede usar no avanza', (tester) async {
    await abrirEnLista(tester);

    await tester.tap(find.text('Oficina'));
    await tester.pumpAndSettle();

    expect(controller.paso.value, PasoAgregar.elegirRed);
    expect(find.byKey(campoClave), findsNothing);
    expect(find.textContaining('pide usuario y contraseña'), findsOneWidget);
  });

  testWidgets('una red abierta no pide contraseña', (tester) async {
    await abrirEnLista(tester);

    await tester.tap(find.text('Invitados'));
    await tester.pumpAndSettle();

    expect(find.text('Esta red no tiene contraseña.'), findsOneWidget);
    expect(find.byKey(campoClave), findsNothing);
    expect(find.text('Conectar'), findsOneWidget);
  });

  testWidgets('"Otra red" pide el nombre y la contraseña', (tester) async {
    await abrirEnLista(tester);

    await tester.tap(find.text('Otra red'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre de la red'), findsOneWidget);
    expect(find.byKey(campoClave), findsOneWidget);
  });
}

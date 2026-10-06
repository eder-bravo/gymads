import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/pantalla_clientes.dart';
import 'package:gymads/app/modules/pantalla_clientes/pantalla_clientes_app.dart';

/// La pantalla para clientes (monitor extra): solo información para el
/// cliente, con el diseño del aviso de siempre.
void main() {
  const escritorio = TargetPlatformVariant(
      {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux});

  test('el aviso llega igual a la otra ventana (ida y vuelta en JSON)', () {
    final aviso = AvisoParaClientes(
      id: 7,
      tipo: TipoAviso.vencida,
      nombre: 'Leo',
      fotoUrl: 'https://foto/firmada',
      diasRestantes: 0,
      vence: DateTime(2026, 9, 30),
      duracion: const Duration(seconds: 6),
    );
    final vuelta = AvisoParaClientes.fromJson(aviso.toJson());
    expect(vuelta.id, 7);
    expect(vuelta.tipo, TipoAviso.vencida);
    expect(vuelta.nombre, 'Leo');
    expect(vuelta.fotoUrl, 'https://foto/firmada');
    expect(vuelta.vence, DateTime(2026, 9, 30));
    expect(vuelta.duracion, const Duration(seconds: 6));
  });

  test('sin la ventana abierta, mandar un pase no hace nada', () {
    PantallaClientes.abierta.value = false;
    PantallaClientes.mostrar(
        tipo: TipoAviso.entrada, duracion: const Duration(seconds: 4));
  });

  test('cada pase sale con su número y sus datos', () {
    final enviados = <(String, Object?)>[];
    PantallaClientes.enviarPara =
        (metodo, datos) => enviados.add((metodo, datos));
    addTearDown(() => PantallaClientes.enviarPara = null);
    PantallaClientes.mostrar(
        tipo: TipoAviso.entrada,
        nombre: 'Ana',
        diasRestantes: 20,
        duracion: const Duration(seconds: 4));
    PantallaClientes.mostrar(
        tipo: TipoAviso.noRegistrada, duracion: const Duration(seconds: 6));
    expect(enviados.map((e) => e.$1), ['aviso', 'aviso']);
    final primero = AvisoParaClientes.fromJson(enviados[0].$2! as Map);
    final segundo = AvisoParaClientes.fromJson(enviados[1].$2! as Map);
    expect(primero.nombre, 'Ana');
    expect(segundo.id, greaterThan(primero.id));
    // Una tarjeta no registrada nunca lleva nombre ni número.
    expect(segundo.nombre, isEmpty);
  });

  Future<ValueNotifier<AvisoParaClientes?>> mostrar(WidgetTester tester,
      {Size tamano = const Size(1024, 768)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = tamano;
    addTearDown(tester.view.reset);
    final avisos = ValueNotifier<AvisoParaClientes?>(null);
    await tester.pumpWidget(MaterialApp(
      home: PantallaClientesVista(
        avisos: avisos,
        ahora: () => DateTime(2026, 10, 6, 16, 23),
      ),
    ));
    await tester.pump();
    return avisos;
  }

  /// Ninguna acción del mostrador: ni botones ni la X para cerrar.
  void sinAccionesDelMostrador() {
    for (final texto in ['Abonar', 'Editar', 'Registrar']) {
      expect(find.text(texto), findsNothing, reason: texto);
    }
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  }

  testWidgets('en espera: logo, "Pasa tu tarjeta" y la hora', (tester) async {
    await mostrar(tester);
    expect(find.text('Pasa tu tarjeta'), findsOneWidget);
    expect(find.text('4:23 p.m.'), findsOneWidget);
    expect(find.text('Martes 6 de octubre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: escritorio);

  testWidgets('entrada: su nombre y la bienvenida, y luego vuelve a la espera',
      (tester) async {
    final avisos = await mostrar(tester);
    avisos.value = AvisoParaClientes(
      id: 1,
      tipo: TipoAviso.entrada,
      nombre: 'Ana López',
      diasRestantes: 20,
      vence: DateTime(2026, 10, 26),
      duracion: const Duration(seconds: 4),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('¡Bienvenido!'), findsOneWidget);
    expect(find.text('Pasa tu tarjeta'), findsNothing);
    sinAccionesDelMostrador();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Pasa tu tarjeta'), findsOneWidget);
    expect(find.text('Ana López'), findsNothing);
  }, variant: escritorio);

  testWidgets('vencida: cuándo venció y que pase al mostrador, sin Abonar',
      (tester) async {
    final avisos = await mostrar(tester);
    avisos.value = AvisoParaClientes(
      id: 2,
      tipo: TipoAviso.vencida,
      nombre: 'Carlos Ruiz',
      vence: DateTime(2026, 9, 30),
      duracion: const Duration(seconds: 6),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Carlos Ruiz'), findsOneWidget);
    expect(find.text('Membresía vencida'), findsOneWidget);
    expect(find.text('Tu membresía venció el 30/09/2026'), findsOneWidget);
    expect(find.text('Pasa al mostrador para renovarla'), findsOneWidget);
    sinAccionesDelMostrador();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Pasa tu tarjeta'), findsOneWidget);
  }, variant: escritorio);

  testWidgets('tarjeta no registrada: sin número de tarjeta y sin Registrar',
      (tester) async {
    final avisos = await mostrar(tester);
    avisos.value = const AvisoParaClientes(
      id: 3,
      tipo: TipoAviso.noRegistrada,
      duracion: Duration(seconds: 6),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tarjeta no registrada'), findsOneWidget);
    expect(find.text('Pasa al mostrador para registrar tu tarjeta'),
        findsOneWidget);
    sinAccionesDelMostrador();
    await tester.pump(const Duration(seconds: 5));
  }, variant: escritorio);

  testWidgets('un pase nuevo reemplaza al anterior', (tester) async {
    final avisos = await mostrar(tester);
    avisos.value =
        const AvisoParaClientes(id: 1, tipo: TipoAviso.entrada, nombre: 'Ana');
    await tester.pump(const Duration(seconds: 1));
    avisos.value =
        const AvisoParaClientes(id: 2, tipo: TipoAviso.salida, nombre: 'Jorge');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Jorge'), findsOneWidget);
    expect(find.text('¡Hasta pronto!'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    // Cuenta desde el último pase: a los 3 s sigue Jorge.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Jorge'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Pasa tu tarjeta'), findsOneWidget);
  }, variant: escritorio);

  testWidgets('se ve completo en ventanas chicas y monitores grandes',
      (tester) async {
    for (final tamano in [
      const Size(480, 360),
      const Size(1920, 1080),
      const Size(3840, 2160),
      const Size(1080, 1920),
    ]) {
      final avisos = await mostrar(tester, tamano: tamano);
      expect(tester.takeException(), isNull, reason: 'espera $tamano');
      avisos.value = AvisoParaClientes(
        id: 9,
        tipo: TipoAviso.vencida,
        nombre: 'María Fernanda González Rodríguez',
        vence: DateTime(2026, 9, 30),
        duracion: const Duration(seconds: 6),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'aviso $tamano');
      await tester.pump(const Duration(seconds: 5));
    }
  }, variant: escritorio);
}

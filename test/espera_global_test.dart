import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/fallo_al_guardar.dart';
import 'package:gymads/app/core/widgets/espera_global.dart';
import 'package:gymads/core/theme/app_theme.dart';

/// La espera de toda la app al guardar: círculo al centro, velo que no deja
/// tocar, y si falla, una tarjeta con el motivo y "Reintentar".
void main() {
  final espera = EsperaGlobal.to;
  tearDown(() {
    espera.reiniciar();
    Get.reset();
  });

  Future<List<int>> abrir(WidgetTester tester, {bool oscuro = false}) async {
    final toques = <int>[];
    espera.vigilarRegreso();
    await tester.pumpWidget(GetMaterialApp(
      theme: oscuro ? AppTheme.oscuro : AppTheme.claro,
      builder: (context, child) => CapaDeEspera(child: child!),
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => toques.add(1),
            child: const Text('Detrás'),
          ),
        ),
      ),
    ));
    return toques;
  }

  testWidgets('mientras guarda hay círculo y velo, y lo de atrás no se toca',
      (tester) async {
    final toques = await abrir(tester);
    final respuesta = Completer<int>();
    final resultado = espera.guardar(() => respuesta.future,
        queHace: 'registrar la venta');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Registrando la venta…'), findsOneWidget);
    await tester.tap(find.text('Detrás'), warnIfMissed: false);
    expect(toques, isEmpty);

    respuesta.complete(7);
    await tester.pump(EsperaGlobal.minimo);
    expect(await resultado, 7);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Detrás'));
    expect(toques, [1]);
  });

  testWidgets('el círculo se ve al menos un momento aunque termine al instante',
      (tester) async {
    await abrir(tester);
    var listo = false;
    espera
        .guardar(() async => 1, queHace: 'guardar')
        .then((_) => listo = true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(listo, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(EsperaGlobal.minimo);
    expect(listo, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('sin internet lo dice y "Reintentar" vuelve a mandarlo',
      (tester) async {
    await abrir(tester);
    var intentos = 0;
    final resultado = espera.guardar(() async {
      intentos++;
      if (intentos == 1) {
        throw const SocketException('Failed host lookup: supabase.co');
      }
      return 'guardado';
    }, queHace: 'registrar al cliente');
    await tester.pump(EsperaGlobal.minimo);
    await tester.pump();

    expect(find.text('No se pudo registrar al cliente'), findsOneWidget);
    expect(
        find.text(
            'No hay conexión a internet. Revisa tu conexión e intenta de nuevo.'),
        findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump(EsperaGlobal.minimo);
    expect(intentos, 2);
    expect(await resultado, 'guardado');
    await tester.pumpAndSettle();
    expect(find.text('No se pudo registrar al cliente'), findsNothing);
  });

  testWidgets('"Cerrar" devuelve null y quita el velo', (tester) async {
    final toques = await abrir(tester);
    final resultado = espera.guardar<int>(
        () async => throw Exception('base de datos'),
        queHace: 'guardar el producto',
        generico: 'No se pudo guardar el producto. Intenta de nuevo.');
    await tester.pump(EsperaGlobal.minimo);
    await tester.pump();
    expect(find.text('No se pudo guardar el producto. Intenta de nuevo.'),
        findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    expect(await resultado, isNull);
    await tester.pumpAndSettle();
    expect(espera.ocupado, isFalse);
    await tester.tap(find.text('Detrás'));
    expect(toques, [1]);
  });

  testWidgets('si se agota el tiempo de un cobro no ofrece reintentar',
      (tester) async {
    await abrir(tester);
    final nunca = Completer<int>();
    final resultado = espera.guardar(() => nunca.future,
        queHace: 'registrar la venta',
        siQuedoEnDuda: 'Puede que la venta sí se haya registrado.');
    await tester.pump(limiteAlGuardar);
    await tester.pump();

    expect(find.text('Puede que la venta sí se haya registrado.'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    await tester.tap(find.text('Entendido'));
    expect(await resultado, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('un cobro que ni siquiera salió sí se puede reintentar',
      (tester) async {
    await abrir(tester);
    final resultado = espera.guardar<int>(
        () async => throw const SocketException('Failed host lookup: x'),
        queHace: 'registrar la venta',
        siQuedoEnDuda: 'Puede que la venta sí se haya registrado.');
    await tester.pump(EsperaGlobal.minimo);
    await tester.pump();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Puede que la venta sí se haya registrado.'),
        findsNothing);
    await tester.tap(find.text('Cerrar'));
    expect(await resultado, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('si la base rechaza un cobro no queda en duda', (tester) async {
    await abrir(tester);
    final resultado = espera.guardar<int>(
        () async => throw Exception('violates check constraint'),
        queHace: 'registrar la venta',
        generico: 'La venta no se registró. Intenta de nuevo.',
        siQuedoEnDuda: 'Puede que la venta sí se haya registrado.');
    await tester.pump(EsperaGlobal.minimo);
    await tester.pump();
    expect(find.text('La venta no se registró. Intenta de nuevo.'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    expect(await resultado, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('un mensaje propio se muestra tal cual, sin reintentar',
      (tester) async {
    await abrir(tester);
    final resultado = espera.guardar<int>(
        () async => throw const GuardadoFallido('Esa tarjeta ya es de otro.'),
        queHace: 'registrar al cliente');
    await tester.pump(EsperaGlobal.minimo);
    await tester.pump();
    expect(find.text('Esa tarjeta ya es de otro.'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    await tester.tap(find.text('Entendido'));
    expect(await resultado, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('un segundo guardado mientras hay uno en curso no se manda',
      (tester) async {
    await abrir(tester);
    final respuesta = Completer<int>();
    var segundo = 0;
    final primero =
        espera.guardar(() => respuesta.future, queHace: 'registrar la venta');
    expect(
        await espera.guardar(() async => ++segundo,
            queHace: 'registrar la venta'),
        isNull);
    expect(segundo, 0);
    respuesta.complete(1);
    await tester.pump(EsperaGlobal.minimo);
    expect(await primero, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('"atrás" no cierra la pantalla mientras guarda', (tester) async {
    await abrir(tester);
    Get.to(() => const Scaffold(body: Text('Formulario')));
    await tester.pumpAndSettle();

    final respuesta = Completer<int>();
    final resultado =
        espera.guardar(() => respuesta.future, queHace: 'registrar la venta');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Formulario'), findsOneWidget);

    respuesta.complete(1);
    await tester.pump(EsperaGlobal.minimo);
    await resultado;
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Formulario'), findsNothing);
  });

  testWidgets('sin la capa en pantalla corre la tarea y un fallo es null',
      (tester) async {
    expect(await espera.guardar(() async => 3, queHace: 'guardar'), 3);
    expect(
        await espera.guardar<int>(() async => throw Exception('x'),
            queHace: 'guardar'),
        isNull);
    expect(espera.ocupado, isFalse);
  });

  testWidgets('la tarjeta de fallo se lee en modo oscuro', (tester) async {
    await abrir(tester, oscuro: true);
    final resultado = espera.guardar<int>(
        () async => throw const SocketException('Failed host lookup: x'),
        queHace: 'registrar el abono');
    await tester.pump(EsperaGlobal.minimo);
    await tester.pump();
    expect(find.text('No se pudo registrar el abono'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    expect(await resultado, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('un +1 al stock que tarda poco no enseña el círculo, pero bloquea',
      (tester) async {
    final toques = await abrir(tester);
    final respuesta = Completer<int>();
    final resultado = espera.guardar(() => respuesta.future,
        queHace: 'actualizar el stock', rapido: true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Detrás'), warnIfMissed: false);
    expect(toques, isEmpty);

    // Si tarda, sí aparece.
    await tester.pump(EsperaGlobal.antesDelCirculo);
    await tester.pump();
    expect(find.text('Actualizando el stock…'), findsOneWidget);
    respuesta.complete(5);
    expect(await resultado, 5);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  test('lo que dice el círculo', () {
    expect(EsperaGlobal.enGerundio('registrar la venta'),
        'Registrando la venta…');
    expect(EsperaGlobal.enGerundio('cobrar la visita'), 'Cobrando la visita…');
    expect(EsperaGlobal.enGerundio('guardar tu nombre'), 'Guardando tu nombre…');
    expect(EsperaGlobal.enGerundio('eliminar al cliente'),
        'Eliminando al cliente…');
  });
}

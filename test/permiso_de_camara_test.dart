import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/permiso_de_camara.dart';
import 'package:permission_handler/permission_handler.dart';

/// La cámara se pide al usarla (foto del cliente, escáner de códigos, foto
/// del comprobante), no en una pantalla de permisos al principio.
void main() {
  tearDown(Get.reset);

  Future<bool> pedir(WidgetTester tester, PermissionStatus respuesta,
      {bool avisar = true}) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    late bool resultado;
    pedirCamara(
      para: 'tomar la foto del cliente',
      avisar: avisar,
      pedir: () async => respuesta,
    ).then((r) => resultado = r);
    await tester.pumpAndSettle();
    if (find.text('Se necesita la cámara').evaluate().isNotEmpty) {
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
    }
    return resultado;
  }

  const moviles =
      TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

  testWidgets('permitida: sigue sin avisos', (tester) async {
    expect(await pedir(tester, PermissionStatus.granted), isTrue);
  }, variant: moviles);

  testWidgets('negada en el aviso: no insiste', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    pedirCamara(para: 'x', pedir: () async => PermissionStatus.denied);
    await tester.pumpAndSettle();
    expect(find.text('Se necesita la cámara'), findsNothing);
  }, variant: moviles);

  testWidgets('bloqueada: explica y ofrece abrir los ajustes', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    late bool resultado;
    pedirCamara(
      para: 'tomar la foto del cliente',
      pedir: () async => PermissionStatus.permanentlyDenied,
    ).then((r) => resultado = r);
    await tester.pumpAndSettle();
    expect(find.text('Se necesita la cámara'), findsOneWidget);
    expect(
        find.textContaining('Para tomar la foto del cliente'), findsOneWidget);
    expect(find.text('Abrir ajustes'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(resultado, isFalse);
  }, variant: moviles);

  testWidgets('bloqueada sin aviso (lo explica la pantalla)', (tester) async {
    expect(
        await pedir(tester, PermissionStatus.permanentlyDenied, avisar: false),
        isFalse);
    expect(find.text('Se necesita la cámara'), findsNothing);
  }, variant: moviles);

  testWidgets('si no se pudo preguntar, deja que la cámara lo intente',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    final permitida = await pedirCamara(
        para: 'x', pedir: () async => throw Exception('sin plugin'));
    expect(permitida, isTrue);
  }, variant: moviles);

  testWidgets('en computadora no se pide: la cámara lo pide al abrir',
      (tester) async {
    var preguntas = 0;
    final permitida = await pedirCamara(
        para: 'x',
        pedir: () async {
          preguntas++;
          return PermissionStatus.denied;
        });
    expect(permitida, isTrue);
    expect(preguntas, 0);
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux
      }));
}

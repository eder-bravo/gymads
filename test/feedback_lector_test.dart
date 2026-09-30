import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/rfid_reader_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:gymads/app/modules/configuracion/widgets/progreso_configuracion_lector.dart';
import 'package:gymads/app/modules/configuracion/widgets/prueba_lector_dialog.dart';
import 'package:gymads/core/theme/app_theme.dart';

typedef _Resultado = ({RespuestaLecturas? respuesta, bool sinSoporte});

_Resultado _lecturas(int seq, [List<PaseLector> pases = const []]) => (
      respuesta: RespuestaLecturas(seq: seq, lecturas: pases),
      sinSoporte: false,
    );

const _vieja = PaseLector(seq: 7, uid: 'ANTERIOR', haceMs: 60000);
const _nueva = PaseLector(seq: 8, uid: 'TARJETA', haceMs: 100);

Future<void> _abrirPrueba(
  WidgetTester tester, {
  required Future<_Resultado> Function(int) leer,
  Future<String?> Function()? leerTarjeta,
  bool reducirMovimiento = false,
  double escalaTexto = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.claro,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reducirMovimiento,
        textScaler: TextScaler.linear(escalaTexto),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(builder: (context) {
        return TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => PruebaLectorDialog(
              leerLecturas: leer,
              leerTarjeta: leerTarjeta ?? () async => null,
            ),
          ),
          child: const Text('Probar lector'),
        );
      }),
    ),
  ));
  await tester.tap(find.text('Probar lector'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _cerrarPrueba(WidgetTester tester) async {
  final cerrar = find.text('Cerrar prueba');
  await tester.ensureVisible(cerrar);
  await tester.tap(cerrar);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la espera llega a su límite estimado sin afirmar 100%',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProgresoConfiguracionLector(
          paso: PasoAgregar.conectando,
          esperandoRespuesta: true,
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 100));
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
    expect(find.text('Avance estimado'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProgresoConfiguracionLector(
          paso: PasoAgregar.comprobando,
          guardando: true,
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 100));
    expect(find.text('95%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProgresoConfiguracionLector(paso: PasoAgregar.listo),
      ),
    ));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Configuración completada'), findsOneWidget);
  });

  testWidgets('un fallo elimina el porcentaje de avance', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProgresoConfiguracionLector(paso: PasoAgregar.fallo),
    ));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Configuración completada'), findsNothing);
  });

  testWidgets('ignora lecturas anteriores y confirma una tarjeta nueva',
      (tester) async {
    var respuesta = _lecturas(7, [_vieja]);
    final desdeConsultados = <int>[];
    await _abrirPrueba(tester, leer: (desde) async {
      desdeConsultados.add(desde);
      return respuesta;
    });
    expect(find.text('Acerca la tarjeta al lector'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('¡Excelente!'), findsNothing);
    expect(desdeConsultados, [0, 7]);

    respuesta = _lecturas(8, [_vieja, _nueva]);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('¡Excelente!'), findsOneWidget);
    expect(find.textContaining('responde bien'), findsOneWidget);
    expect(find.text('TARJETA'), findsNothing);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
  });

  testWidgets('si no pasan tarjetas explica cómo reintentar', (tester) async {
    await _abrirPrueba(tester, leer: (_) async => _lecturas(7));
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.textContaining('No detectamos una tarjeta'), findsOneWidget);
    expect(find.text('¡Excelente!'), findsNothing);
    expect(find.text('Probar de nuevo'), findsOneWidget);

    await tester.tap(find.text('Probar de nuevo'));
    await tester.pump();
    expect(find.text('Acerca la tarjeta al lector'), findsOneWidget);
    await _cerrarPrueba(tester);
  });

  testWidgets('una falta de respuesta muestra revisión del WiFi',
      (tester) async {
    await _abrirPrueba(tester,
        leer: (_) async => (respuesta: null, sinSoporte: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('El lector no respondió'), findsOneWidget);
    expect(find.text('Probar de nuevo'), findsOneWidget);
    await _cerrarPrueba(tester);
  });

  testWidgets('si pierde conexión durante la espera no muestra éxito',
      (tester) async {
    var peticiones = 0;
    await _abrirPrueba(tester, leer: (_) async {
      peticiones++;
      return peticiones == 1
          ? _lecturas(0)
          : (respuesta: null, sinSoporte: false);
    });
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('El lector no respondió'), findsOneWidget);
    expect(find.text('¡Excelente!'), findsNothing);
    await _cerrarPrueba(tester);
  });

  testWidgets('cerrar ignora una respuesta que llega después', (tester) async {
    final pendiente = Completer<_Resultado>();
    var peticiones = 0;
    await _abrirPrueba(tester, leer: (_) {
      peticiones++;
      return peticiones == 1 ? Future.value(_lecturas(7)) : pendiente.future;
    });
    await tester.pump(const Duration(milliseconds: 600));
    await _cerrarPrueba(tester);
    pendiente.complete(_lecturas(8, [_nueva]));
    await tester.pump(const Duration(seconds: 31));
    expect(tester.takeException(), isNull);
    expect(find.byType(PruebaLectorDialog), findsNothing);
    expect(peticiones, 2);
  });

  testWidgets('en lectores antiguos pide una lectura posterior a la prueba',
      (tester) async {
    String? tarjeta = 'ANTERIOR';
    await _abrirPrueba(
      tester,
      leer: (_) async => (respuesta: null, sinSoporte: true),
      leerTarjeta: () async => tarjeta,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('¡Excelente!'), findsNothing);
    tarjeta = null; // Se retira la tarjeta.
    await tester.pump(const Duration(milliseconds: 600));
    tarjeta = 'ANTERIOR'; // Se vuelve a acercar la misma tarjeta.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('¡Excelente!'), findsOneWidget);
  });

  testWidgets('con reducir movimiento la indicación permanece sin animación',
      (tester) async {
    await _abrirPrueba(tester,
        leer: (_) async => _lecturas(0), reducirMovimiento: true);
    await tester.pumpAndSettle();
    expect(find.text('Acerca la tarjeta al lector'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await _cerrarPrueba(tester);
  });

  testWidgets('en pantalla pequeña y letra grande conserva botones accesibles',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _abrirPrueba(tester, leer: (_) async => _lecturas(0), escalaTexto: 2);
    expect(tester.takeException(), isNull);
    await _cerrarPrueba(tester);
    expect(tester.takeException(), isNull);
  });
}

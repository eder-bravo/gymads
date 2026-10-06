import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/repositories/abono_prices_repository.dart';
import 'package:gymads/app/data/repositories/codigo_abono_libre_repository.dart';
import 'package:gymads/app/data/repositories/user_repository.dart';
import 'package:gymads/app/data/services/ingreso_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:gymads/app/modules/abonar/views/abonar_view.dart';
import 'package:gymads/app/modules/configuracion/controllers/abono_prices_controller.dart';
import 'package:gymads/app/modules/configuracion/views/abono_prices_view.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// Con costos fijos, el mostrador necesita el código del encargado para
/// cobrar un abono libre; el dueño y el encargado no. Autoriza un solo cobro.

class _Codigo extends CodigoAbonoLibreRepository {
  bool? hay = true;
  ResultadoAutorizacion? forzado;
  final guardados = <String?>[];
  int intentos = 0;
  @override
  Future<bool?> hayCodigo() async => hay;
  @override
  Future<bool> guardar(String? pin) async {
    guardados.add(pin);
    return true;
  }

  @override
  Future<ResultadoAutorizacion> autorizar(String pin) async {
    intentos++;
    return forzado ??
        (pin == '1234'
            ? ResultadoAutorizacion.ok
            : ResultadoAutorizacion.incorrecto);
  }
}

class _Usuarios extends Fake implements UserRepository {
  @override
  Future<List<UserModel>> getAllUsers() async => [];
  @override
  Future<bool> updateUser(String id, UserModel user, {File? photoFile}) async =>
      true;
}

class _Precios extends Fake implements AbonoPricesRepository {
  _Precios(this.precios);
  final AbonoPricesModel precios;
  @override
  Future<AbonoPricesModel> getPrices() async => precios;
}

class _Ingresos extends Fake implements IngresoService {
  int cobros = 0;
  @override
  Future<bool> registrarAbono({
    required String clienteId,
    required String clienteNombre,
    required double monto,
    double cuotaRegistro = 0,
    required String metodoPago,
    required String descripcion,
    required String usuarioStaff,
    String? notas,
    DateTime? periodoInicio,
    DateTime? periodoFin,
    String? referenciaPago,
  }) async {
    cobros++;
    return true;
  }
}

class _SinTours implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async => {};
  @override
  Future<void> marcarVisto(String rol, String tourId) async {}
}

UserModel _cliente(String nombre) => UserModel(
      id: nombre,
      name: nombre,
      phone: '+520000000000',
      joinDate: DateTime(2026),
      expirationDate: DateTime.now().add(const Duration(days: 3)),
      userNumber: '1',
    );

void main() {
  late ShowcaseView tour;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tour = ShowcaseView.register();
    Get.put(WelcomeTourService(
      toursDelEmpleado: _SinTours(),
      sesion: () =>
          (gymId: 'gym', perfilId: 'p', rol: 'mostrador', esEmpleado: true),
    ));
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  ({AbonarController c, _Codigo codigo, _Ingresos ingresos}) abonar({
    bool mostrador = true,
    AbonoPricesModel precios = const AbonoPricesModel(priceMonth: 500),
  }) {
    final codigo = _Codigo();
    final ingresos = _Ingresos();
    final c = Get.put(AbonarController(
      userRepository: _Usuarios(),
      ingresoService: ingresos,
      pricesRepository: _Precios(precios),
      codigoRepository: codigo,
      sinCodigoParaLibre: () => !mostrador,
    ));
    c.selectedClient.value = _cliente('Juan Pérez');
    return (c: c, codigo: codigo, ingresos: ingresos);
  }

  Future<void> mostrar(WidgetTester tester, Size tamano,
      {double escala = 1}) async {
    tester.view.physicalSize = tamano * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.oscuro,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: VentanaEscritorio(child: child!),
      ),
      home: const AbonarView(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tocarLibre(WidgetTester tester) async {
    // Con letra grande puede quedar abajo: se desplaza hasta verla.
    if (find.text('Abono libre').evaluate().isEmpty) {
      // La lista de pasos (en tableta y computadora, la de la izquierda).
      await tester.scrollUntilVisible(find.text('Abono libre'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first);
    }
    await tester.tap(find.text('Abono libre'));
    await tester.pumpAndSettle();
  }

  Future<void> escribirCodigo(WidgetTester tester, String pin) async {
    await tester.enterText(find.byKey(const Key('codigo_encargado')), pin);
    await tester.tap(find.text('Autorizar'));
    await tester.pumpAndSettle();
  }

  /// Los avisos (snackbars) se quitan solos.
  Future<void> terminar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  final versiones = <({String nombre, Size tamano, TargetPlatform plataforma})>[
    (
      nombre: 'teléfono',
      tamano: const Size(390, 844),
      plataforma: TargetPlatform.android
    ),
    (
      nombre: 'tableta',
      tamano: const Size(1180, 820),
      plataforma: TargetPlatform.iOS
    ),
    (
      nombre: 'computadora',
      tamano: const Size(1280, 800),
      plataforma: TargetPlatform.macOS
    ),
  ];

  for (final v in versiones) {
    testWidgets(
        '${v.nombre}: el mostrador necesita el código; el incorrecto no '
        'deja pasar, el correcto sí y solo para ese cobro', (tester) async {
      final (:c, :codigo, :ingresos) = abonar();
      await mostrar(tester, v.tamano);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      await tocarLibre(tester);
      expect(find.text('Autorización del encargado'), findsOneWidget);
      await escribirCodigo(tester, '9999');
      expect(find.text('Código incorrecto.'), findsOneWidget);
      expect(c.isPrecioFijo.value, isTrue);

      await escribirCodigo(tester, '1234');
      expect(find.text('Autorización del encargado'), findsNothing);
      expect(c.isPrecioFijo.value, isFalse);
      expect(c.libreAutorizado.value, isTrue);

      await tester.enterText(find.byKey(const Key('monto_libre')), '300');
      await tester.pumpAndSettle();
      await c.procesarAbono();
      await tester.pumpAndSettle();
      expect(ingresos.cobros, 1);
      // Para el siguiente cliente se vuelve a pedir.
      expect(c.libreAutorizado.value, isFalse);
      c.clearSelection();
      c.selectClient(_cliente('Ana López'));
      await tester.pumpAndSettle();
      expect(c.isPrecioFijo.value, isTrue);
      await tocarLibre(tester);
      expect(find.text('Autorización del encargado'), findsOneWidget);
      expect(codigo.intentos, 2);
      await tester.tap(find.text('Cancelar'));
      await terminar(tester);
    }, variant: TargetPlatformVariant.only(v.plataforma));

    testWidgets('${v.nombre}: el diálogo cabe con texto grande',
        (tester) async {
      abonar();
      for (final escala in [1.3, 2.0]) {
        await mostrar(tester, v.tamano, escala: escala);
        await tocarLibre(tester);
        expect(tester.takeException(), isNull, reason: 'texto $escala');
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      }
    }, variant: TargetPlatformVariant.only(v.plataforma));
  }

  testWidgets('el encargado y el dueño cambian directo, sin código',
      (tester) async {
    final (:c, :codigo, ingresos: _) = abonar(mostrador: false);
    await mostrar(tester, const Size(1280, 800));
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tocarLibre(tester);
    expect(find.text('Autorización del encargado'), findsNothing);
    expect(c.isPrecioFijo.value, isFalse);
    expect(codigo.intentos, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('sin costos fijos no se pide código', (tester) async {
    final (:c, :codigo, :ingresos) = abonar(precios: const AbonoPricesModel());
    await mostrar(tester, const Size(1280, 800));
    expect(c.isPrecioFijo.value, isFalse);
    expect(c.necesitaCodigoParaLibre, isFalse);
    await tester.enterText(find.byKey(const Key('monto_libre')), '300');
    await tester.pumpAndSettle();
    await c.procesarAbono();
    await tester.pumpAndSettle();
    expect(ingresos.cobros, 1);
    expect(codigo.intentos, 0);
    await terminar(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('sin código configurado explica dónde se crea', (tester) async {
    final (:c, :codigo, ingresos: _) = abonar();
    codigo.hay = false;
    await mostrar(tester, const Size(1280, 800));
    await tocarLibre(tester);
    expect(find.text('Falta el código del encargado'), findsOneWidget);
    expect(find.textContaining('Configuración › Precios de abonos'),
        findsOneWidget);
    expect(c.isPrecioFijo.value, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('con demasiados intentos pide esperar', (tester) async {
    final (:c, :codigo, ingresos: _) = abonar();
    codigo.forzado = ResultadoAutorizacion.demasiadosIntentos;
    await mostrar(tester, const Size(1280, 800));
    await tocarLibre(tester);
    await escribirCodigo(tester, '1234');
    expect(
        find.text('Demasiados intentos. Espera unos minutos.'), findsOneWidget);
    expect(c.isPrecioFijo.value, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('sin autorización no se cobra un abono libre', (tester) async {
    final (:c, codigo: _, :ingresos) = abonar();
    await mostrar(tester, const Size(1280, 800));
    // Aunque algo lo dejara en libre, el cobro lo vuelve a revisar.
    c.isPrecioFijo.value = false;
    c.montoLibre.value = 300;
    await c.procesarAbono();
    await tester.pumpAndSettle();
    expect(ingresos.cobros, 0);
    await terminar(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  group('Precios', () {
    Future<(_Codigo, AbonoPricesController)> precios(WidgetTester tester,
        {bool? hay = false}) async {
      final codigo = _Codigo()..hay = hay;
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      late AbonoPricesController c;
      await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.oscuro,
        home: Builder(builder: (_) {
          c = Get.put(AbonoPricesController(
              repository: _PreciosGuardables(), codigoRepository: codigo));
          return const AbonoPricesView();
        }),
      ));
      await tester.pumpAndSettle();
      return (codigo, c);
    }

    testWidgets('se crea escribiéndolo dos veces y nunca se muestra',
        (tester) async {
      final (codigo, _) = await precios(tester);
      await tester.scrollUntilVisible(
          find.byKey(const Key('crear_codigo')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Crear código'), findsOneWidget);
      await tester.tap(find.byKey(const Key('crear_codigo')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('codigo_nuevo')), '1234');
      await tester.enterText(find.byKey(const Key('codigo_repetido')), '1235');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Los dos códigos no coinciden.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('codigo_repetido')), '1234');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(codigo.guardados, ['1234']);
      // En el estado (y en el aviso de confirmación).
      expect(find.text('Código creado'), findsWidgets);
      expect(find.text('1234'), findsNothing);
      expect(find.text('Cambiar código'), findsOneWidget);

      await terminar(tester);
      await tester.ensureVisible(find.text('Quitar código'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar código'));
      await tester.pumpAndSettle();
      expect(codigo.guardados, ['1234', null]);
      expect(find.text('Crear código'), findsOneWidget);
      await terminar(tester);
    });

    testWidgets('un código de menos de 4 números no se acepta', (tester) async {
      final (codigo, _) = await precios(tester);
      await tester.scrollUntilVisible(
          find.byKey(const Key('crear_codigo')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('crear_codigo')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('codigo_nuevo')), '12');
      await tester.enterText(find.byKey(const Key('codigo_repetido')), '12');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('El código lleva de 4 a 6 números.'), findsOneWidget);
      expect(codigo.guardados, isEmpty);
    });
  });
}

class _PreciosGuardables extends Fake implements AbonoPricesRepository {
  @override
  Future<AbonoPricesModel> getPrices() async =>
      const AbonoPricesModel(priceMonth: 500);
  @override
  Future<bool> savePrices(AbonoPricesModel nuevos) async => true;
}

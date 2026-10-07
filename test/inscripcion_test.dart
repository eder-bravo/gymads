import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/data/models/abono_prices_model.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
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
import 'package:gymads/app/modules/ingresos/widgets/detalle_ingreso_sheet.dart';
import 'package:gymads/app/routes/app_pages.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// La inscripción: una vez, a los clientes nuevos, en el mismo cobro de su
/// primer abono (costo fijo o abono libre). Casilla marcada por defecto.

class _Usuarios extends Fake implements UserRepository {
  @override
  Future<List<UserModel>> getAllUsers() async => [];
  @override
  Future<bool> updateUser(String id, UserModel user, {File? photoFile}) async =>
      true;
}

class _Precios extends Fake implements AbonoPricesRepository {
  _Precios(this.precios);
  AbonoPricesModel precios;
  AbonoPricesModel? guardados;
  @override
  Future<AbonoPricesModel> getPrices() async => precios;
  @override
  Future<bool> savePrices(AbonoPricesModel nuevos) async {
    guardados = nuevos;
    return true;
  }
}

/// Lo que se mandó a guardar como ingreso.
class _Ingresos extends Fake implements IngresoService {
  final cobros = <({double monto, double cuotaRegistro})>[];
  DateTime? ultimoFin;
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
    cobros.add((monto: monto, cuotaRegistro: cuotaRegistro));
    ultimoFin = periodoFin;
    return true;
  }
}

class _Codigo extends CodigoAbonoLibreRepository {
  final guardados = <String?>[];
  @override
  Future<bool?> hayCodigo() async => false;
  @override
  Future<bool> guardar(String? pin) async {
    guardados.add(pin);
    return true;
  }
}

class _SinTours implements ToursDelEmpleado {
  @override
  Future<Set<String>?> vistos(String rol) async => {};
  @override
  Future<void> marcarVisto(String rol, String tourId) async {}
}

UserModel _cliente({DateTime? vence}) => UserModel(
      id: 'c1',
      name: 'Juan Pérez',
      phone: '+520000000000',
      joinDate: DateTime(2026),
      expirationDate: vence,
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
          (gymId: 'gym', perfilId: 'p', rol: 'owner_admin', esEmpleado: false),
    ));
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  const conInscripcion =
      AbonoPricesModel(priceMonth: 500, priceInscripcion: 200);

  ({AbonarController c, _Ingresos ingresos}) abonar(
      {AbonoPricesModel precios = conInscripcion, DateTime? vence}) {
    final ingresos = _Ingresos();
    final c = Get.put(AbonarController(
      userRepository: _Usuarios(),
      ingresoService: ingresos,
      pricesRepository: _Precios(precios),
    ));
    c.selectedClient.value = _cliente(vence: vence);
    return (c: c, ingresos: ingresos);
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

  /// En el teléfono el resumen es el paso 3: "Continuar" dos veces.
  Future<void> alResumen(WidgetTester tester, AbonarController c) async {
    c.continuar();
    c.continuar();
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
        '${v.nombre}: cliente nuevo, la inscripción marcada y en el total; '
        'al quitarla no se cobra', (tester) async {
      final (:c, :ingresos) = abonar();
      await mostrar(tester, v.tamano);
      await alResumen(tester, c);
      expect(find.text('Cobrar inscripción · \$200'), findsOneWidget);
      expect(find.text('Inscripción'), findsOneWidget);
      expect(find.text('Cobrar \$700'), findsOneWidget);
      expect(c.totalAmount, 700);

      await tester.tap(find.byKey(const Key('casilla_inscripcion')));
      await tester.pumpAndSettle();
      expect(c.cobrarInscripcion.value, isFalse);
      expect(find.text('Inscripción'), findsNothing);
      expect(find.text('Cobrar \$500'), findsOneWidget);

      await tester.tap(find.byKey(const Key('casilla_inscripcion')));
      await tester.pumpAndSettle();
      expect(find.text('Cobrar \$700'), findsOneWidget);
      await c.procesarAbono();
      await tester.pumpAndSettle();
      // Un solo ingreso: el abono y la inscripción, desglosados.
      expect(ingresos.cobros.single, (monto: 500.0, cuotaRegistro: 200.0));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(v.plataforma));

    testWidgets('${v.nombre}: cabe con texto grande', (tester) async {
      final (:c, ingresos: _) = abonar();
      for (final escala in [1.3, 2.0]) {
        await mostrar(tester, v.tamano, escala: escala);
        await alResumen(tester, c);
        expect(tester.takeException(), isNull, reason: 'texto $escala');
      }
    }, variant: TargetPlatformVariant.only(v.plataforma));
  }

  testWidgets('desmarcada, se cobra solo el abono', (tester) async {
    final (:c, :ingresos) = abonar();
    await mostrar(tester, const Size(1280, 800));
    c.cobrarInscripcion.value = false;
    await c.procesarAbono();
    await tester.pumpAndSettle();
    expect(ingresos.cobros.single, (monto: 500.0, cuotaRegistro: 0.0));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('un cliente que ya pagó antes no paga inscripción',
      (tester) async {
    final (:c, :ingresos) =
        abonar(vence: DateTime.now().subtract(const Duration(days: 3)));
    await mostrar(tester, const Size(1280, 800));
    expect(find.byKey(const Key('casilla_inscripcion')), findsNothing);
    expect(find.text('Cobrar \$500'), findsOneWidget);
    await c.procesarAbono();
    await tester.pumpAndSettle();
    expect(ingresos.cobros.single.cuotaRegistro, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('renovar un mes vence el mismo día del mes siguiente',
      (tester) async {
    // Vence el 6 de octubre del año que entra (aún vigente): un mes más
    // llega al 6 de noviembre, no 30 días después.
    final anio = DateTime.now().year + 1;
    final (:c, :ingresos) = abonar(vence: DateTime(anio, 10, 6, 9));
    await mostrar(tester, const Size(1280, 800));
    expect(find.textContaining('6 de noviembre'), findsOneWidget);
    await c.procesarAbono();
    await tester.pumpAndSettle();
    expect(ingresos.ultimoFin, DateTime(anio, 11, 6, 9));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('sin inscripción configurada no hay casilla', (tester) async {
    abonar(precios: const AbonoPricesModel(priceMonth: 500));
    await mostrar(tester, const Size(1280, 800));
    expect(find.byKey(const Key('casilla_inscripcion')), findsNothing);
    expect(find.text('Cobrar \$500'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('con abono libre la inscripción se suma a lo que paga',
      (tester) async {
    // Solo inscripción: el gimnasio cobra abono libre.
    final (:c, :ingresos) =
        abonar(precios: const AbonoPricesModel(priceInscripcion: 200));
    await mostrar(tester, const Size(1280, 800));
    expect(c.isPrecioFijo.value, isFalse);
    await tester.enterText(find.byKey(const Key('cantidad_libre')), '2');
    await tester.enterText(find.byKey(const Key('monto_libre')), '300');
    await tester.pumpAndSettle();
    expect(c.totalAmount, 800);
    expect(find.text('Cobrar \$800'), findsOneWidget);
    await c.procesarAbono();
    await tester.pumpAndSettle();
    expect(ingresos.cobros.single, (monto: 600.0, cuotaRegistro: 200.0));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  group('Precios', () {
    late _Codigo codigo;
    final modos = <String>[];
    Future<_Precios> precios(WidgetTester tester,
        {Map<String, dynamic>? argumentos,
        AbonoPricesModel inicial = conInscripcion}) async {
      final repo = _Precios(inicial);
      codigo = _Codigo();
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        theme: AppTheme.oscuro,
        initialRoute: '/inicio',
        getPages: [
          GetPage(name: '/inicio', page: () => const Scaffold()),
          GetPage(name: Routes.HOME, page: () => const Scaffold()),
          GetPage(
            name: '/precios',
            // Aquí, ya con los argumentos de la ruta (los lee en onInit).
            page: () {
              Get.put(AbonoPricesController(
                  repository: repo,
                  codigoRepository: codigo,
                  guardarModo: (modo) async {
                    modos.add(modo);
                    return true;
                  }));
              return const AbonoPricesView();
            },
          ),
        ],
      ));
      await tester.pumpAndSettle();
      Get.toNamed('/precios', arguments: argumentos);
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('la inscripción se configura junto con los precios',
        (tester) async {
      final repo = await precios(tester);
      expect(find.text('También se usa para cobrar una visita de un día.'),
          findsOneWidget);
      expect(find.text('Costo de inscripción'), findsOneWidget);
      expect(find.text('200.00'), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('precio_inscripcion')), '350');
      await Get.find<AbonoPricesController>().savePrices();
      expect(repo.guardados?.priceInscripcion, 350);
      expect(repo.guardados?.priceMonth, 500);
      // Vacía: no se cobra inscripción.
      await tester.enterText(find.byKey(const Key('precio_inscripcion')), '');
      await Get.find<AbonoPricesController>().savePrices();
      expect(repo.guardados?.priceInscripcion, isNull);
      // El aviso "Precios actualizados" se quita solo.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'al configurar con costos fijos se crea ahí el código '
        '(opcional)', (tester) async {
      final repo = await precios(tester,
          argumentos: {'fromOnboarding': true},
          inicial: const AbonoPricesModel(priceMonth: 500));
      final c = Get.find<AbonoPricesController>();
      expect(find.text('¿También cobrarás abonos libres?'), findsOneWidget);
      expect(find.byKey(const Key('crear_codigo')), findsNothing);
      expect(find.byKey(const Key('codigo_inicial')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('codigo_activar')));
      await tester.tap(find.byKey(const Key('codigo_activar')));
      await tester.pump();
      expect(find.byKey(const Key('codigo_inicial')), findsOneWidget);
      // No coinciden: no se guarda nada.
      c.codigoNuevoController.text = '1234';
      c.codigoRepetidoController.text = '4321';
      expect(await c.savePrices(), isFalse);
      expect(repo.guardados, isNull);
      expect(codigo.guardados, isEmpty);
      // Correcto: se guarda con los precios.
      c.codigoRepetidoController.text = '1234';
      await c.savePrices();
      expect(repo.guardados?.priceMonth, 500);
      expect(codigo.guardados, ['1234']);
      expect(modos.last, 'fijo');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('sin código también se puede continuar', (tester) async {
      final repo = await precios(tester,
          argumentos: {'fromOnboarding': true},
          inicial: const AbonoPricesModel(priceMonth: 500));
      await tester.ensureVisible(find.byKey(const Key('codigo_activar')));
      await tester.tap(find.byKey(const Key('codigo_activar')));
      await tester.pump();
      final c = Get.find<AbonoPricesController>();
      c.codigoNuevoController.text = '1234';
      c.codigoRepetidoController.text = '4321';
      await tester.tap(find.byKey(const Key('codigo_no_ahora')));
      await tester.pump();
      expect(find.byKey(const Key('codigo_inicial')), findsNothing);
      await Get.find<AbonoPricesController>().savePrices();
      expect(repo.guardados?.priceMonth, 500);
      expect(codigo.guardados, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('en tableta los precios y el código son fáciles de distinguir',
        (tester) async {
      await precios(tester,
          argumentos: {'fromOnboarding': true},
          inicial: const AbonoPricesModel(priceMonth: 500));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1180, 820);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
          tester.getRect(find.text('Precios')).right,
          lessThan(tester
              .getRect(find.text('¿También cobrarás abonos libres?'))
              .left));
      expect(find.byKey(const Key('codigo_inicial')), findsNothing);
      await tester.tap(find.byKey(const Key('codigo_activar')));
      await tester.pump();
      expect(find.byKey(const Key('codigo_inicial')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el símbolo de moneda se ve aun con los precios vacíos',
        (tester) async {
      await precios(tester,
          argumentos: {'fromOnboarding': true},
          inicial: const AbonoPricesModel());
      tester.view.devicePixelRatio = 1;
      for (final tamano in const [
        Size(390, 844),
        Size(844, 390),
        Size(820, 1180),
        Size(1180, 820),
        Size(1280, 800),
      ]) {
        tester.view.physicalSize = tamano;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tamano');
        expect(find.text('\$'), findsNWidgets(5));
        for (final campo in find.byType(TextField).evaluate()) {
          final campoFinder = find.byWidget(campo.widget);
          await tester.ensureVisible(campoFinder);
          await tester.pumpAndSettle();
          expect(
              find
                  .descendant(of: campoFinder, matching: find.text('\$'))
                  .hitTestable(),
              findsOneWidget,
              reason: '$tamano: moneda visible sin escribir ni enfocar');
        }
        expect(find.text('¿También cobrarás abonos libres?'), findsOneWidget);
        expect(find.textContaining('se usa para cobrar una visita de un día.'),
            findsOneWidget);
      }
    },
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        }));

    testWidgets(
        'en el asistente con abono libre solo se pregunta la '
        'inscripción', (tester) async {
      await precios(tester,
          argumentos: {'fromOnboarding': true, 'soloInscripcion': true},
          inicial: const AbonoPricesModel());
      expect(find.text('Costo de inscripción'), findsOneWidget);
      expect(find.text('Por mes'), findsNothing);
      expect(find.text('No cobro inscripción'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
    });
  });

  testWidgets('el detalle del ingreso muestra la inscripción aparte',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late BuildContext contexto;
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.oscuro,
      home: Builder(builder: (context) {
        contexto = context;
        return const Scaffold();
      }),
    ));
    mostrarDetalleIngreso(
      contexto,
      IngresoModel(
        clienteId: 'c1',
        clienteNombre: 'Juan Pérez',
        concepto: 'abono',
        tipoMembresia: 'Abono: 1 meses × \$500.00',
        montoBase: 500,
        cuotaRegistro: 200,
        montoFinal: 700,
        metodoPago: 'efectivo',
        fecha: DateTime(2026, 10, 6, 10),
        usuarioStaff: 'Staff',
      ),
    );
    await tester.pumpAndSettle();
    // "Abono" es también el título de la hoja.
    expect(find.text('Abono'), findsNWidgets(2));
    expect(find.text('Inscripción'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });
}

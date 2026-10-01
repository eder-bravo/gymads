import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/core/widgets/escaner_automatico.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/services/escaner_fisico_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/modules/inventario/controllers/inventario_controller.dart';
import 'package:gymads/app/modules/inventario/views/inventario_view.dart';
import 'package:gymads/app/modules/point_of_sale/controllers/point_of_sale_controller.dart';
import 'package:gymads/app/modules/point_of_sale/views/point_of_sale_view.dart';
import 'package:gymads/app/routes/app_pages.dart';

const _escritorio =
    TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.windows});

Future<void> _leer(
  WidgetTester tester,
  String codigo, {
  LogicalKeyboardKey finalizador = LogicalKeyboardKey.enter,
  Duration pausa = const Duration(milliseconds: 5),
  TextEditingController? escribirEn,
}) async {
  for (final caracter in codigo.split('')) {
    final tecla = LogicalKeyboardKey.findKeyByKeyId(
            caracter.toLowerCase().codeUnitAt(0)) ??
        LogicalKeyboardKey.keyA;
    final manejada = await tester.sendKeyDownEvent(tecla, character: caracter);
    // Simula la entrada del sistema si Flutter dejó pasar el carácter.
    if (!manejada && escribirEn != null) {
      tester.testTextInput.enterText('${escribirEn.text}$caracter');
    }
    await tester.sendKeyUpEvent(tecla);
    await tester.pump(pausa);
  }
  // El simulador raw de Windows carece del mapa de Numpad Enter; el evento
  // unificado conserva la misma tecla lógica en ambas plataformas.
  await tester.sendKeyEvent(finalizador,
      platform: finalizador == LogicalKeyboardKey.numpadEnter ? 'macos' : null);
  await tester.pump();
}

Product _producto() => Product(
      id: 'agua',
      name: 'Agua',
      description: 'Agua natural',
      categoryId: null,
      barcode: '001234567890',
      price: 15,
      stock: 10,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _Venta extends PointOfSaleController {
  @override
  // Inicialización aislada: los repositorios y tours no se abren en tests.
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

class _Inventario extends InventarioController {
  _Inventario({this.puedeAjustar = true, this.puedeCrear = true});
  final bool puedeAjustar;
  final bool puedeCrear;
  final ajustes = <int>[];
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => switch (permiso) {
        Permission.ajustarStock => puedeAjustar,
        Permission.gestionarProductos => puedeCrear,
        _ => false,
      };
  @override
  Future<int?> ajustarStock(Product product, int delta,
      {String? nota, double? precioUnitario}) async {
    ajustes.add(delta);
    return product.stock + delta;
  }
}

void main() {
  late ShowcaseView tour;
  setUp(() {
    EscanerFisicoService.configuracion.value = const ConfiguracionEscaner();
    WelcomeTourService.recorridoEnCurso.value = false;
    tour = ShowcaseView.register();
  });
  tearDown(() {
    tour.unregister();
    WelcomeTourService.recorridoEnCurso.value = false;
    Get.reset();
  });

  Future<void> captura(
      WidgetTester tester, Future<String?> Function(String) alLeer,
      {Widget? child, bool Function()? habilitado}) async {
    await tester.pumpWidget(GetMaterialApp(
        home: EscanerAutomatico(
      habilitado: habilitado ?? () => true,
      alLeer: alLeer,
      child: Scaffold(body: child ?? const AvisoEscanerAutomatico()),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('lee sin tocar botones y encola códigos repetidos',
      (tester) async {
    final recibidos = <String>[];
    final primera = Completer<void>();
    await captura(tester, (codigo) async {
      recibidos.add(codigo);
      if (recibidos.length == 1) await primera.future;
      return '+1 $codigo';
    });
    for (final codigo in ['001234', '001234', '567890']) {
      await _leer(tester, codigo);
    }
    expect(recibidos, ['001234']);
    primera.complete();
    await tester.pumpAndSettle();
    expect(recibidos, ['001234', '001234', '567890']);
    expect(find.text('+1 567890'), findsOneWidget);
  }, variant: _escritorio);

  testWidgets('respeta Tab, prefijo, sufijo y Enter del teclado numérico',
      (tester) async {
    final recibidos = <String>[];
    await captura(tester, (codigo) async {
      recibidos.add(codigo);
      return null;
    });
    EscanerFisicoService.configuracion.value = const ConfiguracionEscaner(
      terminador: TerminadorEscaner.tab,
      prefijo: 'PRE',
      sufijo: 'FIN',
    );
    await _leer(tester, 'PRE000123FIN', finalizador: LogicalKeyboardKey.tab);
    expect(recibidos, ['000123']);
    EscanerFisicoService.configuracion.value = const ConfiguracionEscaner();
    await _leer(tester, '456789', finalizador: LogicalKeyboardKey.numpadEnter);
    expect(recibidos, ['000123', '456789']);
  }, variant: _escritorio);

  testWidgets(
      'escritura normal no dispara acciones; el lector preserva la búsqueda',
      (tester) async {
    final texto = TextEditingController(text: 'Agua');
    addTearDown(texto.dispose);
    final recibidos = <String>[];
    var busqueda = 'Agua';
    await captura(tester, (codigo) async {
      recibidos.add(codigo);
      return null;
    },
        child: BusquedaConEscaner(
            child:
                TextField(controller: texto, onChanged: (v) => busqueda = v)));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _leer(tester, ' natural',
        pausa: const Duration(milliseconds: 150), escribirEn: texto);
    expect(recibidos, isEmpty);
    expect(busqueda, 'Agua natural');
    await _leer(tester, '001234567890', escribirEn: texto);
    await tester.pumpAndSettle();
    expect(recibidos, ['001234567890']);
    expect(texto.text, 'Agua natural');
    expect(busqueda, 'Agua natural');
  }, variant: _escritorio);

  testWidgets(
      'pausa al abrir un diálogo y otra ruta; vuelve a leer al regresar',
      (tester) async {
    final recibidos = <String>[];
    await captura(tester, (codigo) async {
      recibidos.add(codigo);
      return null;
    });
    Get.dialog<void>(const AlertDialog(content: Text('Ajuste de stock')));
    await tester.pumpAndSettle();
    await _leer(tester, '001234');
    expect(recibidos, isEmpty);
    Get.back<void>();
    await tester.pumpAndSettle();
    Get.to<void>(() => const Scaffold(body: Text('Otra pantalla')));
    await tester.pumpAndSettle();
    await _leer(tester, '001234');
    expect(recibidos, isEmpty);
    Get.back<void>();
    await tester.pumpAndSettle();
    await _leer(tester, '001234');
    expect(recibidos, ['001234']);
  }, variant: _escritorio);

  testWidgets('no captura campos de cantidad ni atajos del teclado',
      (tester) async {
    final recibidos = <String>[];
    final texto = TextEditingController();
    addTearDown(texto.dispose);
    await captura(tester, (codigo) async {
      recibidos.add(codigo);
      return null;
    }, child: TextField(controller: texto));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _leer(tester, '123456', escribirEn: texto);
    expect(recibidos, isEmpty);
    expect(texto.text, '123456');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await _leer(tester, '001234');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(recibidos, isEmpty);
  }, variant: _escritorio);

  testWidgets('un prefijo incorrecto no activa el botón seleccionado',
      (tester) async {
    final foco = FocusNode();
    addTearDown(foco.dispose);
    var pulsaciones = 0;
    var lecturas = 0;
    await captura(tester, (_) async {
      lecturas++;
      return null;
    },
        child: Column(children: [
          ElevatedButton(
              focusNode: foco,
              onPressed: () => pulsaciones++,
              child: const Text('Cobrar')),
          const AvisoEscanerAutomatico(),
        ]));
    foco.requestFocus();
    await tester.pump();
    EscanerFisicoService.configuracion.value =
        const ConfiguracionEscaner(prefijo: 'PRE');
    await _leer(tester, '001234');
    expect(lecturas, 0);
    expect(pulsaciones, 0);
    expect(find.text('Lectura inválida. Revisa la configuración del escáner.'),
        findsOneWidget);
    // Enter sin una lectura conserva el uso normal del botón por teclado.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(pulsaciones, 1);
  }, variant: _escritorio);

  testWidgets('cerrar con lecturas pendientes evita procesarlas después',
      (tester) async {
    final primera = Completer<String?>();
    var recibidas = 0;
    await captura(tester, (_) {
      recibidas++;
      return primera.future;
    });
    await _leer(tester, '001234');
    await _leer(tester, '567890');
    await tester.pumpWidget(const SizedBox());
    primera.complete('OK');
    await tester.pumpAndSettle();
    expect(recibidas, 1);
    expect(tester.takeException(), isNull);
  }, variant: _escritorio);

  testWidgets(
      'venta agrega unidades y total directamente, sin botón de escanear',
      (tester) async {
    final controller = Get.put<PointOfSaleController>(_Venta());
    controller.availableProducts.add(_producto());
    await tester.pumpWidget(const GetMaterialApp(home: PointOfSaleView()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Escanear productos'), findsNothing);
    await _leer(tester, '001234567890');
    await _leer(tester, '001234567890');
    await tester.pumpAndSettle();
    expect(controller.totalUnidades, 2);
    expect(controller.finalAmount, 30);
    expect(find.text('+1 Agua (llevas 2)'), findsOneWidget);
    await _leer(tester, '999999999999');
    await tester.pumpAndSettle();
    expect(controller.totalUnidades, 2);
    expect(find.text('Código no registrado'), findsOneWidget);
  }, variant: _escritorio);

  testWidgets('venta lee códigos cortos también con el buscador seleccionado',
      (tester) async {
    final controller = Get.put<PointOfSaleController>(_Venta());
    controller.availableProducts.add(_producto().copyWith(barcode: '01'));
    await tester.pumpWidget(const GetMaterialApp(home: PointOfSaleView()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final texto =
        tester.widget<EditableText>(find.byType(EditableText)).controller;
    await _leer(tester, '01', escribirEn: texto);
    await tester.pumpAndSettle();
    expect(controller.totalUnidades, 1);
    expect(controller.searchQuery, isEmpty);
    expect(texto.text, isEmpty);
  }, variant: _escritorio);

  testWidgets('venta pausa el lector durante el cobro y lo recupera al cerrar',
      (tester) async {
    final controller = Get.put<PointOfSaleController>(_Venta());
    controller.availableProducts.add(_producto());
    await tester.pumpWidget(const GetMaterialApp(home: PointOfSaleView()));
    await tester.pumpAndSettle();
    await _leer(tester, '001234567890');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    await _leer(tester, '001234567890');
    expect(controller.totalUnidades, 1);
    Get.back<void>();
    await tester.pumpAndSettle();
    await _leer(tester, '001234567890');
    await tester.pumpAndSettle();
    expect(controller.totalUnidades, 2);
  }, variant: _escritorio);

  testWidgets('inventario abre el mismo ajuste de stock al escanear',
      (tester) async {
    final controller =
        Get.put<InventarioController>(_Inventario()) as _Inventario;
    controller.products.add(_producto());
    controller.filterProducts();
    await tester.pumpWidget(const GetMaterialApp(home: InventarioView()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Escanear código'), findsNothing);
    await _leer(tester, '001234567890');
    await tester.pumpAndSettle();
    expect(find.text('Cantidad'), findsOneWidget);
    expect(controller.ajustes, isEmpty);
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '2');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(controller.ajustes, [2]);
    expect(find.text('Agua: stock 12'), findsOneWidget);
  }, variant: _escritorio);

  testWidgets(
      'inventario ofrece registrar un código nuevo con el barcode puesto',
      (tester) async {
    Get.put<InventarioController>(_Inventario());
    await tester
        .pumpWidget(GetMaterialApp(home: const InventarioView(), getPages: [
      GetPage(
          name: Routes.PRODUCT_FORM,
          page: () =>
              Scaffold(body: Text('Nuevo: ${Get.arguments['barcode']}'))),
    ]));
    await tester.pumpAndSettle();
    await _leer(tester, '000999999999');
    await tester.pumpAndSettle();
    expect(find.text('Código no registrado'), findsOneWidget);
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo: 000999999999'), findsOneWidget);
  }, variant: _escritorio);

  testWidgets('inventario respeta el permiso para ajustar stock',
      (tester) async {
    Get.put<InventarioController>(_Inventario(puedeAjustar: false));
    await tester.pumpWidget(const GetMaterialApp(home: InventarioView()));
    await tester.pumpAndSettle();
    await _leer(tester, '001234567890');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AvisoEscanerAutomatico), findsNothing);
  }, variant: _escritorio);

  testWidgets('inventario no ofrece crear productos sin ese permiso',
      (tester) async {
    Get.put<InventarioController>(_Inventario(puedeCrear: false));
    await tester.pumpWidget(const GetMaterialApp(home: InventarioView()));
    await tester.pumpAndSettle();
    await _leer(tester, '000999999999');
    await tester.pumpAndSettle();
    expect(find.text('Código no registrado'), findsOneWidget);
    expect(find.text('Agregar producto'), findsNothing);
    expect(find.text('Entendido'), findsOneWidget);
  }, variant: _escritorio);

  testWidgets('móvil conserva el botón y no activa la captura automática',
      (tester) async {
    Get.put<PointOfSaleController>(_Venta());
    await tester.pumpWidget(const GetMaterialApp(home: PointOfSaleView()));
    await tester.pumpAndSettle();
    expect(find.byType(EscanerAutomatico), findsNothing);
    expect(find.byTooltip('Escanear productos'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

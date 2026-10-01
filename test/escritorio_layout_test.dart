import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/models/staff_profile_model.dart';
import 'package:gymads/app/data/services/escaner_fisico_service.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/global_widgets/cliente_card.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';
import 'package:gymads/app/modules/home/controllers/home_controller.dart';
import 'package:gymads/app/modules/home/views/home_view.dart';
import 'package:gymads/app/modules/inventario/controllers/inventario_controller.dart';
import 'package:gymads/app/modules/inventario/views/inventario_view.dart';
import 'package:gymads/app/modules/point_of_sale/controllers/point_of_sale_controller.dart';
import 'package:gymads/app/modules/point_of_sale/views/point_of_sale_view.dart';
import 'package:gymads/app/modules/point_of_sale/widgets/lista_carrito.dart';
import 'package:gymads/core/theme/app_theme.dart';

const _escritorio =
    TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.windows});
const _capturas = bool.fromEnvironment('CAPTURAS_ESCRITORIO');
final _imagen = GlobalKey();

class _Inicio extends HomeController {
  @override
  void onReady() {}
  @override
  Future<void> checkOnboarding() async {}
  @override
  bool can(Permission permiso) => true;
}

class _Venta extends PointOfSaleController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
}

class _Inventario extends InventarioController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => true;
}

class _Tenant extends GetxService implements TenantContextService {
  @override
  final staffProfileRx = Rx<StaffProfileModel?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Product> _productos() => List.generate(
    12,
    (i) => Product(
          id: '$i',
          name: [
            'Agua natural 1 L',
            'Barra de proteína',
            'Bebida isotónica',
            'Toalla deportiva'
          ][i % 4],
          description: 'Presentación individual',
          categoryId: null,
          barcode: '1234567890$i',
          price: 15 + i * 5,
          stock: 12 + i,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ));

Future<void> _tamano(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpAndSettle();
}

Future<void> _mostrar(WidgetTester tester, Widget child,
    {double escala = 1, bool claro = false}) async {
  tester.view.physicalSize = const Size(1920, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tema = claro ? AppTheme.claro : AppTheme.oscuro;
  await tester.pumpWidget(GetMaterialApp(
    theme: _capturas
        ? tema.copyWith(
            textTheme: tema.textTheme.apply(fontFamily: 'Roboto'),
            primaryTextTheme: tema.primaryTextTheme.apply(fontFamily: 'Roboto'),
          )
        : tema,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(escala)),
      child: RepaintBoundary(key: _imagen, child: child!),
    ),
    home: child,
  ));
  await tester.pumpAndSettle();
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  if (!_capturas) return;
  await tester.runAsync(() async {
    final boundary =
        _imagen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await boundary.toImage();
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final carpeta = Directory('build/capturas_escritorio');
    await carpeta.create(recursive: true);
    await File('${carpeta.path}/$nombre.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  late ShowcaseView tour;
  setUpAll(() async {
    // Para inspección visual opcional se usan las fuentes del SDK instalado.
    if (_capturas) {
      final carpeta = Platform.environment['FUENTES_CAPTURA']!;
      for (final nombre in ['Roboto', 'MaterialIcons']) {
        final archivo = nombre == 'Roboto'
            ? 'Roboto-Regular.ttf'
            : 'MaterialIcons-Regular.otf';
        final loader = FontLoader(nombre)
          ..addFont(File('$carpeta/$archivo')
              .readAsBytes()
              .then(ByteData.sublistView));
        await loader.load();
      }
    }
  });
  setUp(() {
    tour = ShowcaseView.register();
    WelcomeTourService.recorridoEnCurso.value = false;
    EscanerFisicoService.configuracion.value = const ConfiguracionEscaner();
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  testWidgets('inicio distribuye los accesos y cabe al reducir la ventana',
      (tester) async {
    Get.put<TenantContextService>(_Tenant());
    Get.put<HomeController>(_Inicio());
    await _mostrar(tester, const HomeView());
    expect(tester.getTopLeft(find.text('Ingresos')).dy,
        tester.getTopLeft(find.text('Entradas')).dy);
    await _capturar(tester, 'inicio-amplio');
    for (final size in [
      const Size(1280, 720),
      const Size(800, 600),
      const Size(600, 430)
    ]) {
      await _tamano(tester, size);
      expect(find.text('Inventario'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  }, variant: _escritorio);

  testWidgets('venta conserva búsqueda, foco y cantidades al redimensionar',
      (tester) async {
    final controller = Get.put<PointOfSaleController>(_Venta());
    controller.availableProducts.addAll(_productos());
    await _mostrar(tester, const PointOfSaleView());
    await controller.addProductToCart(controller.availableProducts.first);
    await tester.pumpAndSettle();
    expect(find.byType(ListaCarrito), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Agua');
    await tester.pumpAndSettle();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    await _capturar(tester, 'venta-amplia');
    for (final size in [
      const Size(900, 700),
      const Size(700, 430),
      const Size(1920, 1000)
    ]) {
      await _tamano(tester, size);
      expect(tester.state<EditableTextState>(find.byType(EditableText)),
          same(editable));
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(editable.widget.controller.text, 'Agua');
      expect(controller.totalUnidades, 1);
      expect(tester.takeException(), isNull);
    }
    // El lector sigue capturando después de cambiar entre carrito lateral e inferior.
    for (final caracter in '12345678900'.split('')) {
      await tester.sendKeyEvent(
          LogicalKeyboardKey.findKeyByKeyId(caracter.codeUnitAt(0))!,
          character: caracter);
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.totalUnidades, 2);
    await tester.tap(find.byTooltip('Uno más'));
    await tester.pumpAndSettle();
    expect(controller.totalUnidades, 3);
    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    expect(find.byType(ListaCarrito), findsNWidgets(2));
    expect(tester.getSize(find.byType(ListaCarrito).last).width, lessThan(900));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: _escritorio);

  testWidgets(
      'inventario cabe en ventanas amplias y bajas, con texto aumentado',
      (tester) async {
    final controller = Get.put<InventarioController>(_Inventario());
    controller.products.addAll(_productos());
    controller.filterProducts();
    controller.inventoryStats.assignAll(
        {'totalProducts': 12, 'totalStock': 210, 'totalValue': 8500.0});
    await _mostrar(tester, const InventarioView(), claro: true);
    await _capturar(tester, 'inventario-columnas');
    await _mostrar(tester, const InventarioView(), escala: 1.3, claro: true);
    expect(tester.takeException(), isNull);
    await _capturar(tester, 'inventario-amplio');
    for (final size in [const Size(1000, 650), const Size(700, 430)]) {
      await _tamano(tester, size);
      expect(tester.takeException(), isNull);
    }
  }, variant: _escritorio);

  testWidgets('venta permite cobrar con texto aumentado y poca altura',
      (tester) async {
    final controller = Get.put<PointOfSaleController>(_Venta());
    controller.availableProducts.addAll(_productos());
    await _mostrar(tester, const PointOfSaleView(), escala: 1.3);
    await controller.addProductToCart(controller.availableProducts.first);
    await tester.pumpAndSettle();
    for (final size in [const Size(1480, 800), const Size(800, 430)]) {
      await _tamano(tester, size);
      expect(find.text('Cobrar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  }, variant: _escritorio);

  testWidgets(
      'formulario conserva datos y foco, y permite llegar al final en ventana baja',
      (tester) async {
    final campos = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final c in campos) {
        c.dispose();
      }
    });
    await _mostrar(
        tester,
        ClienteFormDialog(
          nombreController: campos[0],
          phoneController: campos[1],
          emailController: campos[2],
          addressController: campos[3],
          userNumberController: campos[4],
          rfidController: campos[5],
          fullScreen: true,
          onSave: (_, __) {},
        ));
    final nombre = find.widgetWithText(TextFormField, 'Nombre completo *');
    await tester.tap(nombre);
    await tester.enterText(nombre, 'María González');
    await tester.pumpAndSettle();
    final foco = FocusManager.instance.primaryFocus;
    await _capturar(tester, 'formulario-amplio');
    await _tamano(tester, const Size(700, 430));
    expect(campos[0].text, 'María González');
    expect(FocusManager.instance.primaryFocus, same(foco));
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Guardar cliente').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: _escritorio);

  testWidgets('lista adapta columnas sin recortar tarjetas con nombres largos',
      (tester) async {
    await _mostrar(
        tester,
        ScaffoldAdaptable(
          anchoMaximo: 1200,
          body: ListaAdaptable(
              itemCount: 3,
              itemBuilder: (_, i) => ClienteCard(
                    cliente: UserModel(
                        id: '$i',
                        name: 'María Fernanda González Rodríguez',
                        phone: '8112345678',
                        userNumber: '$i',
                        joinDate: DateTime(2026),
                        daysRemaining: 12),
                    onTap: () {},
                  )),
        ));
    final tarjetas = find.byType(ClienteCard);
    expect(tester.getTopLeft(tarjetas.at(0)).dy,
        tester.getTopLeft(tarjetas.at(1)).dy);
    await _tamano(tester, const Size(800, 600));
    expect(tester.getTopLeft(tarjetas.at(1)).dy,
        greaterThan(tester.getTopLeft(tarjetas.at(0)).dy));
    expect(tester.takeException(), isNull);
  }, variant: _escritorio);
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/modules/configuracion/views/agregar_lector_view.dart';
import 'package:gymads/app/modules/configuracion/controllers/agregar_lector_controller.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:gymads/app/data/models/product_model.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/app/data/models/staff_profile_model.dart';
import 'package:gymads/app/data/services/escaner_fisico_service.dart';
import 'package:gymads/app/data/services/tenant_context_service.dart';
import 'package:gymads/app/data/services/welcome_tour_service.dart';
import 'package:gymads/app/global_widgets/cliente_card.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';
import 'package:gymads/app/modules/home/controllers/home_controller.dart';
import 'package:gymads/app/modules/home/controllers/resumen_del_dia.dart';
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
  final abiertos = <String>[];
  @override
  void goToPointOfSale() => abiertos.add('Vender');
  @override
  void goToAccessLogs() => abiertos.add('Entradas');
  @override
  void goToConfiguracion() => abiertos.add('Configuración');
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

class _Asistente extends AgregarLectorController {
  _Asistente() : super(ble: _BleFalso());
  @override
  void onReady() {}
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
    {double escala = 1,
    bool claro = false,
    bool protegerVentana = true}) async {
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
      child: RepaintBoundary(
          key: _imagen,
          child: protegerVentana ? VentanaEscritorio(child: child!) : child!),
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
    // Inicio de escritorio muestra los números de hoy: datos fijos de prueba.
    Get.put(ResumenDelDia(
      ingresosDeHoy: () async => 4350,
      entradasDeHoy: () async => 38,
      porVencer: () async => 5,
    ));
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
      const Size(600, 430),
      const Size(480, 360),
      const Size(216, 360)
    ]) {
      await _tamano(tester, size);
      expect(find.text('Inventario'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await _mostrar(tester, const HomeView(), escala: 2);
    for (final size in [const Size(480, 360), const Size(216, 360)]) {
      await _tamano(tester, size);
      expect(tester.takeException(), isNull);
    }
  }, variant: _escritorio);

  testWidgets('inicio cabe con 55 puntos disponibles en el encabezado',
      (tester) async {
    Get.put<TenantContextService>(_Tenant());
    Get.put<HomeController>(_Inicio());
    for (final escala in [1.0, 2.0]) {
      await _mostrar(tester, const HomeView(),
          escala: escala, protegerVentana: false);
      tester.view.devicePixelRatio = 2;
      // 103 puntos de ventana menos los 24 de margen a cada lado: 55.
      for (final ancho in [103.0, 104.0, 168.0, 480.0]) {
        tester.view.physicalSize = Size(ancho * 2, 720);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Inicio con ancho $ancho y texto al ${escala * 100} %');
        expect(find.text('Inicio'), findsOneWidget);
      }
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
      const Size(480, 360),
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
    await _mostrar(tester, const InventarioView(), escala: 2, claro: true);
    expect(tester.takeException(), isNull);
    await _capturar(tester, 'inventario-amplio');
    for (final size in [
      const Size(1000, 650),
      const Size(700, 430),
      const Size(480, 360)
    ]) {
      await _tamano(tester, size);
      expect(tester.takeException(), isNull);
    }
  }, variant: _escritorio);

  testWidgets('venta permite cobrar con texto aumentado y poca altura',
      (tester) async {
    final controller = Get.put<PointOfSaleController>(_Venta());
    controller.availableProducts.addAll(_productos());
    await _mostrar(tester, const PointOfSaleView(), escala: 2);
    await controller.addProductToCart(controller.availableProducts.first);
    await tester.pumpAndSettle();
    // Desde la ventana amplia hasta el mínimo que permite el sistema.
    for (final size in [const Size(1480, 800), VentanaEscritorio.minimo]) {
      await _tamano(tester, size);
      expect(find.text('Cobrar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cobrar venta'));
    await tester.pumpAndSettle();
    expect(find.text('Cobrar venta').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
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
    await _tamano(tester, VentanaEscritorio.minimo);
    expect(campos[0].text, 'María González');
    expect(FocusManager.instance.primaryFocus, same(foco));
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Guardar cliente').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: _escritorio);

  test('la escala crece con la ventana, en pasos y con tope', () {
    expect(VentanaEscritorio.escalaPara(const Size(1280, 800)), 1.0);
    expect(VentanaEscritorio.escalaPara(VentanaEscritorio.minimo), 1.0);
    expect(VentanaEscritorio.escalaPara(const Size(1920, 1050)), 1.3);
    expect(VentanaEscritorio.escalaPara(const Size(2560, 1410)), 1.6);
    expect(VentanaEscritorio.escalaPara(const Size(5120, 2880)), 1.6);
  });

  testWidgets('maximizada, la interfaz crece en proporción y conserva estado',
      (tester) async {
    Get.put<TenantContextService>(_Tenant());
    Get.put<HomeController>(_Inicio());
    await _mostrar(tester, const HomeView());
    await _tamano(tester, const Size(1280, 800));
    final normal = tester.getSize(find.text('Clientes'));
    await _tamano(tester, const Size(2560, 1410));
    expect(MediaQuery.sizeOf(tester.element(find.text('Clientes'))),
        const Size(1600, 881.25));
    final grande = tester.getSize(find.text('Clientes'));
    expect(grande.height, normal.height);
    // getSize es local: el tamaño real en pantalla se mide con su rectángulo.
    final rect = tester.getRect(find.text('Clientes'));
    expect(rect.height, closeTo(normal.height * 1.6, 0.5));
    expect(tester.takeException(), isNull);
    await _capturar(tester, 'inicio-maximizada');
  }, variant: _escritorio);

  testWidgets('inicio de escritorio: rejilla, números de hoy y atajos',
      (tester) async {
    Get.put<TenantContextService>(_Tenant());
    final inicio = Get.put<HomeController>(_Inicio()) as _Inicio;
    // Sombras reales para la captura (en pruebas se dibujan como un borde).
    debugDisableShadows = !_capturas;
    await _mostrar(tester, const HomeView());
    await _tamano(tester, const Size(2560, 1410));
    expect(find.text('\$4,350'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    // Vender es la tarjeta grande: más ancha que Abonar.
    final vender = tester.getRect(find.text('Vender'));
    final abonar = tester.getRect(find.text('Abonar'));
    expect(vender.height, greaterThan(abonar.height));
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final modificador =
        mac ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;
    await tester.sendKeyDownEvent(modificador);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.sendKeyUpEvent(modificador);
    // El engrane de la cabecera responde al clic (nada lo tapa).
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    expect(inicio.abiertos, ['Vender', 'Entradas', 'Configuración']);
    expect(tester.takeException(), isNull);
    await _capturar(tester, 'inicio-bento');
    await _mostrar(tester, const HomeView(), claro: true);
    await _tamano(tester, const Size(2560, 1410));
    await _capturar(tester, 'inicio-bento-claro');
    await _tamano(tester, VentanaEscritorio.minimo);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
  }, variant: _escritorio);

  testWidgets('venta e inventario maximizados, sin desbordes', (tester) async {
    final venta = Get.put<PointOfSaleController>(_Venta());
    venta.availableProducts.addAll(_productos());
    await _mostrar(tester, const PointOfSaleView());
    await venta.addProductToCart(venta.availableProducts.first);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Agua');
    await _tamano(tester, const Size(2560, 1410));
    await _capturar(tester, 'venta-maximizada');
    await _tamano(tester, VentanaEscritorio.minimo);
    expect(find.text('Cobrar').hitTestable(), findsOneWidget);
    await _tamano(tester, const Size(2560, 1410));
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.controller.text, 'Agua');
    expect(editable.widget.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    Get.reset();

    final inventario = Get.put<InventarioController>(_Inventario());
    inventario.products.addAll(_productos());
    inventario.filterProducts();
    inventario.inventoryStats.assignAll(
        {'totalProducts': 12, 'totalStock': 210, 'totalValue': 8500.0});
    await _mostrar(tester, const InventarioView(), claro: true);
    await _tamano(tester, const Size(2560, 1410));
    expect(tester.takeException(), isNull);
    await _capturar(tester, 'inventario-maximizado');
  }, variant: _escritorio);

  testWidgets('formulario abre como ventana modal y se cierra con su botón',
      (tester) async {
    final campos = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final c in campos) {
        c.dispose();
      }
    });
    await _mostrar(tester, const Scaffold(body: SizedBox.expand()));
    await _tamano(tester, const Size(1280, 800));
    abrirFormulario(() => ClienteFormDialog(
          nombreController: campos[0],
          phoneController: campos[1],
          emailController: campos[2],
          addressController: campos[3],
          userNumberController: campos[4],
          rfidController: campos[5],
          fullScreen: true,
          onSave: (_, __) {},
        ));
    await tester.pumpAndSettle();
    final ventana = find.byType(VentanaFormulario);
    expect(ventana, findsOneWidget);
    expect(
        tester.getSize(find.byType(ClienteFormDialog)), const Size(720, 680));
    expect(find.text('Guardar cliente').hitTestable(), findsOneWidget);
    await _capturar(tester, 'formulario-ventana');
    // En la ventana mínima la ventana modal se ajusta y sigue cabiendo.
    await _tamano(tester, VentanaEscritorio.minimo);
    expect(find.text('Guardar cliente').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(ventana, findsNothing);
  }, variant: _escritorio);

  testWidgets('Escape cierra la ventana modal de un formulario',
      (tester) async {
    await _mostrar(tester, const Scaffold(body: SizedBox.expand()));
    abrirFormulario(() => const Scaffold(body: Text('Formulario de prueba')));
    await tester.pumpAndSettle();
    expect(find.byType(VentanaFormulario), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(VentanaFormulario), findsNothing);
  }, variant: _escritorio);

  testWidgets('inventario: acciones con texto y clic en la fila para editar',
      (tester) async {
    final controller = Get.put<InventarioController>(_Inventario());
    controller.products.addAll(_productos().take(2));
    controller.filterProducts();
    await _mostrar(tester, const InventarioView());
    // Nada importante queda detrás de un ícono solo.
    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Editar'), findsNWidgets(2));
    expect(find.text('Stock'), findsNWidgets(2));
    expect(find.text('Más'), findsNWidgets(2));
    expect(find.byIcon(Icons.more_vert), findsNothing);
    // Clic en la ficha (no en un botón): abre el producto para editarlo.
    await tester.tap(find.text('Barra de proteína'));
    await tester.pumpAndSettle();
    expect(find.byType(VentanaFormulario), findsOneWidget);
    expect(find.text('Editar producto'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(VentanaFormulario), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: _escritorio);

  testWidgets('el asistente del lector tiene "Cancelar" a la vista',
      (tester) async {
    final c = Get.put<AgregarLectorController>(_Asistente());
    c.redes.assignAll(const [RedWifi('Gimnasio Centro', rssi: -50)]);
    c.paso.value = PasoAgregar.elegirRed;
    await _mostrar(
        tester,
        Builder(
            builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Get.to(() => const AgregarLectorView()),
                      child: const Text('abrir'),
                    ),
                  ),
                )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(AgregarLectorView), findsOneWidget);
    expect(find.byIcon(Icons.computer), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AgregarLectorView), findsNothing);
  }, variant: _escritorio);

  testWidgets('lista adapta columnas sin recortar tarjetas con nombres largos',
      (tester) async {
    Future<void> mostrar({double escala = 1}) => _mostrar(
        tester,
        escala: escala,
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
    await mostrar();
    expect(tester.getTopLeft(tarjetas.at(0)).dy,
        tester.getTopLeft(tarjetas.at(1)).dy);
    // En la ventana mínima siguen cabiendo dos tarjetas por fila.
    await _tamano(tester, VentanaEscritorio.minimo);
    expect(tester.getTopLeft(tarjetas.at(0)).dy,
        tester.getTopLeft(tarjetas.at(1)).dy);
    expect(tester.takeException(), isNull);
    // Con el texto al doble ya no: una por fila, sin recortar.
    await mostrar(escala: 2);
    await _tamano(tester, VentanaEscritorio.minimo);
    expect(tester.getTopLeft(tarjetas.at(1)).dy,
        greaterThan(tester.getTopLeft(tarjetas.at(0)).dy));
    expect(tester.takeException(), isNull);
  }, variant: _escritorio);
}

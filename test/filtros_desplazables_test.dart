import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/core/theme/app_theme.dart';

/// Los filtros de categoría (Venta e Inventario) que no caben en el ancho se
/// pueden alcanzar: con barra visible, rueda del mouse y arrastre. El teléfono
/// conserva su lista de siempre.

const _pantallaGrande = TargetPlatformVariant({
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.iOS,
  TargetPlatform.android,
});

List<CategoryChipData> _categorias(int n) => [
      for (var i = 0; i < n; i++)
        CategoryChipData(
            id: '$i', label: 'Categoría número $i', icon: Icons.category),
    ];

Future<void> _mostrar(
  WidgetTester tester, {
  required Size tamano,
  required int categorias,
  double escala = 1,
  ThemeData? tema,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  String? elegida;
  await tester.pumpWidget(MaterialApp(
    theme: tema ?? AppTheme.oscuro,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(escala)),
      child: child!,
    ),
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          // Como en Venta: una columna que centra a sus hijos.
          child: Column(children: [
            CategoryFilterChips(
              categories: _categorias(categorias),
              selectedId: elegida,
              onSelected: (id) => setState(() => elegida = id),
            )
          ]),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Si la fila se desplaza: su `maxScrollExtent`.
double _extension(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable))
    .position
    .maxScrollExtent;

void main() {
  testWidgets('pantalla grande: si no caben, hay una barra visible',
      (tester) async {
    await _mostrar(tester, tamano: const Size(1000, 800), categorias: 12);
    expect(_extension(tester), greaterThan(0));
    final barra = find.byType(Scrollbar);
    expect(barra, findsOneWidget);
    final widget = tester.widget<Scrollbar>(barra);
    expect(widget.thumbVisibility, isTrue);
    expect(widget.trackVisibility, isTrue);
    expect(tester.takeException(), isNull);
  }, variant: _pantallaGrande);

  testWidgets('pantalla grande: si caben, no hay barra ni espacio de más',
      (tester) async {
    await _mostrar(tester, tamano: const Size(1000, 800), categorias: 2);
    expect(_extension(tester), 0);
    expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isFalse);
    // Empieza a la izquierda, aunque el padre la centre.
    expect(tester.getTopLeft(find.byType(FilterChip).first).dx, 16);
    // Sin barra, la fila mide lo de siempre: 50.
    expect(tester.getSize(find.byType(Scrollbar)).height, 50);
  }, variant: _pantallaGrande);

  testWidgets('pantalla grande: la rueda del mouse mueve la fila de lado',
      (tester) async {
    await _mostrar(tester, tamano: const Size(1000, 800), categorias: 12);
    final posicion =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(posicion.pixels, 0);
    final raton = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
        raton.hover(tester.getCenter(find.byType(Scrollable))));
    await tester.sendEventToBinding(raton.scroll(const Offset(0, 200)));
    await tester.pumpAndSettle();
    expect(posicion.pixels, 200);
    // Hacia arriba regresa, sin pasar del inicio.
    await tester.sendEventToBinding(raton.scroll(const Offset(0, -500)));
    await tester.pumpAndSettle();
    expect(posicion.pixels, 0);
    expect(tester.takeException(), isNull);
  }, variant: _pantallaGrande);

  testWidgets('pantalla grande: se arrastra con el mouse', (tester) async {
    await _mostrar(tester, tamano: const Size(1000, 800), categorias: 12);
    final posicion =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    await tester.dragFrom(
      tester.getCenter(find.byType(Scrollable)),
      const Offset(-300, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(posicion.pixels, greaterThan(100));
  }, variant: _pantallaGrande);

  testWidgets('pantalla grande: el último filtro se alcanza y se elige',
      (tester) async {
    await _mostrar(tester, tamano: const Size(1000, 800), categorias: 12);
    final ultimo = find.text('Categoría número 11');
    expect(ultimo.hitTestable(), findsNothing);
    final posicion =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    posicion.jumpTo(posicion.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(ultimo.hitTestable(), findsOneWidget);
    await tester.tap(ultimo);
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .where((c) => c.selected)
            .length,
        1);
  }, variant: _pantallaGrande);

  testWidgets('pantalla grande: con texto grande y poco ancho no se desborda',
      (tester) async {
    for (final escala in [1.0, 1.3, 2.0]) {
      // Alto de 800: en tableta el lado corto debe pasar de 720.
      for (final ancho in [1200.0, 1000.0, 760.0]) {
        await _mostrar(tester,
            tamano: Size(ancho, 800), categorias: 8, escala: escala);
        expect(tester.takeException(), isNull,
            reason: 'ancho $ancho, texto $escala');
      }
    }
  }, variant: _pantallaGrande);

  /// Color del texto del filtro elegido ("Todas" al empezar).
  Color? colorDelElegido(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
          of: find.byType(FilterChip).first, matching: find.text('Todas')))
      .style
      ?.color;

  testWidgets('escritorio: el filtro elegido va en blanco, también en claro',
      (tester) async {
    for (final tema in [AppTheme.claro, AppTheme.oscuro]) {
      await _mostrar(tester,
          tamano: const Size(1000, 800), categorias: 3, tema: tema);
      expect(colorDelElegido(tester), Colors.white);
    }
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux
      }));

  testWidgets('teléfono: el filtro elegido conserva su color', (tester) async {
    await _mostrar(tester,
        tamano: const Size(390, 844), categorias: 3, tema: AppTheme.claro);
    expect(colorDelElegido(tester), ColoresTema.claro.textPrimary);
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('teléfono: la lista de siempre, sin barra ni espacio nuevo',
      (tester) async {
    await _mostrar(tester, tamano: const Size(390, 844), categorias: 12);
    expect(find.byType(Scrollbar), findsNothing);
    expect(tester.getSize(find.byType(ListView)).height, 50);
    expect(_extension(tester), greaterThan(0));
    // Se desplaza con el dedo.
    final posicion =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    await tester.drag(find.byType(ListView), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(posicion.pixels, greaterThan(0));
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}));
}

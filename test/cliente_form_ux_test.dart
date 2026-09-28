import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/core/theme/app_theme.dart';

void main() {
  late List<TextEditingController> c;
  late int guardados;

  Future<void> abrir(WidgetTester tester, {bool editar = false}) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    c = List.generate(6, (_) => TextEditingController());
    guardados = 0;
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.app,
      home: ClienteFormDialog(
        nombreController: c[0],
        phoneController: c[1],
        emailController: c[2],
        addressController: c[3],
        userNumberController: c[4],
        rfidController: c[5],
        isEditing: editar,
        onSave: (_, __) => guardados++,
        fullScreen: true,
      ),
    ));
    await tester.pump();
  }

  // Cierra el formulario: detiene su consulta periódica al lector.
  Future<void> cerrar(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets(
      'la foto primero, luego nombre, teléfono y tarjeta; sin textos '
      'de más', (tester) async {
    await abrir(tester);

    double y(String texto) => tester.getTopLeft(find.text(texto)).dy;
    expect(y('Tomar foto *'), lessThan(y('Nombre completo *')));
    expect(y('Nombre completo *'), lessThan(y('Teléfono *')));
    expect(y('Teléfono *'), lessThan(y('Sin lector de tarjetas')));
    // Sin títulos de sección ni explicaciones.
    expect(find.text('Datos del cliente'), findsNothing);
    expect(find.textContaining('pantalla de bienvenida'), findsNothing);
    expect(find.text('Guardar cliente'), findsOneWidget);
    // Un solo botón para guardar; cancelar es la X de arriba.
    expect(find.text('Cancelar'), findsNothing);
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    await cerrar(tester);
  });

  testWidgets('correo y dirección van plegados', (tester) async {
    await abrir(tester);
    expect(find.text('Correo electrónico'), findsNothing);

    await tester.tap(find.text('Correo y dirección (opcional)'));
    await tester.pumpAndSettle();
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Dirección'), findsOneWidget);

    await cerrar(tester);
  });

  testWidgets('la tarjeta leída se ve como "Tarjeta lista", sin su número',
      (tester) async {
    await abrir(tester);
    c[5].text = 'EA7F8005';
    await tester.pump();

    expect(find.text('Tarjeta lista'), findsOneWidget);
    expect(find.textContaining('EA7F8005'), findsNothing);

    await tester.tap(find.text('Quitar'));
    await tester.pump();
    expect(c[5].text, isEmpty);

    await cerrar(tester);
  });

  testWidgets('sin foto no se guarda: se marca en rojo', (tester) async {
    await abrir(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo *'), 'María');
    expect(find.text('Toma la foto del cliente'), findsNothing);

    await tester.tap(find.text('Guardar cliente'));
    await tester.pump();

    expect(find.text('Toma la foto del cliente'), findsOneWidget);
    expect(guardados, 0);

    await cerrar(tester);
  });

  testWidgets('guardar sin nombre dice qué falta', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Guardar cliente'));
    await tester.pump();
    expect(find.text('Escribe el nombre del cliente'), findsOneWidget);

    await cerrar(tester);
  });

  testWidgets('al editar, el botón dice "Guardar cambios"', (tester) async {
    await abrir(tester, editar: true);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Editar cliente'), findsOneWidget);
    await cerrar(tester);
  });

  group('Tema de los campos', () {
    test('el foco y la etiqueta enfocada son naranjas, no del color del fondo',
        () {
      final tema = AppTheme.app.inputDecorationTheme;
      final foco = tema.focusedBorder as OutlineInputBorder;
      expect(foco.borderSide.color, AppColors.accent);
      expect(tema.floatingLabelStyle?.color, AppColors.accent);
      expect(AppTheme.app.textSelectionTheme.cursorColor, AppColors.accent);
      // Las etiquetas se leen sobre fondo oscuro.
      expect(tema.labelStyle?.color, AppColors.textSecondary);
    });
  });

  group('BotonGuardar', () {
    Future<void> boton(WidgetTester tester, Widget b) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: b))));

    testWidgets('normal y guardando', (tester) async {
      var toques = 0;
      await boton(tester,
          BotonGuardar(texto: 'Guardar producto', onPressed: () => toques++));
      await tester.tap(find.text('Guardar producto'));
      expect(toques, 1);

      await boton(
          tester,
          BotonGuardar(
              texto: 'Guardar producto',
              guardando: true,
              onPressed: () => toques++));
      expect(find.text('Guardando…'), findsOneWidget);
      await tester.tap(find.text('Guardando…'));
      expect(toques, 1, reason: 'mientras guarda no responde');
    });

    testWidgets('compacto no ocupa todo el ancho', (tester) async {
      await boton(tester,
          BotonGuardar(texto: 'Guardar', compacto: true, onPressed: () {}));
      expect(tester.getSize(find.byType(ElevatedButton)).width, lessThan(300));
    });
  });
}

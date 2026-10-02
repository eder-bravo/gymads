import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/permissions/staff_role.dart';
import 'package:gymads/app/modules/staff_accesos/controllers/staff_accesos_controller.dart';
import 'package:gymads/app/modules/staff_accesos/views/staff_acceso_form_dialog.dart';

/// Sin base de datos: solo lo que usa el formulario.
class _ControladorFalso extends GetxController
    implements StaffAccesosController {
  final creados = <(String, StaffRole)>[];

  @override
  final RxBool isSaving = false.obs;

  @override
  List<StaffRole> get rolesAsignables => const [
        StaffRole.encargado,
        StaffRole.branchStaff,
        StaffRole.almacen,
        StaffRole.mostrador,
      ];

  @override
  Future<String?> crear(String nombre, StaffRole rol) async {
    creados.add((nombre, rol));
    return 'ABCD2345';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(Get.reset);

  testWidgets('Nuevo acceso se abre en pantalla completa y devuelve el código',
      (tester) async {
    final controlador = _ControladorFalso();
    Get.put<StaffAccesosController>(controlador);

    ({String nombre, String codigo})? resultado;
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (_) => TextButton(
            onPressed: () async =>
                resultado = await showStaffAccesoFormDialog(),
            child: const Text('Nuevo'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();

    // Una página con su barra, no un diálogo.
    expect(find.byType(Dialog), findsNothing);
    expect(find.widgetWithText(AppBar, 'Nuevo acceso'), findsOneWidget);
    expect(find.text('Qué podrá hacer'), findsOneWidget);
    expect(find.text('Mostrador'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'María López');
    await tester.tap(find.text('Mostrador'));
    await tester.pump();
    await tester.tap(find.text('Generar código'));
    await tester.pumpAndSettle();

    expect(controlador.creados, [('María López', StaffRole.mostrador)]);
    expect(resultado?.codigo, 'ABCD2345');
    expect(find.text('Nuevo acceso'), findsNothing, reason: 'se cerró');
  });
}

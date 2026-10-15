import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/permissions/staff_role.dart';
import 'package:gymads/app/data/models/staff_acceso_model.dart';
import 'package:gymads/app/data/repositories/staff_acceso_repository.dart';
import 'package:gymads/app/data/services/cambios_en_vivo_service.dart';
import 'package:gymads/app/modules/staff_accesos/controllers/staff_accesos_controller.dart';
import 'package:gymads/app/modules/staff_accesos/views/codigo_generado_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// La tabla `staff_accesos`: lo que devuelve depende de [estado].
class _Accesos extends Fake implements StaffAccesoRepository {
  String estado = 'pendiente';
  int lecturas = 0;

  @override
  Future<List<StaffAccesoModel>> getAll() async {
    lecturas++;
    return [
      StaffAccesoModel(
        id: 'acceso-1',
        gymId: 'gym',
        branchId: 'sucursal',
        nombre: 'Juanca',
        rol: StaffRole.encargado,
        estado: estado,
        createdAt: DateTime(2026, 10, 14),
        updatedAt: DateTime(2026, 10, 14),
      ),
    ];
  }
}

void main() {
  late CambiosEnVivoService servicio;
  late _Accesos tabla;

  // Dentro de cada prueba, no en setUp: la recarga corre en la zona donde se
  // suscribe el controlador, y solo la del testWidgets avanza con pump.
  StaffAccesosController abrirPantalla() =>
      Get.put(StaffAccesosController(repository: tabla));

  setUp(() {
    servicio = Get.put(CambiosEnVivoService(seguirSesion: false));
    tabla = _Accesos();
  });
  tearDown(Get.reset);

  test('se escucha la tabla de accesos del personal', () {
    expect(TablaEnVivo.personal.nombre, 'staff_accesos');
  });

  testWidgets('al canjearse el código, la lista se recarga sola y sin spinner',
      (tester) async {
    final controller = abrirPantalla();
    await tester.pump();
    expect(controller.accesos.single.estaPendiente, isTrue);

    var spinner = false;
    final vigilar = ever<bool>(controller.isLoading, (v) => spinner |= v);
    addTearDown(vigilar.dispose);

    // El empleado escanea el QR en su teléfono.
    tabla.estado = 'activo';
    servicio.anotar([TablaEnVivo.personal]);
    await tester.pump(const Duration(seconds: 2));

    expect(controller.accesos.single.estaActivo, isTrue);
    expect(tabla.lecturas, 2);
    expect(spinner, isFalse);
  });

  testWidgets(
      'aunque no llegue el aviso de Realtime, el canje se ve en unos segundos; '
      'sin códigos pendientes deja de revisar', (tester) async {
    final controller = abrirPantalla();
    await tester.pump();
    expect(controller.accesos.single.estaPendiente, isTrue);

    tabla.estado = 'activo';
    await tester.pump(const Duration(seconds: 5));
    expect(controller.accesos.single.estaActivo, isTrue);

    final lecturas = tabla.lecturas;
    await tester.pump(const Duration(seconds: 20));
    expect(tabla.lecturas, lecturas);

    Get.delete<StaffAccesosController>();
  });

  testWidgets('el diálogo del código cambia a "Ya entró" en cuanto se usa',
      (tester) async {
    abrirPantalla();
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
    await tester.pump();

    showCodigoGeneradoDialog(
      nombre: 'Juanca',
      codigo: 'ABCD-EFGH',
      gymName: 'Gimnasio de prueba',
      accesoId: 'acceso-1',
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Ya entró'), findsNothing);

    tabla.estado = 'activo';
    servicio.anotar([TablaEnVivo.personal]);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Ya entró'), findsOneWidget);
    expect(find.textContaining('Juanca ya entró con este código'),
        findsOneWidget);

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Ya entró'), findsNothing, reason: 'se cerró');
  });

  testWidgets('el código de otro acceso no cierra este diálogo',
      (tester) async {
    abrirPantalla();
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
    await tester.pump();

    showCodigoGeneradoDialog(
      nombre: 'Alan',
      codigo: 'ABCD-EFGH',
      gymName: 'Gimnasio de prueba',
      accesoId: 'otro-acceso',
    );
    await tester.pumpAndSettle();

    tabla.estado = 'activo';
    servicio.anotar([TablaEnVivo.personal]);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Ya entró'), findsNothing);
  });
}

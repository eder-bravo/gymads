import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:gymads/app/core/permissions/permissions.dart';
import 'package:gymads/app/data/services/background_rfid_service.dart';
import 'package:gymads/app/data/services/tema_service.dart';
import 'package:gymads/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:gymads/app/modules/configuracion/views/configuracion_view.dart';
import 'package:gymads/app/modules/configuracion/views/lector_view.dart';
import 'package:gymads/core/theme/app_theme.dart';

class _Configuracion extends ConfiguracionController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  bool can(Permission permiso) => true;
  @override
  Future<void> cargarEstadoLector() async {}
}

class _Lector extends BackgroundRfidService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  late ShowcaseView tour;
  setUp(() {
    tour = ShowcaseView.register();
    Get.put<ConfiguracionController>(_Configuracion());
    Get.put(TemaService(leer: () => 'oscuro', guardar: (_) {}));
    Get.put<BackgroundRfidService>(_Lector());
  });
  tearDown(() {
    tour.unregister();
    Get.reset();
  });

  for (final oscuro in [true, false]) {
    testWidgets(
        'opciones y lector se dibujan sin errores de Material (${oscuro ? 'oscuro' : 'claro'})',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tema = oscuro ? AppTheme.oscuro : AppTheme.claro;
      await tester.pumpWidget(
          GetMaterialApp(theme: tema, home: const ConfiguracionView()));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester
          .pumpWidget(GetMaterialApp(theme: tema, home: const LectorView()));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        variant: const TargetPlatformVariant(
            {TargetPlatform.macOS, TargetPlatform.windows}));
  }
}

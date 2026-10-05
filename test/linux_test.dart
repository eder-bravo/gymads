import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/data/services/lector_ble_service.dart';
import 'package:universal_ble/universal_ble.dart' as u;

class _Ble extends u.UniversalBlePlatform {
  u.AvailabilityState disponibilidad = u.AvailabilityState.poweredOn;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<u.AvailabilityState> getBluetoothAvailabilityState() async =>
      disponibilidad;
}

/// Linux usa el diseño de escritorio (antes caía en el del teléfono), con
/// cámara (camera_desktop), Bluetooth (Universal BLE sobre BlueZ), sonidos y
/// notificaciones.
void main() {
  testWidgets('Linux es escritorio, no teléfono ni tableta', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    expect(PlataformaApp.escritorio, isTrue);
    expect(PlataformaApp.linux, isTrue);
    expect(PlataformaApp.tableta, isFalse);
    expect(PlataformaApp.pantallaGrande, isTrue);
    expect(PlataformaApp.aparato, 'computadora');
    expect(PlataformaApp.toca, 'Haz clic en');
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('en Linux el Bluetooth del lector habla de Linux, no de Windows',
      (tester) async {
    final ble = _Ble()..disponibilidad = u.AvailabilityState.poweredOff;
    u.UniversalBle.setInstance(ble);
    // En Linux se busca con Universal BLE, como en Windows.
    final servicio = LectorBleService(usarBleWindows: true);
    await expectLater(
      servicio.prepararBluetooth(),
      throwsA(isA<FalloBusquedaBle>()
          .having((f) => f.tipo, 'tipo', TipoFalloBusquedaBle.bluetoothApagado)
          .having((f) => f.mensaje, 'mensaje',
              allOf(contains('Linux'), isNot(contains('Windows'))))),
    );
    ble.disponibilidad = u.AvailabilityState.poweredOn;
    await servicio.prepararBluetooth();
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('macOS y Windows no son Linux', (tester) async {
    expect(PlataformaApp.escritorio, isTrue);
    expect(PlataformaApp.linux, isFalse);
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.macOS, TargetPlatform.windows}));
}

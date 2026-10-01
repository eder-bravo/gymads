import 'dart:async';
import 'package:camera_macos/camera_macos.dart' as mac;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/modules/shared/views/desktop_camera_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CamaraFalsa extends mac.CameraMacOSPlatform {
  List<mac.CameraMacOSDevice> dispositivos = [
    mac.CameraMacOSDevice(deviceId: 'usb', localizedName: 'Webcam USB'),
    mac.CameraMacOSDevice(
        deviceId: 'virtual', localizedName: 'Cámara del celular'),
  ];
  final abiertas = <String?>[];
  int cerradas = 0;
  bool? audio;
  Completer<mac.CameraMacOSArguments?>? pendiente;
  @override
  Future<List<mac.CameraMacOSDevice>> listDevices(
          {mac.CameraMacOSDeviceType? deviceType}) async =>
      dispositivos;
  @override
  Future<mac.CameraMacOSArguments?> initialize(
      {String? deviceId,
      String? audioDeviceId,
      bool enableAudio = true,
      mac.PictureFormat pictureFormat = mac.PictureFormat.tiff,
      mac.VideoFormat videoFormat = mac.VideoFormat.mp4,
      mac.PictureResolution resolution = mac.PictureResolution.max,
      mac.AudioFormat audioFormat = mac.AudioFormat.kAudioFormatAppleLossless,
      mac.AudioQuality audioQuality = mac.AudioQuality.max,
      mac.FlashMode flashMode = mac.FlashMode.off,
      mac.CameraOrientation orientation = mac.CameraOrientation.orientation0deg,
      bool isVideoMirrored = true,
      required mac.CameraMacOSMode cameraMacOSMode}) async {
    abiertas.add(deviceId);
    audio = enableAudio;
    if (pendiente != null) return await pendiente!.future;
    return mac.CameraMacOSArguments(textureId: 1, size: const Size(640, 480));
  }

  @override
  Future<bool?> destroy() async {
    cerradas++;
    return true;
  }
}

void main() {
  late mac.CameraMacOSPlatform original;
  late _CamaraFalsa camara;
  setUp(() {
    original = mac.CameraMacOSPlatform.instance;
    camara = _CamaraFalsa();
    mac.CameraMacOSPlatform.instance = camara;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    mac.CameraMacOSPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('lista webcam y cámara virtual; recuerda selección sin micrófono',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({'camara_escritorio': 'virtual'});
    await tester.pumpWidget(MaterialApp(
        home: DesktopCameraView(onPhotoTaken: (_) {}, onCancel: () {})));
    await tester.pumpAndSettle();
    expect(camara.abiertas, ['virtual']);
    expect(camara.audio, isFalse);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Webcam USB').last);
    await tester.pumpAndSettle();
    expect(camara.abiertas, ['virtual', 'usb']);
    expect(
        (await SharedPreferences.getInstance()).getString('camara_escritorio'),
        'usb');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(camara.cerradas, 2);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('al desconectar la cámara guardada usa otra disponible',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues(
        {'camara_escritorio': 'desconectada'});
    await tester.pumpWidget(MaterialApp(
        home: DesktopCameraView(onPhotoTaken: (_) {}, onCancel: () {})));
    await tester.pumpAndSettle();
    expect(camara.abiertas, ['usb']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('sin cámaras ofrece reintentar y abrir permisos', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    camara.dispositivos.clear();
    await tester.pumpWidget(MaterialApp(
        home: DesktopCameraView(onPhotoTaken: (_) {}, onCancel: () {})));
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay cámaras disponibles'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(find.text('Abrir permisos de cámara'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('cerrar durante inicialización libera el controlador tardío',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    camara.pendiente = Completer<mac.CameraMacOSArguments?>();
    await tester.pumpWidget(MaterialApp(
        home: DesktopCameraView(onPhotoTaken: (_) {}, onCancel: () {})));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    camara.pendiente!.complete(
        mac.CameraMacOSArguments(textureId: 1, size: const Size(640, 480)));
    await tester.pumpAndSettle();
    expect(camara.cerradas, 1);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}

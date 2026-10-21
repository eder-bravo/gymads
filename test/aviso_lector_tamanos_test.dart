import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/modules/shared/widgets/welcome_screen_widget.dart';
import 'package:gymads/core/theme/app_theme.dart';
import 'package:image/image.dart' as img;

/// El aviso del lector, con la foto a pantalla completa, en cada tamaño: el
/// celular de pie y de lado, la tableta, la computadora y el monitor de la
/// pantalla para clientes. Ninguno desborda.
///
/// Inspección visual opcional: con `--dart-define=CAPTURAS_AVISO=true` y
/// `FUENTES_CAPTURA` (las fuentes del SDK), guarda cada uno en
/// build/capturas_aviso.
const _capturas = bool.fromEnvironment('CAPTURAS_AVISO');

/// Una foto vertical de 1200×1600, como las que toma la cámara de la app: una
/// silueta clara sobre un fondo, para ver que la cara no se recorta.
Uint8List _fotoVertical() {
  final foto = img.Image(width: 1200, height: 1600);
  img.fill(foto, color: img.ColorRgb8(70, 96, 120));
  img.fillCircle(foto,
      x: 600, y: 2100, radius: 900, color: img.ColorRgb8(40, 52, 70));
  img.fillCircle(foto,
      x: 600, y: 700, radius: 300, color: img.ColorRgb8(224, 184, 150));
  // Una marca arriba y abajo: si se recortara, desaparecerían.
  img.fillRect(foto,
      x1: 0, y1: 0, x2: 1200, y2: 40, color: img.ColorRgb8(255, 210, 0));
  img.fillRect(foto,
      x1: 0, y1: 1560, x2: 1200, y2: 1600, color: img.ColorRgb8(255, 210, 0));
  return img.encodePng(foto);
}

void main() {
  final foto = MemoryImage(_fotoVertical());

  if (_capturas) {
    setUpAll(() async {
      final carpeta = Platform.environment['FUENTES_CAPTURA']!;
      final roboto = FontLoader('Roboto');
      for (final archivo in [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf'
      ]) {
        roboto.addFont(
            File('$carpeta/$archivo').readAsBytes().then(ByteData.sublistView));
      }
      await roboto.load();
      final iconos = FontLoader('MaterialIcons')
        ..addFont(File('$carpeta/MaterialIcons-Regular.otf')
            .readAsBytes()
            .then(ByteData.sublistView));
      await iconos.load();
    });
  }

  final casos = <String, WelcomeScreenWidget Function()>{
    'bienvenida': () => WelcomeScreenWidget(
          userName: 'María Fernanda González Rodríguez',
          userPhotoUrl: '',
          foto: foto,
          daysLeft: 12,
          expirationDate: DateTime(2026, 10, 29),
          isVisible: true,
          onClose: () {},
        ),
    'vencida': () => WelcomeScreenWidget(
          userName: 'Carlos Ruiz',
          userPhotoUrl: '',
          foto: foto,
          daysLeft: 0,
          expirationDate: DateTime(2026, 9, 30),
          isVisible: true,
          isExpired: true,
          onClose: () {},
          onAbonar: () {},
          onEditar: () {},
        ),
    'sin-foto': () => WelcomeScreenWidget(
          userName: 'Ana López',
          userPhotoUrl: '',
          daysLeft: 20,
          expirationDate: DateTime(2026, 11, 6),
          isVisible: true,
          onClose: () {},
        ),
    'no-registrada': () => WelcomeScreenWidget(
          userName: '',
          userPhotoUrl: '',
          daysLeft: 0,
          isVisible: true,
          isNotFound: true,
          onClose: () {},
          onRegister: () {},
        ),
    'clientes-vencida': () => WelcomeScreenWidget(
          userName: 'Carlos Ruiz',
          userPhotoUrl: '',
          foto: foto,
          daysLeft: 0,
          expirationDate: DateTime(2026, 9, 30),
          isVisible: true,
          isExpired: true,
          paraClientes: true,
        ),
  };

  final tamanos = <({String nombre, Size tamano, TargetPlatform plataforma})>[
    (
      nombre: 'celular',
      tamano: const Size(390, 844),
      plataforma: TargetPlatform.android
    ),
    (
      nombre: 'celular-chico',
      tamano: const Size(320, 640),
      plataforma: TargetPlatform.android
    ),
    (
      nombre: 'celular-de-lado',
      tamano: const Size(844, 390),
      plataforma: TargetPlatform.android
    ),
    (
      nombre: 'tableta',
      tamano: const Size(1180, 820),
      plataforma: TargetPlatform.iOS
    ),
    (
      nombre: 'tableta-de-pie',
      tamano: const Size(820, 1180),
      plataforma: TargetPlatform.iOS
    ),
    (
      nombre: 'escritorio',
      tamano: const Size(1280, 800),
      plataforma: TargetPlatform.macOS
    ),
    // La pantalla para clientes en un monitor 16:9 (ver
    // PantallaClientesVista: lo más chico es 1024×768).
    (
      nombre: 'monitor',
      tamano: const Size(1365, 768),
      plataforma: TargetPlatform.macOS
    ),
  ];

  for (final t in tamanos) {
    for (final claro in [false, true]) {
      for (final caso in casos.entries) {
        testWidgets(
            '${caso.key} en ${t.nombre} ${claro ? 'claro' : 'oscuro'}: '
            'no desborda', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = t.tamano;
          addTearDown(tester.view.reset);
          final imagen = GlobalKey();
          final tema = claro ? AppTheme.claro : AppTheme.oscuro;
          await tester.pumpWidget(MaterialApp(
            theme: _capturas
                ? tema.copyWith(
                    textTheme: tema.textTheme.apply(fontFamily: 'Roboto'))
                : tema,
            home: RepaintBoundary(key: imagen, child: caso.value()),
          ));
          // La foto se decodifica fuera del reloj de prueba.
          await tester.runAsync(() async {
            await precacheImage(foto, tester.element(find.byKey(imagen)));
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          if (!_capturas) return;
          await tester.runAsync(() async {
            final boundary = imagen.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final captura = await boundary.toImage();
            final bytes =
                await captura.toByteData(format: ui.ImageByteFormat.png);
            final carpeta = Directory('build/capturas_aviso');
            await carpeta.create(recursive: true);
            await File('${carpeta.path}/${t.nombre}-${caso.key}-'
                    '${claro ? 'claro' : 'oscuro'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            captura.dispose();
          });
        }, variant: TargetPlatformVariant.only(t.plataforma));
      }
    }
  }
}

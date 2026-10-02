import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

/// El círculo guía de la cámara, en una pantalla de cámara de tamaño [vista]:
/// centrado a lo ancho y un poco arriba del centro. Lo usan el dibujo de la
/// máscara y el recorte, para que coincidan.
Rect circuloGuia(Size vista) {
  final radio = (vista.height * 0.25).clamp(120.0, 200.0);
  return Rect.fromCircle(
    center: Offset(vista.width / 2, vista.height * 0.45),
    radius: radio,
  );
}

/// La parte de la [foto] (en píxeles) que se veía dentro del círculo guía.
///
/// La vista previa ocupa el centro de [vista] con proporción
/// [aspectoVistaPrevia] (ancho/alto) y muestra el centro de la foto con esa
/// misma proporción. El resultado es un cuadrado dentro de la foto.
Rect recorteDelCirculo({
  required Size vista,
  required double aspectoVistaPrevia,
  required Size foto,
}) {
  // Dónde queda la vista previa en la pantalla (como `AspectRatio` centrado).
  var anchoPrevia = vista.width;
  var altoPrevia = anchoPrevia / aspectoVistaPrevia;
  if (altoPrevia > vista.height) {
    altoPrevia = vista.height;
    anchoPrevia = altoPrevia * aspectoVistaPrevia;
  }
  final previa = Rect.fromCenter(
    center: vista.center(Offset.zero),
    width: anchoPrevia,
    height: altoPrevia,
  );

  // Qué parte de la foto muestra la vista previa: su centro, con la
  // proporción de la vista previa (la foto puede ser más ancha o más alta).
  var anchoVisible = foto.width;
  var altoVisible = foto.height;
  if (foto.width / foto.height > aspectoVistaPrevia) {
    anchoVisible = foto.height * aspectoVistaPrevia;
  } else {
    altoVisible = foto.width / aspectoVistaPrevia;
  }
  final visible = Rect.fromCenter(
    center: foto.center(Offset.zero),
    width: anchoVisible,
    height: altoVisible,
  );

  final circulo = circuloGuia(vista);
  final escala = visible.width / previa.width;
  final centro = Offset(
    visible.left + (circulo.center.dx - previa.left) * escala,
    visible.top + (circulo.center.dy - previa.top) * escala,
  );

  // Un cuadrado que quepa en la foto, lo más centrado posible en el círculo.
  final lado = math.min(
    circulo.width * escala,
    math.min(foto.width, foto.height),
  );
  final mitad = lado / 2;
  final x = centro.dx.clamp(mitad, foto.width - mitad);
  final y = centro.dy.clamp(mitad, foto.height - mitad);
  return Rect.fromCenter(center: Offset(x, y), width: lado, height: lado);
}

/// Deja en [ruta] solo lo que se veía dentro del círculo. Se hace en otro
/// hilo para no trabar la pantalla. Si algo falla, la foto queda como se
/// tomó: mejor una foto sin recortar que ninguna.
Future<void> recortarFotoAlCirculo(
  String ruta, {
  required Size vista,
  required double aspectoVistaPrevia,
}) async {
  try {
    final bytes = await File(ruta).readAsBytes();
    final recortada = await Isolate.run(() {
      final original = img.decodeImage(bytes);
      if (original == null) return null;
      // Las fotos del teléfono guardan su giro aparte; se aplica antes de
      // medir, para que alto y ancho sean los que se ven.
      final foto = img.bakeOrientation(original);
      final r = recorteDelCirculo(
        vista: vista,
        aspectoVistaPrevia: aspectoVistaPrevia,
        foto: Size(foto.width.toDouble(), foto.height.toDouble()),
      );
      var cuadro = img.copyCrop(
        foto,
        x: r.left.round(),
        y: r.top.round(),
        width: r.width.round(),
        height: r.height.round(),
      );
      if (cuadro.width > 1080) cuadro = img.copyResize(cuadro, width: 1080);
      return img.encodeJpg(cuadro, quality: 90);
    });
    if (recortada != null) await File(ruta).writeAsBytes(recortada, flush: true);
  } catch (_) {
    // Se queda la foto completa.
  }
}

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

/// El círculo guía de la cámara, en una pantalla de cámara de tamaño [vista]:
/// centrado a lo ancho y un poco arriba del centro. Lo de adentro es lo que
/// se guarda como foto del cliente ([prepararFoto]).
Rect circuloGuia(Size vista) {
  final radio = (vista.height * 0.25).clamp(120.0, 200.0);
  return Rect.fromCircle(
    center: Offset(vista.width / 2, vista.height * 0.45),
    radius: radio,
  );
}

/// Lado máximo de la foto guardada. Una foto de cliente es cuadrada y se ve
/// grande (aviso del lector en una tableta o un monitor), así que se conserva
/// en alta resolución.
const ladoMaximoFoto = 1600;

/// El cuadro de la foto, en píxeles, que contiene el círculo guía.
///
/// - [vista]: el tamaño de la pantalla donde se dibuja la cámara (y el círculo).
/// - [vistaPrevia]: la imagen de la cámara en pantalla; solo importa su
///   proporción (se dibuja entera y centrada en [vista], como hacen
///   `CameraPreview` y `AspectRatio`).
///   Si no se conoce, o está acostada y la foto de pie (o al revés), se toma
///   la foto entera como lo que se veía.
/// - [ancho] y [alto]: los píxeles de la foto ya derecha.
///
/// La foto y la vista previa pueden tener proporciones distintas (el sensor
/// toma 4:3 y la vista previa muestra 16:9): se toma como visible la parte
/// central de la foto con la proporción de la vista previa.
Rect cuadroDelCirculo({
  required Size vista,
  Size? vistaPrevia,
  required int ancho,
  required int alto,
}) {
  var aspecto = ancho / alto;
  if (vistaPrevia != null &&
      vistaPrevia.width > 0 &&
      vistaPrevia.height > 0 &&
      (vistaPrevia.width >= vistaPrevia.height) == (ancho >= alto)) {
    aspecto = vistaPrevia.width / vistaPrevia.height;
  }
  // La imagen de la cámara dentro de la vista: entera y centrada.
  vistaPrevia = vista.width / vista.height > aspecto
      ? Size(vista.height * aspecto, vista.height)
      : Size(vista.width, vista.width / aspecto);

  // Lo que se ve de la foto: su centro, con la proporción de la vista previa.
  final visibleAncho = ancho / alto > aspecto ? alto * aspecto : ancho * 1.0;
  final visibleAlto = visibleAncho / aspecto;
  final visible = Rect.fromCenter(
    center: Offset(ancho / 2, alto / 2),
    width: visibleAncho,
    height: visibleAlto,
  );

  // De puntos de pantalla a píxeles de la foto.
  final escala = visible.width / vistaPrevia.width;
  final previa = Offset((vista.width - vistaPrevia.width) / 2,
      (vista.height - vistaPrevia.height) / 2);
  final circulo = circuloGuia(vista);
  final centro = visible.topLeft + (circulo.center - previa) * escala;
  final lado =
      math.min(circulo.width * escala, math.min(ancho, alto).toDouble());

  // Sin salirse de la foto.
  final izquierda = (centro.dx - lado / 2).clamp(0.0, ancho - lado);
  final arriba = (centro.dy - lado / 2).clamp(0.0, alto - lado);
  return Rect.fromLTWH(izquierda.roundToDouble(), arriba.roundToDouble(),
      lado.roundToDouble(), lado.roundToDouble());
}

/// Deja la foto de [ruta] como se va a guardar: derecha (las del teléfono
/// guardan su giro aparte) y, con [vista], recortada al cuadro del círculo
/// guía (con [vistaPrevia] si se conoce), de [ladoMaximoFoto] píxeles como máximo. Así el
/// cliente se ve de cerca en la lista, la ficha y el aviso del lector, sin
/// el fondo de alrededor. Sin [vista] la foto queda completa.
///
/// Se hace en otro hilo para no trabar la pantalla. Si algo falla, la foto
/// queda como se tomó.
Future<void> prepararFoto(
  String ruta, {
  Size? vista,
  Size? vistaPrevia,
}) async {
  try {
    final bytes = await File(ruta).readAsBytes();
    final lista = await Isolate.run(() {
      final original = img.decodeImage(bytes);
      if (original == null) return null;
      var foto = img.bakeOrientation(original);
      if (vista != null) {
        final c = cuadroDelCirculo(
          vista: vista,
          vistaPrevia: vistaPrevia,
          ancho: foto.width,
          alto: foto.height,
        );
        foto = img.copyCrop(foto,
            x: c.left.toInt(),
            y: c.top.toInt(),
            width: c.width.toInt(),
            height: c.height.toInt());
      }
      if (math.max(foto.width, foto.height) > ladoMaximoFoto) {
        foto = foto.width >= foto.height
            ? img.copyResize(foto,
                width: ladoMaximoFoto,
                interpolation: img.Interpolation.cubic)
            : img.copyResize(foto,
                height: ladoMaximoFoto,
                interpolation: img.Interpolation.cubic);
      }
      // Calidad 85 con color a media resolución (como las cámaras): se ve
      // igual de bien a pantalla completa y pesa la mitad (unos 350 KB en
      // vez de 700), que es lo que cada teléfono guarda de cada cliente.
      return img.encodeJpg(foto,
          quality: 85, chroma: img.JpegChroma.yuv420);
    });
    if (lista != null) await File(ruta).writeAsBytes(lista, flush: true);
  } catch (_) {
    // Se queda como se tomó.
  }
}

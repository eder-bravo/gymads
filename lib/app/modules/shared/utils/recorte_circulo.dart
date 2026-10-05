import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

/// El círculo guía de la cámara, en una pantalla de cámara de tamaño [vista]:
/// centrado a lo ancho y un poco arriba del centro. Es solo una guía para
/// encuadrar la cara: la foto se guarda completa ([prepararFotoCompleta]).
Rect circuloGuia(Size vista) {
  final radio = (vista.height * 0.25).clamp(120.0, 200.0);
  return Rect.fromCircle(
    center: Offset(vista.width / 2, vista.height * 0.45),
    radius: radio,
  );
}

/// La foto completa, como se tomó: derecha (las del teléfono guardan su giro
/// aparte) y de 1600 píxeles como máximo por lado. El círculo de la cámara es
/// solo una guía para encuadrar la cara: antes se guardaba solo lo de adentro
/// y el resto de la foto se perdía. Se hace en otro hilo para no trabar la
/// pantalla. Si algo falla, la foto queda como se tomó.
Future<void> prepararFotoCompleta(String ruta) async {
  try {
    final bytes = await File(ruta).readAsBytes();
    final lista = await Isolate.run(() {
      final original = img.decodeImage(bytes);
      if (original == null) return null;
      var foto = img.bakeOrientation(original);
      const maximo = 1600;
      if (math.max(foto.width, foto.height) > maximo) {
        foto = foto.width >= foto.height
            ? img.copyResize(foto, width: maximo)
            : img.copyResize(foto, height: maximo);
      }
      return img.encodeJpg(foto, quality: 90);
    });
    if (lista != null) await File(ruta).writeAsBytes(lista, flush: true);
  } catch (_) {
    // Se queda como se tomó.
  }
}

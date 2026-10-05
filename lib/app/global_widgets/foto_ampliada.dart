import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/services/storage_service.dart';
import '../../core/theme/siempre_oscuro.dart';

/// Abre la foto de un cliente en grande y completa (la miniatura de su ficha
/// es redonda), sobre fondo negro. Se puede acercar con dos dedos y se cierra
/// con la X, con "atrás" o tocando fuera de la foto.
Future<void> mostrarFotoAmpliada(String url, {String? nombre}) {
  return Get.to<void>(
        () => _FotoAmpliada(url: url, nombre: nombre),
        fullscreenDialog: true,
        transition: Transition.fadeIn,
      ) ??
      Future.value();
}

class _FotoAmpliada extends StatelessWidget {
  const _FotoAmpliada({required this.url, this.nombre});

  final String url;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    return SiempreOscuro(
        child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
          onPressed: () => Get.back(),
        ),
        title: nombre == null
            ? null
            : Text(nombre!, style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        // Tocar fuera de la foto también cierra.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Get.back(),
          child: LayoutBuilder(
            builder: (context, espacio) => Center(
              // Lo de adentro no cierra: ahí se acerca la foto.
              child: GestureDetector(
                onTap: () {},
                child: _FotoCompleta(
                  url: url,
                  maximo:
                      Size(espacio.maxWidth * 0.92, espacio.maxHeight * 0.92),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

/// La foto completa, con su proporción y sin pasar de [maximo].
class _FotoCompleta extends StatelessWidget {
  const _FotoCompleta({required this.url, required this.maximo});

  final String url;
  final Size maximo;

  @override
  Widget build(BuildContext context) {
    // Mientras carga o si falla: un cuadro para el aviso.
    final cuadro = math.min(math.min(maximo.width, maximo.height), 320.0);
    Widget aviso(Widget hijo) =>
        SizedBox(width: cuadro, height: cuadro, child: hijo);
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: maximo.width, maxHeight: maximo.height),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        // Lo guardado es la ruta en el almacenamiento privado, no un enlace:
        // se pide un enlace firmado, como hace la miniatura (CachedUserImage).
        child: FutureBuilder<String?>(
          future: StorageService.instance.signedUrl(url),
          builder: (context, enlace) {
            if (enlace.connectionState != ConnectionState.done) {
              return aviso(const _Cargando());
            }
            final firmado = enlace.data;
            if (firmado == null) return aviso(const _SinFoto());
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: firmado,
                // La misma clave que la miniatura: si ya se descargó, sale
                // al instante.
                cacheKey: StorageService.instance.stableKey(url),
                fit: BoxFit.contain,
                placeholder: (_, __) => aviso(const _Cargando()),
                errorWidget: (_, __, ___) => aviso(const _SinFoto()),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Colors.white));
}

class _SinFoto extends StatelessWidget {
  const _SinFoto();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se pudo cargar la foto. Revisa tu conexión.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
}

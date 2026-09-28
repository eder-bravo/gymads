import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/services/storage_service.dart';

/// Abre la foto de un cliente a pantalla completa, con fondo negro. Se puede
/// acercar con dos dedos y se cierra con la X o con "atrás".
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
    return Scaffold(
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
        // Lo guardado es la ruta en el almacenamiento privado, no un enlace:
        // se pide un enlace firmado, como hace la miniatura (CachedUserImage).
        child: FutureBuilder<String?>(
          future: StorageService.instance.signedUrl(url),
          builder: (context, enlace) {
            if (enlace.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            final firmado = enlace.data;
            if (firmado == null) return const _SinFoto();
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: firmado,
                  // La misma clave que la miniatura: si ya se descargó, sale
                  // al instante.
                  cacheKey: StorageService.instance.stableKey(url),
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(
                      color: Colors.white),
                  errorWidget: (_, __, ___) => const _SinFoto(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'No se pudo cargar la foto. Revisa tu conexión.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
}

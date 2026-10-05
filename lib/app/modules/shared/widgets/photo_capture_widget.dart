import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/cached_user_image.dart';
import '../views/circular_camera_view.dart';
import '../../../core/utils/plataforma_app.dart';

/// La foto del cliente en su formulario: la foto (o una silueta) y un botón
/// que dice claramente qué hacer.
///
/// Antes era solo un círculo gris "tocable" con un texto gris casi invisible:
/// no se entendía que ahí se tomaba la foto.
class PhotoCaptureWidget extends StatefulWidget {
  const PhotoCaptureWidget({
    super.key,
    required this.onPhotoTaken,
    this.currentPhotoUrl,
    this.initialPhotoFile,
    this.obligatoria = false,
    this.mostrarFalta = false,
  });

  final Function(File) onPhotoTaken;

  /// La foto que ya tiene el cliente (al editar).
  final String? currentPhotoUrl;

  /// Una foto tomada que todavía no se guarda.
  final File? initialPhotoFile;

  /// El botón lleva "*", como los demás campos obligatorios.
  final bool obligatoria;

  /// Se intentó guardar sin foto: el círculo y el aviso en rojo.
  final bool mostrarFalta;

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  /// En el State: si la pantalla se redibuja, la foto tomada sigue a la vista.
  late File? _foto = widget.initialPhotoFile;

  bool get _tieneFoto =>
      _foto != null || (widget.currentPhotoUrl?.isNotEmpty ?? false);

  bool get _faltaFoto => widget.mostrarFalta && !_tieneFoto;

  /// Sin permiso no se abre la cámara (fallaría en negro); se explica cómo
  /// darlo.
  Future<bool> _permisoDeCamara() async {
    // El controlador nativo de escritorio solicita el permiso al abrir.
    if (PlataformaApp.escritorio) return true;
    final c = context.colores;
    final estado = await Permission.camera.request();
    if (estado.isGranted || estado.isLimited) return true;
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.cardBackground,
        title: Text('Se necesita la cámara',
            style: TextStyle(color: c.textPrimary)),
        content: Text(
          'Para tomar la foto del cliente, permite el acceso a la cámara en '
          'los ajustes ${PlataformaApp.delAparato}.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Ahora no', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Abrir ajustes',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _tomarFoto() async {
    if (!await _permisoDeCamara()) return;

    File? tomada;
    try {
      // La cámara devuelve la foto solo cuando se toca "Usar foto".
      tomada = await Get.to<File>(
        () => CircularCameraView(
          onPhotoTaken: (archivo) => Get.back(result: archivo),
          onCancel: () => Get.back(),
        ),
        transition: Transition.downToUp,
        duration: const Duration(milliseconds: 250),
      );
    } catch (e) {
      if (PlataformaApp.escritorio) {
        SnackbarHelper.error('No se tomó la foto',
            'No se pudo abrir la cámara. Revisa los permisos del sistema.');
        return;
      }
      // Si la cámara propia falla, la del sistema.
      try {
        final foto = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 80,
        );
        if (foto != null) tomada = File(foto.path);
      } catch (_) {
        SnackbarHelper.error('No se tomó la foto',
            'No se pudo abrir la cámara. Intenta de nuevo.');
      }
    }

    if (tomada == null || !mounted) return;
    setState(() => _foto = tomada);
    widget.onPhotoTaken(tomada);
  }

  @override
  Widget build(BuildContext context) {
    // La foto al centro y un solo botón debajo: sin textos de explicación.
    return Column(
      children: [
        _miniatura(),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _tomarFoto,
          icon: Icon(
            _tieneFoto ? Icons.refresh : Icons.photo_camera_outlined,
            size: 18,
          ),
          label: Text(_tieneFoto
              ? 'Cambiar foto'
              : (widget.obligatoria ? 'Tomar foto *' : 'Tomar foto')),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        if (_faltaFoto)
          const Text(
            'Toma la foto del cliente',
            style: TextStyle(color: AppColors.error, fontSize: 13),
          ),
      ],
    );
  }

  Widget _miniatura() {
    final c = context.colores;
    const tamano = 112.0;
    final foto = _foto;
    final Widget contenido;
    if (foto != null) {
      contenido = Image.file(foto, fit: BoxFit.cover);
    } else if (widget.currentPhotoUrl?.isNotEmpty ?? false) {
      contenido = CachedUserImage(
        imageUrl: widget.currentPhotoUrl,
        size: tamano,
        isCircular: true,
      );
    } else {
      contenido =
          Icon(Icons.person, size: 64, color: c.textSecondary.withOpacity(0.6));
    }

    return GestureDetector(
      onTap: _tomarFoto,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: tamano,
            height: tamano,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.superficie,
            ),
            // El aro va encima de la foto: como `decoration` se pintaba
            // debajo, la foto lo tapaba en las diagonales y el círculo se
            // veía mal recortado.
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _faltaFoto
                    ? AppColors.error
                    : _tieneFoto
                        ? AppColors.accent
                        : c.contraste.withOpacity(0.25),
                width: 2,
              ),
            ),
            child: contenido,
          ),
          // Se nota que ahí se toma la foto.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: c.backgroundColor, width: 3),
              ),
              child:
                  const Icon(Icons.photo_camera, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

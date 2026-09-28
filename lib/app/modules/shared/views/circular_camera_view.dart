import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../../core/theme/siempre_oscuro.dart';

class CircularCameraView extends StatefulWidget {
  final Function(File) onPhotoTaken;
  final Function() onCancel;

  const CircularCameraView({
    super.key,
    required this.onPhotoTaken,
    required this.onCancel,
  });

  @override
  State<CircularCameraView> createState() => _CircularCameraViewState();
}

class _CircularCameraViewState extends State<CircularCameraView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isTakingPicture = false;
  String? _errorMessage;

  /// La foto recién tomada, a la espera de "Usar foto" o "Repetir". Antes se
  /// usaba en cuanto se disparaba, sin poder verla.
  File? _fotoTomada;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _errorMessage = null;
        _isInitialized = false;
      });

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No se encontraron cámaras disponibles');
      }

      // Seleccionar ÚNICAMENTE cámara trasera
      final backCameras = _cameras
          .where(
            (camera) => camera.lensDirection == CameraLensDirection.back,
          )
          .toList();

      if (backCameras.isEmpty) {
        throw Exception('No se encontró cámara trasera disponible');
      }

      CameraDescription selectedCamera = backCameras.first;

      await _controller?.dispose();
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high, // Cambiar a high para mejor calidad
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudo abrir la cámara. Revisa que la app '
              'tenga permiso para usarla e intenta de nuevo.';
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_isTakingPicture || !_isInitialized || _controller == null) return;

    try {
      setState(() {
        _isTakingPicture = true;
      });

      // Capturar la foto con la resolución completa de la cámara
      final XFile photoFile = await _controller!.takePicture();

      // Guardar en Application Documents (NO en el directorio de caché):
      // el usuario puede tardar en llenar el resto del formulario antes de
      // guardar, y Android puede purgar getTemporaryDirectory() en cualquier
      // momento sin avisar, borrando la foto antes de subirla.
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final Directory captureDir =
          Directory(path.join(docsDir.path, 'photo_capture'));
      if (!await captureDir.exists()) {
        await captureDir.create(recursive: true);
      }
      final String targetPath = path.join(
        captureDir.path,
        'cliente_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final File resultFile = File(targetPath);
      await File(photoFile.path).copy(targetPath);

      if (await resultFile.exists() && mounted) {
        // Limpiar archivo temporal original
        try {
          await File(photoFile.path).delete();
        } catch (e) {
          // Ignorar errores al eliminar archivos temporales
        }

        // Se muestra para confirmarla; se entrega con "Usar foto".
        setState(() => _fotoTomada = resultFile);
      } else {
        throw Exception('No se pudo guardar la foto');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.error(
          'No se tomó la foto',
          'No se pudo tomar la foto. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiempreOscuro(
        child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildBody(),
      ),
    ));
  }

  /// Descarta la foto tomada y vuelve a la cámara.
  Future<void> _repetir() async {
    final foto = _fotoTomada;
    setState(() => _fotoTomada = null);
    try {
      await foto?.delete();
    } catch (_) {}
  }

  /// La foto tomada, para confirmarla antes de usarla.
  Widget _vistaPrevia(File foto) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Text(
            '¿Se ve bien la foto?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (context, limites) {
              final lado =
                  (limites.biggest.shortestSide * 0.85).clamp(160.0, 360.0);
              return Container(
                width: lado,
                height: lado,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Image.file(foto, fit: BoxFit.cover),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _repetir,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Repetir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onPhotoTaken(foto),
                  icon: const Icon(Icons.check),
                  label: const Text('Usar foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    final fotoTomada = _fotoTomada;
    if (fotoTomada != null) return _vistaPrevia(fotoTomada);

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Abriendo la cámara…',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Vista previa de la cámara que llena toda la pantalla
        Positioned.fill(
          child: Transform.scale(
            scale: 1.0,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // Máscara circular con superposición
        Positioned.fill(
          child: CustomPaint(
            painter: CircularMaskPainter(),
          ),
        ),

        // Qué hacer, arriba.
        Positioned(
          top: 22,
          left: 72,
          right: 72,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Centra la cara del cliente en el círculo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Botón cerrar
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: widget.onCancel,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),

        // Botón de captura
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isTakingPicture ? null : _takePhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                  color: _isTakingPicture
                      ? AppColors.accent.withOpacity(0.5)
                      : AppColors.accent,
                ),
                child: _isTakingPicture
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'No se pudo abrir la cámara',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Painter para crear la máscara circular
class CircularMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    // Ajustar el centro vertical para mejor posicionamiento
    final double centerY =
        size.height * 0.45; // Ligeramente más arriba del centro

    // Calcular el radio basado en la altura de la pantalla para mejor precisión
    // Usar un factor que tenga más relación con la captura real
    final double radius = (size.height * 0.25).clamp(120.0, 200.0);

    // Crear path para el círculo
    final Path circlePath = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));

    // Crear path para toda la pantalla
    final Path screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Restar el círculo de la pantalla para crear el agujero
    final Path maskPath = Path.combine(
      PathOperation.difference,
      screenPath,
      circlePath,
    );

    // Dibujar la máscara semitransparente (menos opaca para ver mejor)
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withOpacity(0.7), // Aumentado de 0.6 a 0.7
    );

    // Dibujar el borde del círculo con mejor visibilidad
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0, // Aumentar grosor para mejor visibilidad
    );

    // Dibujar un círculo interior para mejor definición del área
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius - 2,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Añadir puntos de referencia para alinear la cara
    final Paint dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    const double dotRadius = 2.5;
    final double guideRadius = radius * 0.75;

    // Puntos de guía (ojos y boca aproximadamente)
    // Punto superior (frente)
    canvas.drawCircle(
      Offset(centerX, centerY - guideRadius * 0.6),
      dotRadius,
      dotPaint,
    );

    // Puntos laterales (orejas aproximadamente)
    canvas.drawCircle(
      Offset(centerX - guideRadius * 0.8, centerY - guideRadius * 0.2),
      dotRadius,
      dotPaint,
    );

    canvas.drawCircle(
      Offset(centerX + guideRadius * 0.8, centerY - guideRadius * 0.2),
      dotRadius,
      dotPaint,
    );

    // Punto inferior (barbilla)
    canvas.drawCircle(
      Offset(centerX, centerY + guideRadius * 0.8),
      dotRadius,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

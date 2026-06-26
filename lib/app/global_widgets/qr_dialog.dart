import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gymads/app/modules/clientes/services/qr_cache_service.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/snackbar_helper.dart';

class QrDialog extends StatefulWidget {
  final String nombre;
  final String telefono;
  final String userNumber;
  final double totalAmount;

  const QrDialog({
    super.key,
    required this.nombre,
    required this.telefono,
    required this.userNumber,
    required this.totalAmount,
  });

  @override
  State<QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<QrDialog> {
  final QrCacheService _qrCacheService = QrCacheService();
  File? _qrImageFile;
  bool _isSharingQr = false;

  @override
  void initState() {
    super.initState();
    // Cargar QR de caché de forma diferida para evitar crash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQrImageSafe();
    });
  }

  Future<void> _loadQrImageSafe() async {
    try {
      // Solo intentar cargar desde caché, no generar nuevo QR aquí
      final existingQrFile =
          await _qrCacheService.getQrImage(widget.userNumber);

      if (existingQrFile != null && await existingQrFile.exists()) {
        // Verificar que el archivo no esté corrupto
        final fileBytes = await existingQrFile.readAsBytes();
        if (fileBytes.isNotEmpty && mounted) {
          setState(() {
            _qrImageFile = existingQrFile;
          });
        }
      }
      // Si no existe en caché, dejamos que QrImageView lo muestre directamente
    } catch (e) {
      print('Error al cargar QR desde caché: $e');
      // No hacer nada - QrImageView se mostrará como fallback
    }
  }

  Future<void> _downloadQr() async {
    if (_isSharingQr) return; // Evitar múltiples toques

    setState(() {
      _isSharingQr = true;
    });

    try {
      // Forzar regeneración del QR exactamente como se muestra
      final qrImage = await _generateVisualQrImage(widget.userNumber);

      if (qrImage == null) {
        SnackbarHelper.error(
          'Error',
          'No se pudo generar el código QR',
        );
        return;
      }

      // Crear nombre único para el archivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'QR_${widget.nombre.replaceAll(' ', '_')}_${widget.userNumber}_$timestamp.png';

      // Crear archivo temporal en el directorio de cache para compartir
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');

      // Guardar el QR regenerado en el archivo temporal
      await tempFile.writeAsBytes(qrImage);

      // También actualizar el caché y Supabase con esta versión
      await _qrCacheService.updateQrWithBytes(widget.userNumber, qrImage);

      if (!await tempFile.exists()) {
        throw Exception('No se pudo crear el archivo temporal');
      }

      // Usar share_plus para compartir el archivo
      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'Código QR de GymAds',
        text: 'Código QR de ${widget.nombre}',
      );

      if (result.status == ShareResultStatus.success) {
        SnackbarHelper.success(
          'QR Compartido',
          'Código QR compartido exitosamente',
        );
      } else {
        // Manejar error de compartir silenciosamente
        print('Compartir QR: ${result.status}');
      }
    } catch (e) {
      print('Error al compartir QR: $e');
      SnackbarHelper.error(
        'Error',
        'No se pudo compartir el código QR. Intenta nuevamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingQr = false;
        });
      }
    }
  }

  // Método para generar una imagen QR exactamente igual a la mostrada
  Future<Uint8List?> _generateVisualQrImage(String userNumber) async {
    try {
      // NOTA: Estos parámetros DEBEN ser exactamente iguales a los usados en
      // QrImageView en el método build y también en QrCacheService._generateQrBytes

      // Nota: Usamos directamente QrPainter ya que maneja internamente la creación del QrCode

      // Pintar usando los mismos parámetros exactos que la vista
      final qrPainter = QrPainter(
        data: userNumber,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        color: Colors.black,
        emptyColor: Colors.white,
        gapless: false,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      // Crear una imagen del QR con fondo blanco
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const size = Size(512, 512); // Tamaño grande para mejor calidad

      // Fondo blanco explícito
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Dibujar el QR en el canvas
      qrPainter.paint(canvas, size);

      final picture = pictureRecorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('No se pudo generar la imagen del QR');
      }

      print('✅ QR generado exitosamente para: $userNumber');
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('❌ Error al generar imagen QR: $e');
      return null;
    }
  }

  Future<void> _openWhatsApp() async {
    final message = '''Bienvenido a Fitness Ads

tu QR de identificación: https://fitnessads.web.app/${widget.userNumber}

Total pagado: \$${widget.totalAmount.toStringAsFixed(2)}''';

    // Codificar el mensaje para la URL
    final encodedMessage = Uri.encodeComponent(message);

    // Crear el enlace de WhatsApp con el número de teléfono y mensaje
    final whatsappUrl = 'https://wa.me/${widget.telefono}?text=$encodedMessage';

    // Abrir WhatsApp
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      SnackbarHelper.error(
        'Error',
        'No se pudo abrir WhatsApp',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Código QR de Acceso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.titleColor,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // QR Code Widget - Mostrar QrImageView directamente, usar archivo de caché si está disponible
                  _qrImageFile != null
                      ? Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Image.file(
                            _qrImageFile!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error al cargar imagen QR: $error');
                              // Si falla la carga del archivo, mostrar el QR generado en tiempo real
                              return QrImageView(
                                data: widget.userNumber,
                                version: QrVersions.auto,
                                size: 200.0,
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white,
                                gapless: false,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              );
                            },
                          ),
                        )
                      : QrImageView(
                          data: widget.userNumber,
                          version: QrVersions.auto,
                          size: 200.0,
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          gapless: false,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                  const SizedBox(height: 12),
                  Text(
                    widget.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usuario: ${widget.userNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total pagado: \$${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Botones de acción
            Row(
              children: [
                // Botón de WhatsApp
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openWhatsApp,
                    icon: Icon(
                      MdiIcons.whatsapp,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón de descarga
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadQr,
                    icon: _isSharingQr
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.download_outlined,
                            color: Colors.white,
                          ),
                    label: Text(
                      _isSharingQr ? 'Procesando...' : 'Descargar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Botón de cerrar
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Cerrar',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

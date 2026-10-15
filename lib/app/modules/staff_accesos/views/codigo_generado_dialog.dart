import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/staff_accesos_controller.dart';

/// Muestra el código de acceso recién generado, como QR y escrito.
///
/// El QR es lo principal: el empleado lo escanea en "Entrar como staff" y
/// entra sin teclear. Lleva el mismo código, así que también es de un solo
/// uso. Es la única vez que ese código es visible: en el servidor solo se guarda su
/// hash. Por eso el diálogo no se cierra tocando fuera y lo dice de forma
/// explícita — si se pierde, la salida es regenerarlo, no recuperarlo.
///
/// Con [accesoId], el diálogo sigue el acceso en la lista (que se recarga en
/// vivo): en cuanto el empleado usa el código, el QR se cambia por un aviso de
/// que ya entró. Así el dueño lo ve sin cerrar el diálogo.
Future<void> showCodigoGeneradoDialog({
  required String nombre,
  required String codigo,
  required String gymName,
  String? accesoId,
  bool esRegenerado = false,
}) {
  return Get.dialog<void>(
    _CodigoGeneradoDialog(
      nombre: nombre,
      codigo: codigo,
      gymName: gymName,
      accesoId: accesoId,
      esRegenerado: esRegenerado,
    ),
    barrierDismissible: false,
  );
}

class _CodigoGeneradoDialog extends StatelessWidget {
  final String nombre;
  final String codigo;
  final String gymName;
  final String? accesoId;
  final bool esRegenerado;

  const _CodigoGeneradoDialog({
    required this.nombre,
    required this.codigo,
    required this.gymName,
    required this.accesoId,
    required this.esRegenerado,
  });

  String get _mensajeCompartir =>
      'Hola $nombre, este es tu código para entrar a $gymName:\n\n'
      '$codigo\n\n'
      'Abre la app, toca "Entrar como staff" y escanea el QR o escribe el '
      'código. Solo funciona una vez.';

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Dialog(
      backgroundColor: c.cardBackground,
      // Ancho de diálogo aunque el teléfono esté de lado, y desplazable si
      // no cabe a lo alto.
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _siguiendoElAcceso(context),
      ),
    );
  }

  /// El código mientras sigue sin usarse; el aviso de que ya entró en cuanto
  /// la lista (recargada en vivo) trae su acceso como activo.
  Widget _siguiendoElAcceso(BuildContext context) {
    final id = accesoId;
    if (id == null || !Get.isRegistered<StaffAccesosController>()) {
      return _codigo(context);
    }
    final accesos = Get.find<StaffAccesosController>().accesos;
    return Obx(() {
      final usado = accesos.any((a) => a.id == id && a.estaActivo);
      return usado ? _yaEntro(context) : _codigo(context);
    });
  }

  Widget _yaEntro(BuildContext context) {
    final c = context.colores;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              color: AppColors.success, size: 40),
        ),
        Text(
          'Ya entró',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$nombre ya entró con este código. El código dejó de servir.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textSecondary.withOpacity(0.85),
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Get.back(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Listo',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _codigo(BuildContext context) {
    final c = context.colores;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.vpn_key, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                esRegenerado ? 'Código nuevo' : 'Acceso creado',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          esRegenerado
              ? 'El código anterior de $nombre dejó de servir.'
              : 'Que $nombre lo escanee en "Entrar como staff".',
          style: TextStyle(
            color: c.textSecondary.withOpacity(0.85),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),

        // El QR, protagonista de la pantalla. Fondo blanco siempre: en
        // modo oscuro un QR claro sobre oscuro muchas cámaras no lo leen.
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withOpacity(0.5)),
            ),
            child: QrImageView(
              data: codigo,
              size: 200,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              semanticsLabel: 'QR del código de acceso',
            ),
          ),
        ),
        const SizedBox(height: 14),

        // El código escrito, por si no se puede escanear.
        Text(
          'O que escriba el código',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textSecondary.withOpacity(0.85),
            fontSize: legible(12.5),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: SelectableText(
            codigo,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),

        // La advertencia va antes de los botones: es lo que el dueño
        // tiene que entender antes de cerrar.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Guárdalo ahora: no se podrá volver a ver.',
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.9),
                    fontSize: legible(12.5),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copiar,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.textSecondary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.copy, size: 18, color: c.textPrimary),
                label: Text('Copiar', style: TextStyle(color: c.textPrimary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // El Builder da el contexto del propio botón, que es lo que
              // necesita _compartir para saber de dónde sale la hoja.
              child: Builder(
                builder: (contextBoton) => ElevatedButton.icon(
                  onPressed: () => _compartir(contextBoton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.share, size: 18, color: Colors.white),
                  label: const Text('Compartir',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            'Ya lo guardé',
            style: TextStyle(color: c.textSecondary),
          ),
        ),
      ],
    );
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: codigo));
    SnackbarHelper.success('Copiado', 'El código está en el portapapeles');
  }

  Future<void> _compartir(BuildContext context) async {
    // iOS exige un rectángulo de origen no vacío: en iPad es el ancla desde la
    // que sale el popover, y sin él la llamada revienta con
    // "sharePositionOrigin: argument must be set". Se ancla al propio botón,
    // que es de donde el usuario espera que salga la hoja.
    final box = context.findRenderObject() as RenderBox?;

    final Rect origen;
    if (box != null && box.hasSize && !box.size.isEmpty) {
      origen = box.localToGlobal(Offset.zero) & box.size;
    } else {
      // Sin medidas no hay ancla, pero un rect vacío vuelve a romper: se cae
      // al centro de la pantalla, que siempre está dentro del área válida.
      final pantalla = MediaQuery.sizeOf(context);
      origen = Rect.fromCenter(
        center: Offset(pantalla.width / 2, pantalla.height / 2),
        width: 1,
        height: 1,
      );
    }

    // Con la imagen del QR, para escanearla desde otra pantalla o elegirla
    // como foto. Si no se puede (sin archivos en esa plataforma), solo el
    // texto, que también trae el código.
    try {
      final qr = await _archivoDelQr();
      await Share.shareXFiles(
        [XFile(qr.path, mimeType: 'image/png')],
        text: _mensajeCompartir,
        sharePositionOrigin: origen,
      );
    } catch (_) {
      await Share.share(_mensajeCompartir, sharePositionOrigin: origen);
    }
  }

  /// El QR como PNG, con fondo blanco y margen para que se lea en cualquier
  /// chat (en modo oscuro un PNG transparente queda negro sobre negro).
  Future<File> _archivoDelQr() async {
    const lado = 600.0;
    const margen = 48.0;
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora)
      ..drawRect(
          const Rect.fromLTWH(0, 0, lado, lado), Paint()..color = Colors.white)
      ..translate(margen, margen);
    QrPainter(data: codigo, version: QrVersions.auto, gapless: true)
        .paint(lienzo, const Size.square(lado - 2 * margen));
    final imagen =
        await grabadora.endRecording().toImage(lado.toInt(), lado.toInt());
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();

    final carpeta = await getTemporaryDirectory();
    final archivo = File('${carpeta.path}/codigo_de_acceso.png');
    await archivo.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    return archivo;
  }
}

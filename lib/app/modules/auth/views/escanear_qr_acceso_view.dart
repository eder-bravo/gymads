import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/core/theme/siempre_oscuro.dart';
import '../../../core/utils/access_code_generator.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/permiso_de_camara.dart';

/// Lee el QR del acceso del personal y devuelve su código (`XXXX-XXXX`) con
/// `Get.back(result: ...)`, o null si se cancela.
///
/// ```dart
/// final codigo = await Get.to<String>(() => const EscanearQrAccesoView());
/// ```
///
/// No es `EscanerCodigoView`: aquel es de productos (solo códigos de barras,
/// varias lecturas iguales, recuadro ancho). Un QR trae su propia corrección
/// de errores, así que basta una lectura.
///
/// También lee el QR de una foto, para cuando llegó por WhatsApp al mismo
/// teléfono con el que se va a entrar.
class EscanearQrAccesoView extends StatefulWidget {
  const EscanearQrAccesoView({super.key});

  @override
  State<EscanearQrAccesoView> createState() => _EscanearQrAccesoViewState();
}

class _EscanearQrAccesoViewState extends State<EscanearQrAccesoView> {
  late final MobileScannerController _controlador = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// Sin esta bandera, los fotogramas que siguen llegando mientras se cierra
  /// la pantalla harían `Get.back` varias veces.
  bool _yaDevuelto = false;

  /// La cámara se pide al abrir. Null mientras se pregunta.
  bool? _camaraPermitida;

  String? _aviso;
  Timer? _ocultarAviso;

  static const double _ladoMarco = 260;

  @override
  void initState() {
    super.initState();
    _revisarCamara();
  }

  Future<void> _revisarCamara() async {
    final permitida = await pedirCamara(para: 'escanear el QR', avisar: false);
    if (mounted) setState(() => _camaraPermitida = permitida);
  }

  @override
  void dispose() {
    _ocultarAviso?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  /// True si [captura] traía un código de acceso (y ya se devolvió).
  bool _revisar(BarcodeCapture? captura) {
    if (_yaDevuelto || captura == null) return false;
    for (final qr in captura.barcodes) {
      final valor = qr.rawValue;
      if (valor == null || valor.trim().isEmpty) continue;
      final codigo = AccessCodeGenerator.codigoDesdeQr(valor);
      if (codigo == null) continue;
      _yaDevuelto = true;
      HapticFeedback.mediumImpact();
      Get.back(result: codigo);
      return true;
    }
    return false;
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_revisar(captura)) return;
    if (captura.barcodes.any((qr) => (qr.rawValue ?? '').trim().isNotEmpty)) {
      _mostrarAviso('Ese QR no es un código de acceso');
    }
  }

  Future<void> _desdeFoto() async {
    try {
      final foto = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (foto == null || !mounted) return;
      final captura = await _controlador.analyzeImage(foto.path,
          formats: const [BarcodeFormat.qrCode]);
      if (!_revisar(captura)) {
        _mostrarAviso('No se encontró un QR de acceso en la foto');
      }
    } catch (e) {
      AppLogger.warning('EscanearQrAcceso', 'No se pudo leer la foto: $e');
      _mostrarAviso('No se pudo leer la foto');
    }
  }

  void _mostrarAviso(String texto) {
    if (!mounted || _aviso == texto) return;
    _ocultarAviso?.cancel();
    setState(() => _aviso = texto);
    _ocultarAviso = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _aviso = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SiempreOscuro(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Escanear QR'),
          actions: [
            if (_camaraPermitida == true)
              IconButton(
                tooltip: 'Linterna',
                icon: const Icon(Icons.flashlight_on),
                onPressed: () => _controlador.toggleTorch(),
              ),
          ],
        ),
        body: switch (_camaraPermitida) {
          null => const Center(
              child: CircularProgressIndicator(color: AppColors.accent)),
          false => _sinCamara(),
          true => _camara(),
        },
      ),
    );
  }

  Widget _camara() {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, limites) => MobileScanner(
            controller: _controlador,
            onDetect: _alDetectar,
            scanWindow: Rect.fromCenter(
              center: limites.biggest.center(Offset.zero),
              width: _ladoMarco + 40,
              height: _ladoMarco + 40,
            ),
            errorBuilder: (context, error) => _sinCamara(),
          ),
        ),
        Center(
          child: Container(
            width: _ladoMarco,
            height: _ladoMarco,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_aviso != null)
          Align(
            alignment: const Alignment(0, 0.5),
            child: _avisoLectura(_aviso!),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            color: Colors.black.withOpacity(0.55),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Apunta al QR que te dio el gimnasio',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 8),
                _botonFoto(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sinCamara() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              textoPermisoCamara('escanear el QR'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Abrir ajustes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _camaraPermitida = null);
                    _revisarCamara();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Intentar de nuevo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _botonFoto(),
            if (_aviso != null) ...[
              const SizedBox(height: 12),
              _avisoLectura(_aviso!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botonFoto() {
    return TextButton.icon(
      onPressed: _desdeFoto,
      icon: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
      label: const Text(
        'Elegir foto del QR',
        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _avisoLectura(String texto) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

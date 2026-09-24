import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/confirmador_codigo.dart';

/// Lector de códigos de barras.
///
/// Tiene dos modos:
///
/// - **Un código** (por defecto): devuelve lo leído con `Get.back(result: ...)`,
///   o null si se cancela.
///
///   ```dart
///   final codigo = await Get.to<String>(() => const EscanerCodigoView());
///   ```
///
/// - **Continuo** (con [alLeer]): la cámara sigue abierta y cada código se
///   entrega a [alLeer], cuyo texto se muestra como aviso. Se cierra con
///   "Listo". Es el del punto de venta, donde se escanean varios productos
///   seguidos.
///
/// No sabe nada de productos: solo lee y entrega.
class EscanerCodigoView extends StatefulWidget {
  const EscanerCodigoView({
    super.key,
    this.titulo = 'Escanear código',
    this.instruccion = 'Apunta al código de barras del producto',
    this.alLeer,
  });

  final String titulo;
  final String instruccion;

  /// Activa el modo continuo. Recibe cada código leído y devuelve el aviso
  /// que se muestra (por ejemplo "+1 Agua"), o null para no mostrar nada.
  final Future<String?> Function(String codigo)? alLeer;

  @override
  State<EscanerCodigoView> createState() => _EscanerCodigoViewState();
}

class _EscanerCodigoViewState extends State<EscanerCodigoView> {
  /// Tiempo mínimo entre dos lecturas del MISMO código en modo continuo. La
  /// cámara entrega decenas de fotogramas por segundo: sin esto, apuntar a una
  /// bebida la sumaría muchas veces. Con esto, escanearla dos veces a
  /// propósito suma dos.
  static const _enfriamiento = Duration(seconds: 2);

  bool get _continuo => widget.alLeer != null;

  late final MobileScannerController _controlador = MobileScannerController(
    // Solo formatos de producto. Sin esta lista también leería QR y otros
    // códigos que en un envase nunca son el código del producto.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf,
    ],
    // Todas las lecturas, cada 100 ms: el código se acepta hasta que se lee
    // igual varias veces (`_confirmador`). `noDuplicates` entregaba solo la
    // primera, y era la que a veces salía con los números cambiados.
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 100,
    // Más resolución que la de fábrica: las barras delgadas de un envase
    // chico se distinguen mejor (en iPhone la elige el sistema).
    cameraResolution: const Size(1920, 1080),
  );

  final _confirmador = ConfirmadorCodigo();

  /// Formatos cuyo último dígito verifica a los demás.
  static const _conVerificador = {
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
  };

  /// Formatos sin dígito verificador obligatorio: un error de lectura no se
  /// nota en el número, así que se piden más lecturas iguales.
  static const _sinVerificador = {BarcodeFormat.code39, BarcodeFormat.itf};

  /// La cámara sigue entregando fotogramas mientras se cierra la pantalla, así
  /// que sin esta bandera el mismo código dispararía `Get.back` varias veces y
  /// se cerrarían pantallas que no eran esta.
  bool _yaDevuelto = false;

  // Estado del modo continuo.
  String? _ultimoCodigo;
  DateTime _ultimaLectura = DateTime.fromMillisecondsSinceEpoch(0);
  bool _procesando = false;
  String? _aviso;
  Timer? _ocultarAviso;

  @override
  void dispose() {
    _ocultarAviso?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_yaDevuelto) return;

    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue?.trim();
      if (valor == null || valor.isEmpty) continue;

      // Un EAN o UPC con el verificador mal es una lectura a medias.
      if (_conVerificador.contains(codigo.format) &&
          !digitoVerificadorValido(valor)) {
        continue;
      }

      final confirmado = _confirmador.registrar(
        valor,
        necesarias: _sinVerificador.contains(codigo.format) ? 4 : 3,
      );
      if (confirmado == null) continue;

      if (_continuo) {
        _entregar(confirmado);
      } else {
        _yaDevuelto = true;
        Get.back(result: confirmado);
      }
      return;
    }
  }

  Future<void> _entregar(String codigo) async {
    // Uno a la vez: `alLeer` puede abrir un diálogo (producto sin
    // existencias) y mientras tanto la cámara sigue leyendo.
    if (_procesando) return;

    final ahora = DateTime.now();
    if (codigo == _ultimoCodigo &&
        ahora.difference(_ultimaLectura) < _enfriamiento) {
      return;
    }

    _procesando = true;
    HapticFeedback.mediumImpact();

    try {
      final aviso = await widget.alLeer!(codigo);
      if (!mounted) return;
      if (aviso != null) _mostrarAviso(aviso);
    } finally {
      // El enfriamiento cuenta desde que terminó de procesarse: si hubo un
      // diálogo, el código seguía frente a la cámara al cerrarlo.
      _ultimoCodigo = codigo;
      _ultimaLectura = DateTime.now();
      _procesando = false;
    }
  }

  void _mostrarAviso(String texto) {
    _ocultarAviso?.cancel();
    setState(() => _aviso = texto);
    _ocultarAviso = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _aviso = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.titulo),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controlador.toggleTorch(),
          ),
          if (_continuo)
            TextButton(
              onPressed: () {
                _yaDevuelto = true;
                Get.back();
              },
              child: const Text('Listo',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, limites) => MobileScanner(
              controller: _controlador,
              onDetect: _alDetectar,
              // Solo se lee lo que está dentro del recuadro (con un poco de
              // margen): un código a medio salir, o el de al lado, ya no se
              // cuela.
              scanWindow: Rect.fromCenter(
                center: limites.biggest.center(Offset.zero),
                width: _anchoMarco + 40,
                height: _altoMarco + 40,
              ),
              errorBuilder: (context, error) => _error(error),
            ),
          ),
          _marco(),
          if (_aviso != null) _avisoLectura(_aviso!),
          _pie(),
        ],
      ),
    );
  }

  static const double _anchoMarco = 280;
  static const double _altoMarco = 160;

  /// El recuadro donde hay que poner el código: solo se lee lo que queda
  /// dentro (ver `scanWindow`).
  Widget _marco() {
    return Center(
      child: Container(
        width: _anchoMarco,
        height: _altoMarco,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Lo que pasó con el último código, justo debajo del recuadro.
  Widget _avisoLectura(String texto) {
    return Align(
      alignment: const Alignment(0, 0.45),
      child: Container(
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
      ),
    );
  }

  Widget _pie() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        color: Colors.black.withOpacity(0.55),
        child: Text(
          widget.instruccion,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  /// Si la cámara no arranca, casi siempre es el permiso denegado. Se dice qué
  /// hacer en vez de dejar la pantalla en negro.
  Widget _error(MobileScannerException error) {
    final esPermiso =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(esPermiso ? Icons.no_photography : Icons.error_outline,
                color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              esPermiso
                  ? 'La app no tiene permiso para usar la cámara. '
                      'Actívalo en los ajustes del teléfono.'
                  : 'No se pudo abrir la cámara.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

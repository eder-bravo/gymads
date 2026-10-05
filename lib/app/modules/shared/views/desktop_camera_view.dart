import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart' as mac;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/permisos_escritorio.dart';
import '../../../../core/theme/siempre_oscuro.dart';
import '../utils/recorte_circulo.dart';

class _Camara {
  const _Camara(this.id, this.nombre, {this.windows});
  final String id;
  final String nombre;
  final CameraDescription? windows;
}

/// Foto con cualquier cámara que el sistema publique, incluidas las virtuales.
class DesktopCameraView extends StatefulWidget {
  const DesktopCameraView(
      {super.key,
      required this.onPhotoTaken,
      required this.onCancel,
      this.circular = true});
  final ValueChanged<File> onPhotoTaken;
  final VoidCallback onCancel;
  final bool circular;
  @override
  State<DesktopCameraView> createState() => _DesktopCameraViewState();
}

class _DesktopCameraViewState extends State<DesktopCameraView>
    with WidgetsBindingObserver {
  List<_Camara> _camaras = [];
  String? _elegida;
  CameraController? _windows;
  mac.CameraMacOSController? _mac;
  mac.CameraMacOSArguments? _argumentos;
  File? _foto;
  String? _error;

  /// El error técnico, aparte del mensaje: se ve solo con "Ver detalles".
  String? _detalleError;
  bool _cargando = true;
  bool _tomando = false;
  bool _cerrado = false;
  Future<void> _operacion = Future.value();
  Size? _vista;
  double get _aspecto => _argumentos != null
      ? _argumentos!.size.width / _argumentos!.size.height
      : _windows?.value.aspectRatio ?? 4 / 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actualizar();
  }

  @override
  void dispose() {
    _cerrado = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_operacion.then((_) => _liberar()));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // En escritorio perder foco no exige cerrar la cámara. Se libera si el
    // sistema realmente pausa la aplicación; al volver se enumeran de nuevo.
    if (estado == AppLifecycleState.paused) {
      _operacion = _operacion.then((_) => _liberar());
    } else if (estado == AppLifecycleState.resumed &&
        !_cargando &&
        _foto == null) {
      _actualizar();
    }
  }

  Future<void> _liberar() async {
    final windows = _windows;
    final macos = _mac;
    _windows = null;
    _mac = null;
    _argumentos = null;
    await windows?.dispose();
    await macos?.destroy();
  }

  void _actualizar({String? seleccionar}) {
    if (_cerrado || _tomando) return;
    setState(() {
      _cargando = true;
      _error = null;
      _detalleError = null;
    });
    _operacion = _operacion.then((_) async {
      try {
        await _liberar();
        if (_cerrado) return;
        final prefs = await SharedPreferences.getInstance();
        if (Platform.isMacOS) {
          final devices = await mac.CameraMacOSPlatform.instance
              .listDevices(deviceType: mac.CameraMacOSDeviceType.video);
          _camaras = devices
              .map((d) =>
                  _Camara(d.deviceId, d.localizedName ?? 'Cámara externa'))
              .toList();
        } else {
          // Windows (camera_windows) y Linux (camera_desktop, con GStreamer)
          // usan el mismo paquete camera.
          final devices = await availableCameras();
          _camaras = devices
              .map((d) =>
                  _Camara(d.name, d.name.split('<').first.trim(), windows: d))
              .toList();
        }
        if (_camaras.isEmpty) {
          throw StateError(
              'No hay cámaras disponibles. Conecta una webcam y pulsa Actualizar.');
        }
        final preferida =
            seleccionar ?? _elegida ?? prefs.getString('camara_escritorio');
        final camara = _camaras.firstWhere((d) => d.id == preferida,
            orElse: () => _camaras.first);
        _elegida = camara.id;
        if (Platform.isMacOS) {
          final args = await mac.CameraMacOSPlatform.instance.initialize(
              deviceId: camara.id,
              cameraMacOSMode: mac.CameraMacOSMode.photo,
              enableAudio: false,
              pictureFormat: mac.PictureFormat.jpeg,
              resolution: mac.PictureResolution.high,
              isVideoMirrored: false);
          if (args == null || args.textureId == null) {
            throw StateError('La cámara no devolvió una vista previa.');
          }
          _argumentos = args;
          _mac = mac.CameraMacOSController(args);
        } else {
          _windows = CameraController(camara.windows!, ResolutionPreset.high,
              enableAudio: false);
          await _windows!.initialize();
          _windows!.addListener(_errorWindows);
        }
        if (_cerrado) {
          await _liberar();
          return;
        }
        await prefs.setString('camara_escritorio', camara.id);
      } catch (e) {
        await _liberar();
        if (!_cerrado) {
          if (e is StateError) {
            // Mensajes de la propia app ("No hay cámaras…"): se leen tal cual.
            _error = e.message;
          } else if (Platform.isLinux) {
            // En Linux no hay permisos de cámara que revisar en el sistema.
            _error = 'No se pudo abrir la cámara. Cierra otras apps que la '
                'usen o elige otra cámara.';
            _detalleError = '$e';
          } else {
            _error = 'No se pudo abrir la cámara. Revisa los permisos, '
                'cierra otras apps que la usen o elige otra cámara.';
            _detalleError = '$e';
          }
        }
      } finally {
        if (mounted) setState(() => _cargando = false);
      }
    });
  }

  Future<void> _tomar() async {
    if (_tomando || _cargando) return;
    setState(() => _tomando = true);
    File? destino;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final carpeta = Directory('${docs.path}/photo_capture');
      await carpeta.create(recursive: true);
      destino = File(
          '${carpeta.path}/cliente_${DateTime.now().microsecondsSinceEpoch}.jpg');
      if (_mac != null) {
        final imagen =
            await _mac!.takePicture().timeout(const Duration(seconds: 10));
        final bytes = imagen?.bytes;
        if (bytes == null || bytes.isEmpty) throw StateError('Sin foto');
        await destino.writeAsBytes(bytes);
      } else {
        final imagen =
            await _windows!.takePicture().timeout(const Duration(seconds: 10));
        await File(imagen.path).copy(destino.path);
        try {
          await File(imagen.path).delete();
        } catch (_) {}
      }
      if (widget.circular && _vista != null) {
        await recortarFotoAlCirculo(destino.path,
            vista: _vista!, aspectoVistaPrevia: _aspecto);
      }
      if (_cerrado) {
        await destino.delete();
        return;
      }
      setState(() => _foto = destino);
    } catch (_) {
      if (destino != null && await destino.exists()) await destino.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No se tomó la foto. Revisa la cámara e intenta de nuevo.')));
      }
    } finally {
      if (mounted) setState(() => _tomando = false);
    }
  }

  @override
  Widget build(BuildContext context) => SiempreOscuro(
          child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            title: const Text('Foto del cliente'),
            leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: _tomando ? null : widget.onCancel),
            actions: [
              IconButton(
                  tooltip: 'Actualizar cámaras',
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargando || _tomando || _foto != null
                      ? null
                      : () => _actualizar())
            ]),
        body: SafeArea(
            child: LayoutBuilder(
                builder: (context, limites) => SingleChildScrollView(
                        child: Column(children: [
                      if (_camaras.isNotEmpty && _foto == null)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: _anchoDeLectura(DropdownButtonFormField<
                                    String>(
                                initialValue: _elegida,
                                key: ValueKey(_elegida),
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'Cámara'),
                                items: _camaras
                                    .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.nombre,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: _cargando || _tomando
                                    ? null
                                    : (id) => _actualizar(seleccionar: id)))),
                      SizedBox(
                          height: (limites.maxHeight * 0.6)
                              .clamp(180, double.infinity),
                          child: _contenido()),
                      Padding(
                          padding: const EdgeInsets.all(16),
                          // Botones de buen tamaño y con ícono: es lo único
                          // que hay que hacer en esta pantalla.
                          child: _foto == null
                              ? FilledButton.icon(
                                  onPressed:
                                      _cargando || _tomando || _error != null
                                          ? null
                                          : _tomar,
                                  style: _estiloBoton,
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text(_tomando
                                      ? 'Tomando foto…'
                                      : 'Tomar foto'))
                              : Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                      OutlinedButton.icon(
                                          onPressed: () async {
                                            final foto = _foto!;
                                            setState(() => _foto = null);
                                            await foto.delete();
                                          },
                                          style: _estiloBoton,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Repetir')),
                                      FilledButton.icon(
                                          onPressed: () =>
                                              widget.onPhotoTaken(_foto!),
                                          style: _estiloBoton,
                                          icon: const Icon(Icons.check),
                                          label: const Text('Usar foto'))
                                    ])),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _anchoDeLectura(const Text(
                              'Para usar la cámara del celular, actívala como webcam en el sistema o en su aplicación y actualiza la lista.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 15)))),
                    ])))),
      ));

  Widget _contenido() {
    if (_foto != null) {
      return Center(child: Image.file(_foto!, fit: BoxFit.contain));
    }
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _anchoDeLectura(
                      Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.4)),
                    if (_detalleError != null)
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: const Text('Ver detalles',
                              textAlign: TextAlign.center),
                          children: [
                            SelectableText(_detalleError!,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                      ),
                    if (!Platform.isLinux)
                      const TextButton(
                          onPressed: PermisosEscritorio.abrirAjustes,
                          child: Text('Abrir permisos de cámara')),
                    TextButton(
                        onPressed: () => _actualizar(),
                        child: const Text('Intentar de nuevo')),
                  ])))));
    }
    return LayoutBuilder(builder: (context, limites) {
      _vista = limites.biggest;
      final preview = _argumentos != null
          ? Texture(textureId: _argumentos!.textureId!)
          : _windows!.buildPreview();
      return Stack(fit: StackFit.expand, children: [
        Center(child: AspectRatio(aspectRatio: _aspecto, child: preview)),
        if (widget.circular)
          IgnorePointer(child: CustomPaint(painter: _GuiaFoto())),
      ]);
    });
  }

  static const _estiloBoton = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(200, 48)),
    textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
  );

  /// Textos y selector con un ancho que se lee cómodo: en una ventana grande
  /// no se estiran de lado a lado.
  Widget _anchoDeLectura(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child,
        ),
      );

  void _errorWindows() {
    final controller = _windows;
    if (mounted && controller != null && controller.value.hasError) {
      setState(
          () => _error = 'La cámara dejó de responder. Revisa su conexión, '
              'elige otra cámara o pulsa Actualizar.');
    }
  }
}

class _GuiaFoto extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final circulo = circuloGuia(size);
    canvas.drawPath(
        Path.combine(PathOperation.difference,
            Path()..addRect(Offset.zero & size), Path()..addOval(circulo)),
        Paint()..color = Colors.black54);
    canvas.drawOval(
        circulo,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

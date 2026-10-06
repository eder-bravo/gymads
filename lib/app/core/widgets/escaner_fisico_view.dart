import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../data/services/escaner_fisico_service.dart';
import '../utils/plataforma_app.dart';
import 'escaner_automatico.dart';

/// Captura solo con este campo enfocado: no intercepta formularios ajenos.
///
/// En la tableta no hay campo (abriría el teclado de la pantalla): escucha
/// al lector con [EscanerAutomatico] y devuelve la primera lectura.
class EscanerFisicoView extends StatefulWidget {
  const EscanerFisicoView({super.key, required this.titulo, this.alLeer});
  final String titulo;
  final Future<String?> Function(String)? alLeer;
  @override
  State<EscanerFisicoView> createState() => _EscanerFisicoViewState();
}

class _EscanerFisicoViewState extends State<EscanerFisicoView> {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  final _cola = <String>[];
  bool _procesando = false;
  bool _devuelto = false;
  String? _aviso;

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  KeyEventResult _tecla(FocusNode _, KeyEvent evento) {
    if (!EscanerFisicoService.esFinDeLectura(evento.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (evento is KeyDownEvent) _recibir();
    return KeyEventResult.handled;
  }

  void _recibir() {
    if (_devuelto) return;
    final codigo = EscanerFisicoService.codigoDe(_texto.text);
    _texto.clear();
    _foco.requestFocus();
    if (codigo == null) {
      setState(() => _aviso = 'No llegó ningún código. Vuelve a escanearlo.');
      return;
    }
    if (widget.alLeer == null) {
      _devuelto = true;
      Get.back(result: codigo);
      return;
    }
    // Cada disparo cuenta; la cola conserva lecturas mientras se procesa una.
    _cola.add(codigo);
    unawaited(_procesar());
  }

  Future<void> _procesar() async {
    if (_procesando) return;
    _procesando = true;
    while (mounted && _cola.isNotEmpty) {
      final codigo = _cola.removeAt(0);
      try {
        final aviso = await widget.alLeer!(codigo);
        if (mounted) setState(() => _aviso = aviso ?? 'Leído: $codigo');
      } catch (_) {
        if (mounted) {
          setState(() =>
              _aviso = 'No se pudo procesar $codigo. Vuelve a escanearlo.');
        }
      }
    }
    _procesando = false;
    if (mounted) _foco.requestFocus();
  }

  /// La tableta: sin campo, solo escucha al lector.
  Widget _sinCampo(BuildContext context) => EscanerAutomatico(
        habilitado: () => !_devuelto,
        alLeer: (codigo) async {
          if (widget.alLeer != null) return widget.alLeer!(codigo);
          _devuelto = true;
          Get.back(result: codigo);
          return null;
        },
        child: Scaffold(
          appBar: AppBar(title: Text(widget.titulo)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: const [
                  Icon(Icons.barcode_reader, size: 64),
                  SizedBox(height: 20),
                  Text('Escanea cualquier código con tu lector',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text(
                      'Si no pasa nada, revisa que el lector esté conectado y '
                      'en modo teclado (HID).',
                      textAlign: TextAlign.center),
                  AvisoEscanerAutomatico(soloTrasLeer: true),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      PlataformaApp.tableta ? _sinCampo(context) : _conCampo(context);

  Widget _conCampo(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Icon(Icons.barcode_reader, size: 64),
                      const SizedBox(height: 20),
                      const Text('Escanea con tu lector físico',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                          'Conecta el lector USB o empareja el Bluetooth como teclado. '
                          'Mantén esta ventana activa y el campo seleccionado.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Focus(
                          onKeyEvent: _tecla,
                          child: TextField(
                              controller: _texto,
                              focusNode: _foco,
                              autofocus: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              maxLength: 512,
                              decoration: const InputDecoration(
                                  labelText: 'Código del lector',
                                  hintText:
                                      'También puedes escribirlo y pulsar Leer'))),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                          onPressed: _recibir,
                          icon: const Icon(Icons.check),
                          label: const Text('Leer')),
                      if (_aviso != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_aviso!, textAlign: TextAlign.center)),
                      const SizedBox(height: 20),
                      const Text(
                          'Si no aparece el código, haz clic en el campo. El lector debe estar '
                          'en modo teclado (HID). Sin Bluetooth puedes usar cable o un receptor '
                          'USB compatible.',
                          textAlign: TextAlign.center),
                    ]))),
      );
}

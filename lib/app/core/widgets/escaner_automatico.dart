import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/escaner_fisico_service.dart';
import '../../data/services/welcome_tour_service.dart';
import '../utils/app_logger.dart';
import '../utils/plataforma_app.dart';

/// Lectura HID al entrar en venta/inventario, sin abrir otra pantalla ni
/// exigir foco en un campo. Solo escucha la ruta visible, en computadora y
/// en tableta ([PlataformaApp.lectorDeTeclado]).
class EscanerAutomatico extends StatefulWidget {
  const EscanerAutomatico({
    super.key,
    required this.child,
    required this.alLeer,
    required this.habilitado,
    this.codigoRegistrado,
  });

  final Widget child;
  final Future<String?> Function(String codigo) alLeer;
  final bool Function() habilitado;
  final bool Function(String codigo)? codigoRegistrado;

  @override
  State<EscanerAutomatico> createState() => _EscanerAutomaticoState();
}

class _EscanerAutomaticoState extends State<EscanerAutomatico> {
  static const _intervalo = Duration(milliseconds: 100);
  final _estado = ValueNotifier<String?>(_mensajeInicial);
  final _cola = <String>[];
  String _entrada = '';
  Duration? _ultimaTecla;
  Timer? _caducidad;
  FocusNode? _focoInicial;
  EditableTextState? _buscador;
  TextEditingValue? _busquedaInicial;
  LogicalKeyboardKey? _terminadorConsumido;
  bool _procesando = false;
  bool _descartar = false;
  AppLifecycleState? _ciclo;
  late final AppLifecycleListener _cicloDeVida;

  bool get _activa =>
      mounted &&
      PlataformaApp.lectorDeTeclado &&
      widget.habilitado() &&
      _ciclo != AppLifecycleState.inactive &&
      _ciclo != AppLifecycleState.paused &&
      _ciclo != AppLifecycleState.hidden &&
      ModalRoute.of(context)?.isCurrent == true &&
      TickerMode.of(context) &&
      !WelcomeTourService.recorridoEnCurso.value;

  @override
  void initState() {
    super.initState();
    _ciclo = WidgetsBinding.instance.lifecycleState;
    _cicloDeVida = AppLifecycleListener(onStateChange: (estado) {
      _ciclo = estado;
      if (estado != AppLifecycleState.resumed) _limpiar();
    });
    FocusManager.instance.addEarlyKeyEventHandler(_tecla);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_tecla);
    _cicloDeVida.dispose();
    _limpiar();
    _cola.clear();
    _estado.dispose();
    super.dispose();
  }

  void _limpiar() {
    _caducidad?.cancel();
    _caducidad = null;
    _entrada = '';
    _ultimaTecla = null;
    _focoInicial = null;
    _buscador = null;
    _busquedaInicial = null;
    _descartar = false;
  }

  KeyEventResult _tecla(KeyEvent evento) {
    if (evento.logicalKey == _terminadorConsumido) {
      if (evento is KeyUpEvent) _terminadorConsumido = null;
      return KeyEventResult.handled;
    }
    if (evento is KeyUpEvent || evento.synthesized) {
      return KeyEventResult.ignored;
    }
    if (!_activa ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        evento is KeyRepeatEvent) {
      _limpiar();
      return KeyEventResult.ignored;
    }

    final foco = FocusManager.instance.primaryFocus;
    final editable =
        foco?.context?.findAncestorStateOfType<EditableTextState>();
    // El buscador puede recibir una lectura. Cantidades, notas y otros
    // formularios conservan el teclado normal.
    if (editable != null &&
        editable.context.findAncestorWidgetOfExactType<BusquedaConEscaner>() ==
            null) {
      _limpiar();
      return KeyEventResult.ignored;
    }

    if (_focoInicial != foco ||
        (_ultimaTecla != null &&
            evento.timeStamp - _ultimaTecla! > _intervalo)) {
      _limpiar();
    }
    // Enter o Tab: la que traiga el lector. Una pulsación suelta (sin
    // ráfaga antes) sigue siendo la tecla normal.
    if (EscanerFisicoService.esFinDeLectura(evento.logicalKey)) {
      final codigo =
          _descartar ? null : EscanerFisicoService.codigoDe(_entrada);
      // Un HID envía una ráfaga y un terminador. En el buscador, los códigos
      // cortos se reconocen si ya están registrados.
      final completa = (_entrada.isNotEmpty || _descartar) &&
          (_entrada.length >= 3 ||
              editable == null ||
              (codigo != null &&
                  widget.codigoRegistrado?.call(codigo) == true));
      if (!completa) {
        _limpiar();
        return KeyEventResult.ignored;
      }
      final buscador = _buscador;
      final busqueda = _busquedaInicial;
      _limpiar();
      _terminadorConsumido = evento.logicalKey;
      if (buscador != null && buscador.mounted && busqueda != null) {
        // Los caracteres pasaron al buscador mientras se reconocía la
        // ráfaga. Recuperar su búsqueda y notificar también al controlador.
        buscador.widget.controller.value = busqueda;
        buscador.widget.onChanged?.call(busqueda.text);
      }
      if (codigo == null) {
        // Incluso una lectura inválida consume el Enter: no debe activar por
        // accidente el botón de producto o cobro seleccionado.
        _estado.value = 'No se pudo leer el código. Vuelve a escanearlo.';
      } else {
        _cola.add(codigo);
        scheduleMicrotask(_procesar);
      }
      return KeyEventResult.handled;
    }

    final caracter = evento.character;
    if (caracter == ' ' && _entrada.isEmpty && editable == null) {
      return KeyEventResult.ignored;
    }
    if (caracter == null || caracter.isEmpty) {
      // Shift forma parte de los códigos con mayúsculas; no rompe la lectura.
      if (evento.logicalKey != LogicalKeyboardKey.shiftLeft &&
          evento.logicalKey != LogicalKeyboardKey.shiftRight) {
        _limpiar();
      }
      return KeyEventResult.ignored;
    }
    if (caracter.runes.any((c) => c < 32 || c == 127)) {
      _limpiar();
      return KeyEventResult.ignored;
    }
    if (_entrada.isEmpty) {
      _focoInicial = foco;
      _buscador = editable;
      _busquedaInicial = editable?.widget.controller.value;
    }
    if (_entrada.length + caracter.length > 512) _descartar = true;
    if (!_descartar) _entrada += caracter;
    _ultimaTecla = evento.timeStamp;
    _caducidad?.cancel();
    _caducidad = Timer(_intervalo, _limpiar);
    // Fuera de un campo, el código no activa atajos de los botones. En el
    // buscador la escritura normal sigue pasando hasta reconocer el lector.
    return editable == null ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  Future<void> _procesar() async {
    if (_procesando || !mounted) return;
    _procesando = true;
    try {
      while (_cola.isNotEmpty && _activa) {
        final codigo = _cola.removeAt(0);
        try {
          final aviso = await widget.alLeer(codigo);
          if (mounted) _estado.value = aviso ?? 'Leído: $codigo';
        } catch (e) {
          AppLogger.warning('EscanerAutomatico', 'No se pudo leer $codigo: $e');
          if (mounted) {
            _estado.value = 'No se pudo procesar $codigo. Vuelve a escanearlo.';
          }
        }
      }
      _cola.clear();
    } finally {
      _procesando = false;
    }
  }

  @override
  Widget build(BuildContext context) => _EstadoEscaner(
        estado: _estado,
        child: Focus(autofocus: true, skipTraversal: true, child: widget.child),
      );
}

/// Marca el buscador como campo compatible con lectura automática. No se
/// marca ningún campo de cobro, de stock o de edición de productos.
class BusquedaConEscaner extends StatelessWidget {
  const BusquedaConEscaner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _EstadoEscaner extends InheritedWidget {
  const _EstadoEscaner({required this.estado, required super.child});
  final ValueNotifier<String?> estado;
  @override
  bool updateShouldNotify(_EstadoEscaner anterior) => estado != anterior.estado;
}

const _mensajeInicial = 'Escanea un producto con tu lector';

class AvisoEscanerAutomatico extends StatelessWidget {
  const AvisoEscanerAutomatico({super.key, this.soloTrasLeer = false});

  /// En la tableta no todos tienen lector (también está la cámara): el
  /// aviso aparece hasta que llega la primera lectura.
  final bool soloTrasLeer;

  @override
  Widget build(BuildContext context) {
    final estado =
        context.dependOnInheritedWidgetOfExactType<_EstadoEscaner>()!;
    return ValueListenableBuilder<String?>(
      valueListenable: estado.estado,
      builder: (context, mensaje, _) => soloTrasLeer &&
              (mensaje == null || mensaje == _mensajeInicial)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                const Icon(Icons.barcode_reader, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        Text(mensaje ?? 'Escanea un producto con tu lector')),
              ]),
            ),
    );
  }
}

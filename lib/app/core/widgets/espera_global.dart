import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/app_logger.dart';
import '../utils/fallo_al_guardar.dart';
import '../utils/plataforma_app.dart';

/// Lo que se muestra cuando un guardado no se pudo hacer.
class FalloEnPantalla {
  const FalloEnPantalla({
    required this.titulo,
    required this.mensaje,
    required this.sinConexion,
    required this.puedeReintentar,
  });

  /// "No se pudo registrar la venta".
  final String titulo;
  final String mensaje;

  /// Para el icono: sin señal o un error cualquiera.
  final bool sinConexion;
  final bool puedeReintentar;
}

/// La espera de toda la app mientras se guarda algo en la base de datos
/// (una venta, un cliente, un abono…): un círculo de "procesando" al centro,
/// con lo que se está haciendo ("Registrando la venta…"), y un velo que no
/// deja tocar nada. Si falla, el velo pasa a una tarjeta con el motivo y
/// "Reintentar"; lo capturado sigue en pantalla.
///
/// Antes cada pantalla esperaba a su manera y con mala señal se quedaba
/// quieta sin decir nada, o decía "Error" y ya.
///
/// La dibuja [CapaDeEspera]. Sin ella (en las pruebas de un controlador)
/// [guardar] corre la tarea sin esperar de más y un fallo cuenta como
/// "Cerrar".
class EsperaGlobal with WidgetsBindingObserver {
  EsperaGlobal._();

  static final to = EsperaGlobal._();

  /// Lo mínimo que se ve el círculo: en un guardado rápido solo parpadeaba.
  static const minimo = Duration(milliseconds: 500);

  /// Con [guardar] `rapido`, cuánto se espera antes de mostrar el círculo:
  /// un +1 al stock que tarda menos ni lo enseña.
  static const antesDelCirculo = Duration(milliseconds: 400);

  final guardando = false.obs;

  /// Lo que dice el círculo ("Registrando la venta…"), o null mientras no
  /// se muestra.
  final aviso = RxnString();
  final fallo = Rxn<FalloEnPantalla>();

  bool get ocupado => guardando.value || fallo.value != null;

  int _capas = 0;
  Completer<bool>? _decision;
  bool _vigilando = false;

  /// Corre [tarea] con el círculo y el velo. Devuelve lo que devuelve [tarea],
  /// o null si falló y se eligió "Cerrar" (o si ya había otro guardado en
  /// curso: un segundo toque no manda otro).
  ///
  /// [queHace] completa el título del fallo: "registrar la venta" → "No se
  /// pudo registrar la venta". [generico] es el mensaje cuando no fue la
  /// conexión. [mensajeDe] traduce los errores propios de la pantalla ("esa
  /// tarjeta ya es de otro cliente"); esos no se reintentan, porque volver a
  /// mandar lo mismo daría lo mismo.
  ///
  /// [siQuedoEnDuda] es para lo que no se puede mandar dos veces (un cobro,
  /// un ajuste de stock): si se agotó el tiempo o la conexión se cortó a
  /// medias, pudo haber llegado. Entonces no se ofrece "Reintentar" y se
  /// muestra este texto. Si la petición ni siquiera salió, o la base
  /// respondió con un error, sí se reintenta.
  ///
  /// Con [rapido] el círculo solo sale si tarda ([antesDelCirculo]) y se
  /// quita en cuanto termina: para los botones que se tocan varias veces
  /// seguidas (+1 al stock). Mientras tanto, igual no se puede tocar nada.
  Future<T?> guardar<T>(
    Future<T> Function() tarea, {
    required String queHace,
    String generico = 'Ocurrió un problema al guardar. Intenta de nuevo.',
    String? Function(Object error)? mensajeDe,
    String? siQuedoEnDuda,
    bool rapido = false,
  }) async {
    if (ocupado) return null;
    final enPantalla = _capas > 0;
    guardando.value = true;
    final texto = enGerundio(queHace);
    Timer? demora;
    if (rapido) {
      demora = Timer(antesDelCirculo, () {
        if (guardando.value && fallo.value == null) aviso.value = texto;
      });
    } else {
      aviso.value = texto;
    }
    try {
      while (true) {
        // Corre a la par de la tarea: al terminar solo se espera lo que falte.
        final minimoCumplido =
            enPantalla ? Future<void>.delayed(minimo) : Future<void>.value();
        try {
          final resultado = await tarea().timeout(limiteAlGuardar);
          if (!rapido) await minimoCumplido;
          return resultado;
        } catch (e) {
          AppLogger.error('EsperaGlobal', 'No se pudo $queHace', e);
          if (!enPantalla || _capas == 0) return null;
          await minimoCumplido;

          final propio = mensajeDe?.call(e);
          // Solo queda en duda si no hubo respuesta: el tiempo se agotó o
          // la conexión se cortó ya enviada. Si la base contestó con un
          // error, no se guardó nada.
          final enDuda = siQuedoEnDuda != null &&
              propio == null &&
              (e is TimeoutException || (esFalloDeConexion(e) && !_noSalio(e)));
          final mensaje = propio ??
              (enDuda ? siQuedoEnDuda : mensajeDeFallo(e, generico: generico));
          fallo.value = FalloEnPantalla(
            titulo: 'No se pudo $queHace',
            mensaje: mensaje,
            sinConexion: esFalloDeConexion(e) || e is TimeoutException,
            puedeReintentar: propio == null && e is! GuardadoFallido && !enDuda,
          );
          final reintentar = await (_decision = Completer<bool>()).future;
          _decision = null;
          fallo.value = null;
          if (!reintentar) return null;
          aviso.value = texto;
        }
      }
    } finally {
      demora?.cancel();
      aviso.value = null;
      guardando.value = false;
    }
  }

  /// "registrar la venta" → "Registrando la venta…".
  @visibleForTesting
  static String enGerundio(String queHace) {
    final espacio = queHace.indexOf(' ');
    final verbo = espacio < 0 ? queHace : queHace.substring(0, espacio);
    final resto = espacio < 0 ? '' : queHace.substring(espacio);
    if (verbo.length < 3) return 'Guardando…';
    final raiz = verbo.substring(0, verbo.length - 2);
    final gerundio = verbo.endsWith('ar') ? '${raiz}ando' : '${raiz}iendo';
    return '${gerundio[0].toUpperCase()}${gerundio.substring(1)}$resto…';
  }

  /// "Reintentar" ([reintentar] true) o "Cerrar" en la tarjeta de fallo.
  void decidir({required bool reintentar}) => _decision?.complete(reintentar);

  /// La petición no llegó a salir del aparato (sin internet, sin red): se
  /// puede mandar otra vez sin miedo a que se guarde doble.
  static bool _noSalio(Object e) {
    final texto = e.toString().toLowerCase();
    return texto.contains('failed host lookup') ||
        texto.contains('network is unreachable') ||
        texto.contains('connection refused') ||
        texto.contains('no address associated');
  }

  /// Desde [main], antes de `runApp`: así este aviso de "atrás" llega antes
  /// que el de la app, que cerraría la pantalla a medio guardar.
  void vigilarRegreso() {
    if (_vigilando) return;
    _vigilando = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<bool> didPopRoute() async => ocupado;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => ocupado;

  @visibleForTesting
  void reiniciar() {
    _decision?.complete(false);
    _decision = null;
    fallo.value = null;
    aviso.value = null;
    guardando.value = false;
  }
}

/// Dibuja la espera de [EsperaGlobal] encima de [child] (todo el Navigator,
/// ventanas incluidas). Va en el `builder` de la app.
class CapaDeEspera extends StatefulWidget {
  const CapaDeEspera({super.key, required this.child});

  final Widget child;

  @override
  State<CapaDeEspera> createState() => _CapaDeEsperaState();
}

class _CapaDeEsperaState extends State<CapaDeEspera> {
  final _espera = EsperaGlobal.to;

  /// Un ámbito propio: con Tab el foco no se sale a lo que está debajo del
  /// velo.
  final _foco = FocusScopeNode(debugLabel: 'Espera');
  FocusNode? _focoAnterior;
  Worker? _alCambiar;

  @override
  void initState() {
    super.initState();
    _espera._capas++;
    // Solo en computadora: en el teléfono y la tableta, quitarle el foco al
    // campo cerraba el teclado y devolvérselo lo volvía a abrir.
    if (PlataformaApp.escritorio) {
      _alCambiar =
          everAll([_espera.guardando, _espera.fallo], (_) => _tomarTeclado());
    }
  }

  /// Mientras hay velo, el teclado es suyo: Escape no cierra la ventana de
  /// atrás ni Enter la confirma otra vez. Al terminar, el foco regresa a
  /// donde estaba.
  void _tomarTeclado() {
    if (_espera.ocupado) {
      if (_foco.hasFocus) return;
      _focoAnterior = FocusManager.instance.primaryFocus;
      _foco.requestFocus();
    } else if (_foco.hasFocus) {
      final anterior = _focoAnterior;
      _focoAnterior = null;
      if (anterior != null && anterior.context != null) {
        anterior.requestFocus();
      } else {
        _foco.unfocus();
      }
    }
  }

  KeyEventResult _tecla(FocusNode nodo, KeyEvent evento) {
    if (!_espera.ocupado) return KeyEventResult.ignored;
    final fallo = _espera.fallo.value;
    if (fallo != null && evento is! KeyUpEvent) {
      final tecla = evento.logicalKey;
      final esEnter = tecla == LogicalKeyboardKey.enter ||
          tecla == LogicalKeyboardKey.numpadEnter;
      if (tecla == LogicalKeyboardKey.escape) {
        _espera.decidir(reintentar: false);
        return KeyEventResult.handled;
      }
      // Sin botón enfocado, Enter hace lo principal de la tarjeta.
      if (esEnter && nodo.hasPrimaryFocus) {
        _espera.decidir(reintentar: fallo.puedeReintentar);
        return KeyEventResult.handled;
      }
      // Tab entre los botones, y Enter o espacio pulsan el enfocado.
      if (tecla == LogicalKeyboardKey.tab ||
          esEnter ||
          tecla == LogicalKeyboardKey.space) {
        return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _espera._capas--;
    _alCambiar?.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Obx(() {
          final ocupado = _espera.ocupado;
          final fallo = _espera.fallo.value;
          final aviso = _espera.aviso.value;
          return FocusScope(
            node: _foco,
            onKeyEvent: _tecla,
            child: IgnorePointer(
              ignoring: !ocupado,
              child: AnimatedOpacity(
                opacity: ocupado ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: ocupado
                    ? _Velo(fallo: fallo, aviso: aviso)
                    : const SizedBox.expand(),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Velo extends StatelessWidget {
  const _Velo({required this.fallo, required this.aviso});

  final FalloEnPantalla? fallo;
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // Sin nada que mostrar todavía (un +1 al stock), el velo es invisible
    // pero igual toma los toques.
    final visible = fallo != null || aviso != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // El velo toma los toques: lo de atrás se ve, pero no se toca.
        ModalBarrier(
          dismissible: false,
          color: visible ? c.backgroundColor.withValues(alpha: 0.7) : null,
        ),
        if (fallo != null)
          Center(child: _TarjetaDeFallo(fallo: fallo!))
        else if (aviso != null)
          Center(child: _Procesando(aviso!)),
      ],
    );
  }
}

/// El círculo de "procesando", en una tarjeta al centro.
class _Procesando extends StatelessWidget {
  const _Procesando(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      liveRegion: true,
      label: texto,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.borde),
              boxShadow: [
                BoxShadow(
                    color: c.sombra,
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      texto,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaDeFallo extends StatelessWidget {
  const _TarjetaDeFallo({required this.fallo});

  final FalloEnPantalla fallo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final espera = EsperaGlobal.to;
    final cerrar = TextButton(
      onPressed: () => espera.decidir(reintentar: false),
      style: TextButton.styleFrom(
        foregroundColor: c.textSecondary,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(fallo.puedeReintentar ? 'Cerrar' : 'Entendido'),
    );
    final reintentar = ElevatedButton.icon(
      autofocus: true,
      onPressed: () => espera.decidir(reintentar: true),
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: const Text('Reintentar'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: PlataformaApp.pantallaGrande ? 420 : 400),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borde),
            boxShadow: [
              BoxShadow(
                  color: c.sombra, blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          fallo.sinConexion
                              ? Icons.wifi_off_rounded
                              : Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fallo.titulo,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fallo.mensaje,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        cerrar,
                        if (fallo.puedeReintentar) reintentar,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

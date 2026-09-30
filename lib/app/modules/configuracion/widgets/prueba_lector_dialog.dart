import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/services/background_rfid_service.dart';
import '../../../data/services/rfid_reader_service.dart';

/// La prueba comparte las lecturas del lector, sin consultar membresías.
/// Conserva una pausa previa del servicio de avisos, si ya estaba pausado.
Future<void> abrirPruebaLector(BuildContext context) async {
  final fondo = Get.isRegistered<BackgroundRfidService>()
      ? Get.find<BackgroundRfidService>()
      : null;
  final reanudar =
      fondo != null && fondo.isScanning.value && !fondo.isPaused.value;
  if (reanudar) fondo.pauseScanning();
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PruebaLectorDialog(),
    );
  } finally {
    if (reanudar) fondo.resumeScanning();
  }
}

enum _EstadoPrueba { preparando, esperando, exito, fallo }

class PruebaLectorDialog extends StatefulWidget {
  const PruebaLectorDialog({
    super.key,
    this.leerLecturas = RfidReaderService.leerLecturas,
    this.leerTarjeta = RfidReaderService.checkForCardSilent,
  });

  final Future<({RespuestaLecturas? respuesta, bool sinSoporte})> Function(int)
      leerLecturas;
  final Future<String?> Function() leerTarjeta;

  @override
  State<PruebaLectorDialog> createState() => _PruebaLectorDialogState();
}

class _PruebaLectorDialogState extends State<PruebaLectorDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _seguimiento = SeguimientoPases();
  Timer? _consulta;
  Timer? _limite;
  var _intento = 0;
  var _fallosSeguidos = 0;
  var _usarLecturas = true;
  String? _ultimaTarjeta;
  String _error = '';
  _EstadoPrueba _estado = _EstadoPrueba.preparando;

  @override
  void initState() {
    super.initState();
    unawaited(_iniciar());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustarAnimacion();
  }

  bool _vigente(int intento) => mounted && intento == _intento;

  Future<void> _iniciar() async {
    final intento = ++_intento;
    _consulta?.cancel();
    _limite?.cancel();
    _seguimiento.reiniciar();
    _fallosSeguidos = 0;
    _ultimaTarjeta = null;
    _cambiarEstado(_EstadoPrueba.preparando);

    try {
      // La primera respuesta sirve de referencia: una tarjeta anterior no
      // puede confirmar una prueba que aún no había empezado.
      final inicial = await widget.leerLecturas(0);
      if (!_vigente(intento)) return;
      _usarLecturas = !inicial.sinSoporte;
      if (_usarLecturas) {
        if (inicial.respuesta == null) {
          _fallarConexion();
          return;
        }
        _seguimiento.nuevos(inicial.respuesta!);
      } else {
        _ultimaTarjeta = _tarjetaValida(await widget.leerTarjeta());
        if (!_vigente(intento)) return;
      }

      _cambiarEstado(_EstadoPrueba.esperando);
      _limite = Timer(const Duration(seconds: 30), () {
        if (!_vigente(intento)) return;
        _error = 'No detectamos una tarjeta. Retírala y vuelve a acercarla '
            'al lector. Revisa que el lector esté encendido.';
        _cambiarEstado(_EstadoPrueba.fallo);
      });
      _programarConsulta(intento);
    } catch (_) {
      if (_vigente(intento)) _fallarConexion();
    }
  }

  void _programarConsulta(int intento) {
    if (!_vigente(intento) || _estado != _EstadoPrueba.esperando) return;
    // Se programa después de cada respuesta: no se acumulan peticiones si
    // el WiFi está lento.
    _consulta = Timer(const Duration(milliseconds: 600), () {
      unawaited(_consultar(intento));
    });
  }

  Future<void> _consultar(int intento) async {
    try {
      var detectada = false;
      if (_usarLecturas) {
        final resultado = await widget.leerLecturas(_seguimiento.desde);
        if (!_vigente(intento) || _estado != _EstadoPrueba.esperando) return;
        if (resultado.respuesta == null) {
          _fallosSeguidos++;
          if (_fallosSeguidos >= 3) {
            _fallarConexion();
            return;
          }
        } else {
          _fallosSeguidos = 0;
          detectada = _seguimiento
              .nuevos(resultado.respuesta!)
              .any((p) => _tarjetaValida(p.uid) != null);
        }
      } else {
        final uid = _tarjetaValida(await widget.leerTarjeta());
        if (!_vigente(intento) || _estado != _EstadoPrueba.esperando) return;
        detectada = uid != null && uid != _ultimaTarjeta;
        _ultimaTarjeta = uid;
      }
      if (detectada) {
        _cambiarEstado(_EstadoPrueba.exito);
        return;
      }
    } catch (_) {
      if (!_vigente(intento) || _estado != _EstadoPrueba.esperando) return;
      _fallosSeguidos++;
      if (_fallosSeguidos >= 3) {
        _fallarConexion();
        return;
      }
    }
    _programarConsulta(intento);
  }

  String? _tarjetaValida(String? uid) {
    final tarjeta = uid?.trim();
    return tarjeta == null || tarjeta.isEmpty || tarjeta == 'NO_CARD'
        ? null
        : tarjeta;
  }

  void _fallarConexion() {
    _error = 'El lector no respondió. Revisa que esté encendido y que este '
        'teléfono esté conectado al mismo WiFi.';
    _cambiarEstado(_EstadoPrueba.fallo);
  }

  void _cambiarEstado(_EstadoPrueba estado) {
    if (!mounted) return;
    if (estado == _EstadoPrueba.exito || estado == _EstadoPrueba.fallo) {
      _consulta?.cancel();
      _limite?.cancel();
    }
    setState(() => _estado = estado);
    // En initState todavía no se pueden leer las preferencias de movimiento.
    if (estado != _EstadoPrueba.preparando) _ajustarAnimacion();
    if (estado == _EstadoPrueba.preparando) _animacion.stop();
  }

  void _ajustarAnimacion() {
    final quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_estado == _EstadoPrueba.esperando && !quieto) {
      if (!_animacion.isAnimating) _animacion.repeat(reverse: true);
    } else {
      _animacion.stop();
      _animacion.value = 0.5;
    }
  }

  @override
  void dispose() {
    _intento++;
    _consulta?.cancel();
    _limite?.cancel();
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final exito = _estado == _EstadoPrueba.exito;
    final fallo = _estado == _EstadoPrueba.fallo;
    final preparando = _estado == _EstadoPrueba.preparando;
    final titulo = switch (_estado) {
      _EstadoPrueba.preparando => 'Preparando la prueba…',
      _EstadoPrueba.esperando => 'Acerca la tarjeta al lector',
      _EstadoPrueba.exito => '¡Excelente!',
      _EstadoPrueba.fallo => 'Vamos a intentarlo de nuevo',
    };
    final detalle = switch (_estado) {
      _EstadoPrueba.preparando => 'Comprobando que el lector responda.',
      _EstadoPrueba.esperando =>
        'Usa cualquier tarjeta del gimnasio. Acércala al lector y espera '
            'la confirmación en esta pantalla.',
      _EstadoPrueba.exito =>
        'El lector leyó la tarjeta y responde bien. Ya está listo para usar.',
      _EstadoPrueba.fallo => _error,
    };

    return AlertDialog(
      backgroundColor: c.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: exito ? AppColors.success : c.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (preparando)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (exito || fallo)
                Icon(
                  exito ? Icons.check_circle : Icons.info_outline,
                  size: 100,
                  color: exito ? AppColors.success : AppColors.warning,
                )
              else
                _tarjetaYLector(context),
              const SizedBox(height: 20),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
              if (!preparando && !exito && !fallo) ...[
                const SizedBox(height: 12),
                Text(
                  'La prueba espera hasta 30 segundos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),
              if (fallo) ...[
                ElevatedButton.icon(
                  onPressed: _iniciar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Probar de nuevo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: exito ? AppColors.success : c.textPrimary,
                  minimumSize: const Size(0, 52),
                ),
                child: Text(exito ? 'Listo' : 'Cerrar prueba'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaYLector(BuildContext context) {
    final c = context.colores;
    return ExcludeSemantics(
      child: SizedBox(
        height: 190,
        child: AnimatedBuilder(
          animation: _animacion,
          builder: (context, _) => Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                bottom: 0,
                child: Container(
                  width: 144,
                  height: 84,
                  decoration: BoxDecoration(
                    color: c.containerBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const Icon(
                    Icons.contactless,
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, 12 + 72 * _animacion.value),
                child: Container(
                  width: 100,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

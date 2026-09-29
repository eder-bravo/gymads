import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/configuracion_controller.dart';

/// El lector dibujado, para ver de un vistazo cómo está sin leer párrafos:
/// conectado (luz verde que late y ondas de señal), sin vincular, de otro
/// gimnasio, sin aparecer (apagado) o sin agregar todavía (silueta punteada).
///
/// Solo anima cuando hay algo vivo que mostrar (conectado, sin vincular o
/// buscándolo); los demás estados quedan quietos.
class IlustracionLector extends StatefulWidget {
  const IlustracionLector({
    super.key,
    required this.estado,
    required this.titulo,
    this.comprobando = false,
  });

  final EstadoLector estado;

  /// El título corto del estado ("Lector conectado").
  final String titulo;

  /// Buscándolo en la red: ondas grises en lugar del resultado.
  final bool comprobando;

  @override
  State<IlustracionLector> createState() => _IlustracionLectorState();
}

class _IlustracionLectorState extends State<IlustracionLector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ciclo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool get _anima =>
      widget.comprobando ||
      widget.estado == EstadoLector.mio ||
      widget.estado == EstadoLector.libre;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustarCiclo();
  }

  @override
  void didUpdateWidget(IlustracionLector anterior) {
    super.didUpdateWidget(anterior);
    _ajustarCiclo();
  }

  void _ajustarCiclo() {
    final quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_anima && !quieto) {
      if (!_ciclo.isAnimating) _ciclo.repeat();
    } else {
      _ciclo.stop();
      _ciclo.value = 0.35;
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final comprobando = widget.comprobando;
    final estado = widget.estado;

    final color = comprobando
        ? c.textSecondary
        : switch (estado) {
            EstadoLector.mio => AppColors.success,
            EstadoLector.libre => AppColors.warning,
            EstadoLector.deOtroGimnasio => AppColors.error,
            EstadoLector.sinConexion => AppColors.error,
            EstadoLector.sinConfigurar => c.textSecondary,
          };

    final (IconData? insignia, Color colorInsignia) = comprobando
        ? (null, c.textSecondary)
        : switch (estado) {
            EstadoLector.mio => (Icons.check, AppColors.success),
            EstadoLector.libre => (Icons.lock_open, AppColors.warning),
            EstadoLector.deOtroGimnasio => (Icons.block, AppColors.error),
            EstadoLector.sinConexion => (Icons.wifi_off, AppColors.error),
            EstadoLector.sinConfigurar => (Icons.add, AppColors.accent),
          };

    final silueta = !comprobando && estado == EstadoLector.sinConfigurar;
    final atenuado = !comprobando &&
        (estado == EstadoLector.sinConexion ||
            estado == EstadoLector.deOtroGimnasio);

    return Column(
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _ciclo,
            builder: (context, _) => CustomPaint(
              painter: _PintorLector(
                t: _ciclo.value,
                color: color,
                ondas: comprobando ||
                    estado == EstadoLector.mio ||
                    estado == EstadoLector.libre,
                ondasBuscando: comprobando,
                silueta: silueta,
                atenuado: atenuado,
                led: comprobando
                    ? c.textSecondary
                    : switch (estado) {
                        EstadoLector.mio => AppColors.success,
                        EstadoLector.libre => AppColors.warning,
                        EstadoLector.sinConfigurar => null,
                        _ => AppColors.error,
                      },
                ledLate: _anima,
                caja: c.cardBackground,
                borde: c.borde,
                ventana: c.containerBackground,
                icono: c.textSecondary,
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const SizedBox(
                        width: _PintorLector.ancho, height: _PintorLector.alto),
                    if (insignia != null)
                      Positioned(
                        right: -12,
                        top: -12,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (hijo, a) =>
                              ScaleTransition(scale: a, child: hijo),
                          child: Container(
                            key: ValueKey(insignia),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorInsignia,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: c.backgroundColor, width: 3),
                            ),
                            child:
                                Icon(insignia, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            comprobando ? 'Buscando tu lector…' : widget.titulo,
            key: ValueKey(comprobando ? '' : widget.titulo),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: comprobando || silueta ? c.textPrimary : color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// El aparato (caja con su ventana de lectura y su luz) y las ondas de señal.
class _PintorLector extends CustomPainter {
  _PintorLector({
    required this.t,
    required this.color,
    required this.ondas,
    required this.ondasBuscando,
    required this.silueta,
    required this.atenuado,
    required this.led,
    required this.ledLate,
    required this.caja,
    required this.borde,
    required this.ventana,
    required this.icono,
  });

  static const ancho = 150.0;
  static const alto = 110.0;

  final double t;
  final Color color;
  final bool ondas;
  final bool ondasBuscando;
  final bool silueta;
  final bool atenuado;
  final Color? led;
  final bool ledLate;
  final Color caja;
  final Color borde;
  final Color ventana;
  final Color icono;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final rect = Rect.fromCenter(center: centro, width: ancho, height: alto);
    final opacidad = atenuado ? 0.45 : 1.0;
    // Las ondas no se salen de su espacio (tapaban el título).
    canvas.clipRect(Offset.zero & size);

    // Ondas de señal: arcos a los lados que salen del lector.
    if (ondas) {
      for (var i = 0; i < 3; i++) {
        final fase = (t + i / 3) % 1.0;
        final radio = ancho / 2 + 10 + fase * 38;
        final pintura = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color.withOpacity((1 - fase) * 0.55);
        final circulo = Rect.fromCircle(center: centro, radius: radio);
        final giro = ondasBuscando ? t * 2 * math.pi : 0.0;
        canvas.drawArc(circulo, -0.5 + giro, 1.0, false, pintura);
        canvas.drawArc(circulo, math.pi - 0.5 + giro, 1.0, false, pintura);
      }
    }

    final forma = RRect.fromRectAndRadius(rect, const Radius.circular(22));

    if (silueta) {
      // Todavía no hay lector: su contorno punteado.
      final pintura = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = icono.withOpacity(0.55);
      final camino = Path()..addRRect(forma);
      for (final m in camino.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 14) {
          canvas.drawPath(m.extractPath(d, d + 7), pintura);
        }
      }
      _dibujarIconoNfc(canvas, centro, icono.withOpacity(0.45));
      return;
    }

    // Sombra y cuerpo.
    canvas.drawRRect(
      forma.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withOpacity(0.12 * opacidad)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(forma, Paint()..color = caja.withOpacity(opacidad));
    canvas.drawRRect(
      forma,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withOpacity(0.75 * opacidad),
    );

    // Ventana de lectura, donde se apoya la tarjeta.
    final zona = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: centro.translate(0, -6), width: ancho - 44, height: 58),
      const Radius.circular(12),
    );
    canvas.drawRRect(zona, Paint()..color = ventana.withOpacity(opacidad));
    _dibujarIconoNfc(
        canvas, centro.translate(0, -6), color.withOpacity(0.9 * opacidad));

    // La luz, abajo a la derecha.
    final luz = led;
    if (luz != null) {
      final pulso =
          ledLate ? 0.55 + 0.45 * math.sin(t * 2 * math.pi).abs() : 1.0;
      final p = Offset(rect.right - 22, rect.bottom - 16);
      canvas.drawCircle(
        p,
        10,
        Paint()
          ..color = luz.withOpacity(0.25 * pulso * opacidad)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
          p, 5, Paint()..color = luz.withOpacity(pulso * opacidad));
    }
  }

  /// El símbolo de "sin contacto": un punto y tres arcos.
  void _dibujarIconoNfc(Canvas canvas, Offset c, Color col) {
    final pintura = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = col;
    final base = c.translate(-12, 0);
    canvas.drawCircle(base, 3.5, Paint()..color = col);
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(Rect.fromCircle(center: base, radius: 8.0 * i + 2), -0.8,
          1.6, false, pintura);
    }
  }

  @override
  bool shouldRepaint(_PintorLector o) =>
      o.t != t ||
      o.color != color ||
      o.ondas != ondas ||
      o.ondasBuscando != ondasBuscando ||
      o.silueta != silueta ||
      o.atenuado != atenuado ||
      o.led != led ||
      o.ledLate != ledLate ||
      o.caja != caja ||
      o.borde != borde ||
      o.ventana != ventana ||
      o.icono != icono;
}

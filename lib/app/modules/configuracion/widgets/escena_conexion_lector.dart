import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/agregar_lector_controller.dart';

/// Lo que se ve del proceso de agregar el lector: del Bluetooth al WiFi.
enum EtapaConexion {
  /// El teléfono busca el lector por Bluetooth.
  buscando,

  /// Lo encontró y se está conectando a él.
  conectandoBluetooth,

  /// Teléfono y lector conectados; la persona elige el WiFi.
  eligiendoWifi,

  /// El lector prueba el WiFi (con el Bluetooth en pausa).
  conectandoWifi,

  /// El lector ya entró al WiFi; el teléfono lo busca en la red.
  comprobando,

  listo,
  falloBluetooth,
  falloWifi,
}

/// La etapa de la escena para cada paso del asistente. En un fallo,
/// [pasoAntesDelFallo] dice si se cayó el Bluetooth o el WiFi.
EtapaConexion etapaDe(PasoAgregar paso, PasoAgregar? pasoAntesDelFallo) {
  switch (paso) {
    case PasoAgregar.buscando:
      return EtapaConexion.buscando;
    case PasoAgregar.preparando:
      return EtapaConexion.conectandoBluetooth;
    case PasoAgregar.elegirRed:
    case PasoAgregar.escribirClave:
      return EtapaConexion.eligiendoWifi;
    case PasoAgregar.conectando:
      return EtapaConexion.conectandoWifi;
    case PasoAgregar.comprobando:
      return EtapaConexion.comprobando;
    case PasoAgregar.listo:
      return EtapaConexion.listo;
    case PasoAgregar.fallo:
      const pasosDelWifi = {
        PasoAgregar.elegirRed,
        PasoAgregar.escribirClave,
        PasoAgregar.conectando,
        PasoAgregar.comprobando,
      };
      return pasosDelWifi.contains(pasoAntesDelFallo)
          ? EtapaConexion.falloWifi
          : EtapaConexion.falloBluetooth;
  }
}

/// Las etapas en las que se está esperando algo: solo en ellas hay
/// movimiento. Mientras la persona elige la red o escribe la contraseña, y al
/// terminar, la escena queda quieta.
bool etapaEnMovimiento(EtapaConexion etapa) => const {
      EtapaConexion.buscando,
      EtapaConexion.conectandoBluetooth,
      EtapaConexion.conectandoWifi,
      EtapaConexion.comprobando,
    }.contains(etapa);

// ─────────────────────────────────────────────────────────
// Escena: teléfono → lector → WiFi
// ─────────────────────────────────────────────────────────

enum _Enlace {
  apagado,
  fluyendo,
  fluyendoDeVuelta,
  fijo,
  pausado,
  hecho,
  fallo
}

enum _Nodo { tenue, activo, hecho, fallo }

/// Teléfono, lector y WiFi, unidos por dos enlaces. Por el enlace activo
/// viajan puntos; mientras se busca, salen ondas del teléfono.
class EscenaConexion extends StatefulWidget {
  const EscenaConexion({super.key, required this.etapa, this.alto = 120});

  final EtapaConexion etapa;
  final double alto;

  @override
  State<EscenaConexion> createState() => _EscenaConexionState();
}

class _EscenaConexionState extends State<EscenaConexion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ciclo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustarCiclo();
  }

  @override
  void didUpdateWidget(EscenaConexion anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.etapa != widget.etapa) _ajustarCiclo();
  }

  /// Solo se mueve si hay algo que esperar y el teléfono no pidió reducir el
  /// movimiento.
  void _ajustarCiclo() {
    final mover = etapaEnMovimiento(widget.etapa) &&
        !MediaQuery.of(context).disableAnimations;
    if (mover && !_ciclo.isAnimating) {
      _ciclo.repeat();
    } else if (!mover && _ciclo.isAnimating) {
      _ciclo.stop();
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  (_Nodo, _Nodo, _Nodo, _Enlace, _Enlace) get _estado => switch (widget.etapa) {
        EtapaConexion.buscando => (
            _Nodo.activo,
            _Nodo.tenue,
            _Nodo.tenue,
            _Enlace.apagado,
            _Enlace.apagado
          ),
        EtapaConexion.conectandoBluetooth => (
            _Nodo.activo,
            _Nodo.activo,
            _Nodo.tenue,
            _Enlace.fluyendo,
            _Enlace.apagado
          ),
        EtapaConexion.eligiendoWifi => (
            _Nodo.hecho,
            _Nodo.activo,
            _Nodo.tenue,
            _Enlace.fijo,
            _Enlace.apagado
          ),
        EtapaConexion.conectandoWifi => (
            _Nodo.hecho,
            _Nodo.activo,
            _Nodo.activo,
            _Enlace.pausado,
            _Enlace.fluyendo
          ),
        EtapaConexion.comprobando => (
            _Nodo.activo,
            _Nodo.hecho,
            _Nodo.hecho,
            _Enlace.fluyendoDeVuelta,
            _Enlace.hecho
          ),
        EtapaConexion.listo => (
            _Nodo.hecho,
            _Nodo.hecho,
            _Nodo.hecho,
            _Enlace.hecho,
            _Enlace.hecho
          ),
        EtapaConexion.falloBluetooth => (
            _Nodo.activo,
            _Nodo.fallo,
            _Nodo.tenue,
            _Enlace.fallo,
            _Enlace.apagado
          ),
        EtapaConexion.falloWifi => (
            _Nodo.hecho,
            _Nodo.activo,
            _Nodo.fallo,
            _Enlace.pausado,
            _Enlace.fallo
          ),
      };

  static String _descripcion(EtapaConexion etapa) => switch (etapa) {
        EtapaConexion.buscando => 'Buscando el lector por Bluetooth',
        EtapaConexion.conectandoBluetooth =>
          'Conectando el ${PlataformaApp.equipo} con el lector',
        EtapaConexion.eligiendoWifi => PlataformaApp.escritorio
            ? 'Equipo y lector conectados'
            : 'Teléfono y lector conectados',
        EtapaConexion.conectandoWifi => 'El lector se conecta al WiFi',
        EtapaConexion.comprobando => 'Buscando el lector en el WiFi',
        EtapaConexion.listo => 'Lector listo',
        EtapaConexion.falloBluetooth => 'No se pudo conectar con el lector',
        EtapaConexion.falloWifi => 'El lector no pudo conectarse al WiFi',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final (telefono, lector, wifi, enlace1, enlace2) = _estado;

    Color colorNodo(_Nodo n) => switch (n) {
          _Nodo.tenue => c.textSecondary.withOpacity(0.35),
          _Nodo.activo => AppColors.accent,
          _Nodo.hecho => AppColors.success,
          _Nodo.fallo => AppColors.error,
        };

    return Semantics(
      label: _descripcion(widget.etapa),
      child: SizedBox(
        height: widget.alto,
        child: LayoutBuilder(builder: (context, espacio) {
          final ancho = espacio.maxWidth;
          final diametro = math.min(56.0, widget.alto * 0.48);
          final centros = [0.16, 0.5, 0.84]
              .map((x) => Offset(ancho * x, widget.alto / 2))
              .toList();

          Widget nodo(int i, IconData icono, _Nodo estado) {
            final color = colorNodo(estado);
            return Positioned(
              left: centros[i].dx - diametro / 2,
              top: centros[i].dy - diametro / 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: diametro,
                height: diametro,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.12),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icono, color: color, size: diametro * 0.46),
              ),
            );
          }

          // La marca de "listo" o de fallo sobre el enlace o el lector.
          Widget? marca;
          if (widget.etapa == EtapaConexion.listo) {
            marca = _Insignia(
              centro: centros[1] + Offset(diametro * 0.36, -diametro * 0.36),
              color: AppColors.success,
              icono: Icons.check,
            );
          } else if (widget.etapa == EtapaConexion.falloBluetooth ||
              widget.etapa == EtapaConexion.falloWifi) {
            final i = widget.etapa == EtapaConexion.falloBluetooth ? 0 : 1;
            marca = _Insignia(
              centro: Offset.lerp(centros[i], centros[i + 1], 0.5)!,
              color: AppColors.error,
              icono: Icons.close,
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ciclo,
                  builder: (context, _) => CustomPaint(
                    painter: _PintorEnlaces(
                      t: _ciclo.value,
                      centros: centros,
                      radio: diametro / 2,
                      enlaces: [enlace1, enlace2],
                      ondas: widget.etapa == EtapaConexion.buscando,
                      tenue: c.textSecondary.withOpacity(0.25),
                    ),
                  ),
                ),
              ),
              // El aparato que configura: la computadora en escritorio.
              nodo(
                  0,
                  PlataformaApp.escritorio ? Icons.computer : Icons.smartphone,
                  telefono),
              nodo(1, Icons.nfc, lector),
              nodo(2, Icons.router_outlined, wifi),
              if (marca != null) marca,
            ],
          );
        }),
      ),
    );
  }
}

/// Un círculo pequeño con palomita o X, que aparece con un rebote.
class _Insignia extends StatelessWidget {
  const _Insignia({
    required this.centro,
    required this.color,
    required this.icono,
  });

  final Offset centro;
  final Color color;
  final IconData icono;

  static const _tamano = 24.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: centro.dx - _tamano / 2,
      top: centro.dy - _tamano / 2,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, escala, hijo) =>
            Transform.scale(scale: escala, child: hijo),
        child: Container(
          width: _tamano,
          height: _tamano,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border:
                Border.all(color: context.colores.backgroundColor, width: 2),
          ),
          child: Icon(icono, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _PintorEnlaces extends CustomPainter {
  _PintorEnlaces({
    required this.t,
    required this.centros,
    required this.radio,
    required this.enlaces,
    required this.ondas,
    required this.tenue,
  });

  /// Avance del ciclo, de 0 a 1.
  final double t;
  final List<Offset> centros;
  final double radio;
  final List<_Enlace> enlaces;
  final bool ondas;
  final Color tenue;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < enlaces.length; i++) {
      // De borde a borde de los círculos, no de centro a centro.
      final direccion = (centros[i + 1] - centros[i]);
      final unidad = direccion / direccion.distance;
      _enlace(canvas, centros[i] + unidad * (radio + 4),
          centros[i + 1] - unidad * (radio + 4), enlaces[i]);
    }
    if (ondas) _ondas(canvas, centros[0]);
  }

  void _enlace(Canvas canvas, Offset a, Offset b, _Enlace estado) {
    final color = switch (estado) {
      _Enlace.apagado || _Enlace.pausado => tenue,
      _Enlace.fluyendo ||
      _Enlace.fluyendoDeVuelta ||
      _Enlace.fijo =>
        AppColors.accent,
      _Enlace.hecho => AppColors.success,
      _Enlace.fallo => AppColors.error,
    };
    final linea = Paint()
      ..color = estado == _Enlace.fluyendo || estado == _Enlace.fluyendoDeVuelta
          ? color.withOpacity(0.25)
          : color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    if (estado == _Enlace.apagado ||
        estado == _Enlace.pausado ||
        estado == _Enlace.fallo) {
      _punteada(canvas, a, b, linea);
    } else {
      canvas.drawLine(a, b, linea);
    }

    if (estado == _Enlace.fluyendo || estado == _Enlace.fluyendoDeVuelta) {
      final punto = Paint()..color = color;
      const cuantos = 3;
      for (var k = 0; k < cuantos; k++) {
        var avance = (t + k / cuantos) % 1;
        if (estado == _Enlace.fluyendoDeVuelta) avance = 1 - avance;
        // Aparecen y se desvanecen en las puntas.
        final opacidad = math.sin(avance * math.pi).clamp(0.0, 1.0);
        punto.color = color.withOpacity(opacidad);
        canvas.drawCircle(Offset.lerp(a, b, avance)!, 4, punto);
      }
    }
  }

  void _punteada(Canvas canvas, Offset a, Offset b, Paint pintura) {
    const trazo = 6.0, hueco = 5.0;
    final largo = (b - a).distance;
    final unidad = (b - a) / largo;
    for (var d = 0.0; d < largo; d += trazo + hueco) {
      canvas.drawLine(
          a + unidad * d, a + unidad * math.min(d + trazo, largo), pintura);
    }
  }

  /// Ondas de Bluetooth que salen del teléfono.
  void _ondas(Canvas canvas, Offset centro) {
    const cuantas = 3;
    for (var k = 0; k < cuantas; k++) {
      final avance = (t + k / cuantas) % 1;
      final pintura = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withOpacity((1 - avance) * 0.6);
      canvas.drawCircle(centro, radio + 4 + avance * radio * 1.1, pintura);
    }
  }

  @override
  bool shouldRepaint(_PintorEnlaces anterior) =>
      anterior.t != t ||
      anterior.ondas != ondas ||
      anterior.tenue != tenue ||
      anterior.radio != radio ||
      anterior.enlaces[0] != enlaces[0] ||
      anterior.enlaces[1] != enlaces[1] ||
      anterior.centros[1] != centros[1];
}

// ─────────────────────────────────────────────────────────
// Pasos: Bluetooth · WiFi · Listo
// ─────────────────────────────────────────────────────────

enum EstadoPaso { pendiente, enCurso, hecho, fallo }

/// Cómo va cada uno de los tres pasos en [etapa].
List<EstadoPaso> estadosDePasos(EtapaConexion etapa) {
  const p = EstadoPaso.pendiente,
      c = EstadoPaso.enCurso,
      h = EstadoPaso.hecho,
      f = EstadoPaso.fallo;
  return switch (etapa) {
    EtapaConexion.buscando || EtapaConexion.conectandoBluetooth => [c, p, p],
    EtapaConexion.eligiendoWifi ||
    EtapaConexion.conectandoWifi ||
    EtapaConexion.comprobando =>
      [h, c, p],
    EtapaConexion.listo => [h, h, h],
    EtapaConexion.falloBluetooth => [f, p, p],
    EtapaConexion.falloWifi => [h, f, p],
  };
}

/// Los tres pasos en fila, con su palomita al completarse.
class PasosConexion extends StatelessWidget {
  const PasosConexion({super.key, required this.etapa});

  final EtapaConexion etapa;

  static const nombres = ['Bluetooth', 'WiFi', 'Listo'];

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estados = estadosDePasos(etapa);
    return Row(
      children: [
        for (var i = 0; i < nombres.length; i++) ...[
          if (i > 0)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: estados[i - 1] == EstadoPaso.hecho
                    ? AppColors.success
                    : c.divisor,
              ),
            ),
          _Paso(nombre: nombres[i], estado: estados[i]),
        ],
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.nombre, required this.estado});

  final String nombre;
  final EstadoPaso estado;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = switch (estado) {
      EstadoPaso.pendiente => c.textSecondary.withOpacity(0.5),
      EstadoPaso.enCurso => AppColors.accent,
      EstadoPaso.hecho => AppColors.success,
      EstadoPaso.fallo => AppColors.error,
    };
    final relleno = estado == EstadoPaso.hecho || estado == EstadoPaso.fallo;

    return Semantics(
      label: '$nombre: ${switch (estado) {
        EstadoPaso.pendiente => 'pendiente',
        EstadoPaso.enCurso => 'en curso',
        EstadoPaso.hecho => 'hecho',
        EstadoPaso.fallo => 'no se pudo',
      }}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // La clave por estado hace que la palomita (o la X) aparezca con
          // su rebote cada vez que el paso cambia.
          TweenAnimationBuilder<double>(
            key: ValueKey(estado),
            tween: Tween(begin: relleno ? 0.4 : 1, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (context, escala, hijo) =>
                Transform.scale(scale: escala, child: hijo),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: relleno ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: switch (estado) {
                EstadoPaso.hecho =>
                  const Icon(Icons.check, size: 14, color: Colors.white),
                EstadoPaso.fallo =>
                  const Icon(Icons.close, size: 14, color: Colors.white),
                EstadoPaso.enCurso => Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                EstadoPaso.pendiente => null,
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nombre,
            style: TextStyle(
              color: estado == EstadoPaso.pendiente ? c.textSecondary : color,
              fontSize: PlataformaApp.escritorio ? 14 : 12,
              fontWeight: estado == EstadoPaso.enCurso
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

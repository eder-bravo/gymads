import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/plataforma_app.dart';
import '../../../core/widgets/formulario.dart';
import '../../../data/services/fotos_de_clientes.dart';
import '../../../data/services/storage_service.dart';

/// El aviso al pasar la tarjeta: la foto del cliente a pantalla completa y
/// dos franjas, arriba qué pasó (¡Bienvenido!, Membresía vencida…) y abajo
/// quién es, cuántos días le quedan y, en el mostrador, qué hacer.
///
/// La foto se ve entera entre las franjas (la cara nunca se recorta, aunque
/// sea vertical en una pantalla acostada) y los lados se llenan con la misma
/// foto difuminada.
class WelcomeScreenWidget extends StatelessWidget {
  final String userName;
  final String userPhotoUrl;
  final int daysLeft;
  final DateTime? expirationDate;
  final bool isVisible;
  final bool isExpired;
  final bool isNotFound;

  /// Despide en vez de saludar. Solo llega en true si el gimnasio tiene el
  /// registro de salidas activado.
  final bool isSalida;
  final VoidCallback? onClose;
  final VoidCallback? onAbonar;
  final VoidCallback? onEditar;
  final VoidCallback? onRegister; // Para cuando no se encuentra tarjeta

  /// La foto ya lista, en lugar de buscarla con [userPhotoUrl]. La usa la
  /// pantalla para clientes, que corre en otra ventana sin Supabase: recibe
  /// el enlace ya firmado.
  final ImageProvider? foto;

  /// En la pantalla para clientes (monitor extra): solo información, dicha
  /// al cliente ("Tu membresía venció el…", "Pasa al mostrador…").
  final bool paraClientes;

  const WelcomeScreenWidget({
    super.key,
    required this.userName,
    required this.userPhotoUrl,
    required this.daysLeft,
    this.expirationDate,
    required this.isVisible,
    this.isExpired = false,
    this.isNotFound = false,
    this.isSalida = false,
    this.onClose,
    this.onAbonar,
    this.onEditar,
    this.onRegister,
    this.foto,
    this.paraClientes = false,
  });

  bool get _rechazo => isNotFound || isExpired;

  String get _titulo => isNotFound
      ? PlataformaApp.elegir(
          escritorio: 'Tarjeta no registrada', movil: 'Tarjeta No Registrada')
      : isExpired
          ? PlataformaApp.elegir(
              escritorio: 'Membresía vencida', movil: 'Membresía Vencida')
          : isSalida
              ? '¡Hasta pronto!'
              : '¡Bienvenido!';

  IconData get _iconoTitulo => isNotFound
      ? Icons.contactless_outlined
      : isExpired
          ? Icons.error_outline
          : isSalida
              ? Icons.logout
              : Icons.check_circle_outline;

  String get _mensaje => isNotFound
      ? (paraClientes
          ? 'Pasa al mostrador para registrar tu tarjeta'
          : 'Acude a recepción para registrar tu acceso')
      : isExpired
          ? (paraClientes
              ? 'Pasa al mostrador para renovarla'
              : '¡Por favor pasa a recepción!')
          : isSalida
              ? '¡Gracias por venir!'
              : '¡Que tengas un excelente entrenamiento!';

  /// "Hasta qué fecha puede entrar" o, vencida, cuándo venció.
  String? get _fecha {
    final vence = expirationDate;
    if (vence == null) return null;
    final fecha = DateFormat('dd/MM/yyyy').format(vence);
    if (!isExpired) return 'Hasta qué fecha puede entrar: $fecha';
    return paraClientes ? 'Tu membresía venció el $fecha' : 'Venció el $fecha';
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    final c = context.colores;
    final medidas = _Medidas.de(context);
    final colorEstado = _rechazo ? AppColors.error : AppColors.accent;

    // Con estilo de texto propio: en Inicio el aviso va encima de todo,
    // fuera del Scaffold, y sin esto Flutter subraya cada texto en amarillo.
    final contenido = Material(
      type: MaterialType.transparency,
      // Fondo sólido: se transparentaba Inicio por detrás.
      child: Container(
        color: c.backgroundColor,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => _FotoDelCliente(
            nombre: userName,
            guardada: userPhotoUrl,
            lista: foto,
            noRegistrada: isNotFound,
            builder: (fondo, centro) => Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: t, child: fondo),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FractionalTranslation(
                      translation: Offset(0, t - 1),
                      child: _franjaDeArriba(colorEstado, medidas),
                    ),
                    // La foto entera, en el hueco que dejan las franjas:
                    // nunca queda debajo de una.
                    Expanded(
                      child: Opacity(
                        opacity: t,
                        child: Padding(
                          padding: EdgeInsets.all(medidas.bajo ? 8 : 16),
                          child: centro,
                        ),
                      ),
                    ),
                    FractionalTranslation(
                      translation: Offset(0, 1 - t),
                      child: _franjaDeAbajo(context, medidas),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Sin [onClose] (la pantalla de check-in lo controla por su cuenta) se
    // muestra tal cual.
    final cerrar = onClose;
    if (cerrar == null) return contenido;

    // Se quita al momento, pero solo con la X: un toque en otro lado (al
    // acomodar el teléfono, o el cliente que se asoma) no debe cerrarlo. Se
    // cierra solo pasados unos segundos. Va sobre la franja de color, así
    // que es blanca en los dos modos.
    return Stack(
      children: [
        Positioned.fill(child: contenido),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(medidas.bajo ? 6 : 12),
              child: IconButton(
                onPressed: cerrar,
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close, size: 28),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.18),
                  side: BorderSide(color: Colors.white.withOpacity(0.4)),
                  minimumSize: const Size(52, 52),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _franjaDeArriba(Color color, _Medidas m) {
    return Material(
      color: color,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          // A los lados deja lugar a la X: el título va centrado.
          padding:
              EdgeInsets.fromLTRB(76, m.rellenoFranja, 76, m.rellenoFranja),
          // En un renglón: si no cabe junto a la X, se encoge un poco en vez
          // de partirse en dos y comerle lugar a la foto.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconoTitulo, color: Colors.white, size: m.titulo * 0.9),
                SizedBox(width: m.titulo * 0.3),
                Text(
                  _titulo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: m.titulo,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _franjaDeAbajo(BuildContext context, _Medidas m) {
    final c = context.colores;
    final fecha = _fecha;
    final botones = <Widget>[
      if (isNotFound && onRegister != null)
        BotonGuardar(
          texto: 'Registrar',
          icono: Icons.person_add,
          compacto: true,
          onPressed: onRegister,
        ),
      if (!isNotFound && onEditar != null)
        OutlinedButton.icon(
          onPressed: onEditar,
          icon: const Icon(Icons.edit, size: 20),
          label: const Text('Editar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textPrimary,
            side: BorderSide(color: c.borde),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      if (!isNotFound && onAbonar != null)
        BotonGuardar(
          texto: 'Abonar',
          icono: Icons.payment,
          compacto: true,
          onPressed: onAbonar,
        ),
    ];
    return Material(
      color: c.cardBackground,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, m.rellenoFranja * 1.2, 24, m.rellenoFranja * 1.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isNotFound) ...[
                Text(
                  userName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: m.nombre,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: m.bajo ? 4 : 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available,
                            size: m.dato * 1.15,
                            color:
                                isExpired ? AppColors.error : c.textSecondary),
                        const SizedBox(width: 6),
                        // Con letra grande en un teléfono angosto se parte
                        // en dos renglones en vez de salirse.
                        Flexible(
                          child: Text(
                            isExpired
                                ? '0 días restantes'
                                : '$daysLeft días restantes',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  isExpired ? AppColors.error : c.textPrimary,
                              fontSize: m.dato,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (fecha != null)
                      Text(
                        fecha,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: m.dato * 0.9,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: m.bajo ? 4 : 10),
              ],
              Text(
                _mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: isNotFound ? m.dato : m.dato * 0.85,
                  fontWeight: isNotFound ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (botones.isNotEmpty) ...[
                SizedBox(height: m.bajo ? 8 : 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: botones,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tamaños del aviso según la pantalla.
class _Medidas {
  const _Medidas({
    required this.titulo,
    required this.nombre,
    required this.dato,
    required this.rellenoFranja,
    required this.bajo,
  });

  final double titulo;
  final double nombre;
  final double dato;
  final double rellenoFranja;

  /// Teléfono de lado: muy poca altura, todo más compacto para que la foto
  /// conserve lugar.
  final bool bajo;

  factory _Medidas.de(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    if (tamano.height < 500) {
      return const _Medidas(
          titulo: 24, nombre: 22, dato: 15, rellenoFranja: 8, bajo: true);
    }
    if (tamano.shortestSide >= 600 || PlataformaApp.pantallaGrande) {
      return const _Medidas(
          titulo: 46, nombre: 40, dato: 22, rellenoFranja: 22, bajo: false);
    }
    if (tamano.shortestSide < 360) {
      return const _Medidas(
          titulo: 26, nombre: 24, dato: 16, rellenoFranja: 14, bajo: false);
    }
    return const _Medidas(
        titulo: 32, nombre: 28, dato: 18, rellenoFranja: 16, bajo: false);
  }
}

/// La foto a pantalla completa: [builder] recibe el fondo (difuminada, de
/// orilla a orilla) y el centro (entera). Sin foto, las iniciales; con una
/// tarjeta no registrada, el ícono.
class _FotoDelCliente extends StatefulWidget {
  const _FotoDelCliente({
    required this.nombre,
    required this.guardada,
    required this.lista,
    required this.noRegistrada,
    required this.builder,
  });

  final String nombre;

  /// La ruta guardada en Storage ('' sin foto).
  final String guardada;

  /// La foto ya resuelta (pantalla para clientes).
  final ImageProvider? lista;

  final bool noRegistrada;

  final Widget Function(Widget fondo, Widget centro) builder;

  @override
  State<_FotoDelCliente> createState() => _FotoDelClienteState();
}

class _FotoDelClienteState extends State<_FotoDelCliente> {
  ImageProvider? _foto;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  @override
  void didUpdateWidget(_FotoDelCliente anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.guardada != widget.guardada ||
        anterior.lista != widget.lista) {
      _fallo = false;
      _resolver();
    }
  }

  /// Ya descargada (la deja lista `prepararParaMostrar` antes del aviso): al
  /// instante y en alta resolución. Si no, con su enlace firmado.
  Future<void> _resolver() async {
    _foto = widget.lista;
    final guardada = widget.guardada;
    if (_foto != null || widget.noRegistrada || guardada.isEmpty) return;
    final archivo = FotosDeClientes.to?.archivo(guardada);
    if (archivo != null) {
      _foto = FotosDeClientes.proveedorGrande(archivo);
      return;
    }
    try {
      final url = await StorageService.instance.signedUrl(guardada);
      if (!mounted || url == null || widget.guardada != guardada) return;
      setState(() => _foto = CachedNetworkImageProvider(url,
          cacheKey: StorageService.instance.stableKey(guardada) ?? url));
    } catch (_) {
      if (mounted) setState(() => _fallo = true);
    }
  }

  void _alFallar() {
    if (_fallo) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _fallo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    if (widget.noRegistrada) {
      return _sustituto(
        AppColors.error,
        (lado) => Icon(Icons.contactless_outlined,
            size: lado * 0.5, color: Colors.white),
      );
    }
    if (foto == null || _fallo) {
      return _sustituto(
        AppColors.accent,
        (lado) => Text(
          _iniciales(widget.nombre),
          style: TextStyle(
            color: Colors.white,
            fontSize: lado * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return widget.builder(
      Stack(
        fit: StackFit.expand,
        children: [
          // Sin clamp las orillas se difuminan contra lo transparente y
          // quedan oscuras.
          ImageFiltered(
            imageFilter: ImageFilter.blur(
                sigmaX: 30, sigmaY: 30, tileMode: TileMode.clamp),
            child: Image(
              image: foto,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, _, __) => const SizedBox.shrink(),
            ),
          ),
          // Oscurece el difuminado para que la foto entera destaque.
          ColoredBox(color: Colors.black.withOpacity(0.35)),
        ],
      ),
      Image(
        image: foto,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, _, __) {
          _alFallar();
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Sin foto: un círculo de color, del mayor tamaño que quepa entre las
  /// franjas, sobre un fondo suave del mismo color.
  Widget _sustituto(Color color, Widget Function(double lado) contenido) {
    return widget.builder(
      ColoredBox(color: color.withOpacity(0.12)),
      LayoutBuilder(builder: (context, limites) {
        final lado = limites.biggest.shortestSide * 0.85;
        return Center(
          child: Container(
            width: lado,
            height: lado,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: contenido(lado),
          ),
        );
      }),
    );
  }
}

String _iniciales(String nombre) {
  final partes =
      nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  final iniciales = partes.map((p) => p[0].toUpperCase()).join();
  return iniciales.isEmpty ? '?' : iniciales;
}

part of 'home_view.dart';

// ═════════════════════════════════════════════════════════════
// INICIO DE ESCRITORIO: rejilla "bento" que llena la ventana
// ═════════════════════════════════════════════════════════════
//
// El módulo de mostrador (Vender) va grande y los demás alrededor, con los
// mismos degradados del teléfono. Debajo, los números de hoy; cada uno abre
// su pantalla. Con ⌘/Ctrl + número se abre cada tarjeta y con ⌘/Ctrl + coma,
// Configuración, como en las apps de escritorio.

/// La rejilla necesita ancho; en una ventana angosta (solo posible antes de
/// recompilar el mínimo nativo) se usa la lista del teléfono.
bool _usaBento(BuildContext context) =>
    PlataformaApp.escritorio && MediaQuery.sizeOf(context).width >= 720;

bool get _esMac => defaultTargetPlatform == TargetPlatform.macOS;

/// "⌘1" en macOS, "Ctrl+1" en Windows.
String _textoAtajo(String tecla) => _esMac ? '⌘$tecla' : 'Ctrl+$tecla';

SingleActivator _atajo(LogicalKeyboardKey tecla) =>
    SingleActivator(tecla, meta: _esMac, control: !_esMac);

const _digitos = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// Un número del día: qué es, cuánto vale (null mientras no llega) y qué
/// pantalla abre.
class _DatoDeHoy {
  const _DatoDeHoy({
    required this.label,
    required this.detalle,
    required this.icon,
    required this.color,
    required this.valor,
    required this.onTap,
    this.showcaseKey,
    this.tourDescription,
    this.conAtajo = true,
  });

  final String label;
  final String detalle;
  final IconData icon;
  final Color color;
  final String? Function() valor;
  final VoidCallback onTap;
  final GlobalKey? showcaseKey;
  final String? tourDescription;
  final bool conAtajo;
}

class _InicioEscritorio extends StatefulWidget {
  const _InicioEscritorio({
    required this.modulos,
    required this.datos,
    required this.cargando,
    required this.recargar,
    required this.abrirConfiguracion,
  });

  /// En el orden de la rejilla: el primero es el grande.
  final List<_ModuleItem> modulos;
  final List<_DatoDeHoy> datos;
  final RxBool cargando;
  final VoidCallback recargar;
  final VoidCallback abrirConfiguracion;

  @override
  State<_InicioEscritorio> createState() => _InicioEscritorioState();
}

class _InicioEscritorioState extends State<_InicioEscritorio> {
  bool _alFrente = false;

  /// Los números se piden cada vez que Inicio vuelve al frente: al regresar
  /// de cobrar o vender ya incluyen lo nuevo.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final alFrente = ModalRoute.isCurrentOf(context) ?? true;
    if (alFrente && !_alFrente) widget.recargar();
    _alFrente = alFrente;
  }

  @override
  Widget build(BuildContext context) {
    const espacio = 16.0;
    final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
    final modulos = widget.modulos;
    // Atajos en el orden en que se leen: módulos y luego los números.
    var siguiente = 0;
    final atajosModulos = [
      for (final _ in modulos) siguiente < 9 ? siguiente++ : null
    ];
    final atajosDatos = [
      for (final d in widget.datos)
        d.conAtajo && siguiente < 9 ? siguiente++ : null
    ];

    Widget modulo(int i) => TourStep(
          tourKey: modulos[i].showcaseKey,
          title: modulos[i].label,
          description: modulos[i].tourDescription,
          borderRadius: 24,
          child: _TarjetaBento(
            module: modulos[i],
            grande: i == 0 && modulos.length >= 3,
            atajo: atajosModulos[i] == null
                ? null
                : _textoAtajo('${atajosModulos[i]! + 1}'),
          ),
        );

    final rejilla = switch (modulos.length) {
      0 => null,
      1 => modulo(0),
      2 => Row(children: [
          Expanded(child: modulo(0)),
          const SizedBox(width: espacio),
          Expanded(child: modulo(1)),
        ]),
      3 => Row(children: [
          Expanded(flex: 5, child: modulo(0)),
          const SizedBox(width: espacio),
          Expanded(
            flex: 6,
            child: Column(children: [
              Expanded(child: modulo(1)),
              const SizedBox(height: espacio),
              Expanded(child: modulo(2)),
            ]),
          ),
        ]),
      _ => Row(children: [
          Expanded(flex: 5, child: modulo(0)),
          const SizedBox(width: espacio),
          Expanded(
            flex: 6,
            child: Column(children: [
              Expanded(
                child: Row(children: [
                  Expanded(child: modulo(1)),
                  const SizedBox(width: espacio),
                  Expanded(child: modulo(2)),
                ]),
              ),
              const SizedBox(height: espacio),
              Expanded(child: modulo(3)),
            ]),
          ),
        ]),
    };

    final datos = [
      for (var i = 0; i < widget.datos.length; i++)
        _conPaso(
          widget.datos[i],
          _TarjetaDato(
            dato: widget.datos[i],
            cargando: widget.cargando,
            atajo: atajosDatos[i] == null
                ? null
                : _textoAtajo('${atajosDatos[i]! + 1}'),
          ),
        ),
    ];

    return CallbackShortcuts(
      bindings: {
        for (var i = 0; i < modulos.length; i++)
          if (atajosModulos[i] != null)
            _atajo(_digitos[atajosModulos[i]!]): modulos[i].onTap,
        for (var i = 0; i < widget.datos.length; i++)
          if (atajosDatos[i] != null)
            _atajo(_digitos[atajosDatos[i]!]): widget.datos[i].onTap,
        _atajo(LogicalKeyboardKey.comma): widget.abrirConfiguracion,
      },
      // Inicio no tiene campos: el foco queda aquí para que los atajos
      // funcionen sin hacer clic antes.
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            if (rejilla != null) Expanded(child: rejilla),
            if (rejilla != null && datos.isNotEmpty)
              const SizedBox(height: espacio),
            if (datos.isNotEmpty)
              SizedBox(
                height: 120 * escala,
                child: Row(children: [
                  for (var i = 0; i < datos.length; i++) ...[
                    if (i > 0) const SizedBox(width: espacio),
                    Expanded(child: datos[i]),
                  ],
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _conPaso(_DatoDeHoy dato, Widget tarjeta) => dato.showcaseKey == null
      ? tarjeta
      : TourStep(
          tourKey: dato.showcaseKey!,
          title: dato.label,
          description: dato.tourDescription ?? '',
          borderRadius: 20,
          child: tarjeta,
        );
}

/// Tarjeta de módulo de la rejilla: el degradado del teléfono, el ícono en
/// grande como marca de agua y su atajo de teclado.
class _TarjetaBento extends StatelessWidget {
  const _TarjetaBento({
    required this.module,
    required this.grande,
    required this.atajo,
  });

  final _ModuleItem module;
  final bool grande;
  final String? atajo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final m = module;
    final radio = BorderRadius.circular(24);
    return AlPasarMouse(
      builder: (context, encima) => AnimatedScale(
        scale: encima ? 1.015 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: radio,
            boxShadow: [
              BoxShadow(
                color: m.gradient[0].withOpacity(encima ? 0.22 : 0.10),
                blurRadius: encima ? 28 : 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: c.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: radio),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: m.onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radio,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      m.gradient[0].withOpacity(encima ? 0.24 : 0.17),
                      m.gradient[1].withOpacity(encima ? 0.12 : 0.07),
                    ],
                  ),
                  border: Border.all(
                    color: m.gradient[0].withOpacity(encima ? 0.55 : 0.22),
                  ),
                ),
                child: Stack(
                  children: [
                    // Marca de agua: el mismo ícono, enorme y tenue.
                    Positioned(
                      right: grande ? -36 : -20,
                      bottom: grande ? -36 : -20,
                      child: Icon(
                        m.icon,
                        size: grande ? 240 : 128,
                        color: m.gradient[0].withOpacity(0.10),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(grande ? 28 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _IconoDegradado(
                                icon: m.icon,
                                colores: m.gradient,
                                tamano: grande ? 64 : 48,
                              ),
                              const SizedBox(width: 8),
                              // Con texto grande en tarjetas chicas, el atajo
                              // se encoge en vez de desbordarse.
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: atajo == null
                                      ? null
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: _ChipAtajo(atajo!),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Se encoge antes que desbordarse con texto grande.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: grande ? 32 : 20,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: grande ? 6 : 2),
                                Text(
                                  m.subtitle,
                                  style: TextStyle(
                                    fontSize: grande ? 16 : 13,
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

/// Un número de hoy: ícono, qué es y su valor en grande.
class _TarjetaDato extends StatelessWidget {
  const _TarjetaDato({
    required this.dato,
    required this.cargando,
    required this.atajo,
  });

  final _DatoDeHoy dato;
  final RxBool cargando;
  final String? atajo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final radio = BorderRadius.circular(20);
    final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
    return AlPasarMouse(
      builder: (context, encima) => Material(
        color: c.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(
            color: dato.color.withOpacity(encima ? 0.45 : 0.14),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: dato.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dato.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(dato.icon, color: dato.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dato.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Alto fijo: un importe largo se encoge sin mover las
                      // etiquetas, que quedan alineadas entre tarjetas.
                      SizedBox(
                        height: 36 * escala,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Obx(() {
                            final valor = dato.valor();
                            return Text(
                              valor ?? (cargando.value ? '…' : '—'),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                      Text(
                        dato.detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: c.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (atajo != null) _ChipAtajo(atajo!) else const SizedBox(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: c.textSecondary.withOpacity(encima ? 0.9 : 0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconoDegradado extends StatelessWidget {
  const _IconoDegradado({
    required this.icon,
    required this.colores,
    required this.tamano,
  });

  final IconData icon;
  final List<Color> colores;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colores,
          ),
          borderRadius: BorderRadius.circular(tamano * 0.3),
          boxShadow: [
            BoxShadow(
              color: colores[0].withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: tamano * 0.5),
      );
}

/// El atajo de teclado de una tarjeta, discreto en una esquina.
class _ChipAtajo extends StatelessWidget {
  const _ChipAtajo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.contraste.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.contraste.withOpacity(0.12)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

part of 'home_view.dart';

// ═════════════════════════════════════════════════════════════
// INICIO DE TABLETA: rejilla "bento"
// ═════════════════════════════════════════════════════════════
//
// Arriba, los números de hoy; cada uno abre su pantalla. Debajo, los módulos
// con los degradados del teléfono: el de mostrador (Vender) grande y los
// demás alrededor, cada uno con un dato del día. En escritorio Inicio es el
// panel del día (panel_del_dia.dart) y la navegación va en la barra lateral.

/// La rejilla es de tableta; el teléfono conserva su lista.
bool _usaBento(BuildContext context) => PlataformaApp.tableta;

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
  });

  final String label;
  final String detalle;
  final IconData icon;
  final Color color;
  final String? Function() valor;
  final VoidCallback onTap;
  final GlobalKey? showcaseKey;
  final String? tourDescription;
}

class _InicioTableta extends StatefulWidget {
  const _InicioTableta({
    required this.modulos,
    required this.datos,
    required this.cargando,
    required this.recargar,
  });

  /// En el orden de la rejilla: el primero es el grande.
  final List<_ModuleItem> modulos;
  final List<_DatoDeHoy> datos;
  final RxBool cargando;
  final VoidCallback recargar;

  @override
  State<_InicioTableta> createState() => _InicioTabletaState();
}

class _InicioTabletaState extends State<_InicioTableta> {
  bool _alFrente = false;

  /// Los números se piden cada vez que Inicio vuelve al frente: al regresar
  /// de cobrar o vender ya incluyen lo nuevo.
  ///
  /// Se piden al terminar el cuadro, no aquí: esto corre mientras se dibuja,
  /// y "cargando" avisa a otras pantallas que lo escuchan. Al regresar a
  /// Inicio con `Get.offAllNamed` (permisos, modo de cobro) el Inicio que se
  /// va sigue montado, y avisarle a mitad del dibujo es un error.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final alFrente = ModalRoute.isCurrentOf(context) ?? true;
    if (alFrente && !_alFrente) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.recargar();
      });
    }
    _alFrente = alFrente;
  }

  @override
  Widget build(BuildContext context) {
    const espacio = 16.0;
    final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
    final modulos = widget.modulos;

    Widget modulo(int i) => TourStep(
          tourKey: modulos[i].showcaseKey,
          title: modulos[i].label,
          description: modulos[i].tourDescription,
          borderRadius: 24,
          child: _TarjetaBento(
            module: modulos[i],
            grande: i == 0 && modulos.length >= 3,
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
            // Estiradas: sin esto la tarjeta de abajo toma el ancho de su
            // contenido y queda angosta y centrada.
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
            // Estiradas: sin esto la tarjeta de abajo toma el ancho de su
            // contenido y queda angosta y centrada.
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          _TarjetaDato(dato: widget.datos[i], cargando: widget.cargando),
        ),
    ];

    // Los números de hoy van primero: es lo que se busca al abrir la app.
    return Column(
      children: [
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
        if (rejilla != null && datos.isNotEmpty)
          const SizedBox(height: espacio),
        if (rejilla != null) Expanded(child: rejilla),
      ],
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
/// grande como marca de agua y un dato del día.
class _TarjetaBento extends StatelessWidget {
  const _TarjetaBento({required this.module, required this.grande});

  final _ModuleItem module;
  final bool grande;

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
                          _IconoDegradado(
                            icon: m.icon,
                            colores: m.gradient,
                            tamano: grande ? 64 : 48,
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
                                    fontSize: grande ? 17 : 14,
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // Un dato del día: el porqué de la tarjeta.
                                if (m.dato != null)
                                  Obx(() {
                                    final dato = m.dato!();
                                    if (dato == null) return const SizedBox();
                                    return Padding(
                                      padding:
                                          EdgeInsets.only(top: grande ? 12 : 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color:
                                              m.gradient[0].withOpacity(0.18),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          dato,
                                          style: TextStyle(
                                            fontSize: grande ? 16 : 14,
                                            fontWeight: FontWeight.w700,
                                            color: c.textPrimary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
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

/// Un número de hoy: ícono, qué es y su valor en grande. También va en el
/// panel del día de escritorio.
class _TarjetaDato extends StatelessWidget {
  const _TarjetaDato({required this.dato, required this.cargando});

  final _DatoDeHoy dato;
  final RxBool cargando;

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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: c.textSecondary.withOpacity(encima ? 0.9 : 0.4),
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

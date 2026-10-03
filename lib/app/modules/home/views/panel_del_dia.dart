part of 'home_view.dart';

// ═════════════════════════════════════════════════════════════
// INICIO DE ESCRITORIO: el panel del día
// ═════════════════════════════════════════════════════════════
//
// La navegación va en la barra lateral; Inicio muestra lo de hoy. Arriba los
// números (cobrado, entradas, por vencer), luego lo que más se hace en el
// mostrador y abajo la actividad: quién entró, qué se cobró y a quién le
// vence la membresía esta semana.

/// El panel necesita ancho; en una ventana angosta (solo posible sin el
/// mínimo nativo) se usa la lista del teléfono.
bool _usaPanel(BuildContext context) =>
    PlataformaApp.escritorio && MediaQuery.sizeOf(context).width >= 720;

/// Filas por lista de actividad.
const _filasPorLista = 6;

class _PanelDelDia extends StatefulWidget {
  const _PanelDelDia({
    required this.home,
    required this.resumen,
    required this.datos,
    required this.recargar,
    required this.pasoCabecera,
  });

  final HomeController home;
  final ResumenDelDia resumen;
  final List<_DatoDeHoy> datos;
  final VoidCallback recargar;

  /// La cabecera es el primer paso del recorrido.
  final Widget Function(Widget cabecera) pasoCabecera;

  @override
  State<_PanelDelDia> createState() => _PanelDelDiaState();
}

class _PanelDelDiaState extends State<_PanelDelDia> {
  bool _alFrente = false;

  HomeController get home => widget.home;
  ResumenDelDia get resumen => widget.resumen;

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
    final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
    final accesos = _accesos();
    final listas = _listasDelDia(context, home, resumen);
    return LayoutBuilder(builder: (context, limites) {
      final ancha = limites.maxWidth >= 900;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.pasoCabecera(_cabecera(context)),
            if (widget.datos.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 120 * escala,
                child: _filaDeTarjetas([
                  for (final d in widget.datos)
                    _TarjetaDato(dato: d, cargando: resumen.cargando),
                ]),
              ),
            ],
            if (accesos.isNotEmpty) ...[
              const SizedBox(height: 32),
              const _TituloDelPanel('Accesos rápidos'),
              const SizedBox(height: 12),
              _rejillaDeTarjetas(accesos,
                  porFila: ancha ? 4 : 2, alto: 96 * escala),
            ],
            if (listas.isNotEmpty) ...[
              const SizedBox(height: 32),
              const _TituloDelPanel('Actividad'),
              const SizedBox(height: 12),
              _rejillaDeTarjetas(
                listas,
                porFila: ancha ? 3 : 2,
                alto: (68 + _filasPorLista * 58) * escala,
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _cabecera(BuildContext context) {
    final c = context.colores;
    final hoy = fechaLarga(DateTime.now(), conDia: true);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inicio',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hoy[0].toUpperCase() + hoy.substring(1),
                style: TextStyle(fontSize: 15, color: c.textSecondary),
              ),
            ],
          ),
        ),
        Obx(() => resumen.cargando.value
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const SizedBox()),
        OutlinedButton.icon(
          onPressed: widget.recargar,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Actualizar'),
          style: estiloBotonEscritorio(),
        ),
      ],
    );
  }

  List<Widget> _accesos() {
    final puedeCobrar = home.can(Permission.cobrarAbonos);
    return [
      if (home.can(Permission.vender))
        _AccesoRapido(
          titulo: 'Nueva venta',
          detalle: 'Cobrar productos del mostrador',
          icono: Icons.storefront_outlined,
          colores: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
          onTap: home.goToPointOfSale,
        ),
      if (puedeCobrar)
        _AccesoRapido(
          titulo: 'Cobrar abono',
          detalle: 'Pagar o renovar una membresía',
          icono: Icons.payments_outlined,
          colores: const [Color(0xFFf093fb), Color(0xFFf5576c)],
          onTap: home.goToAbonar,
        ),
      if (puedeCobrar)
        _AccesoRapido(
          titulo: 'Cobrar visita',
          detalle: 'Un día, sin registrar al cliente',
          detalleVivo: () {
            final precio = resumen.precioDia.value;
            return precio == null
                ? 'Un día, sin registrar al cliente'
                : 'Un día · ${dinero(precio)}';
          },
          icono: Icons.confirmation_number_outlined,
          colores: const [Color(0xFF11998e), Color(0xFF38ef7d)],
          onTap: () async {
            await abrirCobrarVisita(precioDia: resumen.precioDia.value);
            widget.recargar();
          },
        ),
      if (home.can(Permission.gestionarClientes))
        _AccesoRapido(
          titulo: 'Nuevo cliente',
          detalle: 'Dar de alta a un miembro',
          icono: Icons.person_add_alt_1_outlined,
          colores: const [Color(0xFF667eea), Color(0xFF764ba2)],
          onTap: () =>
              Get.toNamed(Routes.CLIENTES, arguments: {'nuevo_cliente': true}),
        ),
    ];
  }
}

/// Lo de hoy en listas cortas: quién entró, qué se cobró y a quién le vence
/// la membresía. En escritorio van en el panel; en tableta, bajo la rejilla.
List<Widget> _listasDelDia(
    BuildContext context, HomeController home, ResumenDelDia resumen) {
  final puedeCobrar = home.can(Permission.cobrarAbonos);
  return [
    if (home.can(Permission.verAccesos))
      _ListaDelDia(
        titulo: 'Últimas entradas',
        icono: Icons.door_sliding_outlined,
        color: const Color(0xFF81C784),
        verTodo: home.goToAccessLogs,
        cargando: resumen.cargando,
        vacio: 'Todavía no ha entrado nadie hoy.',
        filas: () => [
          for (final e in resumen.ultimasEntradas.take(_filasPorLista))
            _FilaDeActividad(
              inicial: e.userName,
              principal: e.userName,
              secundario: switch (e.method) {
                'rfid' => 'Con tarjeta',
                'qr' => 'Con código QR',
                _ => 'Entrada',
              },
              detalle: _hora(e.accessTime),
            ),
        ],
      ),
    if (home.can(Permission.verIngresos))
      _ListaDelDia(
        titulo: 'Últimos cobros',
        icono: Icons.receipt_long_outlined,
        color: AppColors.accent,
        verTodo: home.goToPaymentRegistration,
        cargando: resumen.cargando,
        vacio: 'Todavía no hay cobros hoy.',
        filas: () => [
          for (final i in resumen.cobros.take(_filasPorLista))
            _FilaDeActividad(
              icono: _iconoDeConcepto(i.concepto),
              principal: i.clienteNombre.trim().isEmpty
                  ? i.conceptoDescripcion
                  : i.clienteNombre,
              // Una venta sin cliente ya dice qué es en el renglón de arriba.
              secundario: i.clienteNombre.trim().isEmpty
                  ? i.metodoPagoDescripcion
                  : '${i.conceptoDescripcion} · ${i.metodoPagoDescripcion}',
              detalle: dinero(i.montoFinal),
              debajo: _hora(i.fecha),
              onTap: () => mostrarDetalleIngreso(context, i),
            ),
        ],
      ),
    if (home.can(Permission.gestionarClientes))
      _ListaDelDia(
        titulo: 'Vencen esta semana',
        icono: Icons.event_busy_outlined,
        color: AppColors.warning,
        verTodo: home.goToClientes,
        cargando: resumen.cargando,
        vacio: 'Nadie vence en los próximos '
            '${ResumenDelDia.diasPorVencer} días.',
        filas: () => [
          for (final u in resumen.porVencer.take(_filasPorLista))
            _FilaDeActividad(
              inicial: u.name,
              principal: u.name,
              secundario: _vence(u.expirationDate!),
              accion: puedeCobrar
                  ? OutlinedButton(
                      onPressed: () => Get.toNamed(Routes.ABONAR, arguments: {
                        'cliente': u,
                        'alTerminar': AlTerminarAbono.volverAInicio,
                      }),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cobrar'),
                    )
                  : null,
            ),
        ],
      ),
  ];
}

/// Los hijos en filas de [porFila], todos del mismo ancho (la última fila
/// no se estira).
Widget _rejillaDeTarjetas(List<Widget> hijos,
    {required int porFila, required double alto}) {
  return Column(
    children: [
      for (var i = 0; i < hijos.length; i += porFila) ...[
        if (i > 0) const SizedBox(height: 16),
        SizedBox(
          height: alto,
          child: _filaDeTarjetas([
            for (var j = i; j < i + porFila; j++)
              j < hijos.length ? hijos[j] : const SizedBox(),
          ]),
        ),
      ],
    ],
  );
}

Widget _filaDeTarjetas(List<Widget> hijos) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < hijos.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: hijos[i]),
        ],
      ],
    );

/// "10:32 a. m."
String _hora(DateTime d) {
  final local = d.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m ${local.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// "Vence hoy", "Vence mañana", "Vence el jueves 9". Siempre es esta semana:
/// el día de la semana y el número bastan.
String _vence(DateTime fecha, {DateTime? hoy}) {
  const dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  final ahora = hoy ?? DateTime.now();
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  final faltan =
      dia.difference(DateTime(ahora.year, ahora.month, ahora.day)).inDays;
  if (faltan <= 0) return 'Vence hoy';
  if (faltan == 1) return 'Vence mañana';
  return 'Vence el ${dias[fecha.weekday - 1]} ${fecha.day}';
}

IconData _iconoDeConcepto(String concepto) => switch (concepto) {
      'producto' => Icons.shopping_bag_outlined,
      'visita' => Icons.confirmation_number_outlined,
      _ => Icons.payments_outlined,
    };

class _TituloDelPanel extends StatelessWidget {
  const _TituloDelPanel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: context.colores.textPrimary,
        ),
      );
}

/// Una acción frecuente: ícono con el degradado de su módulo, qué hace y un
/// detalle.
class _AccesoRapido extends StatelessWidget {
  const _AccesoRapido({
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.colores,
    required this.onTap,
    this.detalleVivo,
  });

  final String titulo;
  final String detalle;

  /// Un detalle que cambia (el precio de la visita al llegar).
  final String Function()? detalleVivo;
  final IconData icono;
  final List<Color> colores;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final radio = BorderRadius.circular(18);
    Widget texto(String t) => Text(
          t,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        );
    return AlPasarMouse(
      builder: (context, encima) => Material(
        color: c.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(
            color: colores[0].withOpacity(encima ? 0.55 : 0.18),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _IconoDegradado(icon: icono, colores: colores, tamano: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Con texto grande se recorta en vez de desbordarse.
                      Flexible(
                        child: detalleVivo == null
                            ? texto(detalle)
                            : Obx(() => texto(detalleVivo!())),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una lista corta de lo de hoy, con su "Ver todo".
class _ListaDelDia extends StatelessWidget {
  const _ListaDelDia({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.verTodo,
    required this.cargando,
    required this.vacio,
    required this.filas,
  });

  final String titulo;
  final IconData icono;
  final Color color;
  final VoidCallback verTodo;
  final RxBool cargando;
  final String vacio;
  final List<Widget> Function() filas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.disabled.withOpacity(0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: verTodo,
                  child: const Text('Ver todo'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.disabled.withOpacity(0.4)),
          Expanded(
            child: Obx(() {
              final lista = filas();
              if (lista.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      cargando.value ? 'Cargando…' : vacio,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: c.textSecondary),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: lista,
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Una fila de actividad: inicial o ícono, quién o qué, un detalle y a la
/// derecha la hora, el importe o una acción.
class _FilaDeActividad extends StatelessWidget {
  const _FilaDeActividad({
    required this.principal,
    required this.secundario,
    this.inicial,
    this.icono,
    this.detalle,
    this.debajo,
    this.accion,
    this.onTap,
  });

  final String principal;
  final String secundario;
  final String? inicial;
  final IconData? icono;
  final String? detalle;
  final String? debajo;
  final Widget? accion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final letra = (inicial ?? '').trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LayoutBuilder(builder: (context, limites) {
          // Lo de la derecha (hora, importe o botón) no pasa de la mitad:
          // con texto grande se encoge y el nombre conserva su lugar.
          Widget aLaDerecha(Widget hijo) => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: limites.maxWidth / 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: hijo,
                ),
              );
          return Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent.withOpacity(0.14),
                child: icono != null
                    ? Icon(icono, size: 18, color: AppColors.accent)
                    : Text(
                        letra.isEmpty ? '?' : letra[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      principal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      secundario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (detalle != null || debajo != null) ...[
                const SizedBox(width: 8),
                aLaDerecha(Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (detalle != null)
                      Text(
                        detalle!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: debajo != null
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: debajo != null
                              ? AppColors.success
                              : c.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (debajo != null)
                      Text(
                        debajo!,
                        style: TextStyle(fontSize: 14, color: c.textSecondary),
                      ),
                  ],
                )),
              ],
              if (accion != null) ...[
                const SizedBox(width: 8),
                aLaDerecha(accion!),
              ],
            ],
          );
        }),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/utils/periodo_filtro_mixin.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import '../controllers/ingresos_controller.dart';

String _moneda(double monto) => dinero(monto);

/// Tal como se guardó, igual que en la lista: la app guarda la hora del
/// gimnasio sin zona y pasarla a hora local le restaba 6 horas en México.
String _fechaConHora(DateTime f) {
  final hora = '${f.hour.toString().padLeft(2, '0')}:'
      '${f.minute.toString().padLeft(2, '0')}';
  return '${f.day} ${PeriodoFiltroMixin.nombresMesesCortos[f.month - 1]} '
      '${f.year}, $hora';
}

String _fecha(DateTime f) =>
    '${f.day} ${PeriodoFiltroMixin.nombresMesesCortos[f.month - 1]} ${f.year}';

/// Hoja inferior con el mismo aspecto en las dos vistas: un asa, un título y
/// el contenido, limitada al 80 % de la pantalla. En escritorio, ventana
/// centrada sin asa.
Future<void> _mostrarHoja(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required Widget contenido,
  double anchoMaximo = 600,
  Color? barrierColor,
}) {
  final c = context.colores;
  return mostrarHojaAdaptable(
    context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    anchoMaximo: anchoMaximo,
    barrierColor: barrierColor,
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (PlataformaApp.pantallaGrande)
            const SizedBox(height: 20)
          else
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: c.textSecondary,
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(child: contenido),
        ],
      ),
    ),
  );
}

bool _hayCliente(IngresoModel i) =>
    i.items.isEmpty && i.clienteNombre.isNotEmpty;

/// En un cobro de membresía, el cliente; en una venta, el concepto.
String _titulo(IngresoModel ingreso) =>
    _hayCliente(ingreso) ? ingreso.clienteNombre : ingreso.conceptoDescripcion;

String _subtitulo(IngresoModel ingreso) {
  final fecha = _fechaConHora(ingreso.fecha);
  return _hayCliente(ingreso)
      ? '${ingreso.conceptoDescripcion} · $fecha'
      : fecha;
}

/// Detalle de un cobro en una hoja (teléfono) o una ventana (pantalla
/// grande).
Future<void> mostrarDetalleIngreso(BuildContext context, IngresoModel ingreso) {
  return _mostrarHoja(
    context,
    titulo: _titulo(ingreso),
    subtitulo: _subtitulo(ingreso),
    anchoMaximo: 480,
    // La ventana se despega de la pantalla de atrás, que en oscuro tiene
    // casi el mismo tono.
    barrierColor: Colors.black.withOpacity(0.6),
    contenido: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [_DetalleIngreso(ingreso)],
    ),
  );
}

/// Lo primero es el monto, grande, y cómo se pagó; debajo, en un bloque de
/// otro tono, qué se cobró: los productos de una venta o la membresía y su
/// desglose. Al final, referencia y notas.
class _DetalleIngreso extends StatelessWidget {
  const _DetalleIngreso(this.ingreso);

  final IngresoModel ingreso;

  @override
  Widget build(BuildContext context) {
    final esVenta = ingreso.items.isNotEmpty;
    final piezas = ingreso.items.fold<int>(0, (s, i) => s + i.cantidad);
    final cobro = <Widget>[
      if (ingreso.tipoMembresia.isNotEmpty)
        _Dato('Membresía', ingreso.tipoMembresia),
      if (ingreso.periodoInicio != null && ingreso.periodoFin != null)
        _Dato('Vigencia',
            '${_fecha(ingreso.periodoInicio!)} – ${_fecha(ingreso.periodoFin!)}'),
      // Primer pago de un cliente nuevo: el abono y la inscripción, por
      // separado (el total es la suma).
      if (ingreso.tieneCuotaRegistro) ...[
        _Dato('Abono', _moneda(ingreso.montoBase)),
        _Dato('Inscripción', _moneda(ingreso.cuotaRegistro)),
      ],
      if (ingreso.descuento > 0)
        _Dato('Descuento', '−${_moneda(ingreso.descuento)}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MontoPrincipal(ingreso),
        if (esVenta) ...[
          const SizedBox(height: 20),
          _Bloque(children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${_cuantos(ingreso.items.length, 'producto', 'productos')}'
                ' · ${_cuantos(piezas, 'pieza', 'piezas')}',
                style: TextStyle(
                  fontSize: legible(13),
                  color: context.colores.textSecondary,
                ),
              ),
            ),
            for (final item in ingreso.items) _LineaVenta(item),
          ]),
        ] else if (cobro.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Bloque(children: cobro),
        ],
        if ((ingreso.referenciaPago ?? '').isNotEmpty ||
            (ingreso.notas ?? '').trim().isNotEmpty)
          const SizedBox(height: 12),
        if ((ingreso.referenciaPago ?? '').isNotEmpty)
          _Dato('Referencia', ingreso.referenciaPago!),
        if ((ingreso.notas ?? '').trim().isNotEmpty)
          _Nota(ingreso.notas!.trim()),
      ],
    );
  }
}

String _cuantos(int n, String uno, String varios) =>
    '$n ${n == 1 ? uno : varios}';

/// Cuánto se vendió de cada producto en el periodo elegido, de lo más
/// vendido a lo menos.
Future<void> mostrarProductosVendidos(
    BuildContext context, IngresosController controller) {
  final c = context.colores;
  // Sin lo de otro periodo mientras llega lo de este.
  controller.productosVendidos.clear();
  controller.fetchProductosVendidos();
  // Mientras está abierta, una venta en otro teléfono la actualiza.
  controller.hojaProductosAbierta = true;

  return _mostrarHoja(
    context,
    titulo: 'Productos vendidos',
    subtitulo: controller.periodoLabel,
    contenido: Obx(() {
      if (controller.isLoadingProductos.value &&
          controller.productosVendidos.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        );
      }

      final productos = controller.productosVendidos;
      if (productos.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 48, color: c.textSecondary),
              const SizedBox(height: 12),
              Text(
                'No se vendieron productos en este periodo',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary),
              ),
            ],
          ),
        );
      }

      final piezas = productos.fold<int>(0, (s, p) => s + p.cantidad);
      final monto = productos.fold<double>(0, (s, p) => s + p.monto);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              children: [
                for (final p in productos)
                  _FilaProducto(
                    nombre: p.nombre,
                    detalle:
                        p.cantidad == 1 ? '1 pieza' : '${p.cantidad} piezas',
                    cantidad: p.cantidad,
                    monto: p.monto,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.disabled.withOpacity(0.6)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    piezas == 1
                        ? '1 pieza en total'
                        : '$piezas piezas en total',
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                Text(
                  _moneda(monto),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }),
  ).whenComplete(() => controller.hojaProductosAbierta = false);
}

class _FilaProducto extends StatelessWidget {
  const _FilaProducto({
    required this.nombre,
    required this.detalle,
    required this.cantidad,
    required this.monto,
  });

  final String nombre;
  final String detalle;
  final int cantidad;
  final double monto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$cantidad',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
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
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  detalle,
                  style: TextStyle(
                    fontSize: legible(12),
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _moneda(monto),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// El monto cobrado, lo que uno viene a ver, y con qué se pagó.
class _MontoPrincipal extends StatelessWidget {
  const _MontoPrincipal(this.ingreso);

  final IngresoModel ingreso;

  IconData get _icono {
    switch (ingreso.metodoPago) {
      case 'efectivo':
        return Icons.payments_outlined;
      case 'transferencia':
        return Icons.swap_horiz;
      default:
        return Icons.credit_card;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _moneda(ingreso.montoFinal),
            style: TextStyle(
              fontSize: PlataformaApp.elegir(escritorio: 40.0, movil: 34.0),
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: AppColors.success,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(_icono, size: 18, color: c.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                ingreso.metodoPagoDescripcion,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lo que se cobró, sobre un tono apenas distinto al de la ventana: separa
/// sin líneas y se ve igual en claro y en oscuro.
class _Bloque extends StatelessWidget {
  const _Bloque({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.colores.superficie,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Un renglón del ticket: el producto y "cantidad × precio" debajo; a la
/// derecha, lo que sumó.
class _LineaVenta extends StatelessWidget {
  const _LineaVenta(this.item);

  final ItemVendido item;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    const cifras = [FontFeature.tabularFigures()];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.cantidad} × ${_moneda(item.precioUnitario)}',
                  style: TextStyle(
                    fontSize: legible(13),
                    color: c.textSecondary,
                    fontFeatures: cifras,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _moneda(item.total),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              fontFeatures: cifras,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 15, color: c.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Las notas pueden ser largas: la etiqueta arriba y el texto completo
/// debajo, a lo ancho.
class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notas', style: TextStyle(fontSize: 15, color: c.textSecondary)),
          const SizedBox(height: 4),
          Text(
            texto,
            style: TextStyle(fontSize: 15, height: 1.4, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

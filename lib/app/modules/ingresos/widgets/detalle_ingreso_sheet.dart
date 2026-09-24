import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/utils/periodo_filtro_mixin.dart';
import 'package:gymads/app/data/models/ingreso_model.dart';
import '../controllers/ingresos_controller.dart';

String _moneda(double monto) => '\$${monto.toStringAsFixed(2)}';

String _fechaConHora(DateTime f) {
  final local = f.toLocal();
  final hora = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '${local.day} ${PeriodoFiltroMixin.nombresMesesCortos[local.month - 1]} '
      '${local.year}, $hora';
}

String _fecha(DateTime f) =>
    '${f.day} ${PeriodoFiltroMixin.nombresMesesCortos[f.month - 1]} ${f.year}';

/// Hoja inferior con el mismo aspecto en las dos vistas: un asa, un título y
/// el contenido, limitada al 80 % de la pantalla.
Future<void> _mostrarHoja(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required Widget contenido,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.4),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.titleColor,
                        ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
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

/// Detalle de un cobro: qué productos llevó (si fue una venta), total, método
/// y referencia.
Future<void> mostrarDetalleIngreso(BuildContext context, IngresoModel ingreso) {
  final esVenta = ingreso.items.isNotEmpty;
  final filas = <Widget>[
    if (esVenta) ...[
      const _Etiqueta('Productos'),
      for (final item in ingreso.items)
        _FilaProducto(
          nombre: item.nombre,
          detalle: item.cantidad == 1
              ? _moneda(item.precioUnitario)
              : '${item.cantidad} × ${_moneda(item.precioUnitario)}',
          cantidad: item.cantidad,
          monto: item.total,
        ),
      const Divider(color: AppColors.disabled, height: 24),
    ] else ...[
      if (ingreso.clienteNombre.isNotEmpty)
        _Dato('Cliente', ingreso.clienteNombre),
      if (ingreso.tipoMembresia.isNotEmpty)
        _Dato('Membresía', ingreso.tipoMembresia),
      if (ingreso.periodoInicio != null && ingreso.periodoFin != null)
        _Dato('Vigencia',
            '${_fecha(ingreso.periodoInicio!)} – ${_fecha(ingreso.periodoFin!)}'),
      if (ingreso.descuento > 0) _Dato('Descuento', _moneda(ingreso.descuento)),
    ],
    _Dato('Total', _moneda(ingreso.montoFinal), destacado: true),
    _Dato('Método de pago', ingreso.metodoPagoDescripcion),
    if ((ingreso.referenciaPago ?? '').isNotEmpty)
      _Dato('Referencia', ingreso.referenciaPago!),
    if ((ingreso.notas ?? '').trim().isNotEmpty)
      _Dato('Notas', ingreso.notas!.trim()),
  ];

  return _mostrarHoja(
    context,
    titulo: ingreso.conceptoDescripcion,
    subtitulo: _fechaConHora(ingreso.fecha),
    contenido: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: filas,
    ),
  );
}

/// Cuánto se vendió de cada producto en el periodo elegido, de lo más
/// vendido a lo menos.
Future<void> mostrarProductosVendidos(
    BuildContext context, IngresosController controller) {
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
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No se vendieron productos en este periodo',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
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
                top: BorderSide(color: AppColors.disabled.withOpacity(0.6)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    piezas == 1
                        ? '1 pieza en total'
                        : '$piezas piezas en total',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _moneda(monto),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.destacado = false});

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: destacado ? 18 : 14,
                fontWeight: destacado ? FontWeight.bold : FontWeight.w500,
                color: destacado ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

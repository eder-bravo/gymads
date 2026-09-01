import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../controllers/inventario_controller.dart';

/// Diálogo para mover el stock de un producto **por diferencia**, nunca
/// fijando un valor absoluto: se elige Agregar o Quitar y se escribe cuánto.
///
/// Cuando el producto tiene faltante (stock negativo) el resultado se desglosa
/// para que se vea qué se está saldando: reponer descuenta primero lo que ya
/// se vendió sin existencias.
///
/// Devuelve el stock resultante, o null si se canceló.
Future<int?> showStockAdjustDialog(Product product) {
  return Get.dialog<int>(
    _StockAdjustDialog(product: product),
    barrierDismissible: false,
  );
}

class _StockAdjustDialog extends StatefulWidget {
  const _StockAdjustDialog({required this.product});

  final Product product;

  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  final _cantidadController = TextEditingController();
  final _notaController = TextEditingController();

  bool _agregar = true;
  bool _guardando = false;

  int get _stockActual => widget.product.stock;
  int get _faltante => _stockActual < 0 ? -_stockActual : 0;
  int get _cantidad => int.tryParse(_cantidadController.text) ?? 0;
  int get _delta => _agregar ? _cantidad : -_cantidad;
  int get _resultado => _stockActual + _delta;

  @override
  void dispose() {
    _cantidadController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_cantidad <= 0) return;
    setState(() => _guardando = true);

    final nuevoStock = await Get.find<InventarioController>().ajustarStock(
      widget.product,
      _delta,
      nota: _notaController.text.trim().isEmpty
          ? null
          : _notaController.text.trim(),
    );

    if (!mounted) return;
    if (nuevoStock == null) {
      setState(() => _guardando = false);
      return;
    }
    Get.back(result: nuevoStock);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.product.name,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEstadoActual(),
            const SizedBox(height: 16),
            _buildSelectorDireccion(),
            const SizedBox(height: 16),
            TextField(
              controller: _cantidadController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.containerBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildResultado(),
            const SizedBox(height: 12),
            TextField(
              controller: _notaController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Compra a proveedor, merma, conteo…',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.containerBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Get.back(),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: (_cantidad > 0 && !_guardando) ? _guardar : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.disabled,
          ),
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  /// Encabezado: stock normal, o el faltante con su valor.
  Widget _buildEstadoActual() {
    if (_faltante > 0) {
      final valor = _faltante * widget.product.price;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Faltan $_faltante ${_unidades(_faltante)} · '
                '\$${valor.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      'Stock actual: $_stockActual ${_unidades(_stockActual)}',
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    );
  }

  Widget _buildSelectorDireccion() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.containerBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _direccionButton('Agregar', Icons.add, true),
          _direccionButton('Quitar', Icons.remove, false),
        ],
      ),
    );
  }

  Widget _direccionButton(String label, IconData icon, bool valor) {
    final seleccionado = _agregar == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _agregar = valor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado
                ? (valor ? AppColors.success : AppColors.warning)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: seleccionado ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                  color:
                      seleccionado ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cómo queda el stock. Con faltante se separa en dos líneas: lo que se
  /// salda y lo que queda disponible, porque el número final por sí solo no
  /// explica por qué agregar 10 sobre -3 deja 7.
  Widget _buildResultado() {
    if (_cantidad <= 0) return const SizedBox.shrink();

    final lineas = <(String, Color)>[];

    if (_agregar && _faltante > 0) {
      final cubierto = _cantidad >= _faltante ? _faltante : _cantidad;
      lineas.add(('Cubre el faltante de $cubierto', AppColors.textSecondary));
      lineas.add(_resultado >= 0
          ? ('Quedarán $_resultado ${_unidades(_resultado)} disponibles',
              AppColors.success)
          : ('Seguirán faltando ${-_resultado}', AppColors.error));
    } else {
      lineas.add(_resultado >= 0
          ? ('Quedará en $_resultado ${_unidades(_resultado)}',
              AppColors.textPrimary)
          : ('Quedará con ${-_resultado} ${_unidades(-_resultado)} faltantes',
              AppColors.error));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.containerBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (texto, color) in lineas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _unidades(int n) => n == 1 ? 'unidad' : 'unidades';
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Arriba de cada paso del cobro en el teléfono: una barra con los pasos
/// (los hechos en azul) y "Paso 2 de 4" con el título del paso, con el
/// número en un círculo como en Abonar.
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({
    super.key,
    required this.paso,
    required this.titulo,
    this.total = 4,
  });

  final int paso;
  final int total;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Semantics(
      header: true,
      label: 'Paso $paso de $total: $titulo',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= paso ? AppColors.accent : c.borde,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$paso',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paso $paso de $total',
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 13)),
                      Text(
                        titulo,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

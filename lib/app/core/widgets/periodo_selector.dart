import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/periodo_filtro_mixin.dart';

/// Selector de Día / Semana / Mes con flechas de navegación, salto a una fecha
/// concreta y rango a medida.
///
/// Trabaja contra cualquier controller que use [PeriodoFiltroMixin], así que
/// Ingresos y Entradas comparten exactamente el mismo comportamiento.
class PeriodoSelector extends StatelessWidget {
  const PeriodoSelector({super.key, required this.controller});

  final PeriodoFiltroMixin controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // Segmentado de modo
            Container(
              decoration: BoxDecoration(
                color: c.containerBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Obx(() {
                final modo = controller.selectedPeriodo.value;
                return Row(
                  children: [
                    _modoButton(context, 'Día', 'dia', modo),
                    _modoButton(context, 'Semana', 'semana', modo),
                    _modoButton(context, 'Mes', 'mes', modo),
                  ],
                );
              }),
            ),
            const SizedBox(height: 4),
            // Navegación del periodo
            Row(
              children: [
                Obx(() => IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        color: controller.puedeRetroceder
                            ? AppColors.accent
                            : c.disabled,
                      ),
                      onPressed: controller.puedeRetroceder
                          ? controller.goToPrevious
                          : null,
                      tooltip: 'Anterior',
                    )),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _onLabelTap(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                              child: Obx(() => Text(
                                    controller.periodoLabel,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ))),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down,
                              color: AppColors.accent, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                Obx(() => IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: controller.puedeAvanzar
                            ? AppColors.accent
                            : c.disabled,
                      ),
                      onPressed:
                          controller.puedeAvanzar ? controller.goToNext : null,
                      tooltip: 'Siguiente',
                    )),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.accent.withOpacity(0.2),
                ),
                IconButton(
                  onPressed: () => _seleccionarRango(context),
                  icon: const Icon(Icons.date_range_outlined),
                  color: AppColors.accent,
                  tooltip: 'Rango de fechas',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modoButton(
      BuildContext context, String label, String value, String activo) {
    final c = context.colores;
    final seleccionado = activo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.changePeriodo(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
              color: seleccionado ? Colors.white : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Al tocar la etiqueta: en modo mes abre el selector de mes; en día o
  /// semana, un calendario para saltar a una fecha concreta.
  Future<void> _onLabelTap(BuildContext context) async {
    final modo = controller.selectedPeriodo.value;
    if (modo == 'mes') {
      _showMonthPicker(context);
      return;
    }
    if (modo != 'dia' && modo != 'semana') return;

    final now = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: controller.fechaInicio.value ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      locale: const Locale('es'),
      helpText: modo == 'dia' ? 'Selecciona un día' : 'Selecciona una semana',
    );

    if (fecha != null) {
      if (modo == 'dia') {
        controller.seleccionarDia(fecha);
      } else {
        controller.seleccionarSemana(fecha);
      }
    }
  }

  Future<void> _seleccionarRango(BuildContext context) async {
    final now = DateTime.now();

    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      // Fecha final libre: el usuario decide dónde termina el rango
      lastDate: DateTime(now.year + 1, now.month, now.day),
      // Sin rango inicial: el mes no abre ya pintado de naranja y el primer
      // toque se distingue claramente.
      locale: const Locale('es'),
      helpText: 'Selecciona un rango de fechas',
      saveText: 'Aplicar',
    );

    if (rango != null) {
      // Incluir todo el día final hasta las 23:59:59
      final fin =
          DateTime(rango.end.year, rango.end.month, rango.end.day, 23, 59, 59);
      controller.setFechasPersonalizadas(rango.start, fin);
    }
  }

  void _showMonthPicker(BuildContext context) {
    final c = context.colores;
    final now = DateTime.now();
    final current = controller.fechaInicio.value ?? now;
    int displayYear = current.year;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: c.cardBackground,
              // Ancho de diálogo aunque el teléfono esté de lado, y desplazable si
              // no cabe a lo alto.
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selecciona un mes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Navegador de año
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(builder: (_) {
                          final minYear = controller.anioCreacionCuenta;
                          final puedeRetroceder =
                              minYear == null || displayYear > minYear;
                          return IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              color: puedeRetroceder
                                  ? AppColors.accent
                                  : c.disabled,
                            ),
                            onPressed: puedeRetroceder
                                ? () => setState(() => displayYear--)
                                : null,
                            tooltip: 'Año anterior',
                          );
                        }),
                        Text(
                          '$displayYear',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: displayYear < now.year
                                ? AppColors.accent
                                : c.disabled,
                          ),
                          onPressed: displayYear < now.year
                              ? () => setState(() => displayYear++)
                              : null,
                          tooltip: 'Año siguiente',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Cuadrícula de meses
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isFuture =
                            controller.esMesFuturo(displayYear, month);
                        final isAnterior = controller.esMesAnteriorACreacion(
                            displayYear, month);
                        final isDisabled = isFuture || isAnterior;
                        final isSelected = displayYear == current.year &&
                            month == current.month;
                        final shortName =
                            PeriodoFiltroMixin.nombresMesesCortos[index];
                        final label = '${shortName[0].toUpperCase()}'
                            '${shortName.substring(1)}';

                        return Material(
                          color: isSelected
                              ? AppColors.accent.withOpacity(0.2)
                              : c.containerBackground,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: isDisabled
                                ? null
                                : () {
                                    controller.seleccionarMes(
                                        displayYear, month);
                                    Get.back();
                                  },
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isDisabled
                                      ? c.disabled
                                      : isSelected
                                          ? AppColors.accent
                                          : c.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

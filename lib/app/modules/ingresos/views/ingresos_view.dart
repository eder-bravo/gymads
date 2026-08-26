import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/tour_step.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import '../controllers/ingresos_controller.dart';
import '../widgets/transaction_tile.dart';
import 'todas_transacciones_view.dart';

class IngresosView extends GetView<IngresosController> {
  const IngresosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GymAppBar(
        title: 'Ingresos',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshData(),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selector de mes (compacto, en español)
            TourStep(
              tourKey: controller.keyPeriodo,
              title: 'Periodo',
              description: 'Elige si quieres ver el día, la semana o el mes, '
                  'o define tu propio rango de fechas.',
              borderRadius: 20,
              isFirstStep: true,
              child: _buildMonthSelector(),
            ),

            // Total de ingresos del mes
            TourStep(
              tourKey: controller.keyTotal,
              title: 'Total del periodo',
              description: 'La suma de todo lo cobrado en el periodo que '
                  'tengas seleccionado: abonos y ventas.',
              borderRadius: 20,
              child: _buildMonthTotal(),
            ),

            const SizedBox(height: 12),

            // Encabezado de la lista
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  const Text(
                    'Transacciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.titleColor,
                    ),
                  ),
                  const Spacer(),
                  TourStep(
                    tourKey: controller.keyVerTodas,
                    title: 'Ver todas',
                    description: 'Abre el historial completo, sin el filtro '
                        'de periodo.',
                    borderRadius: 12,
                    child: TextButton.icon(
                      onPressed: _verTodasLasTransacciones,
                      icon: const Icon(Icons.list_alt_outlined, size: 18),
                      label: const Text('Ver todas'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de transacciones a pantalla completa
            Expanded(
              child: TourStep(
                tourKey: controller.keyLista,
                title: 'Transacciones',
                description: 'Cada cobro registrado, con su fecha, su monto y '
                    'de dónde vino.',
                isLastStep: true,
                child: _buildTransactionsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // RANGO DE FECHAS PERSONALIZADO
  // ─────────────────────────────────────────────────────────
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
      builder: (context, child) => Theme(
        // Tema oscuro construido desde cero: copiar el tema claro de la app
        // dejaba la tipografía con texto negro y los días no se veían.
        data: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
            secondary: AppColors.accent,
          ),
          scaffoldBackgroundColor: AppColors.backgroundColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
          ),
          datePickerTheme: DatePickerThemeData(
            // Banda del rango translúcida para que inicio/fin resalten
            rangeSelectionBackgroundColor: AppColors.accent.withOpacity(0.25),
            rangePickerBackgroundColor: AppColors.backgroundColor,
            rangePickerHeaderForegroundColor: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (rango != null) {
      // Incluir todo el día final hasta las 23:59:59
      final fin = DateTime(
          rango.end.year, rango.end.month, rango.end.day, 23, 59, 59);
      controller.setFechasPersonalizadas(rango.start, fin);
    }
  }

  // ─────────────────────────────────────────────────────────
  // SELECTOR DE PERIODO (Día / Semana / Mes)
  // ─────────────────────────────────────────────────────────
  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // Segmentado de modo
            Container(
              decoration: BoxDecoration(
                color: AppColors.containerBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Obx(() {
                final modo = controller.selectedPeriodo.value;
                return Row(
                  children: [
                    _modoButton('Día', 'dia', modo),
                    _modoButton('Semana', 'semana', modo),
                    _modoButton('Mes', 'mes', modo),
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
                            : AppColors.disabled,
                      ),
                      onPressed: controller.puedeRetroceder
                          ? controller.goToPrevious
                          : null,
                      tooltip: 'Anterior',
                    )),
                Expanded(
                  child: Builder(
                    builder: (context) => InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _onLabelTap(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Obx(() => Text(
                                  controller.periodoLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                )),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down,
                                color: AppColors.accent, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Obx(() => IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: controller.puedeAvanzar
                            ? AppColors.accent
                            : AppColors.disabled,
                      ),
                      onPressed: controller.puedeAvanzar
                          ? controller.goToNext
                          : null,
                      tooltip: 'Siguiente',
                    )),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.accent.withOpacity(0.2),
                ),
                Builder(
                  builder: (context) => IconButton(
                    onPressed: () => _seleccionarRango(context),
                    icon: const Icon(Icons.date_range_outlined),
                    color: AppColors.accent,
                    tooltip: 'Rango de fechas',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modoButton(String label, String value, String activo) {
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
              color: seleccionado ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Al tocar la etiqueta: en modo mes abre el selector de mes; en día/semana
  /// abre un calendario para saltar a una fecha concreta.
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
      helpText:
          modo == 'dia' ? 'Selecciona un día' : 'Selecciona una semana',
      builder: (context, child) => Theme(
        data: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
            secondary: AppColors.accent,
          ),
          scaffoldBackgroundColor: AppColors.backgroundColor,
        ),
        child: child!,
      ),
    );

    if (fecha != null) {
      if (modo == 'dia') {
        controller.seleccionarDia(fecha);
      } else {
        controller.seleccionarSemana(fecha);
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // TOTAL DEL MES
  // ─────────────────────────────────────────────────────────
  Widget _buildMonthTotal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.success.withOpacity(0.18),
              AppColors.success.withOpacity(0.06),
            ],
          ),
          border: Border.all(color: AppColors.success.withOpacity(0.25)),
        ),
        child: Obx(() {
          final stats = controller.estadisticas.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.periodoTotalLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                controller.formatCurrency(stats.totalIngresos),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${stats.totalTransacciones} transacciones · Promedio ${controller.formatCurrency(stats.promedioTransaccion)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // LISTA DE TRANSACCIONES
  // ─────────────────────────────────────────────────────────
  Widget _buildTransactionsList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        );
      }

      if (!controller.tieneIngresos) {
        return RefreshIndicator(
          onRefresh: controller.refreshData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 80),
              Icon(Icons.receipt_long,
                  size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Center(
                child: Text(
                  'No hay transacciones en este periodo',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.refreshData,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: controller.ingresos.length,
          itemBuilder: (context, index) {
            return TransactionTile(ingreso: controller.ingresos[index]);
          },
        ),
      );
    });
  }

  // Abre la vista a pantalla completa con todas las transacciones
  void _verTodasLasTransacciones() {
    controller.fetchTodasLasTransacciones();
    Get.to(() => const TodasTransaccionesView());
  }

  // Abre un selector de mes/año para saltar a un mes específico
  void _showMonthPicker(BuildContext context) {
    final now = DateTime.now();
    final current = controller.fechaInicio.value ?? now;
    int displayYear = current.year;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecciona un mes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleColor,
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
                                  : AppColors.disabled,
                            ),
                            onPressed: puedeRetroceder
                                ? () => setState(() => displayYear--)
                                : null,
                            tooltip: 'Año anterior',
                          );
                        }),
                        Text(
                          '$displayYear',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: displayYear < now.year
                                ? AppColors.accent
                                : AppColors.disabled,
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
                            IngresosController.nombresMesesCortos[index];
                        final label = '${shortName[0].toUpperCase()}'
                            '${shortName.substring(1)}';

                        return Material(
                          color: isSelected
                              ? AppColors.accent.withOpacity(0.2)
                              : AppColors.containerBackground,
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
                                      ? AppColors.disabled
                                      : isSelected
                                          ? AppColors.accent
                                          : AppColors.textPrimary,
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

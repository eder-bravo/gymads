import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/access_logs_controller.dart';
import '../../../data/models/access_log_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/widgets/periodo_selector.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../global_widgets/app_header.dart';

class AccessLogsView extends GetView<AccessLogsController> {
  const AccessLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GymAppBar(
        title: 'Entradas',
        actions: [
          Obx(() => IconButton(
                icon: controller.isExportando.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                onPressed: controller.isExportando.value
                    ? null
                    : controller.exportarPdf,
                tooltip: 'Reporte en PDF',
              )),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refreshData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Periodo: día, semana, mes o rango a medida
            TourStep(
              tourKey: controller.keyPeriodo,
              title: 'Periodo',
              description: 'Elige si quieres ver el día, la semana o el mes, '
                  'o define tu propio rango de fechas.',
              borderRadius: 20,
              isFirstStep: true,
              child: PeriodoSelector(controller: controller),
            ),

            // Estadísticas y afluencia por hora
            TourStep(
              tourKey: controller.keyResumen,
              title: 'Resumen',
              description: 'Cuántas personas entraron y a qué horas se llena '
                  'más el gimnasio.',
              borderRadius: 20,
              child: Column(
                children: [
                  _buildStatsSection(),
                  _buildFranjasSection(),
                ],
              ),
            ),

            // Lista de logs
            Expanded(
              child: TourStep(
                tourKey: controller.keyLista,
                title: 'Historial de accesos',
                description: 'Quién entró al gimnasio, a qué hora y quién lo '
                    'registró. Desliza hacia abajo para actualizar.',
                isLastStep: true,
                child: _buildLogsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Obx(() {
        return Row(
          children: [
            _buildStatCard(
              'Entradas',
              '${controller.totalEntries.value}',
              AppColors.success,
            ),
            // Solo tiene sentido si el gimnasio registra salidas.
            if (controller.muestraSalidas)
              _buildStatCard(
                'Salidas',
                '${controller.totalExits.value}',
                AppColors.warning,
              ),
            _buildStatCard(
              'Hora pico',
              controller.franjaPicoLabel,
              AppColors.accent,
            ),
          ],
        );
      }),
    );
  }

  /// Afluencia por franja de dos horas, dentro del horario configurado.
  Widget _buildFranjasSection() {
    return Obx(() {
      final porFranja = controller.entradasPorFranja;
      final maximo = controller.maximoPorFranja;
      if (porFranja.isEmpty || maximo == 0) return const SizedBox.shrink();

      final pico = controller.franjaPico;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entradas por hora',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final entrada in porFranja.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        controller.etiquetaFranja(entrada.key),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: entrada.key == pico
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entrada.value / maximo,
                          minHeight: 10,
                          backgroundColor: AppColors.containerBackground,
                          valueColor: AlwaysStoppedAnimation(
                            entrada.key == pico
                                ? AppColors.accent
                                : AppColors.accent.withOpacity(0.45),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${entrada.value}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: entrada.key == pico
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        height: 88,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              // "18:00 – 20:00" no cabe al mismo tamaño que un número suelto;
              // encogerlo es mejor que recortarlo con puntos suspensivos.
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Cargando logs de acceso...',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: controller.refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }

        // Mostrar todos los logs sin filtros
        if (controller.accessLogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sin entradas en este periodo',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshData,
          color: AppColors.primary,
          child: ListView.builder(
            itemCount: controller.accessLogs.length,
            itemBuilder: (context, index) {
              final log = controller.accessLogs[index];
              return _buildLogCard(log);
            },
          ),
        );
      }),
    );
  }

  Widget _buildLogCard(AccessLogModel log) {
    final isEntry = log.accessType == 'entrada';
    final color = isEntry ? AppColors.success : AppColors.error;
    final icon = isEntry ? Icons.login : Icons.logout;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.cardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icono de acceso
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 26,
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),

            // Información del usuario
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.userName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Staff: ${log.staffUser}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Información del acceso
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    log.accessType.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('dd/MM HH:mm').format(log.accessTime),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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

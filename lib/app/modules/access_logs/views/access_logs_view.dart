import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/access_logs_controller.dart';
import '../../../data/models/access_log_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/hora_formato.dart';
import '../../../core/widgets/periodo_selector.dart';
import '../../../core/widgets/tour_step.dart';
import '../../../global_widgets/app_header.dart';
import '../../../core/widgets/cabecera_con_lista.dart';
import '../../../core/widgets/centrado_desplazable.dart';

class AccessLogsView extends GetView<AccessLogsController> {
  const AccessLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
      backgroundColor: c.backgroundColor,
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
        child: CabeceraConLista(
          cabecera: [
            // Periodo: día, semana, mes o rango a medida
            TourStep(
              tourKey: controller.keyPeriodo,
              title: 'Periodo',
              description: 'Día, semana, mes o las fechas que elijas.',
              borderRadius: 20,
              isFirstStep: true,
              child: PeriodoSelector(controller: controller),
            ),

            // Estadísticas y afluencia por hora
            TourStep(
              tourKey: controller.keyResumen,
              title: 'Resumen',
              description: 'Cuántos entraron y a qué hora hay más gente.',
              borderRadius: 20,
              child: Column(
                children: [
                  _buildStatsSection(context),
                  _buildFranjasSection(context),
                ],
              ),
            ),
          ],

          // Lista de logs
          lista: TourStep(
            tourKey: controller.keyLista,
            title: 'Historial de accesos',
            description: 'Quién entró y a qué hora.',
            isLastStep: true,
            child: _buildLogsList(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Obx(() {
        return Row(
          children: [
            _buildStatCard(
              context,
              'Entradas',
              '${controller.totalEntries.value}',
              AppColors.success,
            ),
            // Solo tiene sentido si el gimnasio registra salidas.
            if (controller.muestraSalidas)
              _buildStatCard(
                context,
                'Salidas',
                '${controller.totalExits.value}',
                AppColors.warning,
              ),
            _buildStatCard(
              context,
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
  Widget _buildFranjasSection(BuildContext context) {
    final c = context.colores;
    return Obx(() {
      final porFranja = controller.entradasPorFranja;
      final maximo = controller.maximoPorFranja;
      if (porFranja.isEmpty || maximo == 0) return const SizedBox.shrink();

      final pico = controller.franjaPico;
      final expandido = controller.franjasExpandidas.value;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // El encabezado entero es el botón: el área de toque es más
            // holgada que la del icono solo.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: controller.alternarFranjas,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Entradas por hora',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    expandido ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
            if (expandido) const SizedBox(height: 8),
            if (expandido)
              for (final entrada in porFranja.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        // "10 a.m. – 12 p.m." es lo más ancho que puede salir.
                        width: 116,
                        child: Text(
                          controller.etiquetaFranja(entrada.key),
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
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
                            backgroundColor: c.containerBackground,
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
                            color: c.textPrimary,
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

  Widget _buildStatCard(
      BuildContext context, String title, String value, Color color) {
    final c = context.colores;
    return Expanded(
      child: Container(
        height: 88,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: c.cardBackground,
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
              // "10 a.m. – 12 p.m." no cabe al mismo tamaño que un número suelto;
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
                color: c.textSecondary,
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

  Widget _buildLogsList(BuildContext context) {
    final c = context.colores;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        if (controller.isLoading.value) {
          return CentradoDesplazable(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 16),
                Text(
                  'Cargando logs de acceso...',
                  style: TextStyle(color: c.textPrimary),
                ),
              ],
            ),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return CentradoDesplazable(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(
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
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Mostrar todos los logs sin filtros
        if (controller.accessLogs.isEmpty) {
          return CentradoDesplazable(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: c.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sin entradas en este periodo',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshData,
          color: AppColors.accent,
          child: ListView.builder(
            itemCount: controller.accessLogs.length,
            itemBuilder: (context, index) {
              final log = controller.accessLogs[index];
              return _buildLogCard(context, log);
            },
          ),
        );
      }),
    );
  }

  Widget _buildLogCard(BuildContext context, AccessLogModel log) {
    final c = context.colores;
    final isEntry = log.accessType == 'entrada';
    // Una visita (pagó el día sin registrarse) solo marca la entrada: se
    // rotula "Visita" para que no parezca que le falta la salida.
    final esVisita = log.method == 'visita';
    final color = esVisita
        ? Colors.teal
        : (isEntry ? AppColors.success : AppColors.error);
    final icon = esVisita
        ? Icons.confirmation_number_outlined
        : (isEntry ? Icons.login : Icons.logout);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: c.cardBackground,
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
                      color: c.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Staff: ${log.staffUser}',
                    style: TextStyle(
                      color: c.textSecondary,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    esVisita ? 'VISITA' : log.accessType.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  HoraFormato.fechaYHora(log.accessTime),
                  style: TextStyle(
                    color: c.textSecondary,
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

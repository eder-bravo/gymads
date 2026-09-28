import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/point_of_sale_controller.dart';
import '../../../../core/theme/app_colors.dart';

class SalesStatsWidget extends GetView<PointOfSaleController> {
  const SalesStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas de Hoy',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: controller.getQuickStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }
              
              if (snapshot.hasError) {
                return const Text(
                  'Error al cargar estadísticas',
                  style: TextStyle(color: AppColors.error),
                );
              }
              
              final stats = snapshot.data ?? {};
              
              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(context,
                      'Ventas',
                      '${stats['today_count'] ?? 0}',
                      Icons.receipt,
                      AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(context,
                      'Total',
                      '\$${(stats['today_total'] ?? 0.0).toStringAsFixed(2)}',
                      Icons.attach_money,
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(context,
                      'Promedio',
                      '\$${(stats['average_sale'] ?? 0.0).toStringAsFixed(2)}',
                      Icons.trending_up,
                      AppColors.accent,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.containerBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/cached_user_image.dart';
import 'package:intl/intl.dart';

class ClienteCard extends StatelessWidget {
  final UserModel cliente;
  final VoidCallback onTap;

  const ClienteCard({
    super.key,
    required this.cliente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // Formatear fecha de expiración
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final String expirationDateText = cliente.expirationDate != null
        ? dateFormatter.format(cliente.expirationDate!)
        : 'Sin límite de fecha';

    // Determinar colores según el estado
    final bool isExpired =
        cliente.daysRemaining <= 0 && cliente.expirationDate != null;

    final Color primaryColor = !cliente.isActive || isExpired
        ? AppColors.error // Rojo para inactivo o vencido
        : cliente.needsRenewal
            ? AppColors.warning // Naranja para por vencer (5 días o menos)
            : AppColors.info; // Azul para activo

    final Color statusColor = primaryColor.withOpacity(0.1);

    // Texto del estado
    final String statusText = !cliente.isActive
        ? 'Inactivo'
        : isExpired
            ? 'Vencido'
            : cliente.needsRenewal
                ? 'Por vencer'
                : 'Activo';

    // Icono según el estado
    final IconData statusIcon = !cliente.isActive || isExpired
        ? Icons.cancel_rounded // X para inactivo o vencido
        : cliente.needsRenewal
            ? Icons.warning_rounded // Advertencia para por vencer
            : Icons.check_circle_rounded; // Check para activo

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: c.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.5),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                // Encabezado con estado
                Container(
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 20, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (cliente.daysRemaining > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryColor, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${cliente.daysRemaining} días',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Contenido principal
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar del cliente con caché optimizado
                      Hero(
                        tag: 'avatar_${cliente.id}',
                        // Con estilo de texto propio: al volar entre la lista
                        // y la ficha, las iniciales (cliente sin foto) salían
                        // subrayadas en amarillo.
                        flightShuttleBuilder: _vueloConEstilo,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: UserThumbnail(
                            imageUrl: cliente.photoUrl,
                            userName: cliente.name,
                            size: 60,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Información del cliente
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nombre del cliente
                            Text(
                              cliente.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            _buildInfoRow(context,
                              Icons.event_available_rounded,
                              'Puede entrar hasta: $expirationDateText',
                              primaryColor,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(context,
                              Icons.phone_rounded,
                              cliente.phone,
                              primaryColor,
                            ),
                          ],
                        ),
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

  // Widget para filas de información
  Widget _buildInfoRow(BuildContext context, IconData icon, String text, Color color,
      {bool allowWrap = false}) {
    final c = context.colores;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: c.textSecondary),
            maxLines: allowWrap ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

}

/// El avatar mientras vuela entre la lista y la ficha, dentro de un
/// `Material`: fuera de la pantalla no hay estilo de texto y Flutter subraya
/// en amarillo las iniciales de un cliente sin foto.
Widget _vueloConEstilo(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  // Como hace Flutter por defecto: vuela la versión del destino.
  final hero = toContext.widget as Hero;
  return Material(type: MaterialType.transparency, child: hero.child);
}

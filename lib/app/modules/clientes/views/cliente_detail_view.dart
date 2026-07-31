import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/cached_user_image.dart';
import 'package:gymads/app/core/utils/phone_utils.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';
import '../controllers/clientes_controller.dart';

class ClienteDetailView extends GetView<ClientesController> {
  final UserModel cliente;

  const ClienteDetailView({
    super.key,
    required this.cliente,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Detalles del Cliente'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cabecera con foto y nombre
            _buildHeader(),

            const SizedBox(height: 16),

            // Tarjetas de información rápida
            _buildQuickInfoCards(),

            const SizedBox(height: 16),

            // Detalles generales (incluyendo los nuevos campos email y address)
            _buildDetailCards(),

            const SizedBox(height: 16),

            // Botones de acción principales
            _buildActionButtons(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Foto de perfil con animación Hero
          Hero(
            tag: 'avatar_${cliente.id}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: UserThumbnail(
                imageUrl: cliente.photoUrl,
                userName: cliente.name,
                size: 130,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Nombre del cliente
          Flexible(
            child: Text(
              cliente.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.titleColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (context) => _buildInfoCard(
                icon: Icons.phone_outlined,
                title: 'Teléfono',
                value: cliente.phone,
                color: AppColors.info,
                trailing: const Icon(Icons.touch_app_outlined,
                    color: AppColors.info, size: 18),
                onTap: () => PhoneUtils.showActions(context, cliente.phone),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Builder(
              builder: (context) {
                final bool vinculado = cliente.rfidCard != null &&
                    cliente.rfidCard!.trim().isNotEmpty;
                return _buildInfoCard(
                  icon: Icons.vpn_key_outlined,
                  title: 'Llavero/Tarjeta',
                  value: vinculado ? 'Vinculado' : 'No vinculado',
                  color: vinculado
                      ? AppColors.success
                      : AppColors.textSecondary,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final card = Container(
      height: 120, // Altura fija para que tengan el mismo tamaño
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const Spacer(), // Empuja el texto hacia abajo
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildDetailCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Card de información de contacto extendida
          _buildDetailCard(
            title: 'Contacto y Dirección',
            icon: Icons.contact_mail_outlined,
            children: [
              _buildDetailRow(
                'Correo',
                cliente.email?.isNotEmpty == true ? cliente.email! : 'No registrado',
                Icons.email_outlined,
              ),
              _buildDetailRow(
                'Dirección',
                cliente.address?.isNotEmpty == true ? cliente.address! : 'No registrada',
                Icons.location_on_outlined,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Card de fechas importantes
          _buildDetailCard(
            title: 'Fechas Importantes',
            icon: Icons.calendar_today_outlined,
            children: [
              _buildDetailRow(
                'Fecha de registro',
                _formatDate(cliente.joinDate),
                Icons.today_outlined,
              ),
              if (cliente.expirationDate != null)
                _buildDetailRow(
                  'Hasta qué fecha puede entrar',
                  _formatDate(cliente.expirationDate!),
                  Icons.event_outlined,
                ),
              if (cliente.lastPaymentDate != null)
                _buildDetailRow(
                  'Último pago',
                  _formatDate(cliente.lastPaymentDate!),
                  Icons.payment_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.titleColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.titleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.titleColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Abonar',
                  icon: Icons.payment,
                  color: AppColors.success,
                  onPressed: _abonarCliente,
                  isOutlined: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  color: AppColors.titleColor,
                  onPressed: _editCliente,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  label: 'Eliminar',
                  icon: Icons.delete_outline,
                  color: AppColors.error,
                  onPressed: _deleteCliente,
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 52,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 1.5),
                backgroundColor: color.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: color.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }

  // Funciones para manejar las acciones
  void _editCliente() {
    controller.setupFormForEdit(cliente);

    Get.to(
      () => ClienteFormDialog(
        nombreController: controller.nombreController,
        phoneController: controller.phoneController,
        emailController: controller.emailController,
        addressController: controller.addressController,
        userNumberController: controller.userNumberController,
        rfidController: controller.rfidController,
        currentPhotoUrl: cliente.photoUrl,
        onSave: (updatedUser, photoFile) {
          final user = updatedUser.copyWith(
            id: cliente.id,
            joinDate: cliente.joinDate,
            accessHistory: cliente.accessHistory,
            photoUrl: photoFile == null ? cliente.photoUrl : null,
          );

          controller.updateCliente(cliente.id!, user, photoFile: photoFile);
          Get.back(); // Cerrar el formulario
          Get.back(); // Volver a la lista de clientes
        },
        isEditing: true,
        fullScreen: true,
      ),
      fullscreenDialog: true,
    );
  }

  void _abonarCliente() {
    Get.back(); // Volver a la lista de clientes
    // Navegar al módulo de abonar pre-seleccionando al cliente, asumiendo ruta /abonar
    Get.toNamed('/abonar', arguments: {'cliente': cliente});
  }

  void _deleteCliente() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar Cliente',
          style: TextStyle(
            color: AppColors.titleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${cliente.name}?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(); // Cerrar dialog
              Get.back(); // Volver a lista
              controller.deleteCliente(cliente.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

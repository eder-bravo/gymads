import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/data/models/user_model.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:gymads/app/core/widgets/cached_user_image.dart';
import 'package:gymads/app/core/utils/phone_utils.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/app/global_widgets/cliente_form_dialog.dart';
import '../controllers/clientes_controller.dart';
import 'package:gymads/app/modules/abonar/controllers/abonar_controller.dart';
import 'package:gymads/app/core/widgets/formulario.dart';
import 'package:gymads/app/global_widgets/foto_ampliada.dart';

class ClienteDetailView extends GetView<ClientesController> {
  final UserModel cliente;

  const ClienteDetailView({
    super.key,
    required this.cliente,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      anchoMaximo: 960,
      backgroundColor: c.backgroundColor,
      appBar: GymAppBar(
          title: PlataformaApp.elegir(
              escritorio: 'Detalle del cliente',
              movil: 'Detalles del Cliente')),
      // SafeArea: de lado, el notch tapaba el borde izquierdo de la ficha.
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Cabecera con foto y nombre
              _buildHeader(context),

              const SizedBox(height: 16),

              // Tarjetas de información rápida
              _buildQuickInfoCards(context),

              const SizedBox(height: 16),

              // Detalles generales (incluyendo los nuevos campos email y address)
              _buildDetailCards(context),

              const SizedBox(height: 16),

              // Botones de acción principales
              _buildActionButtons(context),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final c = context.colores;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.backgroundColor,
        borderRadius: const BorderRadius.only(
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
            // Ver la nota en ClienteCard: sin esto las iniciales volaban
            // subrayadas en amarillo.
            flightShuttleBuilder:
                (context, animation, direction, desde, hacia) => Material(
                    type: MaterialType.transparency,
                    child: (hacia.widget as Hero).child),
            child: GestureDetector(
              // Tocar la foto la abre en grande.
              onTap: (cliente.photoUrl?.isNotEmpty ?? false)
                  ? () => mostrarFotoAmpliada(cliente.photoUrl!,
                      nombre: cliente.name)
                  : null,
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
          ),
          const SizedBox(width: 16),
          // Nombre del cliente
          Flexible(
            child: Text(
              cliente.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: c.titleColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCards(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ResumenAdaptable(
        anchoMinimo: 220,
        espacio: 16,
        children: [
          Builder(
            builder: (context) => _buildInfoCard(
              context,
              icon: Icons.phone_outlined,
              title: 'Teléfono',
              value: cliente.phone,
              color: AppColors.info,
              // En escritorio dice qué pasa al hacer clic; el dedo de
              // "toca aquí" no aplica con mouse.
              trailing: PlataformaApp.escritorio
                  ? const Text('Llamar o WhatsApp',
                      style: TextStyle(
                          color: AppColors.info,
                          fontSize: 14,
                          fontWeight: FontWeight.w600))
                  : const Icon(Icons.touch_app_outlined,
                      color: AppColors.info, size: 18),
              onTap: () => PhoneUtils.showActions(context, cliente.phone),
            ),
          ),
          Builder(
            builder: (context) {
              final bool vinculado = cliente.rfidCard != null &&
                  cliente.rfidCard!.trim().isNotEmpty;
              return _buildInfoCard(
                context,
                icon: Icons.vpn_key_outlined,
                title: 'Llavero/Tarjeta',
                value: vinculado ? 'Vinculado' : 'No vinculado',
                color: vinculado ? AppColors.success : c.textSecondary,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final c = context.colores;
    final card = Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBackground,
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
                  style: TextStyle(
                    fontSize: legible(12),
                    color: c.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                // En escritorio el aviso es texto: que se ajuste al ancho.
                PlataformaApp.escritorio ? Flexible(child: trailing) : trailing,
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
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

  Widget _buildDetailCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Card de información de contacto extendida
          _buildDetailCard(
            context,
            title: PlataformaApp.elegir(
                escritorio: 'Contacto y dirección',
                movil: 'Contacto y Dirección'),
            icon: Icons.contact_mail_outlined,
            children: [
              _buildDetailRow(
                context,
                'Correo',
                cliente.email?.isNotEmpty == true
                    ? cliente.email!
                    : 'No registrado',
                Icons.email_outlined,
              ),
              _buildDetailRow(
                context,
                'Dirección',
                cliente.address?.isNotEmpty == true
                    ? cliente.address!
                    : 'No registrada',
                Icons.location_on_outlined,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Card de fechas importantes
          _buildDetailCard(
            context,
            title: PlataformaApp.elegir(
                escritorio: 'Fechas importantes', movil: 'Fechas Importantes'),
            icon: Icons.calendar_today_outlined,
            children: [
              _buildDetailRow(
                context,
                'Fecha de registro',
                _formatDate(cliente.joinDate),
                Icons.today_outlined,
              ),
              if (cliente.expirationDate != null)
                _buildDetailRow(
                  context,
                  'Hasta qué fecha puede entrar',
                  _formatDate(cliente.expirationDate!),
                  Icons.event_outlined,
                ),
              if (cliente.lastPaymentDate != null)
                _buildDetailRow(
                  context,
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

  Widget _buildDetailCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final c = context.colores;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.titleColor.withOpacity(0.1),
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
                  color: c.titleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: c.titleColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.titleColor,
                ),
              )),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value, IconData icon) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: c.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final c = context.colores;
    // En escritorio, una fila de botones a la derecha, la acción principal al
    // final, como en las ventanas del sistema.
    if (PlataformaApp.escritorio) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              label: 'Eliminar',
              icon: Icons.delete_outline,
              color: AppColors.error,
              onPressed: () => _deleteCliente(context),
              isOutlined: true,
            ),
            _buildActionButton(
              label: 'Editar',
              icon: Icons.edit_outlined,
              color: c.titleColor,
              onPressed: _editCliente,
              isOutlined: true,
            ),
            _buildActionButton(
              label: 'Abonar',
              icon: Icons.payment,
              color: AppColors.success,
              onPressed: _abonarCliente,
            ),
          ],
        ),
      );
    }
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
          ResumenAdaptable(
            anchoMinimo: 180,
            espacio: 16,
            children: [
              _buildActionButton(
                label: 'Editar',
                icon: Icons.edit_outlined,
                color: c.titleColor,
                onPressed: _editCliente,
                isOutlined: true,
              ),
              _buildActionButton(
                label: 'Eliminar',
                icon: Icons.delete_outline,
                color: AppColors.error,
                onPressed: () => _deleteCliente(context),
                isOutlined: true,
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
    return Container(
      width: isFullWidth ? double.infinity : null,
      constraints: PlataformaApp.escritorio
          ? const BoxConstraints(minHeight: 44, minWidth: 140)
          : const BoxConstraints(minHeight: 52),
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

    abrirFormulario(
      () => ClienteFormDialog(
        nombreController: controller.nombreController,
        phoneController: controller.phoneController,
        emailController: controller.emailController,
        addressController: controller.addressController,
        userNumberController: controller.userNumberController,
        rfidController: controller.rfidController,
        tarjetaOriginal: cliente.rfidCard,
        currentPhotoUrl: cliente.photoUrl,
        onSave: (updatedUser, photoFile) async {
          final user = updatedUser.copyWith(
            id: cliente.id,
            joinDate: cliente.joinDate,
            accessHistory: cliente.accessHistory,
            photoUrl: photoFile == null ? cliente.photoUrl : null,
            // Conservar los datos de vigencia: el formulario no los edita y
            // enviarlos vacíos borraría la vigencia del cliente en la BD.
            expirationDate: cliente.expirationDate,
            lastPaymentDate: cliente.lastPaymentDate,
            isActive: cliente.isActive,
          );

          // Se cierra solo si se guardó: si falla (sin conexión, tarjeta de
          // otro cliente) el formulario sigue abierto con lo escrito.
          final guardado = await controller.updateCliente(cliente.id!, user,
              photoFile: photoFile);
          if (!guardado) return;
          Get.back(); // Cerrar el formulario
          Get.back(); // Volver a la lista de clientes
        },
        guardando: controller.guardandoCliente,
        isEditing: true,
        fullScreen: true,
      ),
    );
  }

  void _abonarCliente() {
    Get.back(); // Volver a la lista de clientes
    // Navegar al módulo de abonar pre-seleccionando al cliente, asumiendo ruta /abonar
    Get.toNamed('/abonar', arguments: {
      'cliente': cliente,
      'alTerminar': AlTerminarAbono.volverAClientes,
    });
  }

  void _deleteCliente(BuildContext context) {
    final c = context.colores;
    Get.dialog(
      AlertDialog(
        scrollable: true,
        backgroundColor: c.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar cliente',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${cliente.name}?\n\nEsta acción no se puede deshacer.',
          style: TextStyle(color: c.textPrimary),
        ),
        actions: [
          BotonCancelar(onPressed: () => Get.back()),
          BotonGuardar(
            texto: 'Eliminar',
            compacto: true,
            color: AppColors.error,
            onPressed: () {
              Get.back(); // Cerrar dialog
              Get.back(); // Volver a lista
              controller.deleteCliente(cliente.id!);
            },
          ),
        ],
      ),
    );
  }
}

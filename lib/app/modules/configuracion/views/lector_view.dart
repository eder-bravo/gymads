import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/config/rfid_config.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/configuracion_controller.dart';

/// El lector de tarjetas de este gimnasio: a qué IP está y a quién pertenece.
///
/// Un lector solo atiende al gimnasio que lo reclamó. Sin eso, dos gimnasios
/// en la misma red WiFi recibían la alerta del mismo pase de tarjeta, porque
/// el aparato contestaba a cualquiera que preguntara.
class LectorView extends StatefulWidget {
  const LectorView({super.key});

  @override
  State<LectorView> createState() => _LectorViewState();
}

class _LectorViewState extends State<LectorView> {
  ConfiguracionController get controller => Get.find<ConfiguracionController>();

  late final TextEditingController _ipCtrl;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(
      text: controller.esp32IpAddress.value.isNotEmpty
          ? controller.esp32IpAddress.value
          : RfidConfig.getCurrentIP() ?? '',
    );

    // Se pregunta al entrar, no en build: build se repite y volvería a
    // consultar al lector en cada frame.
    if (RfidConfig.isConfigured) {
      controller.comprobarLector();
    }
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  String get _ip => _ipCtrl.text.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const GymAppBar(title: 'Lector de tarjetas'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() => _tarjetaEstado()),
              const SizedBox(height: 20),
              _campoIp(),
              const SizedBox(height: 16),
              Obx(() => _acciones()),
              const SizedBox(height: 24),
              _interruptorLector(),
              const SizedBox(height: 24),
              _ayuda(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Estado actual
  // ─────────────────────────────────────────────────────────

  Widget _tarjetaEstado() {
    final estado = controller.estadoLector.value;

    late final IconData icono;
    late final Color color;
    late final String titulo;
    late final String detalle;

    switch (estado) {
      case EstadoLector.mio:
        icono = Icons.verified_user;
        color = AppColors.success;
        titulo = 'Vinculado a tu gimnasio';
        detalle = 'Este lector solo atiende a tu gimnasio. '
            'Ningún otro puede leer tus tarjetas.';
        break;
      case EstadoLector.libre:
        icono = Icons.lock_open;
        color = AppColors.warning;
        titulo = 'Lector sin vincular';
        detalle = 'Todavía no pertenece a ningún gimnasio. '
            'Vincúlalo para que solo responda al tuyo.';
        break;
      case EstadoLector.deOtroGimnasio:
        icono = Icons.block;
        color = AppColors.error;
        titulo = 'Es de otro gimnasio';
        detalle = 'Este lector ya fue vinculado por otro gimnasio y no va a '
            'responder al tuyo. Su dueño tiene que liberarlo, o hay que '
            'reiniciarlo de fábrica con el botón del aparato.';
        break;
      case EstadoLector.sinConexion:
        icono = Icons.wifi_off;
        color = AppColors.error;
        titulo = 'No responde';
        detalle = 'Revisa que el lector esté encendido y conectado a la misma '
            'red WiFi que este teléfono.';
        break;
      case EstadoLector.sinConfigurar:
        icono = Icons.nfc;
        color = AppColors.textSecondary;
        titulo = 'Sin lector configurado';
        detalle = 'Escribe la dirección IP del lector para empezar.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // IP del lector
  // ─────────────────────────────────────────────────────────

  Widget _campoIp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dirección IP del lector',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ipCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: '192.168.1.100',
            hintStyle: TextStyle(color: AppColors.textHint.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.containerBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Acciones, según el estado
  // ─────────────────────────────────────────────────────────

  Widget _acciones() {
    if (controller.comprobandoLector.value) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final estado = controller.estadoLector.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _boton(
          texto: 'Buscar lector en esa IP',
          icono: Icons.search,
          color: AppColors.info,
          onTap: () => controller.comprobarLector(ip: _ip),
        ),

        // Solo se ofrece vincular cuando el lector dijo que está libre:
        // intentarlo sobre uno ajeno devuelve 409 y no lleva a ningún lado.
        if (estado == EstadoLector.libre) ...[
          const SizedBox(height: 10),
          _boton(
            texto: 'Vincular a mi gimnasio',
            icono: Icons.link,
            color: AppColors.success,
            onTap: () => controller.vincularLector(_ip),
          ),
        ],

        if (estado == EstadoLector.mio) ...[
          const SizedBox(height: 10),
          _boton(
            texto: 'Cambiar la IP del lector',
            icono: Icons.settings_ethernet,
            color: AppColors.info,
            onTap: _confirmarCambioIp,
          ),
          const SizedBox(height: 10),
          _boton(
            texto: 'Desvincular',
            icono: Icons.link_off,
            color: AppColors.error,
            onTap: _confirmarDesvincular,
          ),
        ],
      ],
    );
  }

  Widget _boton({
    required String texto,
    required IconData icono,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 18),
        label: Text(texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _confirmarDesvincular() async {
    final confirmado = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Desvincular el lector',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'El lector dejará de responder a tu gimnasio y cualquier otro podrá '
          'reclamarlo. Podrás volver a vincularlo cuando quieras.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Desvincular',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmado == true) await controller.desvincularLector();
  }

  Future<void> _confirmarCambioIp() async {
    // Cambiar la IP reinicia el aparato y corta la conexión en curso, así que
    // conviene avisar antes: durante unos segundos parecerá que no responde.
    final confirmado = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cambiar la IP',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'El lector se reiniciará para quedarse en $_ip y tardará unos '
          'segundos en volver. Úsalo si tienes más de un lector en la misma '
          'red, para que no se estorben entre ellos.',
          style: const TextStyle(
              color: AppColors.textSecondary, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Cambiar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmado == true) await controller.cambiarIpLector(_ip);
  }

  // ─────────────────────────────────────────────────────────
  // Interruptor general
  // ─────────────────────────────────────────────────────────

  Widget _interruptorLector() {
    return Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.rfidEnabled.value,
            activeColor: AppColors.accent,
            title: const Text('Usar el lector de tarjetas',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(
              controller.connectionStatusMessage.value,
              style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontSize: 13),
            ),
            onChanged: (activar) {
              if (activar) {
                controller.testRfidConnection();
              } else {
                controller.cancelRfidScan();
              }
            },
          ),
        ));
  }

  Widget _ayuda() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.containerBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¿Perdiste el acceso a un lector? Desconéctalo y vuelve a '
              'conectarlo, y en los primeros 10 segundos mantén pulsado el '
              'botón BOOT unos 3 segundos: sonará un pitido corto al empezar '
              'y uno largo al confirmar. Quedará libre para vincularlo de '
              'nuevo.',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.9),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

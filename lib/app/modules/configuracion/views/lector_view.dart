import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/permissions.dart';
import '../../../data/config/rfid_config.dart';
import '../../../data/services/background_rfid_service.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/configuracion_controller.dart';
import 'agregar_lector_view.dart';

/// El lector de tarjetas de este gimnasio.
///
/// Nadie tiene que saber de IPs: "Agregar lector" lo configura por
/// Bluetooth y la app lo encuentra sola en la red. La IP no aparece en
/// ninguna parte.
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

  @override
  void initState() {
    super.initState();

    // Se pregunta al entrar, no en build: build se repite y volvería a
    // consultar al lector en cada frame.
    _cargar();
  }

  /// Con "Usar el lector" apagado la configuración guardada no se había
  /// leído, y la pantalla decía "Sin lector" aunque hubiera uno.
  Future<void> _cargar() async {
    controller.comprobandoLector.value = true;
    // Carga el lector de ESTE gimnasio y su interruptor "Usar el lector".
    await controller.cargarEstadoLector();
    if (!mounted) return;
    controller.comprobandoLector.value = false;

    controller.lectorEncontrado.value = null;
    if (RfidConfig.isConfigured) {
      await controller.comprobarLector();
    } else {
      // El gimnasio puede tener lector registrado aunque ahora no conteste
      // (apagado, sin WiFi, recién formateado): no es lo mismo que no tener.
      controller.estadoLector.value = RfidConfig.tieneLector
          ? EstadoLector.sinConexion
          : EstadoLector.sinConfigurar;
    }
  }

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
              Obx(() => _acciones()),
              const SizedBox(height: 24),
              _interruptorLector(),
              if (controller.can(Permission.gestionarControlAccesos) &&
                  Get.isRegistered<BackgroundRfidService>()) ...[
                const SizedBox(height: 12),
                _interruptorAvisosAqui(),
              ],
              const SizedBox(height: 16),
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
        titulo = RfidConfig.nombreLector == null
            ? 'Vinculado a tu gimnasio'
            : '${RfidConfig.nombreLector} · vinculado a tu gimnasio';
        detalle = 'Este lector solo atiende a tu gimnasio. '
            'Ningún otro puede leer tus tarjetas.';
        break;
      case EstadoLector.libre:
        icono = Icons.lock_open;
        color = AppColors.warning;
        titulo = controller.lectorEncontrado.value == null
            ? 'Lector sin vincular'
            : '${controller.lectorEncontrado.value!.nombre} · sin vincular';
        detalle = 'Encontré este lector en tu red y todavía no pertenece a '
            'ningún gimnasio. Vincúlalo para que solo responda al tuyo.';
        break;
      case EstadoLector.deOtroGimnasio:
        icono = Icons.block;
        color = AppColors.error;
        titulo = 'Es de otro gimnasio';
        detalle = 'Este lector ya fue vinculado por otro gimnasio y no va a '
            'responder al tuyo. Si el aparato es tuyo, puedes formatearlo '
            'para dejarlo libre y vincularlo de nuevo.';
        break;
      case EstadoLector.sinConexion:
        icono = Icons.wifi_off;
        color = AppColors.error;
        titulo = RfidConfig.nombreLector == null
            ? 'Tu lector no aparece'
            : '${RfidConfig.nombreLector} no aparece';
        detalle = 'Tu gimnasio tiene un lector, pero no está en la red de este '
            'teléfono. Si está apagado, enciéndelo. Si su luz parpadea '
            'rápido, perdió su WiFi o lo reiniciaron: toca "Configurar el '
            'lector".';
        break;
      case EstadoLector.sinConfigurar:
        icono = Icons.nfc;
        color = AppColors.textSecondary;
        titulo = 'Sin lector';
        detalle = 'Agrega tu lector: la app lo configura por Bluetooth, sin '
            'escribir direcciones.';
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
        if (estado == EstadoLector.sinConfigurar) ...[
          _boton(
            texto: 'Agregar lector',
            icono: Icons.add,
            color: AppColors.accent,
            onTap: () => _abrirAsistente(cambiarWifi: false),
          ),
          const SizedBox(height: 10),
          _botonSecundario(
            texto: 'Ya tengo uno funcionando: buscarlo',
            icono: Icons.wifi_find,
            onTap: controller.buscarLectorEnRed,
          ),
        ],

        if (estado == EstadoLector.sinConexion) ...[
          // Si perdió el WiFi o lo reiniciaron, se está ofreciendo por
          // Bluetooth: configurarlo lo vuelve a dejar funcionando (y lo
          // vuelve a vincular si quedó libre).
          _boton(
            texto: 'Configurar el lector',
            icono: Icons.bluetooth_searching,
            color: AppColors.accent,
            onTap: _cambiarWifi,
          ),
          const SizedBox(height: 10),
          _botonSecundario(
            texto: 'Buscar de nuevo en la red',
            icono: Icons.wifi_find,
            onTap: controller.buscarLectorEnRed,
          ),
        ],

        // Solo se ofrece vincular cuando el lector dijo que está libre:
        // intentarlo sobre uno ajeno devuelve 409 y no lleva a ningún lado.
        if (estado == EstadoLector.libre)
          _boton(
            texto: 'Vincular a mi gimnasio',
            icono: Icons.link,
            color: AppColors.success,
            onTap: () => controller.vincularLector(_ipObjetivo),
          ),

        // Formatear un lector ajeno: es la salida para recuperar un aparato
        // vinculado a un gimnasio al que ya no se tiene acceso.
        if (estado == EstadoLector.deOtroGimnasio)
          _boton(
            texto: 'Formatear lector',
            icono: Icons.restart_alt,
            color: AppColors.error,
            onTap: _confirmarFormateo,
          ),

        if (estado == EstadoLector.mio) ...[
          _botonSecundario(
            texto: 'Cambiar WiFi del lector',
            icono: Icons.wifi,
            onTap: _cambiarWifi,
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

  /// La IP del lector sobre el que se actúa en "Vincular" y "Formatear": el
  /// que encontró la búsqueda en la red, o el ya guardado.
  String get _ipObjetivo =>
      controller.lectorEncontrado.value?.ip ?? RfidConfig.getCurrentIP() ?? '';

  Future<void> _abrirAsistente({required bool cambiarWifi}) async {
    await abrirAgregarLector(cambiarWifi: cambiarWifi);
    if (!mounted) return;
    if (RfidConfig.isConfigured) {
      await controller.comprobarLector();
    }
  }

  /// Si el lector contesta, se le pide que se ofrezca por Bluetooth unos
  /// minutos. Si no contesta (perdió el WiFi, lo reiniciaron), ya se está
  /// ofreciendo solo: se abre el asistente directamente.
  Future<void> _cambiarWifi() async {
    final conectado = controller.estadoLector.value == EstadoLector.mio;
    if (conectado) await RfidConfig.abrirModoConfiguracion();
    await _abrirAsistente(cambiarWifi: conectado);
  }

  Widget _botonSecundario({
    required String texto,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 18),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
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
        scrollable: true,
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Desvincular el lector',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'El lector olvidará tu gimnasio y tu WiFi, y se reiniciará. Quedará '
          'listo para agregarse en cualquier lugar (su luz parpadea rápido).\n\n'
          'Para volver a usarlo aquí, agrégalo de nuevo con "Agregar lector".',
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

  Future<void> _confirmarFormateo() async {
    final confirmado = await Get.dialog<bool>(
      AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Formatear el lector',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Este lector pertenece a otro gimnasio. Al formatearlo dejará de '
          'funcionarle a ese gimnasio de inmediato, y quedará libre para que '
          'lo vincules al tuyo.\n\n'
          'El lector pitará mientras se formatea. Hazlo solo si el aparato es '
          'tuyo.',
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
            child:
                const Text('Formatear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmado == true) await controller.formatearLector(_ipObjetivo);
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

  /// Recibir los avisos del lector en este teléfono aunque haya alguien de
  /// mostrador.
  ///
  /// Por defecto los avisos le tocan al mostrador. Si ese teléfono no está
  /// en el gimnasio (o el perfil de mostrador es de prueba), nadie los
  /// recibía; esto permite que el dueño o el encargado los tomen.
  Widget _interruptorAvisosAqui() {
    final servicio = Get.find<BackgroundRfidService>();

    return Obx(() {
      final activo = servicio.recibirAvisosAqui.value;
      final atiende = servicio.atiendeLector.value;
      final motivo = servicio.motivoSinAvisos.value;

      final String detalle;
      if (atiende && activo) {
        detalle = 'Este teléfono recibe los avisos del lector. Si el '
            'mostrador también tiene la app abierta, el aviso sale en los '
            'dos; la entrada se registra una sola vez.';
      } else if (atiende) {
        detalle = 'Este teléfono ya recibe los avisos del lector.';
      } else {
        detalle = '${motivo ?? 'Este teléfono no recibe los avisos.'} '
            'Actívalo para recibirlos aquí también.';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: activo,
          activeColor: AppColors.accent,
          title: const Text('Recibir avisos en este teléfono',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          subtitle: Text(
            detalle,
            style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8), fontSize: 13),
          ),
          onChanged: servicio.setRecibirAvisosAqui,
        ),
      );
    });
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
              'Para dejar el lector como nuevo: desconéctalo, vuelve a '
              'conectarlo y, en los primeros 10 segundos, mantén pulsado el '
              'botón BOOT unos 3 segundos. Suena un pitido corto al empezar '
              'y uno largo al confirmar. Olvida el WiFi y el gimnasio, y su '
              'luz parpadea rápido: ya se puede agregar de nuevo.',
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

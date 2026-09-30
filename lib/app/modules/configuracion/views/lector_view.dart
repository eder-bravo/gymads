import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/permissions/permissions.dart';
import '../../../data/config/rfid_config.dart';
import '../../../data/services/background_rfid_service.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/configuracion_controller.dart';
import 'agregar_lector_view.dart';
import '../widgets/ilustracion_lector.dart';
import '../../../core/widgets/formulario.dart';
import '../../../core/utils/snackbar_helper.dart';

/// Lo que dice la tarjeta de estado: solo el título. Sin explicaciones ni el
/// nombre técnico del aparato (GymOne-AB12); los detalles van en el manual
/// impreso.
String tituloDelEstado(EstadoLector estado) => switch (estado) {
      EstadoLector.mio => 'Lector conectado',
      EstadoLector.libre => 'Lector sin vincular',
      EstadoLector.deOtroGimnasio => 'Es de otro gimnasio',
      EstadoLector.sinConexion => 'Tu lector no aparece',
      EstadoLector.sinConfigurar => 'Sin lector',
    };

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
    final c = context.colores;
    return Scaffold(
      backgroundColor: c.backgroundColor,
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
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Estado actual
  // ─────────────────────────────────────────────────────────

  /// El lector dibujado: de un vistazo, si está conectado o no.
  Widget _tarjetaEstado() {
    final estado = controller.estadoLector.value;
    final reconectando = controller.reconectandoLector.value;
    return IlustracionLector(
      estado: estado,
      titulo: tituloDelEstado(estado),
      comprobando: controller.comprobandoLector.value,
      // Que nadie lo desconecte de la corriente: se está arreglando solo.
      textoComprobando: reconectando
          ? 'Reconectando el lector…'
          : controller.preparandoLector.value
              ? 'Preparando el lector…'
              : null,
      detalle: reconectando ? 'Tarda unos segundos. No lo desconectes.' : null,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Acciones, según el estado
  // ─────────────────────────────────────────────────────────

  Widget _acciones() {
    // Mientras lo busca, el dibujo ya lo dice: los botones salen al terminar.
    if (controller.comprobandoLector.value) return const SizedBox.shrink();

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
            texto: 'Buscar mi lector en la red',
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

  /// Con [cambiarWifi], el lector se reinició para ofrecerse por Bluetooth.
  /// Si se sale sin cambiarlo, tarda unos segundos en volver a su red: se
  /// dice "Reconectando" y se le espera, en vez de buscarlo una vez justo en
  /// ese hueco y decir que no aparece.
  Future<void> _abrirAsistente({required bool cambiarWifi}) async {
    final terminado = await abrirAgregarLector(cambiarWifi: cambiarWifi);
    if (!mounted) return;
    if (cambiarWifi && !terminado) {
      await controller.esperarRegresoDelLectorEnRed();
    } else if (RfidConfig.isConfigured) {
      await controller.comprobarLector();
    }
  }

  /// Si el lector contesta, se le pide que se ofrezca por Bluetooth unos
  /// minutos. Si no contesta (perdió el WiFi, lo reiniciaron), ya se está
  /// ofreciendo solo: se abre el asistente directamente.
  ///
  /// El lector se reinicia para ofrecerse (firmware 6.4.2+): tarda unos
  /// segundos, que el asistente cubre buscándolo. Si no aceptó el pedido (y
  /// no se estaba ofreciendo ya), no se abre el asistente: solo diría "no
  /// apareció ningún lector".
  Future<void> _cambiarWifi() async {
    final conectado = controller.estadoLector.value == EstadoLector.mio;
    if (conectado && !await controller.pedirModoConfiguracion()) {
      SnackbarHelper.error('No se pudo',
          'El lector no respondió. Revisa que esté encendido e intenta de nuevo.');
      return;
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Desvincular el lector'),
        content: const Text(
          'Olvidará tu gimnasio y tu WiFi. Para volver a usarlo, agrégalo de '
          'nuevo.',
          style: TextStyle(height: 1.35),
        ),
        actions: [
          BotonCancelar(onPressed: () => Get.back(result: false)),
          BotonGuardar(
            texto: 'Desvincular',
            compacto: true,
            color: AppColors.error,
            onPressed: () => Get.back(result: true),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Formatear el lector'),
        content: const Text(
          'Dejará de funcionarle al otro gimnasio y quedará libre para el '
          'tuyo. Hazlo solo si el aparato es tuyo.',
          style: TextStyle(height: 1.35),
        ),
        actions: [
          BotonCancelar(onPressed: () => Get.back(result: false)),
          BotonGuardar(
            texto: 'Formatear',
            compacto: true,
            color: AppColors.error,
            onPressed: () => Get.back(result: true),
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
    final c = context.colores;
    return Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: c.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.rfidEnabled.value,
            activeColor: AppColors.accent,
            title: Text('Usar el lector de tarjetas',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
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
    final c = context.colores;
    final servicio = Get.find<BackgroundRfidService>();

    return Obx(() {
      final activo = servicio.recibirAvisosAqui.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: c.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: activo,
          activeColor: AppColors.accent,
          title: Text('Recibir avisos en este teléfono',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          onChanged: servicio.setRecibirAvisosAqui,
        ),
      );
    });
  }
}

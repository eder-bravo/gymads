import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/config/rfid_config.dart';
import '../../../data/services/lector_ble_service.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/agregar_lector_controller.dart';

/// Abre el asistente. [cambiarWifi] solo cambia los textos: el camino es el
/// mismo para un lector nuevo que para uno al que se le cambia la red.
Future<void> abrirAgregarLector({bool cambiarWifi = false}) async {
  await Get.to<void>(
    () => AgregarLectorView(cambiarWifi: cambiarWifi),
    binding: BindingsBuilder(() {
      Get.put(AgregarLectorController());
    }),
  );
}

/// Agregar un lector (o cambiarle el WiFi) sin escribir ninguna IP.
class AgregarLectorView extends GetView<AgregarLectorController> {
  const AgregarLectorView({super.key, this.cambiarWifi = false});

  final bool cambiarWifi;

  @override
  Widget build(BuildContext context) {
    // En el paso de la contraseña, "atrás" (la flecha, el botón de Android o
    // el gesto de iOS) regresa a la lista de redes en vez de cerrar todo: lo
    // normal es que la persona se haya equivocado de red.
    return Obx(() => PopScope(
          canPop: controller.paso.value != PasoAgregar.escribirClave,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.volverARedes();
          },
          child: Scaffold(
            backgroundColor: AppColors.backgroundColor,
            appBar: GymAppBar(
                title: cambiarWifi
                    ? 'Cambiar WiFi del lector'
                    : 'Configurar lector'),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _paso(context),
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  Widget _paso(BuildContext context) {
    switch (controller.paso.value) {
      case PasoAgregar.buscando:
        return _buscando();
      case PasoAgregar.preparando:
        return _esperando(
          icono: Icons.bluetooth_connected,
          titulo: 'Lector encontrado',
          texto: 'Preguntándole qué redes WiFi ve...',
        );
      case PasoAgregar.elegirRed:
        return _elegirRed();
      case PasoAgregar.escribirClave:
        return _escribirClave(context);
      case PasoAgregar.conectando:
        return _esperando(
          icono: Icons.wifi,
          titulo: 'Conectando al WiFi...',
          texto: 'El lector está probando la red. Mientras tanto se '
              'desconecta del teléfono: es normal. Puede tardar hasta un '
              'minuto; no cierres esta pantalla.',
        );
      case PasoAgregar.comprobando:
        return _esperando(
          icono: Icons.wifi_find,
          titulo: 'Casi listo',
          texto: 'El lector se está reiniciando para empezar a trabajar. '
              'Buscándolo en la red...',
        );
      case PasoAgregar.listo:
        return _listo();
      case PasoAgregar.fallo:
        return _fallo();
    }
  }

  // ─────────────────────────────────────────────────────────

  Widget _buscando() {
    final varios = controller.lectores.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          icono: Icons.bluetooth_searching,
          titulo: varios ? '¿Cuál es tu lector?' : 'Buscando el lector...',
          texto: varios
              ? 'Hay más de un lector cerca. Elige el tuyo.'
              : cambiarWifi
                  ? 'Mantén el teléfono cerca del lector.'
                  : 'Conecta el lector a la corriente y deja el teléfono '
                      'cerca. Su luz parpadea rápido cuando está listo; si '
                      'viene de otro lugar, tarda unos 30 segundos en '
                      'empezar.',
        ),
        const SizedBox(height: 24),
        if (!varios)
          const Center(
              child: CircularProgressIndicator(color: AppColors.accent)),
        for (final lector in controller.lectores)
          if (varios)
            Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.nfc, color: AppColors.accent),
                title: Text(lector.nombre,
                    style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  _esDeEsteGimnasio(lector.nombre)
                      ? 'Es el lector de tu gimnasio'
                      : (lector.rssi > -60 ? 'Muy cerca' : 'Cerca'),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => controller.elegirLector(lector),
              ),
            ),
      ],
    );
  }

  /// Paso 1 del WiFi: solo la lista. Tocar una red lleva a su contraseña.
  Widget _elegirRed() {
    final redes = controller.redes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          icono: Icons.wifi,
          titulo: '¿A qué WiFi se conecta?',
          texto: redes.isEmpty
              ? 'El lector no vio ninguna red. Acércalo al módem y busca de '
                  'nuevo, o escribe el nombre de la red.'
              : 'Toca la red del gimnasio.',
        ),
        const SizedBox(height: 20),
        if (controller.mensaje.value != null) ...[
          _aviso(controller.mensaje.value!),
          const SizedBox(height: 16),
        ],
        if (controller.buscandoRedes.value)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.accent)),
          )
        else
          for (final red in redes) _filaRed(red),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: controller.buscandoRedes.value
                  ? null
                  : controller.actualizarRedes,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Buscar de nuevo'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary),
            ),
            const Spacer(),
            TextButton(
              onPressed: controller.elegirOtraRed,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: const Text('Otra red'),
            ),
          ],
        ),
      ],
    );
  }

  /// Paso 2 del WiFi: la contraseña de la red elegida (o el nombre, con
  /// "Otra red"). Siempre con la salida "Cambiar de red".
  Widget _escribirClave(BuildContext context) {
    final red = controller.redSeleccionada;
    final otraRed = controller.usarOtraRed.value;

    void conectar() {
      FocusScope.of(context).unfocus();
      controller.conectar();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          icono: Icons.wifi_password,
          titulo: otraRed ? 'Otra red' : (red?.ssid ?? 'Red elegida'),
          texto: otraRed
              ? 'Escribe el nombre de la red tal como aparece en el teléfono, '
                  'y su contraseña.'
              : controller.pideClave
                  ? 'Escribe la contraseña del WiFi.'
                  : 'Esta red no tiene contraseña.',
        ),
        const SizedBox(height: 20),
        if (controller.mensaje.value != null) ...[
          _aviso(controller.mensaje.value!),
          const SizedBox(height: 16),
        ],
        if (red?.senalDebil == true) ...[
          _aviso('La señal de esta red es débil donde está el lector. Si no '
              'conecta, acércalo al módem.'),
          const SizedBox(height: 16),
        ],
        if (otraRed) ...[
          TextField(
            controller: controller.otraRedCtrl,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _decoracion('Nombre de la red'),
          ),
          const SizedBox(height: 12),
        ],
        if (controller.pideClave) ...[
          TextField(
            key: const Key('campo_clave_wifi'),
            controller: controller.claveCtrl,
            // Recién elegida la red, el teclado aparece solo.
            autofocus: !otraRed,
            obscureText: !controller.mostrarClave.value,
            // Al mostrarla, el teclado de iOS corregía la contraseña o le
            // ponía mayúscula inicial sin que se notara. Se escribe tal cual.
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.go,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _decoracion('Contraseña del WiFi').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  controller.mostrarClave.value
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                tooltip: controller.mostrarClave.value
                    ? 'Ocultar contraseña'
                    : 'Mostrar contraseña',
                onPressed: () => controller.mostrarClave.value =
                    !controller.mostrarClave.value,
              ),
            ),
            onSubmitted: (_) => conectar(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Distingue mayúsculas y minúsculas.',
              style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _botonPrincipal('Conectar', Icons.check, conectar),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: controller.volverARedes,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Cambiar de red'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _listo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          icono: Icons.check_circle,
          color: AppColors.success,
          titulo: '¡Listo!',
          texto: cambiarWifi
              ? 'El lector ya está en la red nueva.'
              : 'El lector ya es de tu gimnasio. Pasa una tarjeta para '
                  'probarlo.',
        ),
        const SizedBox(height: 24),
        _botonPrincipal('Terminar', Icons.done, () => Get.back()),
      ],
    );
  }

  Widget _fallo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          icono: Icons.error_outline,
          color: AppColors.error,
          titulo: 'No se pudo',
          texto: controller.mensaje.value ?? 'Algo salió mal.',
        ),
        if (cambiarWifi || RfidConfig.tieneLector) ...[
          const SizedBox(height: 16),
          _aviso('Si acabas de conectar el lector en otro lugar, tarda unos '
              '30 segundos en empezar a parpadear rápido. Si ya estaba '
              'funcionando y perdió el WiFi, tarda 2 minutos. También puedes '
              'desconectarlo, volver a conectarlo y, en los primeros 10 '
              'segundos, mantener el botón BOOT 3 segundos: queda como nuevo.'),
        ],
        const SizedBox(height: 24),
        _botonPrincipal('Intentar de nuevo', Icons.refresh, controller.buscar),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────

  Widget _esperando({
    required IconData icono,
    required String titulo,
    required String texto,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(icono: icono, titulo: titulo, texto: texto),
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ],
    );
  }

  Widget _encabezado({
    required IconData icono,
    required String titulo,
    required String texto,
    Color color = AppColors.accent,
  }) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, color: color, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.9),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _aviso(String texto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Una red de la lista: señal, nombre y si pide contraseña. Tocarla lleva
  /// a su contraseña.
  Widget _filaRed(RedWifi red) {
    const iconosSenal = [
      Icons.signal_wifi_0_bar,
      Icons.network_wifi_1_bar,
      Icons.network_wifi_2_bar,
      Icons.signal_wifi_4_bar,
    ];
    final color =
        red.compatible ? AppColors.textPrimary : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => controller.elegirRed(red),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Icon(iconosSenal[red.barras], size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  red.ssid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 15),
                ),
              ),
              if (!red.compatible)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('No compatible',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ),
              if (red.pideClave)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.lock_outline,
                      size: 16, color: AppColors.textSecondary),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  /// Si el lector de la lista de Bluetooth es el que el gimnasio ya tiene
  /// registrado (mismos 4 últimos caracteres de la MAC).
  bool _esDeEsteGimnasio(String nombreBle) =>
      RfidConfig.registrados.any((r) => r.nombre == nombreBle);

  Widget _botonPrincipal(String texto, IconData icono, VoidCallback? onTap) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 20),
        label: Text(texto,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta) {
    return InputDecoration(
      labelText: etiqueta,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.containerBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

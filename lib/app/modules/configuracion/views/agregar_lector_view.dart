import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../data/config/rfid_config.dart';
import '../../../data/services/lector_ble_service.dart';
import '../../../global_widgets/app_header.dart';
import '../controllers/agregar_lector_controller.dart';
import '../widgets/escena_conexion_lector.dart';
import '../widgets/progreso_configuracion_lector.dart';
import '../widgets/prueba_lector_dialog.dart';

/// Abre el asistente. [cambiarWifi] solo cambia los textos: el camino es el
/// mismo para un lector nuevo que para uno al que se le cambia la red.
///
/// Devuelve si se terminó (el lector quedó en la red). False si la persona
/// salió antes, o si falló.
Future<bool> abrirAgregarLector({bool cambiarWifi = false}) async {
  final asistente = AgregarLectorController();
  await Get.to<void>(
    () => AgregarLectorView(cambiarWifi: cambiarWifi),
    binding: BindingsBuilder(() {
      Get.put(asistente);
    }),
  );
  return asistente.paso.value == PasoAgregar.listo;
}

/// Agregar un lector (o cambiarle el WiFi) sin escribir ninguna IP.
class AgregarLectorView extends GetView<AgregarLectorController> {
  const AgregarLectorView({super.key, this.cambiarWifi = false});

  final bool cambiarWifi;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // En el paso de la contraseña, "atrás" (la flecha, el botón de Android o
    // el gesto de iOS) regresa a la lista de redes en vez de cerrar todo: lo
    // normal es que la persona se haya equivocado de red.
    return Obx(() => PopScope(
          canPop: controller.paso.value != PasoAgregar.escribirClave,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.volverARedes();
          },
          child: Scaffold(
            backgroundColor: c.backgroundColor,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Lo que está pasando, de un vistazo: teléfono,
                        // lector y WiFi, y en qué paso va.
                        _progreso(),
                        const SizedBox(height: 20),
                        _paso(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  Widget _progreso() {
    if (controller.lectorOcupado.value) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Icon(Icons.lock_clock, color: AppColors.warning, size: 64),
      );
    }
    final paso = controller.paso.value;
    final etapa = etapaDe(paso, controller.pasoAntesDelFallo);
    // Más baja mientras se escribe: con el teclado abierto falta espacio.
    final escribiendo =
        paso == PasoAgregar.elegirRed || paso == PasoAgregar.escribirClave;
    return Column(
      children: [
        EscenaConexion(etapa: etapa, alto: escribiendo ? 96 : 120),
        const SizedBox(height: 12),
        PasosConexion(etapa: etapa),
        ProgresoConfiguracionLector(
          paso: paso,
          esperandoRespuesta: controller.esperandoRespuesta.value,
          guardando: controller.guardandoLector.value,
        ),
      ],
    );
  }

  Widget _paso(BuildContext context) {
    switch (controller.paso.value) {
      case PasoAgregar.buscando:
        return _buscando(context);
      case PasoAgregar.preparando:
        return _encabezado(
          context,
          titulo: 'Lector encontrado',
          texto: 'Preparando las redes WiFi que puedes elegir. '
              'Mantén el teléfono cerca del lector.',
        );
      case PasoAgregar.elegirRed:
        return _elegirRed(context);
      case PasoAgregar.escribirClave:
        return _escribirClave(context);
      case PasoAgregar.conectando:
        return _encabezado(
          context,
          titulo: controller.esperandoRespuesta.value
              ? 'Esperando la respuesta del lector…'
              : 'Enviando la red al lector…',
          texto: controller.esperandoRespuesta.value
              ? 'El lector está conectándose al WiFi. En cuanto responda, '
                  'terminará la configuración. Mantén el lector encendido.'
              : 'Mantén el teléfono cerca y el lector encendido.',
        );
      case PasoAgregar.comprobando:
        return _encabezado(
          context,
          titulo: 'Casi listo',
          texto: controller.guardandoLector.value
              ? 'El lector respondió. Terminando la configuración…'
              : 'El lector se conectó. Confirmando que responda en tu WiFi…',
        );
      case PasoAgregar.listo:
        return _listo(context);
      case PasoAgregar.fallo:
        return _fallo(context);
    }
  }

  // ─────────────────────────────────────────────────────────

  Widget _buscando(BuildContext context) {
    final c = context.colores;
    final varios = controller.lectores.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          context,
          titulo: varios ? '¿Cuál es tu lector?' : 'Buscando el lector...',
          texto: varios
              ? 'Hay más de un lector cerca. Elige el tuyo.'
              : cambiarWifi
                  ? 'Mantén el teléfono cerca del lector.'
                  : 'Conecta el lector a la corriente y deja el teléfono '
                      'cerca.',
        ),
        if (varios) const SizedBox(height: 16),
        for (final lector in controller.lectores)
          if (varios)
            Card(
              color: c.cardBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.nfc, color: AppColors.accent),
                title:
                    Text(lector.nombre, style: TextStyle(color: c.textPrimary)),
                subtitle: Text(
                  lector.ocupado
                      ? 'Otro dispositivo lo está configurando'
                      : _esDeEsteGimnasio(lector.nombre)
                          ? 'Es el lector de tu gimnasio'
                          : (lector.rssi > -60 ? 'Muy cerca' : 'Cerca'),
                  style: TextStyle(color: c.textSecondary),
                ),
                trailing: Icon(Icons.chevron_right, color: c.textSecondary),
                onTap: () => controller.elegirLector(lector),
              ),
            ),
      ],
    );
  }

  /// Paso 1 del WiFi: solo la lista. Tocar una red lleva a su contraseña.
  Widget _elegirRed(BuildContext context) {
    final c = context.colores;
    final redes = controller.redes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          context,
          titulo: '¿A qué WiFi se conecta?',
          texto: redes.isEmpty
              ? 'El lector no vio ninguna red. Acércalo al módem y busca de '
                  'nuevo, o escribe el nombre de la red.'
              : 'Toca la red del gimnasio.',
        ),
        const SizedBox(height: 20),
        if (controller.mensaje.value != null) ...[
          _aviso(context, controller.mensaje.value!),
          const SizedBox(height: 16),
        ],
        if (controller.buscandoRedes.value)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.accent)),
          )
        else
          for (final red in redes) _filaRed(context, red),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: controller.buscandoRedes.value
                  ? null
                  : controller.actualizarRedes,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Buscar de nuevo'),
              style: TextButton.styleFrom(foregroundColor: c.textSecondary),
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
    final c = context.colores;
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
          context,
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
          _aviso(context, controller.mensaje.value!),
          const SizedBox(height: 16),
        ],
        if (red?.senalDebil == true) ...[
          _aviso(
              context,
              'La señal de esta red es débil donde está el lector. Si no '
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
            style: TextStyle(color: c.textPrimary),
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
            style: TextStyle(color: c.textPrimary),
            decoration: _decoracion('Contraseña del WiFi').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  controller.mostrarClave.value
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: c.textSecondary,
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
                  color: c.textSecondary.withOpacity(0.8), fontSize: 12),
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
          style: TextButton.styleFrom(foregroundColor: c.textSecondary),
        ),
      ],
    );
  }

  Widget _listo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          context,
          titulo: '¡Lector configurado!',
          texto: cambiarWifi
              ? 'El lector respondió en la red nueva. Puedes probarlo '
                  'con una tarjeta.'
              : 'El lector ya está conectado a tu gimnasio. Puedes probarlo '
                  'con una tarjeta.',
        ),
        if (controller.avisoFinal.value != null) ...[
          const SizedBox(height: 16),
          _aviso(context, controller.avisoFinal.value!),
        ],
        const SizedBox(height: 24),
        _botonPrincipal('Probar lector', Icons.contactless,
            () => abrirPruebaLector(context)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.done),
          label: const Text('Terminar'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            foregroundColor: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _fallo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _encabezado(
          context,
          titulo:
              controller.lectorOcupado.value ? 'Lector ocupado' : 'No se pudo',
          texto: controller.mensaje.value ?? 'Algo salió mal.',
        ),
        const SizedBox(height: 24),
        _botonPrincipal(
            controller.lectorOcupado.value
                ? 'Volver a buscar'
                : 'Intentar de nuevo',
            Icons.refresh,
            controller.buscar),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────

  /// El título y una frase de lo que toca hacer. El dibujo de arriba
  /// ([EscenaConexion]) ya muestra en qué va el proceso.
  Widget _encabezado(
    BuildContext context, {
    required String titulo,
    required String texto,
  }) {
    final c = context.colores;
    return Column(
      children: [
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textSecondary.withOpacity(0.9),
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _aviso(BuildContext context, String texto) {
    final c = context.colores;
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
              style:
                  TextStyle(color: c.textPrimary, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Una red de la lista: señal, nombre y si pide contraseña. Tocarla lleva
  /// a su contraseña.
  Widget _filaRed(BuildContext context, RedWifi red) {
    final c = context.colores;
    const iconosSenal = [
      Icons.signal_wifi_0_bar,
      Icons.network_wifi_1_bar,
      Icons.network_wifi_2_bar,
      Icons.signal_wifi_4_bar,
    ];
    final color = red.compatible ? c.textPrimary : c.textSecondary;

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
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text('No compatible',
                      style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ),
              if (red.pideClave)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.lock_outline,
                      size: 16, color: c.textSecondary),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
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
    );
  }
}

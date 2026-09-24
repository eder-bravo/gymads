import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';

import '../../../data/services/permisos_app.dart';
import '../controllers/permisos_controller.dart';

class PermisosView extends GetView<PermisosController> {
  const PermisosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: controller.desdeConfiguracion
          ? const GymAppBar(title: 'Permisos de la app')
          : null,
      body: SafeArea(
        child: Obx(() {
          final contestado = controller.contestado.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (!controller.desdeConfiguracion) ...[
                const Text(
                  'Permisos de la app',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para que todo funcione, GymOne te pedirá estos permisos. '
                  'Se preguntan ahora, todos juntos, para no interrumpirte '
                  'después.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              for (final permiso in controller.permisos)
                _FilaPermiso(
                  permiso: permiso,
                  estado: contestado ? controller.estados[permiso] : null,
                ),
              const SizedBox(height: 16),
              ..._botones(contestado),
            ],
          );
        }),
      ),
    );
  }

  List<Widget> _botones(bool contestado) {
    final pidiendo = controller.pidiendo.value;

    if (!contestado) {
      return [
        _BotonPrincipal(
          texto: 'Permitir',
          cargando: pidiendo,
          onPressed: pidiendo ? null : controller.permitir,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: pidiendo ? null : controller.ahoraNo,
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Ahora no'),
        ),
      ];
    }

    return [
      if (controller.hayBloqueados) ...[
        const Text(
          'Los bloqueados solo se pueden activar desde los ajustes del '
          'teléfono.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.abrirAjustes,
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('Abrir ajustes'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
            minimumSize: const Size.fromHeight(46),
          ),
        ),
        const SizedBox(height: 8),
      ],
      // Desde Configuración, los que se negaron (sin bloquear) se pueden
      // volver a pedir.
      if (controller.desdeConfiguracion && controller.hayNegados) ...[
        _BotonPrincipal(
          texto: 'Permitir',
          cargando: pidiendo,
          onPressed: pidiendo ? null : controller.permitir,
        ),
        const SizedBox(height: 8),
      ],
      _BotonPrincipal(
        texto: controller.desdeConfiguracion ? 'Listo' : 'Continuar',
        onPressed: controller.continuar,
      ),
    ];
  }
}

class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.accent.withOpacity(0.4),
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: cargando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(texto,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}

class _FilaPermiso extends StatelessWidget {
  const _FilaPermiso({required this.permiso, this.estado});

  final PermisoApp permiso;

  /// Null mientras no se ha preguntado.
  final EstadoPermiso? estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.disabled.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icono(permiso), color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titulo(permiso),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _motivo(permiso),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (estado != null) ...[
            const SizedBox(width: 8),
            _Estado(estado!),
          ],
        ],
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado(this.estado);

  final EstadoPermiso estado;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = switch (estado) {
      EstadoPermiso.permitido => ('Permitido', AppColors.success),
      EstadoPermiso.denegado => ('No permitido', AppColors.warning),
      EstadoPermiso.bloqueado => ('Bloqueado', AppColors.error),
      EstadoPermiso.sinDato => ('Sin confirmar', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

String _titulo(PermisoApp permiso) => switch (permiso) {
      PermisoApp.notificaciones => 'Notificaciones',
      PermisoApp.camara => 'Cámara',
      PermisoApp.bluetooth => 'Bluetooth',
      PermisoApp.redLocal => 'Red local',
    };

String _motivo(PermisoApp permiso) => switch (permiso) {
      PermisoApp.notificaciones =>
        'Para avisarte de cada pase del lector aunque estés en otra app.',
      PermisoApp.camara => 'Para la foto de los clientes y para escanear '
          'códigos de barras y referencias de pago.',
      // En Android el aviso del sistema lo llama "Dispositivos cercanos".
      PermisoApp.bluetooth => defaultTargetPlatform == TargetPlatform.android
          ? 'Para configurar el WiFi del lector de tarjetas. Android lo '
              'llama "Dispositivos cercanos".'
          : 'Para configurar el WiFi del lector de tarjetas.',
      PermisoApp.redLocal =>
        'Para hablar con el lector de tarjetas en el WiFi del gimnasio.',
    };

IconData _icono(PermisoApp permiso) => switch (permiso) {
      PermisoApp.notificaciones => Icons.notifications_active_outlined,
      PermisoApp.camara => Icons.photo_camera_outlined,
      PermisoApp.bluetooth => Icons.bluetooth,
      PermisoApp.redLocal => Icons.wifi,
    };

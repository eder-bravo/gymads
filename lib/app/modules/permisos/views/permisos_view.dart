import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gymads/app/global_widgets/app_header.dart';
import 'package:gymads/core/theme/app_colors.dart';

import '../../../data/services/permisos_app.dart';
import '../controllers/permisos_controller.dart';
import '../../../core/utils/plataforma_app.dart';

class PermisosView extends GetView<PermisosController> {
  const PermisosView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ScaffoldAdaptable(
      // Al abrir la app por primera vez todavía no hay barra lateral.
      conMenu: controller.desdeConfiguracion,
      anchoMaximo: 760,
      backgroundColor: c.backgroundColor,
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
                Text(
                  'Permisos de la app',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: c.titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  PlataformaApp.escritorio
                      ? 'Puedes continuar y activar estos permisos después en Configuración.'
                      : 'GymOne necesita estos permisos para funcionar.',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
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
              if (PlataformaApp.escanerFisico)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        'El escáner USB o Bluetooth en modo teclado no necesita permisos de cámara. '
                        'Empareja los lectores Bluetooth desde el sistema. '
                        '${!kIsWeb && defaultTargetPlatform == TargetPlatform.windows ? 'En Windows habilita la cámara para aplicaciones de escritorio desde Privacidad; no aparece un diálogo de permiso.' : ''}')),
              const SizedBox(height: 16),
              if (PlataformaApp.pantallaGrande)
                _botonesEscritorio(context, contestado)
              else
                ..._botones(context, contestado),
            ],
          );
        }),
      ),
    );
  }

  /// En escritorio: los avisos arriba y los botones en una fila, cada uno de
  /// su ancho, la acción principal al final.
  Widget _botonesEscritorio(BuildContext context, bool contestado) {
    final c = context.colores;
    final pidiendo = controller.pidiendo.value;
    final notas = <String>[];
    final botones = <Widget>[];
    Widget principal(String texto, VoidCallback? onPressed,
            {bool cargando = false}) =>
        ElevatedButton(
          onPressed: onPressed,
          style: estiloBotonEscritorio(
              fondo: AppColors.accent, texto: Colors.white),
          child: cargando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(texto),
        );
    final abrirAjustes = OutlinedButton.icon(
      onPressed: controller.abrirAjustes,
      icon: const Icon(Icons.settings_outlined, size: 18),
      label: const Text('Abrir ajustes'),
      style: estiloBotonEscritorio(texto: AppColors.accent, contorno: true),
    );

    if (controller.permisos.isEmpty) {
      botones.add(principal(
          controller.desdeConfiguracion ? 'Listo' : 'Continuar',
          controller.desdeConfiguracion
              ? controller.continuar
              : controller.ahoraNo));
    } else if (!contestado) {
      if (pidiendo) {
        notas.add('Responde a los avisos del sistema. Puedes continuar '
            'aunque algún permiso quede pendiente.');
      }
      botones
        ..add(TextButton(
          onPressed: controller.ahoraNo,
          style: TextButton.styleFrom(
              foregroundColor: c.textSecondary,
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(fontSize: 15)),
          child: Text(pidiendo ? 'Continuar sin esperar' : 'Ahora no'),
        ))
        ..add(principal(
            !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
                ? 'Comprobar'
                : 'Permitir',
            pidiendo ? null : controller.permitir,
            cargando: pidiendo));
    } else {
      if (controller.estados.values.contains(EstadoPermiso.sinDato)) {
        notas.add('Algunos permisos siguen sin confirmar. Puedes continuar '
            'y revisarlos después en Configuración.');
      }
      if (controller.hayBloqueados) {
        notas.add('Los bloqueados solo se pueden activar desde los ajustes '
            'del sistema.');
      }
      // En tableta, como en el teléfono: solo si algo quedó bloqueado. En
      // Linux no hay permisos del sistema que abrir.
      if (controller.hayBloqueados ||
          (PlataformaApp.escritorio && controller.permisos.isNotEmpty)) {
        botones.add(abrirAjustes);
      }
      if (controller.desdeConfiguracion && controller.hayNegados) {
        botones.add(principal('Permitir', pidiendo ? null : controller.permitir,
            cargando: pidiendo));
      }
      botones.add(principal(
          controller.desdeConfiguracion ? 'Listo' : 'Continuar',
          controller.continuar));
    }

    return Column(
      children: [
        for (final nota in notas)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(nota,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: c.textSecondary)),
          ),
        FilaDeBotones(children: botones),
      ],
    );
  }

  List<Widget> _botones(BuildContext context, bool contestado) {
    final c = context.colores;
    final pidiendo = controller.pidiendo.value;

    if (controller.permisos.isEmpty) {
      return [
        _BotonPrincipal(
          texto: controller.desdeConfiguracion ? 'Listo' : 'Continuar',
          onPressed: controller.desdeConfiguracion
              ? controller.continuar
              : controller.ahoraNo,
        )
      ];
    }

    if (!contestado) {
      return [
        _BotonPrincipal(
          texto: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
              ? 'Comprobar'
              : 'Permitir',
          cargando: pidiendo,
          onPressed: pidiendo ? null : controller.permitir,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: controller.ahoraNo,
          style: TextButton.styleFrom(foregroundColor: c.textSecondary),
          child: Text(pidiendo ? 'Continuar sin esperar' : 'Ahora no'),
        ),
        if (pidiendo)
          Text(
            'Responde a los avisos del sistema. Puedes continuar aunque algún permiso quede pendiente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
      ];
    }

    return [
      if (controller.estados.values.contains(EstadoPermiso.sinDato)) ...[
        Text(
          'Algunos permisos siguen sin confirmar. Puedes continuar y revisarlos después en Configuración.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        const SizedBox(height: 8),
      ],
      if (controller.hayBloqueados || PlataformaApp.escritorio) ...[
        if (controller.hayBloqueados)
          Text(
            'Los bloqueados solo se pueden activar desde los ajustes del '
            'dispositivo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
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
    final c = context.colores;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.disabled.withOpacity(0.4)),
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _motivo(permiso),
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
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
    final c = context.colores;
    final (texto, color) = switch (estado) {
      EstadoPermiso.permitido => ('Permitido', AppColors.success),
      EstadoPermiso.denegado => ('No permitido', AppColors.warning),
      EstadoPermiso.bloqueado => ('Bloqueado', AppColors.error),
      EstadoPermiso.sinDato => ('Sin confirmar', c.textSecondary),
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
      PermisoApp.camara => PlataformaApp.escanerFisico
          ? 'Para tomar fotos con la cámara integrada, una webcam o una cámara virtual.'
          : 'Para la foto de los clientes y para escanear códigos de barras y referencias de pago.',
      // En Android el aviso del sistema lo llama "Dispositivos cercanos".
      PermisoApp.bluetooth => defaultTargetPlatform == TargetPlatform.android
          ? 'Para configurar el WiFi del lector. Android lo llama "Dispositivos cercanos".'
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

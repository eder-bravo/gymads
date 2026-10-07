import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import 'app_logger.dart';
import 'plataforma_app.dart';

/// Pide la cámara justo antes de usarla: la foto del cliente, el escáner de
/// códigos o la foto del comprobante de pago.
///
/// Antes se pedían todos los permisos juntos la primera vez, en una pantalla
/// antes de Inicio, y fallaba seguido (en la tableta no se podía usar la
/// cámara). Ahora cada función pide lo suyo al usarse.
///
/// - Permitida: true.
/// - Negada en el aviso: false, sin insistir; se vuelve a preguntar la
///   próxima vez.
/// - Bloqueada (ya no se puede pedir desde la app): con [avisar] explica que
///   se activa en los ajustes y ofrece abrirlos.
///
/// En computadora la piden las propias vistas de cámara al abrirse.
Future<bool> pedirCamara({
  required String para,
  bool avisar = true,
  @visibleForTesting Future<PermissionStatus> Function()? pedir,
}) async {
  if (kIsWeb || PlataformaApp.escritorio) return true;
  final PermissionStatus estado;
  try {
    estado = await (pedir ?? () => Permission.camera.request())();
  } catch (e) {
    // Si no se pudo preguntar, que lo intente la cámara: ella misma avisa
    // si no tiene permiso.
    AppLogger.warning('PermisoDeCamara', 'No se pudo pedir la cámara: $e');
    return true;
  }
  if (estado.isGranted || estado.isLimited) return true;
  if (avisar && (estado.isPermanentlyDenied || estado.isRestricted)) {
    await Get.dialog<void>(_AvisoCamara(para: para));
  }
  return false;
}

/// "Para tomar la foto del cliente, permite el acceso a la cámara en los
/// ajustes de la tableta."
String textoPermisoCamara(String para) =>
    'Para $para, permite el acceso a la cámara en los ajustes '
    '${PlataformaApp.delAparato}.';

class _AvisoCamara extends StatelessWidget {
  const _AvisoCamara({required this.para});

  final String para;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return AlertDialog(
      backgroundColor: c.cardBackground,
      title: Text('Se necesita la cámara',
          style: TextStyle(color: c.textPrimary)),
      content: Text(
        textoPermisoCamara(para),
        style: TextStyle(color: c.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('Ahora no', style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            Get.back();
            openAppSettings();
          },
          child: const Text('Abrir ajustes',
              style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// Una pantalla que va oscura en los dos modos: la cámara, el escáner de
/// códigos y la foto ampliada. Como en las apps de cámara, el fondo negro
/// deja ver mejor la imagen. Lleva el tema oscuro (lo de adentro, como
/// diálogos y botones, también sale oscuro) y la barra de estado clara.
class SiempreOscuro extends StatelessWidget {
  const SiempreOscuro({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(data: AppTheme.oscuro, child: child),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/formulario.dart';
import '../../../global_widgets/app_header.dart';

/// Cambiar la contraseña con la sesión abierta: la actual (para confirmar que
/// es la persona) y la nueva dos veces.
///
/// [cambiar] hace el cambio y devuelve el error para mostrar, o null si
/// salió bien (`ConfiguracionController.cambiarContrasena`).
class CambiarContrasenaView extends StatefulWidget {
  const CambiarContrasenaView({super.key, required this.cambiar});

  final Future<String?> Function(String actual, String nueva) cambiar;

  @override
  State<CambiarContrasenaView> createState() => _CambiarContrasenaViewState();
}

class _CambiarContrasenaViewState extends State<CambiarContrasenaView> {
  final _form = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _ver = false;
  bool _guardando = false;
  String? _error;

  static const _minimo = 6;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    final error = await widget.cambiar(_actual.text, _nueva.text);
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = error;
    });
    if (error == null) {
      Get.back();
      SnackbarHelper.success('Listo', 'Contraseña actualizada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final ojo = IconButton(
      icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
      tooltip: _ver ? 'Ocultar contraseñas' : 'Mostrar contraseñas',
      onPressed: () => setState(() => _ver = !_ver),
    );

    Widget campo(
      TextEditingController ctrl,
      String etiqueta, {
      required String? Function(String?) validar,
      TextInputAction accion = TextInputAction.next,
    }) {
      return TextFormField(
        controller: ctrl,
        obscureText: !_ver,
        enabled: !_guardando,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: accion,
        style: TextStyle(color: c.textPrimary),
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: ojo,
        ),
        validator: validar,
        onFieldSubmitted: accion == TextInputAction.done ? (_) => _guardar() : null,
      );
    }

    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: c.backgroundColor,
        appBar: const GymAppBar(title: 'Cambiar contraseña'),
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                campo(
                  _actual,
                  'Contraseña actual',
                  validar: (v) => (v ?? '').isEmpty
                      ? 'Escribe tu contraseña actual'
                      : null,
                ),
                const SizedBox(height: 14),
                campo(
                  _nueva,
                  'Contraseña nueva',
                  validar: (v) {
                    final t = v ?? '';
                    if (t.length < _minimo) return 'Mínimo $_minimo caracteres';
                    if (t == _actual.text) return 'La nueva debe ser distinta';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                campo(
                  _confirmar,
                  'Confirmar contraseña nueva',
                  accion: TextInputAction.done,
                  validar: (v) =>
                      v != _nueva.text ? 'Las contraseñas no coinciden' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: PieDeFormulario(
          child: BotonGuardar(
            texto: 'Cambiar contraseña',
            guardando: _guardando,
            onPressed: _guardar,
          ),
        ),
      ),
    );
  }
}

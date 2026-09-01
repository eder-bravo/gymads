import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';

/// Muestra el código de acceso recién generado.
///
/// Es la única vez que ese código es visible: en el servidor solo se guarda su
/// hash. Por eso el diálogo no se cierra tocando fuera y lo dice de forma
/// explícita — si se pierde, la salida es regenerarlo, no recuperarlo.
Future<void> showCodigoGeneradoDialog({
  required String nombre,
  required String codigo,
  required String gymName,
  bool esRegenerado = false,
}) {
  return Get.dialog<void>(
    _CodigoGeneradoDialog(
      nombre: nombre,
      codigo: codigo,
      gymName: gymName,
      esRegenerado: esRegenerado,
    ),
    barrierDismissible: false,
  );
}

class _CodigoGeneradoDialog extends StatelessWidget {
  final String nombre;
  final String codigo;
  final String gymName;
  final bool esRegenerado;

  const _CodigoGeneradoDialog({
    required this.nombre,
    required this.codigo,
    required this.gymName,
    required this.esRegenerado,
  });

  String get _mensajeCompartir =>
      'Hola $nombre, este es tu código para entrar a $gymName:\n\n'
      '$codigo\n\n'
      'Abre la app, toca "Entrar como staff" y escríbelo. '
      'Solo funciona una vez.';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.vpn_key,
                      color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    esRegenerado ? 'Código nuevo' : 'Acceso creado',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              esRegenerado
                  ? 'El código anterior de $nombre dejó de servir.'
                  : 'Comparte este código con $nombre.',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // El código, protagonista de la pantalla.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.containerBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withOpacity(0.5)),
              ),
              child: Center(
                child: SelectableText(
                  codigo,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // La advertencia va antes de los botones: es lo que el dueño
            // tiene que entender antes de cerrar.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Guárdalo ahora: por seguridad no se puede volver a ver. '
                      'Si se pierde, genera uno nuevo desde la lista.',
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.9),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copiar,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.copy,
                        size: 18, color: AppColors.textPrimary),
                    label: const Text('Copiar',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _compartir,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 18, color: Colors.white),
                    label: const Text('Compartir',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Get.back(),
              child: const Text(
                'Ya lo guardé',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: codigo));
    SnackbarHelper.success('Copiado', 'El código está en el portapapeles');
  }

  Future<void> _compartir() async {
    await Share.share(_mensajeCompartir);
  }
}

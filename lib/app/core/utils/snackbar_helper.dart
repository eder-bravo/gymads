import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Helper para mostrar snackbars de forma segura sin errores de Overlay
class SnackbarHelper {
  SnackbarHelper._();

  /// Muestra un snackbar de éxito
  static void success(String title, String message) {
    _show(title, message, isError: false);
  }

  /// Muestra un snackbar de error
  static void error(String title, String message) {
    _show(title, message, isError: true);
  }

  /// Muestra un snackbar de información
  static void info(String title, String message) {
    _show(title, message, isError: false, isInfo: true);
  }

  /// Método interno para mostrar snackbars de forma segura
  static void _show(String title, String message,
      {bool isError = false, bool isInfo = false}) {
    // Usar Future.delayed para evitar problemas de overlay durante navegación
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        final context = Get.context;
        if (context == null) {
          debugPrint(
              'SnackbarHelper: Context es null, no se puede mostrar snackbar');
          return;
        }

        // Limpiar snackbars anteriores
        ScaffoldMessenger.of(context).clearSnackBars();

        Color backgroundColor;
        IconData icon;

        if (isError) {
          backgroundColor = Colors.red.shade600;
          icon = Icons.error_outline;
        } else if (isInfo) {
          backgroundColor = Colors.blue.shade600;
          icon = Icons.info_outline;
        } else {
          backgroundColor = Colors.green.shade600;
          icon = Icons.check_circle_outline;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            dismissDirection: DismissDirection.horizontal,
          ),
        );
      } catch (e) {
        debugPrint('SnackbarHelper: Error mostrando snackbar: $e');
      }
    });
  }
}

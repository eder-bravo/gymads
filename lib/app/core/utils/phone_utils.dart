import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import 'snackbar_helper.dart';

/// Utilidades para interactuar con números telefónicos:
/// permite llamar o abrir WhatsApp desde cualquier parte de la app.
class PhoneUtils {
  PhoneUtils._();

  /// Deja únicamente los dígitos del número.
  static String _onlyDigits(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Normaliza el número para WhatsApp. Si tiene 10 dígitos (formato local
  /// de México) se le antepone el código de país 52.
  static String _whatsappNumber(String phone) {
    final digits = _onlyDigits(phone);
    if (digits.length == 10) return '52$digits';
    return digits;
  }

  static bool _isValid(String phone) => _onlyDigits(phone).length >= 7;

  /// Muestra un menú inferior con las acciones de Llamar y WhatsApp.
  static void showActions(BuildContext context, String? phone) {
    if (phone == null || !_isValid(phone)) {
      SnackbarHelper.error(
        'Teléfono inválido',
        'Este cliente no tiene un número de teléfono válido.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                phone,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.call, color: AppColors.success),
                title: const Text(
                  'Llamar',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _call(phone);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
                title: const Text(
                  'Enviar WhatsApp',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _whatsApp(phone);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${_onlyDigits(phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      SnackbarHelper.error('Error', 'No se pudo iniciar la llamada.');
    }
  }

  static Future<void> _whatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/${_whatsappNumber(phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      SnackbarHelper.error('Error', 'No se pudo abrir WhatsApp.');
    }
  }
}

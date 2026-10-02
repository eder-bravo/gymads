import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/core/theme/app_colors.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../routes/app_pages.dart';

/// Screen shown after registration telling user to confirm their email.
///
/// Receives 'email' via Get.arguments.
/// Has a "Ya confirmé mi correo" button → goes to login.
/// Has a "Reenviar correo" button.
class EmailConfirmationView extends StatelessWidget {
  const EmailConfirmationView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final email = (Get.arguments as Map<String, dynamic>?)?['email'] ?? '';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: c.fondoAcceso),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              // En escritorio, un ancho de lectura como el del login: en
              // pantalla grande el texto y los botones no cruzan la ventana.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: PlataformaApp.escritorio ? 560 : double.infinity),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Email icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 56,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      '¡Revisa tu correo!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: c.contraste,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Hemos enviado un enlace de confirmación a:',
                      style: TextStyle(
                        fontSize: 15,
                        color: c.contraste.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Email address
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: c.contraste.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: c.contraste.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: Colors.blueAccent.withOpacity(0.8),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              email,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.contraste,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.contraste.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.contraste.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          _buildStep(
                              context, '1', 'Abre tu correo electrónico'),
                          const SizedBox(height: 12),
                          _buildStep(context, '2',
                              'Busca el correo de confirmación de GymOne'),
                          const SizedBox(height: 12),
                          _buildStep(context, '3',
                              'Haz clic en el enlace de confirmación'),
                          const SizedBox(height: 12),
                          _buildStep(
                              context, '4', 'Regresa aquí e inicia sesión'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // "Ya confirmé" button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => Get.offAllNamed(Routes.LOGIN),
                        icon: const Icon(Icons.login, size: 20),
                        label: const Text(
                          'Ya confirmé, ir a Login',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // "Resend" button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _resendConfirmation(email),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text(
                          'Reenviar correo',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.contraste.withOpacity(0.70),
                          side: BorderSide(color: c.contraste.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Spam notice
                    Text(
                      '¿No lo encuentras? Revisa tu carpeta de spam.',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.contraste.withOpacity(0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    final c = context.colores;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: c.contraste.withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _resendConfirmation(String email) async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      SnackbarHelper.success(
          'Correo reenviado', 'Revisa tu bandeja de entrada');
    } catch (e) {
      SnackbarHelper.error('Error', 'No se pudo reenviar. Intenta más tarde.');
    }
  }
}

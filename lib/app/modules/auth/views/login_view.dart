import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:gymads/app/core/widgets/centrado_desplazable.dart';
import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:get/get.dart';
import '../../../routes/app_pages.dart';
import '../controllers/auth_controller.dart';
import 'package:gymads/core/theme/app_colors.dart';

/// Login view with email/password form
///
/// Acostada (tableta o teléfono de lado), en dos columnas: el logo y "Crear
/// cuenta" a la izquierda, la tarjeta para entrar a la derecha.
class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: c.fondoAcceso),
        child: SafeArea(
          child: pantallaAcostada(context)
              ? _acostada(context)
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo / Title
                        _buildHeader(context),
                        const SizedBox(height: 48),

                        // Login Card
                        _buildLoginCard(context),
                        const SizedBox(height: 24),

                        // Create account link
                        _crearCuenta(context),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// De lado: el logo a la izquierda y la tarjeta a la derecha, cada uno
  /// centrado en su mitad. En el teléfono acostado (poco alto) todo va más
  /// compacto y la tarjeta se desplaza.
  Widget _acostada(BuildContext context) {
    final bajo = MediaQuery.sizeOf(context).height < 560;
    return Row(
      children: [
        Expanded(
          child: CentradoDesplazable(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, compacto: bajo),
                SizedBox(height: bajo ? 20 : 40),
                _crearCuenta(context),
              ],
            ),
          ),
        ),
        Expanded(
          child: CentradoDesplazable(
            padding:
                EdgeInsets.symmetric(horizontal: 24, vertical: bajo ? 12 : 24),
            child: _buildLoginCard(context, compacta: bajo),
          ),
        ),
      ],
    );
  }

  Widget _crearCuenta(BuildContext context) {
    final c = context.colores;
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text(
          '¿No tienes cuenta? ',
          style: TextStyle(
            color: c.contraste.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () => Get.toNamed(Routes.REGISTER),
          child: const Text(
            'Crear cuenta',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, {bool compacto = false}) {
    final c = context.colores;
    return Column(
      children: [
        // App Icon
        Image.asset(
          'assets/images/logo_app.png',
          width: compacto ? 64 : 100,
          height: compacto ? 64 : 100,
          filterQuality: FilterQuality.medium,
        ),
        SizedBox(height: compacto ? 14 : 24),

        // App Name
        Text(
          'GYMONE',
          style: TextStyle(
            fontSize: compacto ? 26 : 32,
            fontWeight: FontWeight.bold,
            color: c.contraste,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sistema de Gestión de Gimnasio',
          style: TextStyle(
            fontSize: 14,
            color: c.contraste.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  /// [compacta]: el teléfono acostado, con poca altura.
  Widget _buildLoginCard(BuildContext context, {bool compacta = false}) {
    final c = context.colores;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(compacta ? 20 : 32),
      decoration: BoxDecoration(
        color: c.tarjetaAcceso,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.contraste.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: c.sombra,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Iniciar Sesión',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: c.contraste,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa tus credenciales para acceder',
            style: TextStyle(
              fontSize: 14,
              color: c.contraste.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compacta ? 20 : 32),

          // Email field
          _buildEmailField(context),
          const SizedBox(height: 16),

          // Password field
          _buildPasswordField(context),
          const SizedBox(height: 24),

          // Error message
          Obx(() => controller.errorMessage.value != null
              ? _buildErrorMessage()
              : const SizedBox.shrink()),

          // Login button
          _buildLoginButton(),
          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: c.contraste.withOpacity(0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'o',
                  style: TextStyle(
                    color: c.contraste.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: Divider(color: c.contraste.withOpacity(0.2))),
            ],
          ),
          const SizedBox(height: 20),

          // Google Sign-In button
          _buildGoogleButton(context),
          const SizedBox(height: 12),

          // Entrada del personal con código de un solo uso
          _buildStaffButton(context),
        ],
      ),
    );
  }

  /// Los empleados no tienen cuenta: entran con el código que les dio el
  /// dueño desde Configuración.
  Widget _buildStaffButton(BuildContext context) {
    final c = context.colores;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: OutlinedButton(
        onPressed: () => Get.toNamed(Routes.STAFF_CODE),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.contraste.withOpacity(0.24)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: c.contraste.withOpacity(0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 20, color: c.contraste),
            const SizedBox(width: 12),
            Flexible(
                child: Text(
              'Entrar como staff',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.contraste,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final c = context.colores;
    return TextField(
      controller: controller.emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: c.contraste),
      decoration: InputDecoration(
        labelText: 'Correo electrónico',
        prefixIcon: Icon(
          Icons.email_outlined,
          color: c.contraste.withOpacity(0.7),
        ),
      ),
      onChanged: (_) => controller.clearError(),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final c = context.colores;
    return Obx(() => TextField(
          controller: controller.passwordController,
          obscureText: controller.obscurePassword.value,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: c.contraste),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: Icon(
              Icons.lock_outline,
              color: c.contraste.withOpacity(0.7),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                controller.obscurePassword.value
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: c.contraste.withOpacity(0.7),
              ),
              tooltip: PlataformaApp.escritorio
                  ? (controller.obscurePassword.value
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña')
                  : null,
              onPressed: controller.togglePasswordVisibility,
            ),
          ),
          onChanged: (_) => controller.clearError(),
          onSubmitted: (_) => controller.login(),
        ));
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.errorMessage.value!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Obx(() => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: ElevatedButton(
            onPressed:
                controller.isLoading.value && !controller.waitingForGoogle.value
                    ? null
                    : controller.login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child:
                controller.isLoading.value && !controller.waitingForGoogle.value
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                              child: Text(
                            'Iniciar Sesión',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          )),
                        ],
                      ),
          ),
        ));
  }

  Widget _buildGoogleButton(BuildContext context) {
    final c = context.colores;
    return Obx(() => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: OutlinedButton(
            onPressed: controller.waitingForGoogle.value
                ? controller.cancelGoogleSignIn
                : (controller.isLoading.value
                    ? null
                    : controller.loginWithGoogle),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.contraste.withOpacity(0.24)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: c.contraste.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Image.asset(
                    'assets/images/google_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                    child: Text(
                  controller.waitingForGoogle.value
                      ? 'Cancelar inicio con Google'
                      : 'Continuar con Google',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.contraste,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                )),
              ],
            ),
          ),
        ));
  }
}

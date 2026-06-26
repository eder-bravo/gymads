import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/register_controller.dart';

/// Registration view — single-form with email/password + Google option
class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: _buildForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear Cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Configura tu gimnasio en minutos',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google Sign-In button
        _buildGoogleButton(),
        const SizedBox(height: 20),

        // Divider
        _buildDivider(),
        const SizedBox(height: 20),

        // Personal info card
        _buildCard(
          title: 'Datos Personales',
          icon: Icons.person_outline,
          children: [
            _buildTextField(
              controller: controller.firstNameController,
              label: 'Nombre(s)',
              icon: Icons.person,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: controller.lastNameController,
              label: 'Apellidos',
              icon: Icons.person_outline,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: controller.emailController,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            Obx(() => _buildTextField(
                  controller: controller.passwordController,
                  label: 'Contraseña',
                  icon: Icons.lock_outline,
                  obscureText: controller.obscurePassword.value,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscurePassword.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => controller.obscurePassword.value =
                        !controller.obscurePassword.value,
                  ),
                )),
            const SizedBox(height: 14),
            Obx(() => _buildTextField(
                  controller: controller.confirmPasswordController,
                  label: 'Confirmar contraseña',
                  icon: Icons.lock_outline,
                  obscureText: controller.obscureConfirmPassword.value,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.obscureConfirmPassword.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => controller.obscureConfirmPassword.value =
                        !controller.obscureConfirmPassword.value,
                  ),
                )),
          ],
        ),
        const SizedBox(height: 16),

        // Gym info card
        _buildCard(
          title: 'Tu Gimnasio',
          icon: Icons.fitness_center,
          children: [
            _buildTextField(
              controller: controller.gymNameController,
              label: 'Nombre del gimnasio',
              icon: Icons.store,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: controller.locationController,
              label: 'Ubicación',
              icon: Icons.location_on_outlined,
              textInputAction: TextInputAction.done,
              hint: 'Ej: Col. Centro, Monterrey',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Error message
        Obx(() => controller.errorMessage.value != null
            ? _buildErrorMessage()
            : const SizedBox.shrink()),

        // Register button
        _buildRegisterButton(),
        const SizedBox(height: 16),

        // Login link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¿Ya tienes cuenta? ',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Get.back(),
              child: const Text(
                'Iniciar sesión',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // REUSABLE WIDGETS
  // ==========================================

  Widget _buildGoogleButton() {
    return Obx(() => SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: controller.isLoading.value
                ? null
                : controller.registerWithGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: Colors.white.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google logo
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
                const Text(
                  'Registrarse con Google',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'o regístrate con email',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: (_) => this.controller.clearError(),
    );
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
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.errorMessage.value!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Obx(() => SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: controller.isLoading.value ? null : _onRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: controller.isLoading.value
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
                      Icon(Icons.person_add, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Crear Cuenta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ));
  }

  void _onRegister() {
    controller.clearError();

    // Validate all fields
    final nameErr = controller.validateFirstName(controller.firstNameController.text);
    if (nameErr != null) {
      controller.errorMessage.value = nameErr;
      return;
    }
    final lastErr = controller.validateLastName(controller.lastNameController.text);
    if (lastErr != null) {
      controller.errorMessage.value = lastErr;
      return;
    }
    final emailErr = controller.validateEmail(controller.emailController.text);
    if (emailErr != null) {
      controller.errorMessage.value = emailErr;
      return;
    }
    final passErr = controller.validatePassword(controller.passwordController.text);
    if (passErr != null) {
      controller.errorMessage.value = passErr;
      return;
    }
    final confirmErr = controller.validateConfirmPassword(controller.confirmPasswordController.text);
    if (confirmErr != null) {
      controller.errorMessage.value = confirmErr;
      return;
    }
    final gymErr = controller.validateGymName(controller.gymNameController.text);
    if (gymErr != null) {
      controller.errorMessage.value = gymErr;
      return;
    }
    final locErr = controller.validateLocation(controller.locationController.text);
    if (locErr != null) {
      controller.errorMessage.value = locErr;
      return;
    }

    controller.register();
  }
}

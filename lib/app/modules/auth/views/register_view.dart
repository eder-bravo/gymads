import 'package:gymads/app/core/widgets/diseno_escritorio.dart';
import 'package:flutter/material.dart';
import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'package:get/get.dart';
import '../controllers/register_controller.dart';
import '../widgets/horario_selector.dart';
import 'package:gymads/core/theme/app_colors.dart';

/// Registration view — single-form with email/password + Google option
///
/// En escritorio y tableta, las secciones van en vertical y los campos
/// relacionados comparten fila cuando hay espacio y la letra lo permite.
class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: c.fondoAcceso),
        child: ContenidoEscritorio(
          // La columna conserva un ancho cómodo en escritorio y tableta.
          anchoMaximo: _dosTarjetas(context) ? 1100 : 720,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('formulario_registro'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: PlataformaApp.pantallaGrande
                        ? const EdgeInsets.fromLTRB(20, 12, 20, 20)
                        : const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: _buildForm(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            tooltip: PlataformaApp.escritorio ? 'Regresar' : null,
            icon: Icon(Icons.arrow_back_ios, color: c.contraste),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear Cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: c.contraste,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configura tu gimnasio en minutos',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.contraste.withOpacity(0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final c = context.colores;
    final acostada = _dosTarjetas(context);
    final botonesCentrados = PlataformaApp.pantallaGrande || acostada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google Sign-In button
        _angosto(botonesCentrados, _buildGoogleButton(context)),
        SizedBox(height: PlataformaApp.pantallaGrande ? 14 : 20),

        // Divider
        _angosto(botonesCentrados, _buildDivider(context)),
        SizedBox(height: PlataformaApp.pantallaGrande ? 14 : 20),

        // En pantallas grandes, primero la cuenta y debajo el gimnasio.
        if (acostada)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _cardPersonal(context)),
              const SizedBox(width: 16),
              Expanded(child: _cardGimnasio(context)),
            ],
          )
        else ...[
          _cardPersonal(context),
          const SizedBox(height: 16),
          _cardGimnasio(context),
        ],
        const SizedBox(height: 24),

        // Error message
        Obx(() => controller.errorMessage.value != null
            ? _buildErrorMessage()
            : const SizedBox.shrink()),

        // Register button
        _angosto(botonesCentrados, _buildRegisterButton()),
        const SizedBox(height: 16),

        // Login link
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            Text(
              '¿Ya tienes cuenta? ',
              style:
                  TextStyle(color: c.contraste.withOpacity(0.60), fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Get.back(),
              child: Text(
                'Iniciar sesión',
                style: TextStyle(
                  color: PlataformaApp.pantallaGrande
                      ? c.titleColor
                      : AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: PlataformaApp.pantallaGrande
                      ? c.titleColor
                      : AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _dosTarjetas(BuildContext context) =>
      !PlataformaApp.pantallaGrande && pantallaAcostada(context);

  /// Los campos vuelven a una columna al ampliar la letra o reducir el ancho.
  Widget _camposRelacionados(List<Widget> campos) =>
      PlataformaApp.pantallaGrande
          ? ResumenAdaptable(anchoMinimo: 270, espacio: 14, children: campos)
          : Column(
              children: [
                for (var i = 0; i < campos.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  campos[i],
                ],
              ],
            );

  /// Las acciones principales mantienen un ancho cómodo para leerlas.
  Widget _angosto(bool limitarAncho, Widget boton) => limitarAncho
      ? Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(width: double.infinity, child: boton),
          ),
        )
      : boton;

  Widget _cardPersonal(BuildContext context) {
    final c = context.colores;
    return _buildCard(
      context,
      title: 'Datos Personales',
      icon: Icons.person_outline,
      children: [
        _camposRelacionados([
          _buildTextField(
            context,
            controller: controller.firstNameController,
            label: 'Nombre(s)',
            icon: Icons.person,
            textInputAction: TextInputAction.next,
          ),
          _buildTextField(
            context,
            controller: controller.lastNameController,
            label: 'Apellidos',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
          ),
        ]),
        const SizedBox(height: 14),
        _buildTextField(
          context,
          controller: controller.emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: controller.revisarCorreo,
        ),
        // Un error de dedo en el dominio (gmial.com): se sugiere, no se
        // impide.
        Obx(() {
          final sugerida = controller.sugerenciaCorreo.value;
          if (sugerida == null) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.usarSugerenciaCorreo,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text('¿Quisiste decir $sugerida?'),
            ),
          );
        }),
        const SizedBox(height: 14),
        _camposRelacionados([
          Obx(() => _buildTextField(
                context,
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
                    color: c.contraste.withOpacity(0.54),
                    size: 20,
                  ),
                  tooltip: PlataformaApp.escritorio
                      ? (controller.obscurePassword.value
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña')
                      : null,
                  onPressed: () => controller.obscurePassword.value =
                      !controller.obscurePassword.value,
                ),
              )),
          Obx(() => _buildTextField(
                context,
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
                    color: c.contraste.withOpacity(0.54),
                    size: 20,
                  ),
                  tooltip: PlataformaApp.escritorio
                      ? (controller.obscureConfirmPassword.value
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña')
                      : null,
                  onPressed: () => controller.obscureConfirmPassword.value =
                      !controller.obscureConfirmPassword.value,
                ),
              )),
        ]),
      ],
    );
  }

  Widget _cardGimnasio(BuildContext context) {
    return _buildCard(
      context,
      title: 'Tu Gimnasio',
      icon: Icons.fitness_center,
      children: [
        _camposRelacionados([
          _buildTextField(
            context,
            controller: controller.gymNameController,
            label: 'Nombre del gimnasio',
            icon: Icons.store,
            textInputAction: TextInputAction.next,
          ),
          _buildTextField(
            context,
            controller: controller.locationController,
            label: 'Ubicación',
            icon: Icons.location_on_outlined,
            textInputAction: TextInputAction.done,
            hint: 'Ej: Col. Centro, Monterrey',
          ),
        ]),
        const SizedBox(height: 14),
        Obx(() => HorarioSelector(
              apertura: controller.horaApertura.value,
              cierre: controller.horaCierre.value,
              onChanged: controller.setHorario,
            )),
      ],
    );
  }

  // ==========================================
  // REUSABLE WIDGETS
  // ==========================================

  Widget _buildGoogleButton(BuildContext context) {
    final c = context.colores;
    return Obx(() => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: OutlinedButton(
            onPressed: controller.waitingForGoogle.value
                ? controller.cancelGoogleSignIn
                : (controller.isLoading.value
                    ? null
                    : controller.registerWithGoogle),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.contraste.withOpacity(0.24)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: c.contraste.withOpacity(0.05),
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
                Flexible(
                    child: Text(
                  controller.waitingForGoogle.value
                      ? 'Cancelar inicio con Google'
                      : 'Registrarse con Google',
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

  Widget _buildDivider(BuildContext context) {
    final c = context.colores;
    // En escritorio el texto toma su ancho y las dos líneas se reparten el
    // resto: con el texto en un espacio fijo quedaba recargado a un lado.
    if (PlataformaApp.pantallaGrande || pantallaAcostada(context)) {
      return Row(
        children: [
          Expanded(child: Divider(color: c.contraste.withOpacity(0.2))),
          Flexible(
            flex: PlataformaApp.pantallaGrande ? 3 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'o regístrate con tu correo',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.contraste.withOpacity(0.6), fontSize: 14),
              ),
            ),
          ),
          Expanded(child: Divider(color: c.contraste.withOpacity(0.2))),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: Divider(color: c.contraste.withOpacity(0.2))),
        Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'o regístrate con email',
                style: TextStyle(
                  color: c.contraste.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            )),
        Expanded(child: Divider(color: c.contraste.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final c = context.colores;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(PlataformaApp.pantallaGrande ? 16 : 20),
      decoration: BoxDecoration(
        color: c.tarjetaAcceso,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.contraste.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: c.sombra,
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
              Icon(icon, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: c.contraste,
                ),
              )),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    final c = context.colores;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      style: TextStyle(color: c.contraste, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: c.contraste.withOpacity(0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: c.contraste.withOpacity(0.54), size: 20),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: (valor) {
        this.controller.clearError();
        onChanged?.call(valor);
      },
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
    return Obx(() => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: ElevatedButton(
            onPressed: controller.isLoading.value ? null : _onRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
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
                      Flexible(
                          child: Text(
                        'Crear Cuenta',
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

  void _onRegister() {
    controller.clearError();

    // Validate all fields
    final nameErr =
        controller.validateFirstName(controller.firstNameController.text);
    if (nameErr != null) {
      controller.errorMessage.value = nameErr;
      return;
    }
    final lastErr =
        controller.validateLastName(controller.lastNameController.text);
    if (lastErr != null) {
      controller.errorMessage.value = lastErr;
      return;
    }
    final emailErr = controller.validateEmail(controller.emailController.text);
    if (emailErr != null) {
      controller.errorMessage.value = emailErr;
      return;
    }
    final passErr =
        controller.validatePassword(controller.passwordController.text);
    if (passErr != null) {
      controller.errorMessage.value = passErr;
      return;
    }
    final confirmErr = controller
        .validateConfirmPassword(controller.confirmPasswordController.text);
    if (confirmErr != null) {
      controller.errorMessage.value = confirmErr;
      return;
    }
    final gymErr =
        controller.validateGymName(controller.gymNameController.text);
    if (gymErr != null) {
      controller.errorMessage.value = gymErr;
      return;
    }
    final locErr =
        controller.validateLocation(controller.locationController.text);
    if (locErr != null) {
      controller.errorMessage.value = locErr;
      return;
    }

    controller.register();
  }
}

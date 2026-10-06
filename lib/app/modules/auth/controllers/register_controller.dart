import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gymads/app/data/models/gym_settings_model.dart';
import '../../../data/providers/staff_profile_provider.dart';
import '../../../data/services/cuenta_de_google.dart';
import '../../../data/services/google_play_services.dart';
import '../../../data/services/google_browser_auth.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../routes/app_pages.dart';
import 'package:gymads/app/core/utils/correo_valido.dart';
import 'package:gymads/app/core/utils/nombre_completo.dart';

/// Controller for registration (creating a new gym account)
///
/// Simplified flow:
///   1. User fills: name, email, password, gym name, location
///   2. On submit → creates auth user → calls RPC → auto-login → HOME
///   OR: Google Sign-In → if no gym → shows gym/location form → RPC → HOME
class RegisterController extends GetxController {
  RegisterController({GoogleBrowserAuth Function(GoTrueClient)? browserFactory})
      : _browserFactory = browserFactory ?? GoogleBrowserAuth.new;

  final GoogleBrowserAuth Function(GoTrueClient) _browserFactory;
  final SupabaseClient _supabase = Supabase.instance.client;
  final StaffProfileProvider _staffProfileProvider = StaffProfileProvider();

  // Form controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final gymNameController = TextEditingController();

  /// Horario del gimnasio. Nace con el valor más común para que quien no lo
  /// toque no alargue el registro; se guarda junto con el gimnasio.
  final horaApertura = const HoraDelDia(6, 0).obs;
  final horaCierre = const HoraDelDia(22, 0).obs;

  void setHorario(HoraDelDia apertura, HoraDelDia cierre) {
    horaApertura.value = apertura;
    horaCierre.value = cierre;
  }

  final locationController = TextEditingController();

  // State
  final RxBool isLoading = false.obs;
  final RxBool waitingForGoogle = false.obs;
  GoogleBrowserAuth? _browserAuth;
  int _googleAttempt = 0;

  void cancelGoogleSignIn() {
    if (!waitingForGoogle.value) return;
    _googleAttempt++;
    _browserAuth?.cancel();
    _browserAuth = null;
    waitingForGoogle.value = false;
    isLoading.value = false;
    clearError();
  }

  final RxnString errorMessage = RxnString();
  final RxBool obscurePassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;

  // Google sign-in state (if user came from Google, these are pre-filled)
  final RxBool isGoogleUser = false.obs;
  String? googleUserId;

  // Form key
  final formKey = GlobalKey<FormState>();

  @override
  void onClose() {
    _googleAttempt++;
    _browserAuth?.cancel();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    gymNameController.dispose();
    locationController.dispose();
    super.onClose();
  }

  /// Composed full name for display
  String get fullName {
    final parts = <String>[];
    if (firstNameController.text.trim().isNotEmpty) {
      parts.add(firstNameController.text.trim());
    }
    if (lastNameController.text.trim().isNotEmpty) {
      parts.add(lastNameController.text.trim());
    }
    return parts.join(' ');
  }

  // ============================================
  // VALIDATION
  // ============================================

  void clearError() {
    errorMessage.value = null;
  }

  String? validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es requerido';
    }
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    return null;
  }

  String? validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Los apellidos son requeridos';
    }
    return null;
  }

  /// Que tenga forma de correo y sea de un proveedor real (correo_valido.dart).
  String? validateEmail(String? value) => validarCorreoDeRegistro(value);

  /// "¿Quisiste decir juan@gmail.com?" mientras se escribe el correo.
  final sugerenciaCorreo = RxnString();

  void revisarCorreo(String valor) =>
      sugerenciaCorreo.value = sugerenciaDeCorreo(valor);

  void usarSugerenciaCorreo() {
    final sugerida = sugerenciaCorreo.value;
    if (sugerida == null) return;
    emailController.text = sugerida;
    emailController.selection =
        TextSelection.collapsed(offset: sugerida.length);
    sugerenciaCorreo.value = null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  String? validateGymName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre del gimnasio es requerido';
    }
    return null;
  }

  String? validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La ubicación es requerida';
    }
    return null;
  }

  // ============================================
  // GOOGLE SIGN-IN
  // ============================================

  Future<void> registerWithGoogle() async {
    // Prevent concurrent calls (double-tap)
    if (isLoading.value) return;
    final attempt = ++_googleAttempt;
    clearError();
    isLoading.value = true;

    try {
      if (GetPlatform.isAndroid) {
        if (!await GooglePlayServices.disponibles) {
          AppLogger.info(
            'RegisterController',
            'Google Play Services no disponible; usando OAuth por navegador',
          );
          await _registerWithGoogleNavegador(attempt);
        } else {
          try {
            await _registerWithGoogleNativo();
          } on PlatformException catch (e) {
            if (e.code == 'sign_in_failed' ||
                e.message?.contains('12500') == true) {
              AppLogger.warning(
                'RegisterController',
                'Google nativo no disponible; usando OAuth por navegador',
              );
              await _registerWithGoogleNavegador(attempt);
            } else {
              rethrow;
            }
          }
        }
      } else if (GetPlatform.isIOS) {
        await _registerWithGoogleNativo();
      } else {
        // Las apps de escritorio usan el navegador del sistema.
        await _registerWithGoogleNavegador(attempt);
      }
    } on AuthException catch (e) {
      if (attempt != _googleAttempt) return;
      AppLogger.error(
          'RegisterController', 'Fallo de autenticación con Google', e);
      errorMessage.value = tokenRechazado(e)
          ? mensajeTokenRechazado
          : 'Error con Google: ${e.message}';
    } catch (e) {
      if (attempt != _googleAttempt) return;
      AppLogger.error('RegisterController', 'Google sign-in error', e);
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (attempt == _googleAttempt) {
        waitingForGoogle.value = false;
        isLoading.value = false;
      }
    }
  }

  /// Android e iOS: hoja nativa de Google + signInWithIdToken.
  ///
  /// Mismo motivo que en el inicio de sesión: por navegador, iOS terminaba en
  /// `http://localhost:3000` porque el proyecto no tiene ninguna Redirect URL
  /// permitida y Supabase caía a su Site URL.
  Future<void> _registerWithGoogleNativo() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
      scopes: ['email', 'profile'],
    );

    // Elige la cuenta y entra a Supabase con su token (si llega vencido, pide
    // otro).
    final entrada = await entrarConGoogle(
      googleSignIn,
      (idToken, accessToken) => _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      ),
    );
    if (entrada == null) {
      isLoading.value = false;
      return;
    }
    final googleUser = entrada.cuenta;
    final authResponse = entrada.respuesta;

    if (authResponse.user == null) {
      throw Exception('Error al autenticar con Google');
    }

    await _handleGoogleRegResult(
      authResponse.user!.id,
      googleUser.displayName,
      googleUser.email,
    );
  }

  /// Huawei sin GMS y apps de escritorio: flujo OAuth por navegador.
  Future<void> _registerWithGoogleNavegador(int attempt) async {
    AppLogger.info(
        'RegisterController', 'Starting Supabase OAuth flow for registration');

    final browser = _browserAuth = _browserFactory(_supabase.auth);
    final User? user;
    try {
      user = await browser.signIn(onWaiting: (waiting) {
        if (attempt == _googleAttempt) waitingForGoogle.value = waiting;
      });
    } finally {
      if (identical(_browserAuth, browser)) _browserAuth = null;
    }
    if (user == null || attempt != _googleAttempt) return;
    final userId = user.id;
    final userMeta = user.userMetadata;
    final fullName =
        userMeta?['full_name'] as String? ?? userMeta?['name'] as String? ?? '';
    final email = user.email ?? '';

    await _handleGoogleRegResult(userId, fullName, email);
  }

  /// Common handler after Google auth in registration
  Future<void> _handleGoogleRegResult(
      String userId, String? displayName, String? email) async {
    AppLogger.info('RegisterController', 'Google auth successful');

    final staffProfile = await _staffProfileProvider.getByUserId(userId);

    if (staffProfile != null && staffProfile.isActive) {
      await TenantContextService.to.setProfile(staffProfile);
      Get.offAllNamed(Routes.HOME);
    } else {
      final nombre = separarNombreCompleto(displayName);
      firstNameController.text = nombre.nombres;
      lastNameController.text = nombre.apellidos;
      emailController.text = email ?? '';

      isGoogleUser.value = true;
      googleUserId = userId;

      Get.toNamed(Routes.GOOGLE_COMPLETE);
    }
  }

  /// Complete Google registration (user already authenticated, just needs gym)
  Future<void> completeGoogleRegistration() async {
    clearError();

    final gymError = validateGymName(gymNameController.text);
    final locError = validateLocation(locationController.text);

    if (gymError != null) {
      errorMessage.value = gymError;
      return;
    }
    if (locError != null) {
      errorMessage.value = locError;
      return;
    }

    isLoading.value = true;

    try {
      final userId = googleUserId ?? _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No se encontró sesión activa');
      }

      // Call RPC to create gym + branch + staff_profile
      await _supabase.rpc('register_gym_owner', params: {
        'p_user_id': userId,
        'p_first_name': firstNameController.text.trim(),
        'p_last_name': lastNameController.text.trim(),
        'p_gym_name': gymNameController.text.trim(),
        'p_main_branch_name': locationController.text.trim(),
        'p_hora_apertura': horaApertura.value.toSql(),
        'p_hora_cierre': horaCierre.value.toSql(),
      });

      AppLogger.info('RegisterController', 'Gym registered via Google flow');

      // Auto-login
      final staffProfile = await _staffProfileProvider.getByUserId(userId);

      if (staffProfile != null && staffProfile.isActive) {
        await TenantContextService.to.setProfile(staffProfile);
        Get.offAllNamed(Routes.HOME);
      } else {
        throw Exception('Error creando el perfil');
      }
    } catch (e) {
      AppLogger.error('RegisterController', 'Complete registration error', e);
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================
  // EMAIL/PASSWORD REGISTRATION
  // ============================================

  Future<void> register() async {
    clearError();
    isLoading.value = true;

    try {
      // 1. Create auth user
      AppLogger.info('RegisterController', 'Creating auth user');
      final authResponse = await _supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        data: {
          'display_name': fullName,
          'first_name': firstNameController.text.trim(),
        },
      );

      if (authResponse.user == null) {
        throw Exception('Error al crear la cuenta');
      }

      final userId = authResponse.user!.id;
      AppLogger.info('RegisterController', 'Auth user created');

      // 2. Call the register_gym_owner RPC function
      AppLogger.info('RegisterController', 'Registering gym via RPC');

      await _supabase.rpc('register_gym_owner', params: {
        'p_user_id': userId,
        'p_first_name': firstNameController.text.trim(),
        'p_last_name': lastNameController.text.trim(),
        'p_gym_name': gymNameController.text.trim(),
        'p_main_branch_name': locationController.text.trim(),
        'p_hora_apertura': horaApertura.value.toSql(),
        'p_hora_cierre': horaCierre.value.toSql(),
      });

      AppLogger.info('RegisterController', 'Gym registered');

      // 3. Auto-login: fetch staff profile and set tenant context
      AppLogger.info(
          'RegisterController', 'Auto-login: fetching staff profile');
      final staffProfile = await _staffProfileProvider.getByUserId(userId);

      if (staffProfile != null && staffProfile.isActive) {
        await TenantContextService.to.setProfile(staffProfile);
        Get.offAllNamed(Routes.HOME);
      } else {
        // Fallback: staff profile not ready yet, go to login
        AppLogger.warning('RegisterController',
            'Staff profile not ready, redirecting to login');
        Get.offAllNamed(Routes.LOGIN);
      }
    } on AuthException catch (e) {
      AppLogger.error('RegisterController', 'Fallo de autenticación', e);
      if (e.message.contains('already registered')) {
        errorMessage.value = 'Este correo ya está registrado';
      } else if (e.message.contains('correo_no_permitido') ||
          e.message.contains('Database error saving new user')) {
        // La base de datos lo rechazó (la misma regla, por si la cuenta se
        // intentó crear sin pasar por la validación de la pantalla).
        errorMessage.value = mensajeCorreoNoPermitido;
      } else {
        errorMessage.value = 'Error: ${e.message}';
      }
    } catch (e) {
      AppLogger.error('RegisterController', 'Registration error', e);
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}

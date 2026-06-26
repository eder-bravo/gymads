import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../data/models/staff_profile_model.dart';
import '../../../data/providers/staff_profile_provider.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../data/services/branding_service.dart';
import '../../../routes/app_pages.dart';
import 'register_controller.dart';

/// Controller for authentication (login/logout)
///
/// Handles Supabase Auth login and fetches staff_profile
/// to establish tenant context before allowing access.
class AuthController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StaffProfileProvider _staffProfileProvider = StaffProfileProvider();

  // Form controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // State
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool obscurePassword = true.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  /// Clear error message
  void clearError() {
    errorMessage.value = null;
  }

  /// Validate form fields
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo es requerido';
    }
    if (!GetUtils.isEmail(value)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  /// Login with email and password
  ///
  /// Returns true if login was successful
  Future<bool> login() async {
    clearError();

    // Validate fields
    final emailError = validateEmail(emailController.text);
    final passwordError = validatePassword(passwordController.text);

    if (emailError != null) {
      errorMessage.value = emailError;
      return false;
    }
    if (passwordError != null) {
      errorMessage.value = passwordError;
      return false;
    }

    isLoading.value = true;

    try {
      // 1. Authenticate with Supabase Auth
      final response = await _supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Error de autenticación');
      }

      print('✅ Auth successful for: ${response.user!.email}');

      // 2. Fetch staff_profile for this user
      final staffProfile = await _staffProfileProvider.getByUserId(
        response.user!.id,
      );

      if (staffProfile == null || !staffProfile.isActive) {
        // No staff profile means this user is not authorized
        await _supabase.auth.signOut();
        throw Exception(
          'Usuario no asignado a ninguna sucursal.\nContacta al administrador.',
        );
      }

      print(
          '✅ Staff profile loaded: ${staffProfile.displayName ?? staffProfile.userId}');
      print('   Gym ID: ${staffProfile.gymId}');
      print('   Branch ID: ${staffProfile.branchId}');
      print('   Role: ${staffProfile.role}');

      // 3. Set tenant context
      await TenantContextService.to.setProfile(staffProfile);

      // 3b. Sync branding from DB (force to overwrite any stale local data)
      BrandingService.to.syncFromDb(
        dbGymName: staffProfile.gymName,
        dbBrandColor: staffProfile.brandColor,
        dbBrandFont: staffProfile.brandFont,
        force: true,
      );

      // 4. Clear form
      emailController.clear();
      passwordController.clear();

      // 5. Navigate to home
      Get.offAllNamed(Routes.HOME);

      return true;
    } on AuthException catch (e) {
      print('❌ Auth error: ${e.message}');
      if (e.message.contains('Invalid login credentials')) {
        errorMessage.value = 'Credenciales inválidas';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage.value = 'Email no confirmado';
      } else {
        errorMessage.value = 'Error de autenticación: ${e.message}';
      }
      return false;
    } catch (e) {
      print('❌ Login error: $e');
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Login with Google — platform-specific
  Future<bool> loginWithGoogle() async {
    // Prevent concurrent calls (double-tap)
    if (isLoading.value) return false;
    clearError();
    isLoading.value = true;

    try {
      if (GetPlatform.isAndroid) {
        return await _loginWithGoogleAndroid();
      } else {
        // iOS / other platforms — use Supabase OAuth flow
        return await _loginWithGoogleiOS();
      }
    } on AuthException catch (e) {
      print('❌ [Google] AuthException: ${e.message}');
      if (e.message.contains('host lookup') || e.message.contains('SocketException')) {
        errorMessage.value = 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
      } else {
        errorMessage.value = 'Error con Google: ${e.message}';
      }
      return false;
    } catch (e, stackTrace) {
      print('❌ [Google] Exception: $e');
      print('❌ [Google] StackTrace: $stackTrace');
      final msg = e.toString();
      if (msg.contains('12500') || msg.contains('sign_in_failed')) {
        errorMessage.value =
            'Google no está disponible en este dispositivo. Usa correo y contraseña para iniciar sesión.';
      } else if (msg.contains('host lookup') ||
          msg.contains('SocketException') ||
          msg.contains('No address associated')) {
        errorMessage.value =
            'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
      } else if (msg.contains('network_error') || msg.contains('12502')) {
        errorMessage.value =
            'Error de conexión. Verifica tu internet e intenta de nuevo.';
      } else {
        errorMessage.value = msg.replaceAll('Exception: ', '');
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Android: use google_sign_in plugin + signInWithIdToken
  Future<bool> _loginWithGoogleAndroid() async {
    print('🔵 [Google-Android] Starting Google Sign-In...');
    final srvClientId = dotenv.env['GOOGLE_SERVER_CLIENT_ID'];
    print('🔵 [Google-Android] serverClientId: $srvClientId');
    final googleSignIn = GoogleSignIn(
      serverClientId: srvClientId,
      scopes: ['email', 'profile'],
    );

    print('🔵 [Google-Android] Calling signIn()...');
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      print('🔵 [Google-Android] User cancelled sign-in');
      isLoading.value = false;
      return false;
    }

    print('🔵 [Google-Android] Signed in as: ${googleUser.email}');
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('No se pudo obtener el token de Google');
    }

    // Sign in to Supabase with Google token
    print('🔵 [Google-Android] Calling Supabase signInWithIdToken...');
    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (response.user == null) {
      throw Exception('Error al autenticar con Google');
    }

    return await _handleGoogleAuthResult(response.user!.id, googleUser.displayName, googleUser.email);
  }

  /// iOS: use Supabase native OAuth flow (no google_sign_in plugin)
  Future<bool> _loginWithGoogleiOS() async {
    print('🔵 [Google-iOS] Starting Supabase OAuth flow...');

    final success = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.googleusercontent.apps.161338034924-4kfeihb6hgt7hf8f3ritrb1v6lukodv5://',
    );

    if (!success) {
      print('❌ [Google-iOS] OAuth flow failed to launch');
      throw Exception('No se pudo iniciar sesión con Google');
    }

    print('🔵 [Google-iOS] OAuth launched, waiting for session...');

    // Listen for the auth state change when the OAuth redirect comes back
    final session = await _supabase.auth.onAuthStateChange
        .firstWhere((data) =>
            data.event == AuthChangeEvent.signedIn &&
            data.session != null)
        .timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw Exception('Tiempo de espera agotado'),
        );

    final userId = session.session!.user.id;
    print('✅ [Google-iOS] Supabase auth successful: $userId');

    // Get user metadata from Supabase session
    final userMeta = session.session!.user.userMetadata;
    final fullName = userMeta?['full_name'] as String? ??
        userMeta?['name'] as String? ??
        '';
    final email = session.session!.user.email ?? '';

    return await _handleGoogleAuthResult(userId, fullName, email);
  }

  /// Common handler after Google auth succeeds on any platform
  Future<bool> _handleGoogleAuthResult(
      String userId, String? displayName, String? email) async {
    // Check if user has staff_profile (existing gym owner)
    print('🔵 [Google] Checking staff profile for $userId...');
    final staffProfile = await _staffProfileProvider.getByUserId(userId);

    if (staffProfile != null && staffProfile.isActive) {
      print('✅ [Google] Existing user, navigating to HOME...');
      await TenantContextService.to.setProfile(staffProfile);
      BrandingService.to.syncFromDb(
        dbGymName: staffProfile.gymName,
        dbBrandColor: staffProfile.brandColor,
        dbBrandFont: staffProfile.brandFont,
        force: true,
      );

      emailController.clear();
      passwordController.clear();
      Get.offAllNamed(Routes.HOME);
      return true;
    } else {
      print('🔵 [Google] New user, navigating to GOOGLE_COMPLETE...');
      final registerCtrl = Get.put(RegisterController());
      final gName = displayName ?? '';
      final nameParts = gName.split(' ');
      registerCtrl.firstNameController.text =
          nameParts.isNotEmpty ? nameParts.first : '';
      registerCtrl.lastNameController.text =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      registerCtrl.emailController.text = email ?? '';
      registerCtrl.isGoogleUser.value = true;
      registerCtrl.googleUserId = userId;

      Get.toNamed(Routes.GOOGLE_COMPLETE);
      return false;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    // Backup current branding to DB before clearing
    try {
      final gymId = TenantContextService.to.currentGymId;
      if (gymId != null) {
        await _supabase.from('gyms').update({
          'brand_color': BrandingService.to.brandColorHex.value,
          'brand_font': BrandingService.to.brandFontName.value,
        }).eq('id', gymId);
      }
    } catch (e) {
      print('⚠️ Error backing up branding: $e');
    }

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('⚠️ Error signing out: $e');
    }
    // Clear branding so next account starts fresh
    BrandingService.to.clearBranding();
    await TenantContextService.to.clearProfile();
    Get.offAllNamed(Routes.LOGIN);
  }

  /// Check if there's an existing session
  ///
  /// Called on app start to determine if user is already logged in
  Future<bool> checkSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        print('⚠️ No existing session');
        return false;
      }

      print('📍 Found existing session for: ${session.user.email}');

      // Verify staff_profile is still valid
      final staffProfile = await _staffProfileProvider.getByUserId(
        session.user.id,
      );

      if (staffProfile == null || !staffProfile.isActive) {
        print('⚠️ Staff profile no longer valid');
        await logout();
        return false;
      }

      // Set tenant context
      await TenantContextService.to.setProfile(staffProfile);

      print(
          '✅ Session restored for ${staffProfile.displayName ?? session.user.email}');
      return true;
    } catch (e) {
      print('❌ Error checking session: $e');
      return false;
    }
  }

  /// Get current user info
  User? get currentUser => _supabase.auth.currentUser;

  /// Get current staff profile
  StaffProfileModel? get staffProfile => TenantContextService.to.staffProfile;

  /// Check if user is authenticated
  bool get isAuthenticated => TenantContextService.to.isAuthenticated;
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../data/providers/staff_profile_provider.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../data/services/branding_service.dart';
import '../../../routes/app_pages.dart';

/// Controller for registration (creating a new gym account)
///
/// Simplified flow:
///   1. User fills: name, email, password, gym name, location
///   2. On submit → creates auth user → calls RPC → auto-login → HOME
///   OR: Google Sign-In → if no gym → shows gym/location form → RPC → HOME
class RegisterController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StaffProfileProvider _staffProfileProvider = StaffProfileProvider();

  // Form controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final gymNameController = TextEditingController();
  final locationController = TextEditingController();

  // State
  final RxBool isLoading = false.obs;
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
    clearError();
    isLoading.value = true;

    try {
      if (GetPlatform.isAndroid) {
        await _registerWithGoogleAndroid();
      } else {
        // iOS / other platforms — use Supabase OAuth flow
        await _registerWithGoogleiOS();
      }
    } on AuthException catch (e) {
      print('❌ Google auth error: ${e.message}');
      errorMessage.value = 'Error con Google: ${e.message}';
    } catch (e) {
      print('❌ Google sign-in error: $e');
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  /// Android: use google_sign_in plugin
  Future<void> _registerWithGoogleAndroid() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
      scopes: ['email', 'profile'],
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      isLoading.value = false;
      return;
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('No se pudo obtener el token de Google');
    }

    final authResponse = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (authResponse.user == null) {
      throw Exception('Error al autenticar con Google');
    }

    await _handleGoogleRegResult(
      authResponse.user!.id,
      googleUser.displayName,
      googleUser.email,
    );
  }

  /// iOS: use Supabase native OAuth flow
  Future<void> _registerWithGoogleiOS() async {
    print('🔵 [Google-iOS] Starting Supabase OAuth flow for registration...');

    final success = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.googleusercontent.apps.161338034924-4kfeihb6hgt7hf8f3ritrb1v6lukodv5://',
    );

    if (!success) {
      throw Exception('No se pudo iniciar sesión con Google');
    }

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
    final userMeta = session.session!.user.userMetadata;
    final fullName = userMeta?['full_name'] as String? ??
        userMeta?['name'] as String? ??
        '';
    final email = session.session!.user.email ?? '';

    await _handleGoogleRegResult(userId, fullName, email);
  }

  /// Common handler after Google auth in registration
  Future<void> _handleGoogleRegResult(
      String userId, String? displayName, String? email) async {
    print('✅ Google auth successful: $userId');

    final staffProfile = await _staffProfileProvider.getByUserId(userId);

    if (staffProfile != null && staffProfile.isActive) {
      await TenantContextService.to.setProfile(staffProfile);
      BrandingService.to.syncFromDb(
        dbGymName: staffProfile.gymName,
        dbBrandColor: staffProfile.brandColor,
        dbBrandFont: staffProfile.brandFont,
        force: true,
      );
      Get.offAllNamed(Routes.HOME);
    } else {
      final gName = displayName ?? '';
      final nameParts = gName.split(' ');
      firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
      lastNameController.text =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
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
      });

      print('✅ Gym registered via Google flow');

      // Auto-login
      final staffProfile = await _staffProfileProvider.getByUserId(userId);

      if (staffProfile != null && staffProfile.isActive) {
        await TenantContextService.to.setProfile(staffProfile);
        BrandingService.to.setGymTitle(gymNameController.text.trim());
        Get.offAllNamed(Routes.HOME);
      } else {
        throw Exception('Error creando el perfil');
      }
    } catch (e) {
      print('❌ Complete registration error: $e');
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
      print('📝 Creating auth user...');
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
      print('✅ Auth user created: $userId');

      // 2. Call the register_gym_owner RPC function
      print('🏋️ Registering gym via RPC...');

      await _supabase.rpc('register_gym_owner', params: {
        'p_user_id': userId,
        'p_first_name': firstNameController.text.trim(),
        'p_last_name': lastNameController.text.trim(),
        'p_gym_name': gymNameController.text.trim(),
        'p_main_branch_name': locationController.text.trim(),
      });

      print('✅ Gym registered');

      // 3. Auto-login: fetch staff profile and set tenant context
      print('🔑 Auto-login: fetching staff profile...');
      final staffProfile = await _staffProfileProvider.getByUserId(userId);

      if (staffProfile != null && staffProfile.isActive) {
        await TenantContextService.to.setProfile(staffProfile);
        BrandingService.to.setGymTitle(gymNameController.text.trim());
        Get.offAllNamed(Routes.HOME);
      } else {
        // Fallback: staff profile not ready yet, go to login
        print('⚠️ Staff profile not ready, redirecting to login');
        Get.offAllNamed(Routes.LOGIN);
      }
    } on AuthException catch (e) {
      print('❌ Auth error: ${e.message}');
      if (e.message.contains('already registered')) {
        errorMessage.value = 'Este correo ya está registrado';
      } else {
        errorMessage.value = 'Error: ${e.message}';
      }
    } catch (e) {
      print('❌ Registration error: $e');
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}

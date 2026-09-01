import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/access_code_generator.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/staff_profile_model.dart';
import '../../../data/services/tenant_context_service.dart';
import '../../../routes/app_pages.dart';

/// Entrada del personal con un código de un solo uso.
///
/// El empleado no tiene correo ni contraseña. Al canjear el código, la app
/// abre una sesión ANÓNIMA de Supabase y la vincula a un `staff_profiles`
/// mediante la función `canjear_codigo_staff`. Esa sesión es una sesión real,
/// así que `auth.uid()` existe y toda la RLS del proyecto sigue aplicando sin
/// ningún cambio; para el empleado, en cambio, se siente como entrar sin login
/// y queda guardada en el dispositivo.
class StaffCodeController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  final codigoController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onClose() {
    codigoController.dispose();
    super.onClose();
  }

  void clearError() => errorMessage.value = null;

  /// Canjea el código y entra. Devuelve true si lo consiguió.
  Future<bool> entrar() async {
    if (isLoading.value) return false;
    clearError();

    final codigo = codigoController.text;
    if (!AccessCodeGenerator.esFormatoValido(codigo)) {
      errorMessage.value = 'El código tiene 8 caracteres. Revísalo.';
      return false;
    }

    isLoading.value = true;
    bool sesionCreada = false;

    try {
      // 1. Sesión anónima: la función de canje necesita un auth.uid().
      await _supabase.auth.signInAnonymously();
      sesionCreada = true;

      // 2. Canje. El código en claro nunca sale del dispositivo.
      final response = await _supabase.rpc(
        'canjear_codigo_staff',
        params: {'p_codigo_hash': AccessCodeGenerator.hash(codigo)},
      );

      if (response == null) {
        throw Exception('Código inválido o ya utilizado');
      }

      final profile =
          StaffProfileModel.fromJson(Map<String, dynamic>.from(response));

      // 3. Contexto de tenant y a Inicio.
      await TenantContextService.to.setProfile(profile);
      codigoController.clear();
      Get.offAllNamed(Routes.HOME);
      return true;
    } catch (e) {
      AppLogger.error('StaffCodeController', 'Error al canjear código', e);

      // Sin esto, cada intento fallido dejaría un usuario anónimo suelto.
      if (sesionCreada) {
        try {
          await _supabase.auth.signOut();
        } catch (_) {
          // Da igual: la sesión inválida no sirve de nada.
        }
      }

      errorMessage.value = _mensajeError(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String _mensajeError(Object e) {
    final texto = e.toString().toLowerCase();

    if (texto.contains('anonymous') && texto.contains('disabled')) {
      return 'La entrada por código no está habilitada. '
          'Avisa al dueño del gimnasio.';
    }
    if (texto.contains('ya tiene un acceso asignado')) {
      return 'Este dispositivo ya tiene una sesión. Ciérrala antes de usar '
          'otro código.';
    }
    if (texto.contains('inválido') || texto.contains('invalido')) {
      return 'Código inválido o ya utilizado. Pídele uno nuevo al dueño.';
    }
    if (texto.contains('socketexception') ||
        texto.contains('host lookup') ||
        texto.contains('failed host')) {
      return 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
    }
    return 'Código inválido o ya utilizado. Pídele uno nuevo al dueño.';
  }
}

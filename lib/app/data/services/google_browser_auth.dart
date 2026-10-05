import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_oauth_window.dart';

/// El resultado viene de la ventana que abrió este intento, nunca de una
/// sesión de correo ni de una escucha pendiente de un intento anterior.
class GoogleBrowserAuth {
  GoogleBrowserAuth(this.auth, {GoogleOAuthWindow Function()? windowFactory})
      : _windowFactory = windowFactory ?? createGoogleOAuthWindow;

  final GoTrueClient auth;
  final GoogleOAuthWindow Function() _windowFactory;
  GoogleOAuthWindow? _window;
  bool _cancelled = false;
  bool _exchanging = false;
  static GoogleBrowserAuth? _active;

  void cancel() {
    // Después del retorno ya se está completando la sesión: los botones
    // vuelven al estado de carga hasta que ese paso termine.
    if (_exchanging) return;
    _cancelled = true;
    _window?.cancel();
  }

  Future<User?> signIn({void Function(bool waiting)? onWaiting}) async {
    _active?.cancel();
    _active = this;
    try {
      if (_cancelled) return null;
      final window = _window = _windowFactory();
      final redirect = await window.prepare();
      if (_cancelled) return null;
      final authorization = await auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: redirect,
        queryParams: const {'prompt': 'select_account'},
      );
      if (_cancelled) return null;

      onWaiting?.call(true);
      final callback = await window.authenticate(authorization.url);
      onWaiting?.call(false);
      if (_cancelled || callback == null) return null;

      final expected = Uri.parse(redirect);
      if (callback.scheme != expected.scheme ||
          callback.host != expected.host ||
          callback.port != expected.port ||
          callback.path != expected.path) {
        throw const GoogleOAuthFailure(
            'No se pudo completar el regreso de Google. Intenta de nuevo.');
      }

      _exchanging = true;
      final response = await auth.getSessionFromUrl(callback).timeout(
            const Duration(seconds: 30),
          );
      return response.session.user;
    } on TimeoutException {
      throw const GoogleOAuthFailure(
          'No se pudo completar el inicio de sesión. Revisa tu conexión e intenta de nuevo.');
    } finally {
      onWaiting?.call(false);
      await _window?.dispose();
      if (identical(_active, this)) _active = null;
    }
  }
}

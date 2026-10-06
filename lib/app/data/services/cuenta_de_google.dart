import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/app_logger.dart';

/// Abre la hoja nativa de Google (Android e iOS) dejando elegir la cuenta.
///
/// El plugin recuerda la última cuenta usada y `signIn()` la devolvía directo,
/// sin mostrar el selector: al cerrar sesión en la app solo se cerraba la de
/// Supabase, así que ya no había forma de entrar con otra cuenta. Se olvida
/// antes de cada inicio, sin importar cómo se cerró la sesión (Inicio,
/// Configuración, al borrar el gimnasio o porque venció). El flujo por
/// navegador (computadora, Huawei) ya lo pide con `prompt=select_account`.
Future<GoogleSignInAccount?> elegirCuentaDeGoogle(GoogleSignIn google) async {
  try {
    await google.signOut();
  } catch (e) {
    // Sin una cuenta recordada no hay nada que olvidar.
    AppLogger.warning('CuentaDeGoogle', 'No se pudo olvidar la cuenta: $e');
  }
  return google.signIn();
}

/// Elige la cuenta de Google y entra con ella a Supabase ([entrar] recibe el
/// `idToken` y el `accessToken`). Null si se cancela la elección.
///
/// Los servicios de Google de Android guardan el último token de cada cuenta
/// y lo vuelven a entregar al elegirla. Dura una hora: al volver a entrar con
/// la misma cuenta más tarde (pasó al borrar la cuenta y crearla otra vez),
/// llegaba vencido y Supabase respondía "Bad ID token". Si lo rechaza, se
/// desconecta la cuenta (eso obliga a pedir un token nuevo) y se intenta una
/// vez más.
Future<({GoogleSignInAccount cuenta, AuthResponse respuesta})?> entrarConGoogle(
  GoogleSignIn google,
  Future<AuthResponse> Function(String idToken, String? accessToken) entrar,
) async {
  var cuenta = await elegirCuentaDeGoogle(google);
  if (cuenta == null) return null;
  try {
    return (cuenta: cuenta, respuesta: await _conSusTokens(cuenta, entrar));
  } on AuthException catch (e) {
    if (!tokenRechazado(e)) rethrow;
    AppLogger.warning(
        'CuentaDeGoogle', 'Supabase rechazó el token de Google; se pide otro');
    try {
      await google.disconnect();
    } catch (e) {
      AppLogger.warning('CuentaDeGoogle', 'No se pudo desconectar: $e');
    }
    cuenta = await google.signIn();
    if (cuenta == null) return null;
    return (cuenta: cuenta, respuesta: await _conSusTokens(cuenta, entrar));
  }
}

Future<AuthResponse> _conSusTokens(
  GoogleSignInAccount cuenta,
  Future<AuthResponse> Function(String idToken, String? accessToken) entrar,
) async {
  final tokens = await cuenta.authentication;
  final idToken = tokens.idToken;
  if (idToken == null) {
    throw Exception('No se pudo obtener el token de Google');
  }
  return entrar(idToken, tokens.accessToken);
}

/// Supabase no aceptó el token de Google (vencido o inválido).
bool tokenRechazado(AuthException e) =>
    e.message.toLowerCase().contains('bad id token');

/// Lo que se le dice a la persona si ni con un token nuevo se pudo entrar.
const mensajeTokenRechazado =
    'Google no pudo confirmar tu cuenta. Revisa que la fecha y la hora del '
    'dispositivo sean correctas e inténtalo de nuevo.';

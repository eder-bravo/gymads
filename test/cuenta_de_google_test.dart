import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gymads/app/data/services/cuenta_de_google.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entrar con Google en Android e iOS: siempre se elige la cuenta, y si
/// Supabase rechaza un token guardado y vencido ("Bad ID token") se pide uno
/// nuevo en lugar de mostrar el error.
class _Tokens extends Fake implements GoogleSignInAuthentication {
  _Tokens(this.idToken);
  @override
  final String? idToken;
  @override
  String? get accessToken => 'acceso';
}

class _Cuenta extends Fake implements GoogleSignInAccount {
  _Cuenta(this.token);
  final String token;
  @override
  Future<GoogleSignInAuthentication> get authentication async => _Tokens(token);
}

class _Google extends Fake implements GoogleSignIn {
  _Google({this.fallaAlOlvidar = false, List<String?>? tokens})
      : _tokens = tokens ?? ['token-1', 'token-2'];
  final bool fallaAlOlvidar;
  final List<String?> _tokens;
  final llamadas = <String>[];
  var _elegidas = 0;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    llamadas.add('olvidar');
    if (fallaAlOlvidar) throw Exception('sin cuenta');
    return null;
  }

  @override
  Future<GoogleSignInAccount?> disconnect() async {
    llamadas.add('desconectar');
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    llamadas.add('elegir');
    final token = _tokens[_elegidas++];
    return token == null ? null : _Cuenta(token);
  }
}

const _vencido = AuthException('Bad ID token', statusCode: '400');

void main() {
  test('olvida la cuenta anterior antes de abrir el selector', () async {
    final google = _Google();
    await elegirCuentaDeGoogle(google);
    expect(google.llamadas, ['olvidar', 'elegir']);
  });

  test('si no había cuenta que olvidar, igual abre el selector', () async {
    final google = _Google(fallaAlOlvidar: true);
    await elegirCuentaDeGoogle(google);
    expect(google.llamadas, ['olvidar', 'elegir']);
  });

  test('entra con el token de la cuenta elegida', () async {
    final google = _Google();
    final usados = <String>[];
    final entrada = await entrarConGoogle(google, (id, acceso) async {
      usados.add('$id/$acceso');
      return AuthResponse();
    });
    expect(entrada, isNotNull);
    expect(usados, ['token-1/acceso']);
    expect(google.llamadas, ['olvidar', 'elegir']);
  });

  test('con un token vencido ("Bad ID token") pide otro y entra', () async {
    final google = _Google();
    final usados = <String>[];
    final entrada = await entrarConGoogle(google, (id, _) async {
      usados.add(id);
      if (id == 'token-1') throw _vencido;
      return AuthResponse();
    });
    expect(entrada, isNotNull);
    expect(usados, ['token-1', 'token-2']);
    expect(google.llamadas, ['olvidar', 'elegir', 'desconectar', 'elegir']);
  });

  test('si el nuevo también se rechaza, avisa (una sola vez más)', () async {
    final google = _Google();
    var intentos = 0;
    await expectLater(
      entrarConGoogle(google, (_, __) async {
        intentos++;
        throw _vencido;
      }),
      throwsA(isA<AuthException>().having(tokenRechazado, 'rechazado', true)),
    );
    expect(intentos, 2);
  });

  test('otros errores no se reintentan', () async {
    final google = _Google();
    await expectLater(
      entrarConGoogle(google, (_, __) async {
        throw const AuthException('Database error saving new user');
      }),
      throwsA(isA<AuthException>()),
    );
    expect(google.llamadas, isNot(contains('desconectar')));
  });

  test('cancelar la elección no entra', () async {
    final google = _Google(tokens: [null]);
    var entro = false;
    final entrada = await entrarConGoogle(google, (_, __) async {
      entro = true;
      return AuthResponse();
    });
    expect(entrada, isNull);
    expect(entro, isFalse);
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gymads/app/data/services/google_browser_auth.dart';
import 'package:gymads/app/data/services/google_oauth_window_types.dart';
import 'package:gymads/app/data/services/google_oauth_window_io.dart';
import 'package:gymads/app/modules/auth/controllers/auth_controller.dart';
import 'package:gymads/app/modules/auth/controllers/register_controller.dart';

class _Window implements GoogleOAuthWindow {
  final started = Completer<void>();
  final result = Completer<Uri?>();
  int disposals = 0;

  @override
  Future<String> prepare() async => 'gymone-test://';

  @override
  Future<Uri?> authenticate(String url) {
    started.complete();
    return result.future;
  }

  @override
  void cancel() {
    if (!result.isCompleted) result.complete(null);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    cancel();
  }
}

class _Auth extends GoTrueClient {
  _Auth() : super(autoRefreshToken: false);
  int exchanges = 0;
  String? redirect;
  Map<String, String>? query;

  @override
  Future<OAuthResponse> getOAuthSignInUrl({
    required OAuthProvider provider,
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    redirect = redirectTo;
    query = queryParams;
    return OAuthResponse(
        provider: provider, url: 'https://accounts.google.com/');
  }

  @override
  Future<AuthSessionUrlResponse> getSessionFromUrl(Uri uri,
      {bool storeSession = true}) async {
    exchanges++;
    return AuthSessionUrlResponse(
      session: Session(
        accessToken: 'test-token',
        tokenType: 'bearer',
        user: const User(
          id: 'google-user',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-10-05',
        ),
      ),
      redirectType: null,
    );
  }
}

// Solo loopback local: evita el HttpClient simulado por el binding de Flutter.
class _LocalHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Resultado de la ventana de Google', () {
    late _Auth auth;
    late _Window window;
    late GoogleBrowserAuth flow;

    setUp(() {
      auth = _Auth();
      window = _Window();
      flow = GoogleBrowserAuth(auth, windowFactory: () => window);
    });

    tearDown(() => auth.dispose());

    test('cerrar no intercambia una sesión y libera la espera', () async {
      final waiting = <bool>[];
      final pending = flow.signIn(onWaiting: waiting.add);
      await window.started.future;
      window.result.complete(null);
      expect(await pending, isNull);
      expect(waiting, [true, false, false]);
      expect(auth.exchanges, 0);
      expect(window.disposals, 1);
    });

    test('el retorno se intercambia una sola vez sin escuchar otras sesiones',
        () async {
      final pending = flow.signIn();
      await window.started.future;
      window.result.complete(Uri.parse('gymone-test://?code=one-use-code'));
      expect((await pending)?.id, 'google-user');
      expect(auth.exchanges, 1);
      expect(auth.query, {'prompt': 'select_account'});
      expect(window.disposals, 1);
    });

    test('cancelar no espera a que el navegador termine', () async {
      final pending = flow.signIn();
      await window.started.future;
      flow.cancel();
      expect(await pending, isNull);
      expect(auth.exchanges, 0);
    });

    test('un nuevo intento cancela el anterior', () async {
      final old = flow.signIn();
      await window.started.future;
      final nextWindow = _Window();
      final next = GoogleBrowserAuth(auth, windowFactory: () => nextWindow);
      final pending = next.signIn();
      await nextWindow.started.future;
      expect(await old, isNull);
      next.cancel();
      expect(await pending, isNull);
      expect(auth.exchanges, 0);
    });

    test('rechaza un retorno con destino distinto', () async {
      final pending = flow.signIn();
      final expectation =
          expectLater(pending, throwsA(isA<GoogleOAuthFailure>()));
      await window.started.future;
      window.result.complete(Uri.parse('other-app://?code=unexpected'));
      await expectation;
      expect(auth.exchanges, 0);
    });
  });

  group('Controles de acceso y registro', () {
    late Completer<http.Response> emailResponse;
    late Completer<void> emailStarted;
    late _Auth auth;
    late _Window window;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        publishableKey: 'test-key',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          detectSessionInUri: false,
          autoRefreshToken: false,
        ),
        httpClient: MockClient((request) {
          expect(request.url.queryParameters['grant_type'], 'password');
          emailStarted.complete();
          return emailResponse.future;
        }),
      );
    });

    tearDownAll(() => Supabase.instance.dispose());

    setUp(() {
      emailResponse = Completer<http.Response>();
      emailStarted = Completer<void>();
      auth = _Auth();
      window = _Window();
    });

    tearDown(() => auth.dispose());

    GoogleBrowserAuth factory(GoTrueClient _) =>
        GoogleBrowserAuth(auth, windowFactory: () => window);

    test('cerrar Google vuelve a habilitar el login', () async {
      final controller = AuthController(browserFactory: factory);
      addTearDown(controller.onClose);
      final pending = controller.loginWithGoogle();
      await window.started.future;
      expect(controller.waitingForGoogle.value, isTrue);
      window.cancel();
      expect(await pending, isFalse);
      expect(controller.isLoading.value, isFalse);
      expect(controller.waitingForGoogle.value, isFalse);
      expect(controller.errorMessage.value, isNull);
    });

    test('correo cancela Google; el intento viejo no altera su carga',
        () async {
      final controller = AuthController(browserFactory: factory);
      addTearDown(controller.onClose);
      final google = controller.loginWithGoogle();
      await window.started.future;
      controller.emailController.text = 'usuario@example.com';
      controller.passwordController.text = 'password123';
      final email = controller.login();
      await emailStarted.future;
      expect(await google, isFalse);
      expect(controller.waitingForGoogle.value, isFalse);
      expect(controller.isLoading.value, isTrue);
      expect(auth.exchanges, 0);
      emailResponse.complete(http.Response(
        '{"msg":"Invalid login credentials","code":"invalid_credentials"}',
        400,
        headers: {'content-type': 'application/json'},
      ));
      expect(await email, isFalse);
      expect(controller.errorMessage.value, 'Credenciales inválidas');
      expect(controller.isLoading.value, isFalse);
    });

    test('cancelar Google también libera el registro', () async {
      final controller = RegisterController(browserFactory: factory);
      addTearDown(controller.onClose);
      final pending = controller.registerWithGoogle();
      await window.started.future;
      controller.cancelGoogleSignIn();
      await pending;
      expect(controller.isLoading.value, isFalse);
      expect(controller.waitingForGoogle.value, isFalse);
      expect(controller.errorMessage.value, isNull);
      expect(controller.isGoogleUser.value, isFalse);
    });
  });

  group('Retorno del navegador de escritorio', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('window_to_front'), (_) async => null);
    });

    test('recibe el código solo en la ruta correcta y ofrece cerrar la pestaña',
        () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final window = DesktopGoogleOAuthWindow(openUrl: (_) async => true);
        final client = HttpClient();
        addTearDown(() async {
          client.close(force: true);
          await window.dispose();
        });
        final redirect = Uri.parse(await window.prepare());
        final pending = window.authenticate('https://accounts.google.com/');
        final invalid = await client.getUrl(redirect.replace(path: '/wrong'));
        final invalidResponse = await invalid.close();
        expect(invalidResponse.statusCode, 404);
        await invalidResponse.drain<void>();
        final request =
            await client.getUrl(redirect.replace(query: 'code=valid'));
        final response = await request.close();
        final page =
            await response.transform(const SystemEncoding().decoder).join();
        expect(page, contains('window.close()'));
        expect(page, contains('Puedes cerrar esta pestaña'));
        expect((await pending)?.queryParameters['code'], 'valid');
      }, _LocalHttp());
    });

    test('cancelar completa la espera sin retorno de Google', () async {
      final window = DesktopGoogleOAuthWindow(openUrl: (_) async => true);
      addTearDown(window.dispose);
      await window.prepare();
      final pending = window.authenticate('https://accounts.google.com/');
      window.cancel();
      expect(await pending, isNull);
    });
  });

  if (Platform.isMacOS) {
    test('macOS abre el navegador externo, no la sesión de Safari', () async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final launched = Completer<MethodCall>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        launched.complete(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final window = createGoogleOAuthWindow();
      expect(window, isA<DesktopGoogleOAuthWindow>());
      addTearDown(window.dispose);
      final redirect = Uri.parse(await window.prepare());
      expect(redirect.host, '127.0.0.1');
      final pending = window.authenticate('https://accounts.google.com/');
      final call = await launched.future;
      expect(call.method, 'launch');
      expect(call.arguments['url'], 'https://accounts.google.com/');
      expect(call.arguments['useSafariVC'], isFalse);
      expect(call.arguments['useWebView'], isFalse);
      window.cancel();
      expect(await pending, isNull);
    });
  }
}

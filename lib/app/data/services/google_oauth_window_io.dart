import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_to_front/window_to_front.dart';

import '../config/auth_config.dart';
import 'google_oauth_window_types.dart';

GoogleOAuthWindow createGoogleOAuthWindow() =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux
        ? DesktopGoogleOAuthWindow()
        : _SystemGoogleOAuthWindow();

/// Sesión del navegador del sistema (sin WebView ni Google Play Services).
class _SystemGoogleOAuthWindow implements GoogleOAuthWindow {
  final _cancelled = Completer<Uri?>();

  @override
  Future<String> prepare() async => AuthConfig.oauthRedirectUrl;

  @override
  Future<Uri?> authenticate(String url) async {
    if (_cancelled.isCompleted) return null;
    final result = _authenticate(url);
    return Future.any([result, _cancelled.future]);
  }

  Future<Uri?> _authenticate(String url) async {
    try {
      final callback = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: AuthConfig.oauthRedirectScheme,
      );
      return _cancelled.isCompleted ? null : Uri.parse(callback);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') return null;
      if (error.code == 'NO_BROWSER' || error.code == 'SECURITY_EXCEPTION') {
        throw const GoogleOAuthFailure(
            'No se pudo abrir el navegador. Revisa que tengas uno instalado e intenta de nuevo.');
      }
      rethrow;
    }
  }

  @override
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete(null);
  }

  @override
  Future<void> dispose() async => cancel();
}

/// macOS/Windows/Linux usan el navegador predeterminado y un retorno de un solo uso en
/// loopback. Nunca se abre Google en un WebView incrustado.
class DesktopGoogleOAuthWindow implements GoogleOAuthWindow {
  DesktopGoogleOAuthWindow({Future<bool> Function(Uri)? openUrl})
      : _openUrl = openUrl ?? _openBrowser;

  final Future<bool> Function(Uri) _openUrl;

  static Future<bool> _openBrowser(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  final _result = Completer<Uri?>();
  HttpServer? _server;
  Timer? _timeout;

  @override
  Future<String> prepare() async {
    final server =
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (_result.isCompleted) {
      await server.close(force: true);
      return '';
    }
    final redirect = 'http://127.0.0.1:${server.port}/auth/callback';
    server.listen((request) async {
      final uri = Uri.parse(redirect).replace(query: request.uri.query);
      final isCallback = request.uri.path == '/auth/callback' &&
          (uri.queryParameters.containsKey('code') ||
              uri.queryParameters.containsKey('error'));
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.set('Referrer-Policy', 'no-referrer');
      if (!isCallback || _result.isCompleted) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.write(_landingPage);
      await request.response.close();
      if (!_result.isCompleted) _result.complete(uri);
      // El navegador puede impedir cerrar una pestaña abierta externamente;
      // en cualquier caso la app vuelve al frente y termina la espera.
      try {
        await WindowToFront.activate();
      } catch (_) {
        // No afecta al intercambio del código ni a la sesión.
      }
    });
    return redirect;
  }

  @override
  Future<Uri?> authenticate(String url) async {
    if (_result.isCompleted) return null;
    _timeout = Timer(const Duration(minutes: 5), cancel);
    final opened = await _openUrl(Uri.parse(url));
    if (!opened) {
      throw const GoogleOAuthFailure('No se pudo abrir el navegador.');
    }
    return _result.future;
  }

  @override
  void cancel() {
    if (!_result.isCompleted) _result.complete(null);
    _timeout?.cancel();
    unawaited(_server?.close(force: true));
  }

  @override
  Future<void> dispose() async {
    cancel();
    await _server?.close(force: true);
  }
}

const _landingPage = '''<!doctype html>
<html lang="es"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Volver a GymOne</title>
<body style="font-family:system-ui;text-align:center;padding:48px">
<h1>Regresa a GymOne para continuar</h1>
<p>Puedes cerrar esta pestaña.</p>
<script>history.replaceState(null, '', '/auth/callback'); window.close();</script>
</body></html>''';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:win32_registry/win32_registry.dart';

import '../config/auth_config.dart';

/// Registra para el usuario actual el protocolo que devuelve OAuth a GymOne.
/// No requiere permisos de administrador y solo se ejecuta en Windows.
abstract final class WindowsOAuthProtocol {
  static void register() {
    if (kIsWeb || !Platform.isWindows) return;

    final currentUser = Registry.currentUser;
    try {
      final protocolKey = currentUser.createKey(
        'Software\\Classes\\${AuthConfig.oauthRedirectScheme}',
      );
      try {
        protocolKey
          ..createValue(const RegistryValue.string('', 'URL:GymOne'))
          ..createValue(const RegistryValue.string('URL Protocol', ''));

        final commandKey = protocolKey.createKey(r'shell\open\command');
        try {
          commandKey.createValue(
            RegistryValue.string(
              '',
              '"${Platform.resolvedExecutable}" "%1"',
            ),
          );
        } finally {
          commandKey.close();
        }
      } finally {
        protocolKey.close();
      }
    } finally {
      currentUser.close();
    }
  }
}

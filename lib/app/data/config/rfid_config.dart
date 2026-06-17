import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Configuración simplificada del lector RFID ESP32 con IP manual
class RfidConfig {
  // ⭐ CAMBIAR ESTA IP POR LA DEL ESP32 ⭐
  static const String DEFAULT_ESP32_IP = '192.168.100.109';

  static const String _urlKey = 'esp32_api_url';
  static String? _currentUrl;

  // URL del ESP32
  static String? get baseUrl {
    return _currentUrl ?? 'http://$DEFAULT_ESP32_IP/api';
  }

  // Siempre configurado con IP manual
  static bool get isConfigured => true;

  // Cargar configuración
  static Future<void> loadConfig() async {
    try {
      if (kDebugMode) {
        print('🔧 Cargando configuración RFID...');
      }

      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_urlKey);

      if (savedUrl != null && savedUrl.isNotEmpty) {
        if (kDebugMode) {
          print('📱 URL guardada encontrada: $savedUrl');
        }
        if (await _testConnection(savedUrl)) {
          _currentUrl = savedUrl;
          if (kDebugMode) {
            print('✅ IP guardada es válida: $savedUrl');
          }
          return;
        } else {
          if (kDebugMode) {
            print('❌ IP guardada no responde, intentando IP por defecto');
          }
        }
      }

      // Usar IP por defecto
      final defaultUrl = 'http://$DEFAULT_ESP32_IP/api';
      _currentUrl = defaultUrl;
      if (kDebugMode) {
        print('🔧 Intentando IP por defecto: $defaultUrl');
      }

      if (await _testConnection(defaultUrl)) {
        await saveConfig(defaultUrl);
        if (kDebugMode) {
          print('✅ Conectado usando IP por defecto: $defaultUrl');
        }
      } else {
        if (kDebugMode) {
          print('❌ IP por defecto no responde: $defaultUrl');
          print('🔧 Verificar que el ESP32 esté encendido y en la red WiFi');
        }
      }
    } catch (e) {
      _currentUrl = 'http://$DEFAULT_ESP32_IP/api';
      if (kDebugMode) {
        print('❌ Error al cargar configuración: $e');
      }
    }
  }

  // Configurar IP manualmente
  static Future<bool> setManualIP(String ipAddress) async {
    if (ipAddress.isEmpty) {
      if (kDebugMode) {
        print('IP proporcionada está vacía');
      }
      return false;
    }

    String validatedUrl = 'http://$ipAddress/api';

    if (kDebugMode) {
      print('Configurando ESP32 manualmente: $validatedUrl');
    }

    if (await _testConnection(validatedUrl)) {
      _currentUrl = validatedUrl;
      await saveConfig(validatedUrl);
      if (kDebugMode) {
        print('IP configurada exitosamente: $validatedUrl');
      }
      return true;
    } else {
      if (kDebugMode) {
        print('IP proporcionada no responde: $ipAddress');
      }
      return false;
    }
  }

  // Obtener IP actual
  static String? getCurrentIP() {
    if (_currentUrl == null) return DEFAULT_ESP32_IP;
    try {
      final uri = Uri.parse(_currentUrl!);
      return uri.host;
    } catch (e) {
      return DEFAULT_ESP32_IP;
    }
  }

  // Probar conexión
  static Future<bool> _testConnection(String url) async {
    try {
      // La URL ya debe incluir /api, solo agregamos /status
      final statusUrl =
          url.endsWith('/api') ? '$url/status' : '$url/api/status';

      if (kDebugMode) {
        print('🔍 Probando conexión a: $statusUrl');
      }

      final response = await http.get(
        Uri.parse(statusUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          print('✅ ESP32 encontrado y funcionando');
          print('📊 Status: ${data['status'] ?? 'unknown'}');
          print('📡 WiFi: ${data['wifi_connected'] ?? 'unknown'}');
          print('🌐 IP: ${data['ip_address'] ?? 'unknown'}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ ESP32 respondió con código: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al probar conexión: $e');
        if (e.toString().contains('TimeoutException')) {
          print('⏱️  Timeout: El ESP32 no responde en el tiempo esperado');
          print(
              '🔧 Verificar que el ESP32 esté encendido y en la misma red WiFi');
        }
      }
      return false;
    }
  }

  // Guardar configuración
  static Future<void> saveConfig(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlKey, url);
      if (kDebugMode) {
        print('Configuración guardada: $url');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al guardar configuración: $e');
      }
    }
  }

  // Método de compatibilidad
  static Future<void> updateConfig({String? newUrl}) async {
    if (newUrl != null && newUrl.isNotEmpty) {
      _currentUrl = validateUrl(newUrl);
      await saveConfig(_currentUrl!);
      if (kDebugMode) {
        print('Configuración actualizada: $_currentUrl');
      }
    }
  }

  // Forzar actualización de IP manualmente (sin validación previa)
  static Future<void> forceUpdateIP(String ip) async {
    try {
      String formattedUrl = 'http://$ip/api';
      _currentUrl = formattedUrl;
      await saveConfig(formattedUrl);
      if (kDebugMode) {
        print('IP forzada manualmente: $ip');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al forzar IP manual: $e');
      }
    }
  }

  // Limpiar configuración
  static Future<void> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_urlKey);
      _currentUrl = null;
      if (kDebugMode) {
        print('Configuración limpiada');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al limpiar configuración: $e');
      }
    }
  }

  // Validar URL
  static String validateUrl(String url) {
    String validUrl =
        url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (!validUrl.startsWith('http://') && !validUrl.startsWith('https://')) {
      validUrl = 'http://$validUrl';
    }
    // Añadir /api si no está presente
    if (!validUrl.endsWith('/api')) {
      validUrl = '$validUrl/api';
    }
    return validUrl;
  }

  // Verificar si el ESP32 está disponible
  static Future<bool> isESP32Available() async {
    try {
      return await _testConnection(baseUrl ?? 'http://$DEFAULT_ESP32_IP/api');
    } catch (e) {
      return false;
    }
  }

  // Obtener información del ESP32
  static Future<Map<String, dynamic>?> getESP32Info() async {
    try {
      final url = baseUrl ?? 'http://$DEFAULT_ESP32_IP/api';
      final response = await http.get(
        Uri.parse('$url/discover'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener información del ESP32: $e');
      }
      return null;
    }
  }

  // Mostrar configuración actual
  static void showCurrentConfig() {
    if (kDebugMode) {
      print('========================================');
      print('CONFIGURACIÓN RFID ACTUAL');
      print('========================================');
      print('IP por defecto: $DEFAULT_ESP32_IP');
      print('URL actual: ${_currentUrl ?? "No configurada"}');
      print('IP actual: ${getCurrentIP()}');
      print('Configurado: $isConfigured');
      print('========================================');
    }
  }

  // =================== CONSTANTES DEL SISTEMA ===================

  // Tiempo máximo de espera para lectura de tarjeta (en segundos)
  static int get maxReadingTimeoutSeconds => 15;

  // Intervalo de verificación para nuevas tarjetas (en milisegundos)
  static int get pollingIntervalMs => 500;

  // Estados de membresía para el sistema de LEDs
  static const String membershipActive = 'active';
  static const String membershipExpiring = 'expiring';
  static const String membershipExpired = 'expired';
  static const String membershipNotFound = 'not_found';

  // Días de advertencia antes del vencimiento
  static int get expiringWarningDays => 5;
}

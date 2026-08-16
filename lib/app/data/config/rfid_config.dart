import 'package:flutter/foundation.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Configuración simplificada del lector RFID ESP32 con IP manual
class RfidConfig {
  // CAMBIAR ESTA IP POR LA DEL ESP32
  static const String DEFAULT_ESP32_IP = '192.168.1.100';

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
      AppLogger.info('RfidConfig', 'Cargando configuración RFID');

      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_urlKey);

      if (savedUrl != null && savedUrl.isNotEmpty) {
        AppLogger.info('RfidConfig', 'URL guardada encontrada');
        if (await _testConnection(savedUrl)) {
          _currentUrl = savedUrl;
          AppLogger.info('RfidConfig', 'IP guardada es válida');
          return;
        } else {
          AppLogger.error('RfidConfig', 'IP guardada no responde, intentando IP por defecto');
        }
      }

      // Usar IP por defecto
      final defaultUrl = 'http://$DEFAULT_ESP32_IP/api';
      _currentUrl = defaultUrl;
      AppLogger.info('RfidConfig', 'Intentando IP por defecto');

      if (await _testConnection(defaultUrl)) {
        await saveConfig(defaultUrl);
        AppLogger.info('RfidConfig', 'Conectado usando IP por defecto');
      } else {
        AppLogger.error('RfidConfig', 'IP por defecto no responde');
        AppLogger.info('RfidConfig', 'Verificar que el ESP32 esté encendido y en la red WiFi');
      }
    } catch (e) {
      _currentUrl = 'http://$DEFAULT_ESP32_IP/api';
      AppLogger.error('RfidConfig', 'Error al cargar configuración', e);
    }
  }

  // Configurar IP manualmente
  static Future<bool> setManualIP(String ipAddress) async {
    if (ipAddress.isEmpty) {
      AppLogger.info('RfidConfig', 'IP proporcionada está vacía');
      return false;
    }

    String validatedUrl = 'http://$ipAddress/api';

    AppLogger.info('RfidConfig', 'Configurando ESP32 manualmente');

    if (await _testConnection(validatedUrl)) {
      _currentUrl = validatedUrl;
      await saveConfig(validatedUrl);
      AppLogger.info('RfidConfig', 'IP configurada exitosamente');
      return true;
    } else {
      AppLogger.warning('RfidConfig', 'La IP proporcionada no responde');
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

      AppLogger.info('RfidConfig', 'Probando conexión');

      final response = await http.get(
        Uri.parse(statusUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        AppLogger.info('RfidConfig', 'ESP32 encontrado y funcionando');
        return true;
      } else {
        AppLogger.error('RfidConfig', 'ESP32 respondió con código');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.error('RfidConfig', 'Error al probar conexión', e);
        if (e.toString().contains('TimeoutException')) {
          AppLogger.info('RfidConfig', 'Timeout: El ESP32 no responde en el tiempo esperado');
          AppLogger.info('RfidConfig', 'Verificar que el ESP32 esté encendido y en la misma red WiFi');
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
      AppLogger.info('RfidConfig', 'Configuración guardada');
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al guardar configuración', e);
    }
  }

  // Método de compatibilidad
  static Future<void> updateConfig({String? newUrl}) async {
    if (newUrl != null && newUrl.isNotEmpty) {
      _currentUrl = validateUrl(newUrl);
      await saveConfig(_currentUrl!);
      AppLogger.info('RfidConfig', 'Configuración actualizada');
    }
  }

  // Forzar actualización de IP manualmente (sin validación previa)
  static Future<void> forceUpdateIP(String ip) async {
    try {
      String formattedUrl = 'http://$ip/api';
      _currentUrl = formattedUrl;
      await saveConfig(formattedUrl);
      AppLogger.info('RfidConfig', 'IP forzada manualmente');
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al forzar IP manual', e);
    }
  }

  // Limpiar configuración
  static Future<void> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_urlKey);
      _currentUrl = null;
      AppLogger.info('RfidConfig', 'Configuración limpiada');
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al limpiar configuración', e);
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
      AppLogger.error('RfidConfig', 'Error al obtener información del ESP32', e);
      return null;
    }
  }

  // Mostrar configuración actual
  static void showCurrentConfig() {
    AppLogger.info('RfidConfig', 'Lector configurado: $isConfigured');
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

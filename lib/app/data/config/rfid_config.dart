import 'package:flutter/foundation.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tenant_context_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Configuración simplificada del lector RFID ESP32 con IP manual
class RfidConfig {
  // CAMBIAR ESTA IP POR LA DEL ESP32
  static const String DEFAULT_ESP32_IP = '192.168.1.100';

  /// Clave heredada, de cuando la configuración era una sola para todo el
  /// dispositivo. Se sigue leyendo una única vez para no perder la IP de
  /// quien ya tenía el lector andando (ver [_migrarClaveAntigua]).
  static const String _urlKeyGlobal = 'esp32_api_url';

  /// La configuración es POR GIMNASIO, no por dispositivo: un mismo teléfono
  /// puede entrar a dos gimnasios, y cada uno tiene su propio lector. Con una
  /// clave única, el segundo heredaba la IP del primero.
  static String get _urlKey {
    final gymId = TenantContextService.to.currentGymId;
    return gymId == null || gymId.isEmpty
        ? _urlKeyGlobal
        : '${_urlKeyGlobal}_$gymId';
  }

  static String? _currentUrl;

  /// URL del lector de ESTE gimnasio, o null si no tiene ninguno.
  ///
  /// Devuelve null a propósito cuando no hay nada configurado. Antes caía a
  /// `DEFAULT_ESP32_IP`, que es la IP de fábrica de TODOS los lectores: en
  /// una red compartida eso apuntaba la app al aparato del gimnasio vecino
  /// sin que nadie lo hubiera pedido. Quien llama ya comprueba el null.
  static String? get baseUrl => _currentUrl;

  /// Si este gimnasio tiene un lector configurado a propósito.
  ///
  /// Antes devolvía `true` siempre, lo que dejaba guardas muertas repartidas
  /// por el proyecto: comprobaban algo que nunca podía ser falso.
  static bool get isConfigured => _currentUrl != null;

  // Cargar configuración
  static Future<void> loadConfig() async {
    try {
      AppLogger.info('RfidConfig', 'Cargando configuración RFID');

      final prefs = await SharedPreferences.getInstance();
      await _migrarClaveAntigua(prefs);
      final savedUrl = prefs.getString(_urlKey);

      if (savedUrl != null && savedUrl.isNotEmpty) {
        AppLogger.info('RfidConfig', 'URL guardada encontrada');
        if (await _testConnection(savedUrl)) {
          _currentUrl = savedUrl;
          AppLogger.info('RfidConfig', 'IP guardada es válida');
          return;
        }
        // Se conserva aunque ahora no responda: el lector puede estar
        // apagado o el router recién reiniciado. Borrarla obligaría al
        // dueño a reconfigurarlo cada vez que se va la luz.
        _currentUrl = savedUrl;
        AppLogger.warning('RfidConfig', 'La IP guardada no responde ahora mismo');
        return;
      }

      // Sin nada guardado no se adivina ninguna IP. Antes se caía a
      // 192.168.1.100, que es la de fábrica de TODOS los lectores: en una red
      // compartida eso llevaba a la app directa al aparato del gimnasio de al
      // lado. El lector se elige a mano en Configuración.
      _currentUrl = null;
      AppLogger.info(
          'RfidConfig', 'Este gimnasio todavía no tiene lector configurado');
    } catch (e) {
      _currentUrl = null;
      AppLogger.error('RfidConfig', 'Error al cargar configuración', e);
    }
  }

  /// Traslada la configuración de la clave global antigua a la de este
  /// gimnasio, una sola vez.
  ///
  /// Sin esto, quien ya tenía el lector funcionando se lo encontraría
  /// "sin configurar" después de actualizar, sin entender por qué.
  static Future<void> _migrarClaveAntigua(SharedPreferences prefs) async {
    if (_urlKey == _urlKeyGlobal) return;            // aún no hay gimnasio
    if (prefs.getString(_urlKey) != null) return;    // ya migrado

    final antigua = prefs.getString(_urlKeyGlobal);
    if (antigua == null || antigua.isEmpty) return;

    await prefs.setString(_urlKey, antigua);
    AppLogger.info('RfidConfig', 'Configuración del lector migrada a este gimnasio');
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
  static Future<Map<String, dynamic>?> getESP32Info({String? ip}) async {
    try {
      final base = ip != null ? 'http://$ip/api' : baseUrl;
      if (base == null) return null;

      final gymId = TenantContextService.to.currentGymId ?? '';
      final response = await http.get(
        Uri.parse('$base/discover?gym_id=$gymId'),
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

  /// Vincula el lector de [ip] a este gimnasio.
  ///
  /// Devuelve [VinculacionResultado] para que la pantalla pueda distinguir
  /// "ya es de otro gimnasio" de "no respondió", que exigen mensajes muy
  /// distintos: uno se arregla liberándolo, el otro revisando la red.
  static Future<VinculacionResultado> vincular(String ip) async {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null || gymId.isEmpty) {
      return VinculacionResultado.sinSesion;
    }

    try {
      final response = await http
          .post(
            Uri.parse('http://$ip/api/claim'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'gym_id': gymId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Solo ahora se guarda: vincular y configurar van juntos, para que no
        // quede una IP apuntando a un lector que rechaza a este gimnasio.
        _currentUrl = 'http://$ip/api';
        await saveConfig(_currentUrl!);
        return VinculacionResultado.ok;
      }
      if (response.statusCode == 409) return VinculacionResultado.deOtroGimnasio;
      return VinculacionResultado.error;
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al vincular el lector', e);
      return VinculacionResultado.sinConexion;
    }
  }

  /// Libera el lector para que otro gimnasio pueda reclamarlo.
  static Future<bool> desvincular() async {
    final base = baseUrl;
    final gymId = TenantContextService.to.currentGymId;
    if (base == null || gymId == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$base/unclaim'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'gym_id': gymId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await clearConfig();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al desvincular el lector', e);
      return false;
    }
  }

  /// Le asigna al lector una IP fija propia y espera a que reinicie con ella.
  ///
  /// El aparato responde ANTES de reiniciar, así que un 200 significa "voy a
  /// cambiarme", no "ya estoy en la IP nueva": por eso se guarda la nueva URL
  /// aquí y se avisa de que tarda unos segundos en volver.
  static Future<bool> cambiarIp(String nuevaIp, {String? gateway}) async {
    final base = baseUrl;
    final gymId = TenantContextService.to.currentGymId;
    if (base == null || gymId == null) return false;

    try {
      final cuerpo = <String, String>{'gym_id': gymId, 'ip': nuevaIp};
      if (gateway != null && gateway.isNotEmpty) cuerpo['gateway'] = gateway;

      final response = await http
          .post(
            Uri.parse('$base/network'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(cuerpo),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _currentUrl = 'http://$nuevaIp/api';
        await saveConfig(_currentUrl!);
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al cambiar la IP del lector', e);
      return false;
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

/// En qué puede acabar un intento de vincular un lector.
enum VinculacionResultado {
  ok,

  /// El lector ya pertenece a otro gimnasio. Solo su dueño puede liberarlo,
  /// o hay que hacerle el reset de fábrica con el botón.
  deOtroGimnasio,

  /// No contestó: apagado, otra IP, u otra red.
  sinConexion,

  /// No hay gimnasio en la sesión actual.
  sinSesion,

  error,
}

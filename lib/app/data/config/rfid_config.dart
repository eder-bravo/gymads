import 'package:flutter/foundation.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tenant_context_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Configuración del lector RFID ESP32.
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

  /// URL del lector de ESTE gimnasio, o null mientras no se haya encontrado.
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

      const defaultUrl = 'http://$DEFAULT_ESP32_IP/api';
      final candidatos = <String>[
        if (savedUrl != null && savedUrl.isNotEmpty) savedUrl,
        if (savedUrl != defaultUrl) defaultUrl,
      ];

      // Primero se prueba la IP guardada y, si dejó de responder, la IP de
      // fábrica. Así se recupera la detección automática que tenía la app sin
      // perder la configuración particular de cada gimnasio.
      for (final candidato in candidatos) {
        if (await _configurarAutomaticamente(candidato)) {
          _currentUrl = candidato;
          await saveConfig(candidato);
          AppLogger.info('RfidConfig', 'Lector encontrado automáticamente');
          return;
        }
      }

      // Si el lector estaba guardado pero está apagado, se conserva la URL
      // para que vuelva a funcionar cuando reaparezca en la red. Sin una IP
      // guardada se mantiene la de fábrica como siguiente intento automático.
      _currentUrl = savedUrl?.isNotEmpty == true ? savedUrl : defaultUrl;
      AppLogger.warning('RfidConfig', 'El lector no responde por ahora');
    } catch (e) {
      _currentUrl ??= 'http://$DEFAULT_ESP32_IP/api';
      AppLogger.error('RfidConfig', 'Error al cargar configuración', e);
    }
  }

  /// Comprueba un lector, valida que pertenezca al gimnasio actual y reclama
  /// automáticamente uno nuevo si todavía está libre.
  static Future<bool> _configurarAutomaticamente(String url) async {
    if (!await _testConnection(url)) return false;

    final info = await _getESP32InfoForBase(url);
    // Firmware antiguo: si no existe /discover pero /status sí respondió, se
    // mantiene la compatibilidad y se usa igual que antes.
    if (info == null || !info.containsKey('claimed')) return true;

    if (info['claimed'] == true) {
      return info['mine'] == true;
    }

    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null || gymId.isEmpty) return true;

    try {
      final response = await http
          .post(
            Uri.parse('$url/claim'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'gym_id': gymId}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error(
          'RfidConfig', 'No se pudo vincular automáticamente el lector', e);
      return false;
    }
  }

  /// Traslada la configuración de la clave global antigua a la de este
  /// gimnasio, una sola vez.
  ///
  /// Sin esto, quien ya tenía el lector funcionando se lo encontraría
  /// "sin configurar" después de actualizar, sin entender por qué.
  static Future<void> _migrarClaveAntigua(SharedPreferences prefs) async {
    if (_urlKey == _urlKeyGlobal) return; // aún no hay gimnasio
    if (prefs.getString(_urlKey) != null) return; // ya migrado

    final antigua = prefs.getString(_urlKeyGlobal);
    if (antigua == null || antigua.isEmpty) return;

    await prefs.setString(_urlKey, antigua);
    AppLogger.info(
        'RfidConfig', 'Configuración del lector migrada a este gimnasio');
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
          AppLogger.info('RfidConfig',
              'Timeout: El ESP32 no responde en el tiempo esperado');
          AppLogger.info('RfidConfig',
              'Verificar que el ESP32 esté encendido y en la misma red WiFi');
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
    final base = ip != null ? 'http://$ip/api' : baseUrl;
    if (base == null) return null;
    return _getESP32InfoForBase(base);
  }

  static Future<Map<String, dynamic>?> _getESP32InfoForBase(String base) async {
    try {
      final gymId = TenantContextService.to.currentGymId ?? '';
      final response = await http.get(
        Uri.parse('$base/discover?gym_id=$gymId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      AppLogger.error(
          'RfidConfig', 'Error al obtener información del ESP32', e);
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
      if (response.statusCode == 409) {
        return VinculacionResultado.deOtroGimnasio;
      }
      return VinculacionResultado.error;
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al vincular el lector', e);
      return VinculacionResultado.sinConexion;
    }
  }

  /// Formatea un lector aunque NO sea de este gimnasio.
  ///
  /// Es el camino para recuperar un aparato que quedó vinculado a un gimnasio
  /// al que ya no se tiene acceso. A diferencia de [desvincular], no manda el
  /// gym_id porque el lector no lo comprueba: por eso apunta a una IP
  /// explícita y no a [baseUrl], que sería la del lector propio.
  ///
  /// El aparato pita mientras lo hace, así que un formateo ajeno se oye.
  static Future<bool> formatear(String ip) async {
    try {
      final response = await http.post(
        Uri.parse('http://$ip/api/reset'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al formatear el lector', e);
      return false;
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

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/permissions/permissions.dart';
import '../repositories/lector_repository.dart';
import '../services/lector_red_service.dart';
import '../services/tenant_context_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Configuración del lector RFID ESP32.
///
/// Nadie escribe IPs: el lector se configura por Bluetooth (ver
/// `LectorBleService`) y el router le da la dirección que quiera. Si esa
/// dirección cambia, la app lo vuelve a encontrar sola en la red por su id.
///
/// Cada dato de aquí es de UN gimnasio: el de la sesión. Un teléfono puede
/// entrar a varios gimnasios (o crear una cuenta nueva), y el lector de uno
/// nunca debe aparecer en otro.
class RfidConfig {
  /// Claves de cuando la configuración era una sola para todo el teléfono.
  /// No se pueden atribuir a ningún gimnasio: se borran (ver
  /// [_borrarClavesGlobales]). Antes se copiaban al primer gimnasio que no
  /// tuviera lector, y así una cuenta recién creada "ya tenía" el lector de
  /// otra.
  static const String _urlKeyGlobal = 'esp32_api_url';
  static const String _usarKeyGlobal = 'rfid_enabled';

  /// El gimnasio de la sesión. Se puede sustituir en las pruebas.
  static String? Function() gymIdActual = _gymIdDeLaSesion;

  /// Si quien usa la app puede dar de alta lectores (dueño, encargado). Se
  /// puede sustituir en las pruebas.
  static bool Function() puedeGestionar = _puedeGestionarEnLaSesion;

  /// Con qué se pregunta a los lectores en la red. Se puede sustituir en las
  /// pruebas por uno con un cliente HTTP falso.
  static LectorRedService Function(String gymId) servicioRed =
      (gymId) => LectorRedService(gymId: gymId);

  static String? _gymIdDeLaSesion() {
    if (!Get.isRegistered<TenantContextService>()) return null;
    final gymId = TenantContextService.to.currentGymId;
    return gymId == null || gymId.isEmpty ? null : gymId;
  }

  static bool _puedeGestionarEnLaSesion() =>
      Get.isRegistered<TenantContextService>() &&
      TenantContextService.to.can(Permission.gestionarControlAccesos);

  /// Claves por gimnasio. Null sin gimnasio: entonces no se lee ni se
  /// escribe nada (antes se usaba la clave global, y eso luego se colaba al
  /// siguiente gimnasio).
  static String? _urlKeyDe(String? gymId) =>
      gymId == null ? null : '${_urlKeyGlobal}_$gymId';
  static String? _idKeyDe(String? gymId) =>
      gymId == null ? null : '${_urlKeyGlobal}_${gymId}_id';
  static String? _usarKeyDe(String? gymId) =>
      gymId == null ? null : '${_usarKeyGlobal}_$gymId';

  static String? _currentUrl;
  static String? _idLector;

  /// Los lectores que el gimnasio tiene registrados en el servidor. Así
  /// cualquier teléfono del gimnasio (el de mostrador, uno nuevo, una
  /// reinstalación) sabe que hay lector y cuál buscar.
  static List<LectorRegistrado> _registrados = const [];

  /// A qué gimnasio pertenece lo que hay en memoria.
  static String? _gymEnMemoria;

  /// Si el gimnasio de la sesión cambió (otra cuenta, cerrar sesión), olvida
  /// el lector del anterior. Se llama antes de cualquier lectura.
  static void _alinearConGimnasio() {
    final gymId = gymIdActual();
    if (gymId == _gymEnMemoria) return;
    _gymEnMemoria = gymId;
    _currentUrl = null;
    _idLector = null;
    _registrados = const [];
    _ultimaBusqueda = null;
  }

  /// Id del lector de este gimnasio, si ya se conoce.
  static String? get idLector {
    _alinearConGimnasio();
    return _idLector;
  }

  static List<LectorRegistrado> get registrados {
    _alinearConGimnasio();
    return _registrados;
  }

  /// Si este gimnasio tiene lector, conteste o no ahora mismo.
  static bool get tieneLector {
    _alinearConGimnasio();
    return _currentUrl != null || _registrados.isNotEmpty;
  }

  /// `GymOne-XXXX` del lector de este gimnasio, si se conoce.
  static String? get nombreLector {
    _alinearConGimnasio();
    return _idLector == null ? null : LectorEnRed.nombreDeId(_idLector);
  }

  /// URL del lector de ESTE gimnasio, o null mientras no se haya encontrado.
  static String? get baseUrl {
    _alinearConGimnasio();
    return _currentUrl;
  }

  /// Si este gimnasio tiene un lector configurado a propósito.
  static bool get isConfigured => baseUrl != null;

  // Cargar configuración
  static Future<void> loadConfig() async {
    try {
      _alinearConGimnasio();
      final gymId = gymIdActual();
      final prefs = await SharedPreferences.getInstance();
      await _borrarClavesGlobales(prefs);
      if (gymId == null) return; // sin gimnasio no hay lector que cargar

      AppLogger.info('RfidConfig', 'Cargando configuración RFID');
      bool sigueIgual() => gymIdActual() == gymId;

      final savedUrl = prefs.getString(_urlKeyDe(gymId)!);
      final registrados = await LectorRepository().delGimnasio(gymId);
      if (!sigueIgual()) return;

      _idLector = prefs.getString(_idKeyDe(gymId)!);
      // Null = no se pudo preguntar (sin conexión): se sigue con lo que sabe
      // este teléfono.
      _registrados = registrados ?? const [];
      if (_idLector == null && _registrados.isNotEmpty) {
        _idLector = _registrados.first.id;
      }

      // Dónde probar primero: lo guardado en este teléfono y la última IP en
      // que el gimnasio vio a su lector.
      final candidatos = <String>{
        if (savedUrl != null && savedUrl.isNotEmpty) savedUrl,
        for (final r in _registrados)
          if (r.ultimaIp != null) 'http://${r.ultimaIp}/api',
      };

      if (candidatos.isEmpty && _registrados.isEmpty) {
        // Este gimnasio no tiene lector. Se agrega desde Configuración →
        // Lector de tarjetas. Sin lector no se barre la red para nada.
        _currentUrl = null;
        return;
      }

      var localYaNoEsMio = false;
      for (final url in candidatos) {
        final prueba = await _probarLector(url, gymId);
        if (!sigueIgual()) return;
        if (prueba.lector != null) {
          await guardarLector(prueba.lector!);
          AppLogger.info('RfidConfig', 'Lector encontrado');
          return;
        }
        if (url == savedUrl && prueba.respondioQueNoEsMio) {
          localYaNoEsMio = true;
        }
      }

      // En la dirección guardada contestó un lector que ya no es de este
      // gimnasio (lo desvincularon desde otro teléfono, o lo formatearon):
      // lo guardado aquí ya no vale.
      if (localYaNoEsMio) {
        await _olvidarLocal(prefs, gymId);
        if (_registrados.isEmpty) return;
      }

      // No contestó donde se le esperaba: quizá el router le dio otra IP. Se
      // busca en la red antes de rendirse.
      _currentUrl = localYaNoEsMio
          ? null
          : (savedUrl ?? (candidatos.isEmpty ? null : candidatos.first));
      if (await redescubrir()) return;

      // Apagado, sin WiFi o recién formateado. Se conserva lo que había para
      // que vuelva a funcionar en cuanto reaparezca.
      AppLogger.warning('RfidConfig', 'El lector no responde por ahora');
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al cargar configuración', e);
    }
  }

  /// Las claves de cuando todo era de un solo gimnasio. Se borran en vez de
  /// adoptarse: no hay forma de saber de qué gimnasio eran.
  static Future<void> _borrarClavesGlobales(SharedPreferences prefs) async {
    for (final clave in [
      _urlKeyGlobal,
      '${_urlKeyGlobal}_id',
      _usarKeyGlobal,
      'esp32_ip_manual',
    ]) {
      if (prefs.containsKey(clave)) await prefs.remove(clave);
    }
  }

  static Future<void> _olvidarLocal(
      SharedPreferences prefs, String gymId) async {
    await prefs.remove(_urlKeyDe(gymId)!);
    await prefs.remove(_idKeyDe(gymId)!);
    _currentUrl = null;
    if (!_registrados.any((r) => r.id == _idLector)) _idLector = null;
  }

  /// Comprueba el lector de [url]. Solo lo acepta si dice que es de este
  /// gimnasio: un lector libre NO se reclama por su cuenta. Vincular es
  /// siempre un paso explícito (asistente, o "Vincular a mi gimnasio"); si
  /// no, un "Desvincular" hecho desde otro teléfono se deshacía solo.
  static Future<_Prueba> _probarLector(String url, String gymId) async {
    final ip = Uri.tryParse(url)?.host;
    if (ip == null || ip.isEmpty) return const _Prueba();

    final lector = await servicioRed(gymId).consultar(ip);
    if (lector == null) return const _Prueba();
    if (lector.mine) return _Prueba(lector: lector);
    return const _Prueba(respondioQueNoEsMio: true);
  }

  static Future<bool>? _busquedaEnCurso;
  static DateTime? _ultimaBusqueda;

  /// Busca el lector de este gimnasio en la red y, si aparece en otra IP,
  /// la guarda.
  ///
  /// Se llama cuando la IP guardada deja de contestar. Como barrer la red
  /// cuesta unos segundos, se hace como mucho una vez por minuto (salvo
  /// [forzar]) y nunca dos a la vez.
  static Future<bool> redescubrir({bool forzar = false}) {
    _alinearConGimnasio();
    if (!tieneLector && _idLector == null && !forzar) {
      return Future.value(false);
    }
    final ahora = DateTime.now();
    if (!forzar &&
        _ultimaBusqueda != null &&
        ahora.difference(_ultimaBusqueda!) < const Duration(minutes: 1)) {
      return _busquedaEnCurso ?? Future.value(false);
    }
    _ultimaBusqueda = ahora;

    return _busquedaEnCurso ??= _buscarYGuardar().whenComplete(() {
      _busquedaEnCurso = null;
    });
  }

  static Future<bool> _buscarYGuardar() async {
    final gymId = gymIdActual();
    if (gymId == null) return false;
    final lector = await buscarEnRed();
    // Si mientras buscaba se cambió de gimnasio, lo encontrado es del
    // anterior: no se guarda en el nuevo.
    if (lector == null || gymIdActual() != gymId) return false;
    await guardarLector(lector);
    AppLogger.info('RfidConfig', 'Lector reencontrado en otra dirección');
    return true;
  }

  /// El lector de este gimnasio en la red, o null si no aparece.
  static Future<LectorEnRed?> buscarEnRed() async {
    final gymId = gymIdActual();
    if (gymId == null) return null;
    return servicioRed(gymId).buscarMio(id: idLector);
  }

  /// Todos los lectores de la red: el de este gimnasio, los libres y los de
  /// otros gimnasios, en ese orden.
  static Future<List<LectorEnRed>> buscarTodosEnRed() async {
    final gymId = gymIdActual();
    if (gymId == null) return const [];
    return servicioRed(gymId).buscarTodos();
  }

  /// Deja [lector] como el de este gimnasio: en este teléfono y en el
  /// servidor, para que los demás teléfonos del gimnasio lo sepan.
  static Future<void> guardarLector(LectorEnRed lector) async {
    _alinearConGimnasio();
    final gymId = gymIdActual();
    if (gymId == null) return;

    _currentUrl = lector.baseUrl;
    if (lector.id != null) _idLector = lector.id;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKeyDe(gymId)!, lector.baseUrl);
    if (lector.id != null) {
      await prefs.setString(_idKeyDe(gymId)!, lector.id!);
    }

    await _sincronizarRegistro(lector, gymId);
  }

  /// Registra el lector en el servidor si es nuevo o cambió de IP. Si ya
  /// estaba igual, no hace ninguna petición.
  static Future<void> _sincronizarRegistro(
      LectorEnRed lector, String gymId) async {
    final id = lector.id;
    if (id == null) return;
    final igual =
        _registrados.any((r) => r.id == id && r.ultimaIp == lector.ip);
    if (igual) return;

    await LectorRepository().registrar(
      lector,
      gymId: gymId,
      puedeDarDeAlta: puedeGestionar(),
    );
    _registrados = [
      LectorRegistrado(id: id, ultimaIp: lector.ip, version: lector.version),
      ..._registrados.where((r) => r.id != id),
    ];
  }

  // =================== "USAR EL LECTOR" EN ESTE TELÉFONO ===================

  /// Si en este teléfono está encendido "Usar el lector de tarjetas", para
  /// el gimnasio de la sesión.
  ///
  /// Es por gimnasio: antes era uno solo para el teléfono, y una cuenta
  /// nueva lo encontraba encendido. Si nunca se tocó, sigue a si el gimnasio
  /// tiene lector.
  static Future<bool> lectorActivado() async {
    final clave = _usarKeyDe(gymIdActual());
    if (clave == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(clave) ?? tieneLector;
  }

  static Future<void> activarLector(bool activo) async {
    final clave = _usarKeyDe(gymIdActual());
    if (clave == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clave, activo);
  }

  /// Pide al lector que se ofrezca por Bluetooth unos minutos, para
  /// cambiarle el WiFi sin tocar el aparato. Solo lo acepta del dueño.
  static Future<bool> abrirModoConfiguracion() async {
    final base = baseUrl;
    final gymId = gymIdActual();
    if (base == null || gymId == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$base/configurar'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'gym_id': gymId}),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.warning('RfidConfig', 'El lector no aceptó configurarse: $e');
      return false;
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
      _alinearConGimnasio();
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
    final url = baseUrl;
    if (url == null) return null;
    return Uri.tryParse(url)?.host;
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
      ).timeout(const Duration(seconds: 3));

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
    final clave = _urlKeyDe(gymIdActual());
    if (clave == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clave, url);
      AppLogger.info('RfidConfig', 'Configuración guardada');
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al guardar configuración', e);
    }
  }

  // Método de compatibilidad
  static Future<void> updateConfig({String? newUrl}) async {
    if (newUrl != null && newUrl.isNotEmpty) {
      _alinearConGimnasio();
      _currentUrl = validateUrl(newUrl);
      await saveConfig(_currentUrl!);
      AppLogger.info('RfidConfig', 'Configuración actualizada');
    }
  }

  // Forzar actualización de IP manualmente (sin validación previa)
  static Future<void> forceUpdateIP(String ip) async {
    try {
      String formattedUrl = 'http://$ip/api';
      _alinearConGimnasio();
      _currentUrl = formattedUrl;
      await saveConfig(formattedUrl);
      AppLogger.info('RfidConfig', 'IP forzada manualmente');
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al forzar IP manual', e);
    }
  }

  // Limpiar configuración
  static Future<void> clearConfig() async {
    _alinearConGimnasio();
    _currentUrl = null;
    _idLector = null;
    final gymId = gymIdActual();
    if (gymId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_urlKeyDe(gymId)!);
      await prefs.remove(_idKeyDe(gymId)!);
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
    final base = baseUrl;
    if (base == null) return false;
    try {
      return await _testConnection(base);
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
      final gymId = gymIdActual() ?? '';
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
    final gymId = gymIdActual();
    if (gymId == null) {
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
        final info = await servicioRed(gymId).consultar(ip);
        await guardarLector(
            info ?? LectorEnRed(ip: ip, claimed: true, mine: true));
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
    final gymId = gymIdActual();
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
        final id = _idLector;
        if (id != null) {
          await LectorRepository().quitar(gymId: gymId, id: id);
          _registrados = _registrados.where((r) => r.id != id).toList();
        }
        await clearConfig();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('RfidConfig', 'Error al desvincular el lector', e);
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

/// Lo que dijo una dirección al probarla.
class _Prueba {
  const _Prueba({this.lector, this.respondioQueNoEsMio = false});

  /// El lector, si contestó y es de este gimnasio.
  final LectorEnRed? lector;

  /// Contestó un lector, pero dijo que no es de este gimnasio (libre o de
  /// otro). Distinto de no contestar: eso puede ser que esté apagado.
  final bool respondioQueNoEsMio;
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

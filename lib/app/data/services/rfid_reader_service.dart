import 'dart:convert';
import 'package:get/get.dart';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;
import '../config/rfid_config.dart';
import 'tenant_context_service.dart';

class RfidReaderService {
  /// Por qué el lector se negó a contestar, si es que se negó.
  ///
  /// Un 403 no es un fallo de red del que valga la pena reintentar: por más
  /// veces que se pregunte, ese lector nunca va a contestar. Quien sondea lo
  /// mira para dejar de hacerlo y para decirle al usuario qué hacer.
  static final Rx<RechazoLector> rechazo = RechazoLector.ninguno.obs;

  /// Añade el gym_id a la URL, que es lo que el lector compara para decidir
  /// si contesta. Sin esto, cualquier app de la red se llevaba los pases.
  static String _conGymId(String url) {
    final gymId = TenantContextService.to.currentGymId;
    if (gymId == null || gymId.isEmpty) return url;
    final separador = url.contains('?') ? '&' : '?';
    return '$url$separador' 'gym_id=$gymId';
  }

  /// Anota POR QUÉ el lector rechazó la petición, y corta el sondeo.
  ///
  /// El firmware usa 403 para dos situaciones muy distintas y las separa con
  /// el campo `claimed` del cuerpo: `false` significa que el lector está
  /// libre y solo falta vincularlo; `true`, que es de otro gimnasio.
  /// Confundirlas manda al usuario a buscar un problema que no tiene.
  static void _marcarRechazo(String metodo, String cuerpo) {
    var motivo = RechazoLector.deOtroGimnasio;

    try {
      final datos = jsonDecode(cuerpo);
      if (datos is Map && datos['claimed'] == false) {
        motivo = RechazoLector.sinVincular;
      }
    } catch (_) {
      // Sin cuerpo legible se asume el caso más restrictivo: es preferible
      // decir "es de otro gimnasio" que invitar a vincular algo ajeno.
    }

    if (rechazo.value != motivo) {
      AppLogger.warning(
          'RfidReaderService',
          motivo == RechazoLector.sinVincular
              ? 'El lector todavía no está vinculado a ningún gimnasio ($metodo)'
              : 'El lector configurado pertenece a otro gimnasio ($metodo)');
    }
    rechazo.value = motivo;
  }
  /// Los pases posteriores a [desde] (firmware 6.3+).
  ///
  /// `sinSoporte` es true si el lector no conoce `/api/lecturas` (firmware
  /// anterior): entonces hay que usar [checkForCard]. `respuesta` es null si
  /// no se pudo preguntar (sin red, lector apagado, o lo rechazó: ver
  /// [rechazo]).
  static Future<({RespuestaLecturas? respuesta, bool sinSoporte})>
      leerLecturas(int desde) async {
    const nada = (respuesta: null, sinSoporte: false);
    final baseUrl = RfidConfig.baseUrl;
    if (baseUrl == null) return nada;

    try {
      final response = await http
          .get(Uri.parse(_conGymId('$baseUrl/lecturas?desde=$desde')))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 404) {
        return (respuesta: null, sinSoporte: true);
      }
      if (response.statusCode == 403) {
        _marcarRechazo('leerLecturas', response.body);
        return nada;
      }
      if (response.statusCode != 200) return nada;

      rechazo.value = RechazoLector.ninguno;
      final datos = jsonDecode(response.body);
      if (datos is! Map<String, dynamic>) return nada;
      return (respuesta: RespuestaLecturas.fromJson(datos), sinSoporte: false);
    } catch (e) {
      // No contestó: puede que el router le haya dado otra IP. Se busca en
      // segundo plano (como mucho una vez por minuto) sin frenar el sondeo.
      RfidConfig.redescubrir();
      return nada;
    }
  }

  // Método para verificar si hay un UID disponible desde el ESP32
  static Future<String?> checkForCard() async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        AppLogger.info('RfidReaderService', 'ESP32 no configurado - usando IP estática predeterminada');
        return null;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32');
        return null;
      }

      final response = await http.get(
        Uri.parse(_conGymId('$baseUrl/uid')),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 403) {
        _marcarRechazo('checkForCard', response.body);
        return null;
      }

      if (response.statusCode == 200) {
        rechazo.value = RechazoLector.ninguno;
        final responseText = response.body.trim();
        
        if (responseText.isNotEmpty && responseText != "NO_CARD") {
          AppLogger.info('RfidReaderService', 'UID detectado');
          return responseText;
        }
        return null;
      } else {
        AppLogger.error('RfidReaderService', 'Error al verificar tarjeta');
        return null;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al verificar tarjeta', e);
      // No contestó: puede que el router le haya dado otra IP. Se busca en
      // segundo plano (como mucho una vez por minuto) sin frenar el sondeo.
      RfidConfig.redescubrir();
      return null;
    }
  }
  
  // Método silencioso para capturar UID sin activar LEDs ni buzzer
  // Usado exclusivamente para registrar nuevas tarjetas RFID
  static Future<String?> checkForCardSilent() async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        AppLogger.info('RfidReaderService', 'ESP32 no configurado');
        return null;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32');
        return null;
      }

      final response = await http.get(
        Uri.parse(_conGymId('$baseUrl/uid_only')),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 403) {
        _marcarRechazo('checkForCardSilent', response.body);
        return null;
      }

      if (response.statusCode == 200) {
        final responseText = response.body.trim();
        
        if (responseText.isNotEmpty && responseText != "NO_CARD") {
          AppLogger.info('RfidReaderService', 'UID detectado (silencioso)');
          return responseText;
        }
        return null;
      } else {
        AppLogger.error('RfidReaderService', 'Error al verificar tarjeta (silencioso)');
        return null;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al verificar tarjeta (silencioso)', e);
      return null;
    }
  }
  
  // Método para iniciar la lectura (verificación de conectividad del ESP32)
  static Future<bool> startReading() async {
    try {
      // Cargar configuración primero
      await RfidConfig.loadConfig();
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32, usando IP por defecto');
        return false;
      }
      
      AppLogger.info('RfidReaderService', 'Intentando conectar con ESP32');
      
      // Verificamos si podemos conectarnos al ESP32
      final response = await http.get(
        Uri.parse(_conGymId('$baseUrl/status')),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        AppLogger.info('RfidReaderService', 'ESP32 conectado exitosamente');
        AppLogger.info('RfidReaderService', 'Respuesta del ESP32');
        return true;
      } else {
        AppLogger.info('RfidReaderService', 'ESP32 respondió con código');
        return false;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al comunicarse con el lector RFID', e);
      AppLogger.info('RfidReaderService', 'Verificar que el ESP32 esté encendido en la IP');
      AppLogger.info('RfidReaderService', 'Red WiFi: Asegúrese de que ambos dispositivos estén en la misma red');
      return false;
    }
  }
  
  // Método para enviar el estado de membresía al ESP32
  static Future<bool> sendMembershipStatus(
    String uid, 
    String status, {
    String? userName,
    String? accessType,
    String? verificationType = 'rfid',
  }) async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        AppLogger.info('RfidReaderService', 'ESP32 no configurado - no se puede enviar estado de membresía');
        return false;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32');
        return false;
      }
      
      AppLogger.info('RfidReaderService', 'Enviando estado de membresía al lector');

      final body = {
        'uid': uid,
        'status': status,
        'verification_type': verificationType,
      };
      
      // Agregar información adicional si está disponible
      if (userName != null) body['user_name'] = userName;
      if (accessType != null) body['access_type'] = accessType;

      final response = await http.post(
        Uri.parse(_conGymId('$baseUrl/membership')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        AppLogger.info('RfidReaderService', 'Estado de membresía enviado correctamente');
        return true;
      } else {
        AppLogger.error('RfidReaderService', 'Error al enviar estado de membresía');
        return false;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al enviar estado de membresía', e);
      return false;
    }
  }
  
  // Este es el fin de la clase RfidReaderService
}

/// Por qué el lector se negó a entregar los pases de tarjeta.
///
/// El firmware responde 403 en los dos casos de rechazo; lo que los separa es
/// el campo `claimed` del cuerpo JSON.
enum RechazoLector {
  /// No hubo rechazo.
  ninguno,

  /// El lector existe y responde, pero todavía no pertenece a ningún
  /// gimnasio. Se arregla vinculándolo desde Configuración.
  sinVincular,

  /// El lector es de otro gimnasio. Su dueño tiene que liberarlo, o hay que
  /// hacerle el reset de fábrica con el botón.
  deOtroGimnasio,
}

/// Un pase de tarjeta registrado por el lector.
class PaseLector {
  const PaseLector({required this.seq, required this.uid, required this.haceMs});

  final int seq;
  final String uid;

  /// Hace cuánto pasó, según el reloj del lector.
  final int haceMs;

  factory PaseLector.fromJson(Map<String, dynamic> json) => PaseLector(
        seq: (json['seq'] as num).toInt(),
        uid: json['uid'] as String,
        haceMs: (json['hace_ms'] as num?)?.toInt() ?? 0,
      );
}

/// Lo que contesta `GET /api/lecturas`.
class RespuestaLecturas {
  const RespuestaLecturas({required this.seq, required this.lecturas});

  /// El último número de pase que dio el lector.
  final int seq;
  final List<PaseLector> lecturas;

  factory RespuestaLecturas.fromJson(Map<String, dynamic> json) =>
      RespuestaLecturas(
        seq: (json['seq'] as num?)?.toInt() ?? 0,
        lecturas: [
          for (final l in (json['lecturas'] as List? ?? const []))
            PaseLector.fromJson(l as Map<String, dynamic>),
        ],
      );
}

/// Decide qué pases son nuevos, recordando el último número visto.
///
/// Así ningún pase se procesa dos veces ni se pierde: aunque la tarjeta se
/// retire antes de la siguiente consulta, o pasen dos seguidas.
class SeguimientoPases {
  int? _ultima;
  bool _trasReinicio = false;

  /// Desde qué número preguntar.
  int get desde => _ultima ?? 0;

  /// Olvida lo visto (al empezar a escanear, o al cambiar de lector).
  void reiniciar() {
    _ultima = null;
    _trasReinicio = false;
  }

  /// Los pases a procesar de [r], en el orden en que ocurrieron.
  List<PaseLector> nuevos(RespuestaLecturas r) {
    final ultima = _ultima;

    // Primera consulta: lo que ya estaba en el lector es de antes de que la
    // app empezara a escuchar. No se procesa.
    if (ultima == null) {
      _ultima = r.seq;
      return const [];
    }

    // El número bajó: el lector se reinició y empezó a contar de nuevo. Se
    // pregunta desde cero en la siguiente vuelta.
    if (r.seq < ultima) {
      _ultima = 0;
      _trasReinicio = true;
      return const [];
    }

    final pases = r.lecturas
        .where((l) => l.seq > ultima)
        // Tras un reinicio solo lo reciente: lo viejo ya no tiene a nadie
        // esperando en la puerta.
        .where((l) => !_trasReinicio || l.haceMs <= 10000)
        .toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));

    _trasReinicio = false;
    _ultima = r.seq;
    return pases;
  }
}

/// Un pase de hace más de esto ya no tiene a nadie esperando en la puerta:
/// ocurrió mientras la app estaba congelada en segundo plano (iOS la
/// suspende a los pocos segundos). Se registra con su hora real, sin aviso.
const paseAtrasadoDespuesDe = Duration(seconds: 15);

/// Si el pase de [cuando] ya es viejo para avisarlo (ver
/// [paseAtrasadoDespuesDe]).
bool esPaseAtrasado(DateTime cuando, {DateTime? ahora}) =>
    (ahora ?? DateTime.now()).difference(cuando) > paseAtrasadoDespuesDe;

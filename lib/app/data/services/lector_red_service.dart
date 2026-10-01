import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/app_logger.dart';

/// Un lector GymOne que contestó en la red.
class LectorEnRed {
  const LectorEnRed({
    required this.ip,
    this.id,
    this.claimed = false,
    this.mine = false,
    this.modoConfig = false,
    this.configOcupada = false,
    this.version,
    this.ssid,
  });

  final String ip;

  /// Identidad del aparato (su MAC). Firmware anterior a 6.0 no la manda.
  final String? id;

  /// Si ya tiene dueño, y si ese dueño es el gimnasio que preguntó.
  final bool claimed;
  final bool mine;

  /// Si está ofreciéndose por Bluetooth para que le cambien el WiFi.
  final bool modoConfig;
  final bool configOcupada;

  final String? version;

  /// La red WiFi a la que está conectado.
  final String? ssid;

  String get baseUrl => 'http://$ip/api';

  /// `GymOne-XXXX`, como se anuncia por Bluetooth (últimos 4 de su MAC).
  String get nombre => nombreDeId(id);

  static String nombreDeId(String? id) => id == null || id.length < 4
      ? 'Lector GymOne'
      : 'GymOne-${id.substring(id.length - 4).toUpperCase()}';

  /// Cómo se identifica el lector en `/api/discover`. El segundo es el de
  /// los firmwares anteriores a la v6.4.0, que aún no se actualizan.
  static const _idsDeLector = {'ESP32_RFID_GYMONE', 'ESP32_RFID_GYMADS'};

  /// Interpreta la respuesta de `/api/discover`. Null si no es un lector.
  static LectorEnRed? desdeDiscover(String ip, Map<String, dynamic> json) {
    if (!_idsDeLector.contains(json['device_id']) &&
        json['device_type'] != 'RFID_READER') {
      return null;
    }
    return LectorEnRed(
      ip: ip,
      id: json['id'] as String?,
      claimed: json['claimed'] == true,
      mine: json['mine'] == true,
      modoConfig: json['modo_config'] == true,
      configOcupada: json['config_ocupada'] == true,
      version: json['version'] as String?,
      ssid: json['ssid'] as String?,
    );
  }
}

enum ConfirmacionLector { confirmada, sinSoporte, sinRespuesta }

/// Encuentra el lector en la red sin que nadie tenga que saber su IP.
///
/// El router le da la IP que quiere (DHCP) y puede cambiarla al reiniciarse.
/// Dos caminos en paralelo; devuelve el primero que confirma el lector:
///
/// 1. mDNS: el lector se anuncia como `_gymone._tcp`. Contesta en ~1 s, pero
///    algunos routers bloquean el multicast.
/// 2. Barrido de la subred del teléfono: se pregunta `/api/discover` a cada
///    dirección. Unos segundos, pero funciona con cualquier router.
class LectorRedService {
  LectorRedService({http.Client? cliente, this.gymId})
      : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  /// Con qué gimnasio se pregunta: el lector responde `mine` comparándolo.
  final String? gymId;

  /// Cómo se anuncia el lector por mDNS. El segundo es el nombre de los
  /// firmwares anteriores a la v6.4.0: así se siguen encontrando los lectores
  /// que aún no se actualizan. Los dos van también en `NSBonjourServices`
  /// (ios/Runner/Info.plist): iOS no deja buscar lo que no esté declarado.
  static const _tiposServicio = ['_gymone._tcp', '_gymads._tcp'];

  /// Busca el lector de ESTE gimnasio. Si se conoce su [id], se prefiere ese
  /// aparato (por si el gimnasio tuviera más de uno).
  Future<LectorEnRed?> buscarMio({
    String? id,
    Duration tiempoMdns = const Duration(seconds: 4),
    bool Function(LectorEnRed)? aceptar,
  }) async {
    bool esMio(LectorEnRed l) =>
        l.mine &&
        (id == null || l.id == null || l.id == id) &&
        (aceptar == null || aceptar(l));

    final resultado = Completer<LectorEnRed?>();
    void recibir(LectorEnRed? lector) {
      if (!resultado.isCompleted && lector != null && esMio(lector)) {
        resultado.complete(lector);
      }
    }

    final consultas = <Future<void>>[];
    final vistas = <String>{};
    Future<void> porMdns() async {
      await ipsPorMdns(
        tiempo: tiempoMdns,
        cancelar: resultado.future.then((_) {}),
        alEncontrar: (ip) {
          if (!resultado.isCompleted && vistas.add(ip)) {
            consultas.add(consultar(ip).then(recibir));
          }
        },
      );
      await Future.wait(consultas);
    }

    // Se pregunta desde que mDNS resuelve una dirección, sin esperar a
    // juntar la lista. El barrido comienza a la vez, por si no hay multicast.
    unawaited(Future.wait([
      porMdns(),
      barrerSubred(parar: esMio).then(recibir),
    ]).then((_) {
      if (!resultado.isCompleted) resultado.complete(null);
    }, onError: (Object error, StackTrace traza) {
      if (!resultado.isCompleted) resultado.completeError(error, traza);
    }));
    return resultado.future;
  }

  /// La app ya guardó el lector y está por mostrar 100%. El mismo token en
  /// los reintentos evita repetir la melodía si solo se perdió la respuesta.
  Future<ConfirmacionLector> confirmarConfiguracion(
    LectorEnRed lector, {
    required String intento,
    String? sesion,
  }) async {
    for (var vuelta = 0; vuelta < 2; vuelta++) {
      try {
        final respuesta = await _cliente
            .post(
              Uri.parse('${lector.baseUrl}/confirmar_config'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'gym_id': gymId,
                'intento': intento,
                if (sesion != null) 'sesion': sesion,
              }),
            )
            .timeout(const Duration(milliseconds: 1200));
        if (respuesta.statusCode == 200) {
          final datos = json.decode(respuesta.body);
          if (datos is Map && datos['ok'] == true) {
            return ConfirmacionLector.confirmada;
          }
        }
        if (respuesta.statusCode == 404) {
          return ConfirmacionLector.sinSoporte;
        }
        if (respuesta.statusCode == 403) {
          return ConfirmacionLector.sinRespuesta;
        }
      } catch (_) {
        // Puede haberse perdido la respuesta: se repite con el mismo token.
      }
    }
    return ConfirmacionLector.sinRespuesta;
  }

  /// Todos los lectores que contestan en la red: el propio, los libres y los
  /// de otros gimnasios. El propio primero, luego los libres.
  ///
  /// Para "buscar en la red" a mano: con uno libre se puede ofrecer
  /// vincularlo; con uno ajeno, formatearlo.
  Future<List<LectorEnRed>> buscarTodos({
    Duration tiempoMdns = const Duration(seconds: 3),
    List<String>? ips,
  }) async {
    final porIp = <String, LectorEnRed>{};

    if (ips == null) {
      for (final ip in await ipsPorMdns(tiempo: tiempoMdns)) {
        final lector = await consultar(ip);
        if (lector != null) porIp[ip] = lector;
      }
    }

    final encontrados = <LectorEnRed>[];
    await barrerSubred(ips: ips, alEncontrar: encontrados.add);
    for (final l in encontrados) {
      porIp[l.ip] = l;
    }

    int orden(LectorEnRed l) => l.mine ? 0 : (!l.claimed ? 1 : 2);
    return porIp.values.toList()..sort((a, b) => orden(a).compareTo(orden(b)));
  }

  /// Pregunta a una IP si es un lector. Null si no contesta o no lo es.
  Future<LectorEnRed?> consultar(
    String ip, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final uri = Uri.parse('http://$ip/api/discover')
          .replace(queryParameters: {'gym_id': gymId ?? ''});
      final respuesta = await _cliente.get(uri).timeout(timeout);
      if (respuesta.statusCode != 200) return null;

      final datos = json.decode(respuesta.body);
      if (datos is! Map<String, dynamic>) return null;
      return LectorEnRed.desdeDiscover(ip, datos);
    } catch (_) {
      return null;
    }
  }

  /// IPs de los lectores que se anuncian por mDNS, con cualquiera de los
  /// [_tiposServicio] (se buscan a la vez).
  Future<List<String>> ipsPorMdns({
    Duration tiempo = const Duration(seconds: 4),
    void Function(String ip)? alEncontrar,
    Future<void>? cancelar,
  }) async {
    final porTipo = await Future.wait([
      for (final tipo in _tiposServicio)
        _ipsPorMdns(tipo, tiempo, alEncontrar, cancelar),
    ]);
    return {for (final ips in porTipo) ...ips}.toList();
  }

  Future<List<String>> _ipsPorMdns(String tipo, Duration tiempo,
      void Function(String ip)? alEncontrar, Future<void>? cancelar) async {
    final ips = <String>{};
    BonsoirDiscovery? descubrimiento;
    StreamSubscription<BonsoirDiscoveryEvent>? sub;

    try {
      descubrimiento = BonsoirDiscovery(type: tipo, printLogs: false);
      await descubrimiento.initialize();

      sub = descubrimiento.eventStream?.listen((evento) {
        switch (evento) {
          case BonsoirDiscoveryServiceFoundEvent(:final service):
            service.resolve(descubrimiento!.serviceResolver);
          case BonsoirDiscoveryServiceResolvedEvent(:final service):
            for (final ip in service.hostAddresses.where(_esIpv4)) {
              if (ips.add(ip)) alEncontrar?.call(ip);
            }
          default:
            break;
        }
      });

      await descubrimiento.start();
      await Future.any([
        Future<void>.delayed(tiempo),
        if (cancelar != null) cancelar,
      ]);
    } catch (e) {
      // Sin mDNS (permiso negado, router que lo bloquea) queda el barrido.
      AppLogger.warning('LectorRedService', 'mDNS no disponible: $e');
    } finally {
      await sub?.cancel();
      try {
        await descubrimiento?.stop();
      } catch (_) {}
    }

    return ips.toList();
  }

  /// Pregunta a toda la subred del teléfono, [concurrencia] IPs a la vez.
  ///
  /// Termina en cuanto un lector cumple [parar] (si se pasa), o al recorrer
  /// todas. [alEncontrar] recibe cada lector que contesta, cumpla o no.
  /// [ips] sustituye a la subred detectada; es para las pruebas.
  Future<LectorEnRed?> barrerSubred({
    bool Function(LectorEnRed)? parar,
    void Function(LectorEnRed)? alEncontrar,
    List<String>? ips,
    int concurrencia = 32,
    Duration timeoutPorIp = const Duration(milliseconds: 900),
  }) async {
    final candidatas = ips ?? await ipsDeMiSubred();
    if (candidatas.isEmpty) return null;

    LectorEnRed? encontrado;
    final terminado = Completer<LectorEnRed?>();
    var siguiente = 0;

    Future<void> trabajador() async {
      while (encontrado == null && siguiente < candidatas.length) {
        final ip = candidatas[siguiente++];
        final lector = await consultar(ip, timeout: timeoutPorIp);
        if (encontrado != null) return;
        if (lector == null) continue;
        alEncontrar?.call(lector);
        if (parar != null && parar(lector)) {
          encontrado ??= lector;
          if (!terminado.isCompleted) terminado.complete(encontrado);
        }
      }
    }

    unawaited(
        Future.wait(List.generate(concurrencia, (_) => trabajador())).then((_) {
      if (!terminado.isCompleted) terminado.complete(null);
    }, onError: (Object error, StackTrace traza) {
      if (!terminado.isCompleted) terminado.completeError(error, traza);
    }));
    return terminado.future;
  }

  /// Las 254 direcciones de la red /24 del teléfono, sin la suya.
  ///
  /// Se lee de las interfaces del sistema (no hace falta permiso de
  /// ubicación, a diferencia de pedir el nombre del WiFi).
  static Future<List<String>> ipsDeMiSubred() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // WiFi primero: en0 (iOS) / wlan0 (Android).
      interfaces.sort((a, b) =>
          _prioridadInterfaz(a.name).compareTo(_prioridadInterfaz(b.name)));

      final candidatas = <String>{};
      for (final interfaz in interfaces) {
        for (final direccion in interfaz.addresses) {
          if (esIpPrivada(direccion.address)) {
            candidatas.addAll(ipsDeLaSubred(direccion.address));
            // Un equipo puede tener Ethernet y WiFi activos a la vez.
            if (!Platform.isWindows && !Platform.isMacOS) {
              return candidatas.toList();
            }
          }
        }
      }
      return candidatas.toList();
    } catch (e) {
      AppLogger.warning('LectorRedService', 'No se pudo leer la red: $e');
    }
    return const [];
  }

  static int _prioridadInterfaz(String nombre) {
    final n = nombre.toLowerCase();
    if (n.startsWith('wi-fi') ||
        n.startsWith('wifi') ||
        n.startsWith('ethernet')) {
      return 0;
    }
    if (nombre == 'en0' || nombre.startsWith('wlan')) return 0;
    if (nombre.startsWith('en') || nombre.startsWith('eth')) return 1;
    return 2; // datos móviles, VPN...
  }

  /// Las otras 253 direcciones de la /24 de [ip].
  static List<String> ipsDeLaSubred(String ip) {
    final partes = ip.split('.');
    if (partes.length != 4) return const [];
    final prefijo = partes.take(3).join('.');
    return [
      for (var i = 1; i <= 254; i++)
        if ('$prefijo.$i' != ip) '$prefijo.$i',
    ];
  }

  /// 10.x, 172.16-31.x y 192.168.x: las de una red de casa u oficina.
  static bool esIpPrivada(String ip) {
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.any((n) => n == null)) return false;
    if (p[0] == 10) return true;
    if (p[0] == 192 && p[1] == 168) return true;
    if (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31) return true;
    return false;
  }

  static bool _esIpv4(String ip) =>
      InternetAddress.tryParse(ip)?.type == InternetAddressType.IPv4;
}

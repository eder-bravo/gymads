import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/utils/app_logger.dart';

// UUIDs del firmware 6.0 (arduino/esp32_rfid_wifi_setup_fixed). Si cambian
// allá, cambian aquí. No cambiaron con el nombre GymOne (v6.4.0): con ellos
// se encuentran igual los lectores nuevos y los que aún no se actualizan.
final Guid _servicioUuid = Guid('6b1a0001-5c1e-4f7a-9d2e-47796d416473');
final Guid _redesUuid = Guid('6b1a0002-5c1e-4f7a-9d2e-47796d416473');
final Guid _ssidUuid = Guid('6b1a0003-5c1e-4f7a-9d2e-47796d416473');
final Guid _claveUuid = Guid('6b1a0004-5c1e-4f7a-9d2e-47796d416473');
final Guid _gymUuid = Guid('6b1a0005-5c1e-4f7a-9d2e-47796d416473');
final Guid _ordenUuid = Guid('6b1a0006-5c1e-4f7a-9d2e-47796d416473');
final Guid _estadoUuid = Guid('6b1a0007-5c1e-4f7a-9d2e-47796d416473');

/// En qué va el lector mientras se configura.
enum FaseConfig {
  listo,
  buscandoRedes,
  conectando,
  ok,
  errorClave,
  errorSinRed,

  /// La contraseña pasó, pero el módem no le dio dirección (DHCP).
  errorSinIp,

  /// La red usa una seguridad que el lector no admite (empresarial, WEP).
  errorSeguridad,

  /// Falló sin que sea la contraseña: señal débil, módem que no responde...
  errorNoConecta,
  errorDatos,
  errorOtroGimnasio,
  desconocido;

  bool get esFinal =>
      this == ok ||
      this == errorClave ||
      this == errorSinRed ||
      this == errorSinIp ||
      this == errorSeguridad ||
      this == errorNoConecta ||
      this == errorDatos ||
      this == errorOtroGimnasio;
}

/// Lo que dice la característica `estado` del lector.
class EstadoConfig {
  const EstadoConfig(this.fase, {this.ip});

  final FaseConfig fase;

  /// La IP que le dio el router, solo con [FaseConfig.ok].
  final String? ip;

  /// Interpreta el texto del firmware: `listo`, `ok:192.168.1.57`,
  /// `error:clave`...
  static EstadoConfig parse(String texto) {
    final t = texto.trim();
    if (t.startsWith('ok:')) {
      final ip = t.substring(3).trim();
      return EstadoConfig(FaseConfig.ok, ip: ip.isEmpty ? null : ip);
    }
    return EstadoConfig(switch (t) {
      'listo' => FaseConfig.listo,
      'buscando_redes' => FaseConfig.buscandoRedes,
      'conectando' => FaseConfig.conectando,
      'error:clave' => FaseConfig.errorClave,
      'error:sin_red' => FaseConfig.errorSinRed,
      'error:no_conecta' => FaseConfig.errorNoConecta,
      'error:sin_ip' => FaseConfig.errorSinIp,
      'error:seguridad' => FaseConfig.errorSeguridad,
      'error:datos' => FaseConfig.errorDatos,
      'error:otro_gimnasio' => FaseConfig.errorOtroGimnasio,
      _ => FaseConfig.desconocido,
    });
  }

  /// El texto tal como lo manda el firmware, para comparar estados.
  String toTexto() => switch (fase) {
        FaseConfig.listo => 'listo',
        FaseConfig.buscandoRedes => 'buscando_redes',
        FaseConfig.conectando => 'conectando',
        FaseConfig.ok => 'ok:${ip ?? ''}',
        FaseConfig.errorClave => 'error:clave',
        FaseConfig.errorSinRed => 'error:sin_red',
        FaseConfig.errorSinIp => 'error:sin_ip',
        FaseConfig.errorSeguridad => 'error:seguridad',
        FaseConfig.errorNoConecta => 'error:no_conecta',
        FaseConfig.errorDatos => 'error:datos',
        FaseConfig.errorOtroGimnasio => 'error:otro_gimnasio',
        FaseConfig.desconocido => '',
      };

  @override
  String toString() => ip == null ? fase.name : '${fase.name}($ip)';
}

/// Qué pide una red para entrar.
enum SeguridadRed {
  /// Sin contraseña.
  abierta,

  /// Contraseña normal (WPA/WPA2/WPA3). La de casi todos los módems.
  clave,

  /// Usuario y contraseña (redes de empresa o escuela): el lector no puede.
  empresarial,

  /// WEP, obsoleta: el lector no la usa.
  wep;

  static SeguridadRed desdeTexto(String t) => switch (t.trim()) {
        'abierta' => abierta,
        'empresarial' => empresarial,
        'wep' => wep,
        _ => clave,
      };
}

/// Una red WiFi que vio el lector.
class RedWifi {
  const RedWifi(this.ssid, {this.rssi, this.seguridad = SeguridadRed.clave});

  final String ssid;

  /// Señal en dBm (-30 excelente, -90 casi nada). Null con firmware viejo.
  final int? rssi;
  final SeguridadRed seguridad;

  /// Si el lector puede conectarse a ella.
  bool get compatible =>
      seguridad == SeguridadRed.abierta || seguridad == SeguridadRed.clave;

  bool get pideClave => seguridad != SeguridadRed.abierta;

  /// 0 a 3 rayitas, como en el teléfono.
  int get barras {
    final r = rssi;
    if (r == null) return 3;
    if (r >= -60) return 3;
    if (r >= -70) return 2;
    if (r >= -80) return 1;
    return 0;
  }

  bool get senalDebil => rssi != null && rssi! < -80;
}

/// La lista de redes que vio el lector, la de mejor señal primero.
///
/// Firmware 6.1+: una por línea, `<dBm>\t<seguridad>\t<nombre>`. El nombre va
/// al final porque puede traer cualquier carácter. Firmware anterior: solo
/// el nombre.
List<RedWifi> parsearRedes(String texto) {
  final vistas = <String>{};
  final redes = <RedWifi>[];
  for (final linea in texto.split('\n')) {
    if (linea.trim().isEmpty) continue;

    final partes = linea.split('\t');
    final RedWifi red;
    if (partes.length >= 3 && int.tryParse(partes[0]) != null) {
      red = RedWifi(
        partes.sublist(2).join('\t'),
        rssi: int.parse(partes[0]),
        seguridad: SeguridadRed.desdeTexto(partes[1]),
      );
    } else {
      red = RedWifi(linea);
    }
    if (red.ssid.isNotEmpty && vistas.add(red.ssid)) redes.add(red);
  }
  return redes;
}

/// Un lector que se está ofreciendo por Bluetooth para configurarlo.
class LectorCercano {
  LectorCercano(this.dispositivo, this.nombre, this.rssi);

  final BluetoothDevice dispositivo;

  /// `GymOne-XXXX`: los 4 últimos caracteres de su MAC, como en la etiqueta.
  final String nombre;
  final int rssi;
}

/// Un problema que la pantalla le puede explicar a la persona tal cual.
class LectorBleException implements Exception {
  const LectorBleException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Configura el WiFi del lector por Bluetooth.
///
/// El Bluetooth es SOLO para esto: una sesión corta (~30 s) y se cierra. El
/// trabajo diario —leer tarjetas— sigue por WiFi, como siempre. El intento
/// anterior tenía el Bluetooth como canal permanente, y ahí se caía.
///
/// Reglas para que no se caiga:
/// - Valores pequeños, cada uno en su característica. Nada de JSON por
///   notificaciones, que llegaban cortados.
/// - El `estado` se escucha por notificación Y se relee cada segundo: si se
///   pierde una notificación, la lectura la recupera.
/// - Si la conexión se corta antes del resultado, se reconecta una vez y se
///   relee el estado. El lector no pierde el avance: vive en su loop.
class LectorBleService {
  BluetoothDevice? _dispositivo;
  BluetoothCharacteristic? _chRedes;
  BluetoothCharacteristic? _chSsid;
  BluetoothCharacteristic? _chClave;
  BluetoothCharacteristic? _chGym;
  BluetoothCharacteristic? _chOrden;
  BluetoothCharacteristic? _chEstado;

  /// Deja el Bluetooth listo para buscar, o explica por qué no se puede.
  Future<void> prepararBluetooth() async {
    if (!await FlutterBluePlus.isSupported) {
      throw const LectorBleException(
          'Este teléfono no tiene Bluetooth compatible.');
    }

    var estado = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 5),
            onTimeout: () => BluetoothAdapterState.unknown);

    if (estado == BluetoothAdapterState.off && Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
        estado = BluetoothAdapterState.on;
      } catch (_) {}
    }

    if (estado == BluetoothAdapterState.unauthorized) {
      throw const LectorBleException(
          'La app no tiene permiso para usar Bluetooth. Actívalo en los '
          'ajustes del teléfono.');
    }
    if (estado != BluetoothAdapterState.on) {
      throw const LectorBleException(
          'Enciende el Bluetooth del teléfono para encontrar el lector.');
    }
  }

  /// Busca lectores cercanos en modo configuración.
  ///
  /// Emite la lista cada vez que aparece uno nuevo, ordenada por cercanía.
  Stream<List<LectorCercano>> buscar({
    Duration duracion = const Duration(seconds: 15),
  }) async* {
    await prepararBluetooth();

    final encontrados = <String, LectorCercano>{};
    final controlador = StreamController<List<LectorCercano>>();

    final sub = FlutterBluePlus.onScanResults.listen((resultados) {
      for (final r in resultados) {
        final nombre = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : 'Lector GymOne');
        encontrados[r.device.remoteId.str] =
            LectorCercano(r.device, nombre, r.rssi);
      }
      final lista = encontrados.values.toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      controlador.add(lista);
    });

    FlutterBluePlus.cancelWhenScanComplete(sub);

    unawaited(FlutterBluePlus.isScanning
        .where((escaneando) => !escaneando)
        .skip(1)
        .first
        .then((_) => controlador.close()));

    await FlutterBluePlus.startScan(
      withServices: [_servicioUuid],
      timeout: duracion,
    );

    yield* controlador.stream;
  }

  Future<void> detenerBusqueda() => FlutterBluePlus.stopScan();

  /// Se conecta al [lector] y localiza sus características.
  Future<void> conectar(LectorCercano lector) async {
    await detenerBusqueda();
    _dispositivo = lector.dispositivo;
    await _conectarDispositivo();
  }

  bool get conectado =>
      _chEstado != null && (_dispositivo?.isConnected ?? false);

  /// Vuelve a conectarse al lector elegido (p. ej. para reintentar tras un
  /// error, después de haber soltado el Bluetooth).
  Future<void> asegurarConexion() async {
    if (conectado) return;
    await _conectarDispositivo();
  }

  Future<void> _conectarDispositivo() async {
    final d = _dispositivo;
    if (d == null) throw const LectorBleException('No hay lector elegido.');

    try {
      await d.connect(timeout: const Duration(seconds: 15));
      await _prepararCaracteristicas(d);
    } on LectorBleException {
      await desconectar();
      rethrow;
    } catch (e) {
      AppLogger.error('LectorBleService', 'No se pudo conectar', e);
      await desconectar();
      throw const LectorBleException(
          'No se pudo conectar con el lector. Acerca el teléfono y reintenta.');
    }
  }

  /// Localiza el servicio y las características del lector ya conectado.
  Future<void> _prepararCaracteristicas(BluetoothDevice d) async {
    final servicios = await d.discoverServices();
    final servicio = servicios.firstWhere(
      (s) => s.uuid == _servicioUuid,
      orElse: () =>
          throw const LectorBleException('Ese aparato no es un lector GymOne.'),
    );

    BluetoothCharacteristic ch(Guid uuid) =>
        servicio.characteristics.firstWhere((c) => c.uuid == uuid,
            orElse: () => throw const LectorBleException(
                'El lector tiene un programa distinto. Actualízalo.'));

    _chRedes = ch(_redesUuid);
    _chSsid = ch(_ssidUuid);
    _chClave = ch(_claveUuid);
    _chGym = ch(_gymUuid);
    _chOrden = ch(_ordenUuid);
    _chEstado = ch(_estadoUuid);

    // Las notificaciones son un extra: si fallan, la relectura periódica
    // de `estado` basta.
    try {
      await _chEstado!.setNotifyValue(true);
    } catch (e) {
      AppLogger.warning('LectorBleService', 'Sin notificaciones: $e');
    }
  }

  /// Pide al lector que busque redes y devuelve lo que vio.
  Future<List<RedWifi>> leerRedes() async {
    return _conReintento(() async {
      await _escribir(_chOrden, 'escanear');
      // El escaneo del lector tarda ~3-5 s.
      await _esperarEstado(
        (e) => e.fase != FaseConfig.buscandoRedes,
        timeout: const Duration(seconds: 15),
        ignorarPrimero: true,
      );
      final bytes = await _chRedes!.read(timeout: 10);
      return parsearRedes(utf8.decode(bytes, allowMalformed: true));
    });
  }

  /// Manda el WiFi y el gimnasio y SUELTA el Bluetooth.
  ///
  /// El lector prueba el WiFi con el Bluetooth en pausa: comparten antena, y
  /// con el teléfono conectado la negociación de la contraseña fallaba por
  /// tiempo agotado (parecía contraseña incorrecta sin serlo). El resultado
  /// se lee después con [esperarResultado].
  ///
  /// Devuelve un error si el lector lo rechaza al instante (datos
  /// incompletos, es de otro gimnasio); null si empezó a probar la red.
  Future<EstadoConfig?> enviarWifi({
    required String ssid,
    required String clave,
    required String gymId,
  }) async {
    await asegurarConexion();

    // El estado de ANTES de la orden: si el intento anterior falló, sigue
    // diciendo ese error, y no hay que confundirlo con la respuesta nueva.
    String anterior = '';
    try {
      anterior =
          utf8.decode(await _chEstado!.read(timeout: 5), allowMalformed: true);
    } catch (_) {}

    await _conReintento(() async {
      await _escribir(_chSsid, ssid);
      await _escribir(_chClave, clave);
      await _escribir(_chGym, gymId);
      await _escribir(_chOrden, 'conectar');
    });

    EstadoConfig? respuesta;
    try {
      respuesta = await _esperarEstado(
        (e) =>
            e.fase == FaseConfig.conectando ||
            (e.fase.esFinal && e.toTexto() != anterior.trim()),
        timeout: const Duration(seconds: 6),
      );
    } catch (_) {
      // Sin respuesta clara: el resultado se sabrá al reconectar.
    }

    // Se suelta el Bluetooth para que el lector pruebe el WiFi sin él.
    await desconectar();

    if (respuesta != null && respuesta.fase.esFinal) return respuesta;
    return null;
  }

  /// Espera el resultado del intento después de [enviarWifi].
  ///
  /// Si el lector falla, vuelve a anunciarse por Bluetooth: se reconecta y
  /// se lee el error. Si lo logra, se reinicia sin Bluetooth y no vuelve a
  /// aparecer aquí: eso lo detecta quien lo busque en la red. Por eso esto
  /// devuelve null si llega [hasta] o [cancelado] sin saber nada.
  Future<EstadoConfig?> esperarResultado({
    required DateTime hasta,
    required bool Function() cancelado,
  }) async {
    final d = _dispositivo;
    if (d == null) return null;

    // El intento dura hasta ~30 s: no tiene caso intentar antes.
    await Future<void>.delayed(const Duration(seconds: 5));

    while (!cancelado() && DateTime.now().isBefore(hasta)) {
      final restante = hasta.difference(DateTime.now());
      try {
        // Mientras el lector prueba el WiFi no se anuncia: la conexión queda
        // pendiente hasta que reaparezca (o se agota y se vuelve a intentar).
        await d.connect(
          timeout: restante < const Duration(seconds: 15)
              ? restante
              : const Duration(seconds: 15),
        );
        if (cancelado()) {
          await desconectar();
          return null;
        }
        await _prepararCaracteristicas(d);
        final e = EstadoConfig.parse(utf8
            .decode(await _chEstado!.read(timeout: 5), allowMalformed: true));
        if (e.fase.esFinal) return e;
        // Seguía probando: se suelta otra vez y se espera.
        await desconectar();
      } catch (_) {
        // No se anunció todavía (sigue probando, o ya se conectó y reinició).
      }
      if (cancelado()) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<void> desconectar() async {
    try {
      await _dispositivo?.disconnect();
    } catch (_) {}
    _chRedes = _chSsid = _chClave = _chGym = _chOrden = _chEstado = null;
  }

  // ─────────────────────────────────────────────────────────

  Future<void> _escribir(BluetoothCharacteristic? c, String valor) async {
    if (c == null) throw const LectorBleException('No hay lector conectado.');
    await c.write(utf8.encode(valor), allowLongWrite: true, timeout: 10);
  }

  /// Ejecuta [accion]; si falla porque se cayó la conexión, reconecta una
  /// vez y la repite.
  Future<T> _conReintento<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on LectorBleException {
      rethrow;
    } catch (e) {
      AppLogger.warning('LectorBleService', 'Reintentando tras: $e');
      await _conectarDispositivo();
      try {
        return await accion();
      } catch (e) {
        if (e is LectorBleException) rethrow;
        throw const LectorBleException(
            'Se perdió la conexión con el lector. Acerca el teléfono y '
            'reintenta.');
      }
    }
  }

  /// Espera a que `estado` cumpla [listo]: por notificación o releyéndolo
  /// cada segundo, lo que llegue primero.
  ///
  /// [ignorarPrimero] descarta la primera lectura, que puede ser el estado
  /// de ANTES de la orden recién enviada.
  Future<EstadoConfig> _esperarEstado(
    bool Function(EstadoConfig) listo, {
    required Duration timeout,
    bool ignorarPrimero = false,
  }) async {
    final ch = _chEstado;
    final d = _dispositivo;
    if (ch == null || d == null) throw _Desconectado();

    final fin = DateTime.now().add(timeout);
    final resultado = Completer<EstadoConfig>();
    // El error de desconexión puede llegar antes de que alguien espere este
    // futuro; sin un oyente desde ya, saldría como error no manejado.
    unawaited(resultado.future.then((_) {}, onError: (_) {}));

    final subValor = ch.onValueReceived.listen((bytes) {
      final e = EstadoConfig.parse(utf8.decode(bytes, allowMalformed: true));
      if (listo(e) && !resultado.isCompleted) resultado.complete(e);
    });
    final subConexion = d.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected &&
          !resultado.isCompleted) {
        resultado.completeError(_Desconectado());
      }
    });

    try {
      if (ignorarPrimero) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
      while (DateTime.now().isBefore(fin)) {
        if (resultado.isCompleted) return await resultado.future;
        try {
          final bytes = await ch.read(timeout: 5);
          final e =
              EstadoConfig.parse(utf8.decode(bytes, allowMalformed: true));
          if (listo(e)) return e;
        } catch (_) {
          if (d.isDisconnected) throw _Desconectado();
        }
        await Future.any([
          resultado.future.then((_) {}, onError: (_) {}),
          Future<void>.delayed(const Duration(seconds: 1)),
        ]);
      }
      if (resultado.isCompleted) return await resultado.future;
      throw TimeoutException('El lector no respondió a tiempo');
    } finally {
      await subValor.cancel();
      await subConexion.cancel();
    }
  }
}

class _Desconectado implements Exception {}

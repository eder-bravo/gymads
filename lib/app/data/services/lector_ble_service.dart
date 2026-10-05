import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart' as universal;

import '../../core/utils/app_logger.dart';
import 'estado_configuracion_lector.dart';
import 'registro_busqueda_lector.dart';
import 'transporte_lector_ble.dart';

/// Dónde se da el permiso de Bluetooth: en macOS, los ajustes del sistema;
/// en el teléfono, los permisos de la app.
String get _ajustesBluetooth => PlataformaApp.linux
    ? 'la configuración de Bluetooth del sistema'
    : PlataformaApp.escritorio
        ? 'Ajustes del Sistema > Privacidad y seguridad > Bluetooth'
        : 'Ajustes > Aplicaciones > GymOne > Permisos';

/// Windows o Linux: las dos computadoras que buscan con Universal BLE.
String get _sistemaUniversal => PlataformaApp.linux ? 'Linux' : 'Windows';

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
final Guid _sesionUuid = Guid('6b1a0008-5c1e-4f7a-9d2e-47796d416473');

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
  ocupado,
  desconocido;

  bool get esFinal =>
      this == ok ||
      this == errorClave ||
      this == errorSinRed ||
      this == errorSinIp ||
      this == errorSeguridad ||
      this == errorNoConecta ||
      this == errorDatos ||
      this == errorOtroGimnasio ||
      this == ocupado;
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
      'ocupado' => FaseConfig.ocupado,
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
        FaseConfig.ocupado => 'ocupado',
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
  LectorCercano(this.dispositivo, this.nombre, this.rssi,
      {this.ocupado = false});

  final BluetoothDevice dispositivo;

  /// `GymOne-XXXX`: los 4 últimos caracteres de su MAC, como en la etiqueta.
  final String nombre;
  final int rssi;
  final bool ocupado;
}

/// Un problema que la pantalla le puede explicar a la persona tal cual.
class LectorBleException implements Exception {
  const LectorBleException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

enum TipoFalloBusquedaBle {
  ubicacion,
  permisoUbicacion,
  permisoBluetooth,
  bluetoothApagado,
  bluetoothNoListo,
  inicioFallido,
  interno,
  demasiadosIntentos,
  sinCompatibilidad,
  desconocido,
}

/// Un fallo del teléfono al buscar, distinto de una búsqueda sin lectores.
class FalloBusquedaBle extends LectorBleException {
  const FalloBusquedaBle(super.mensaje, this.tipo, {this.codigo});

  final TipoFalloBusquedaBle tipo;
  final int? codigo;
  bool get reintentable =>
      tipo == TipoFalloBusquedaBle.interno ||
      tipo == TipoFalloBusquedaBle.inicioFallido ||
      tipo == TipoFalloBusquedaBle.bluetoothNoListo;
}

FalloBusquedaBle explicarFalloBusquedaBle(Object error) {
  if (error is FalloBusquedaBle) return error;
  final String descripcion;
  int? codigo;
  if (error is FlutterBluePlusException) {
    descripcion = error.description?.toLowerCase() ?? '';
    if (error.platform == ErrorPlatform.android && error.function == 'scan') {
      codigo = error.code;
    }
  } else if (error is PlatformException) {
    descripcion = error.message?.toLowerCase() ?? '';
  } else {
    descripcion = '';
  }
  if (descripcion.contains('location services')) {
    return FalloBusquedaBle(
      'Activa «Ubicación» en los ajustes rápidos ${PlataformaApp.delAparato} y '
      'vuelve a intentar. ${_Frase.mayuscula(PlataformaApp.esteAparato)} la '
      'necesita para buscar el lector por Bluetooth.',
      TipoFalloBusquedaBle.ubicacion,
    );
  }
  if (descripcion.contains('permission') ||
      descripcion.contains('unauthorized')) {
    final ubicacion = descripcion.contains('location');
    return FalloBusquedaBle(
      ubicacion
          ? 'Permite a GymOne acceder a la ubicación en Ajustes > '
              'Aplicaciones > GymOne > Permisos y vuelve a intentar.'
          : PlataformaApp.escritorio
              ? 'Permite a GymOne usar Bluetooth en $_ajustesBluetooth y '
                  'vuelve a intentar.'
              : 'Permite a GymOne usar Bluetooth o «Dispositivos cercanos» en '
                  '$_ajustesBluetooth y vuelve a intentar.',
      ubicacion
          ? TipoFalloBusquedaBle.permisoUbicacion
          : TipoFalloBusquedaBle.permisoBluetooth,
    );
  }
  if (descripcion.contains('must be turned on')) {
    return FalloBusquedaBle(
      'Enciende el Bluetooth del ${PlataformaApp.equipo} y pulsa «Intentar de nuevo».',
      TipoFalloBusquedaBle.bluetoothApagado,
    );
  }
  if (codigo == 6) {
    return FalloBusquedaBle(
      '${_Frase.mayuscula(PlataformaApp.elAparato)} necesita una pausa entre '
      'búsquedas. Espera 30 segundos y pulsa «Intentar de nuevo».',
      TipoFalloBusquedaBle.demasiadosIntentos,
      codigo: 6,
    );
  }
  if (codigo == 4) {
    return FalloBusquedaBle(
      '${_Frase.mayuscula(PlataformaApp.elAparato)} no pudo iniciar la '
      'búsqueda Bluetooth. Apaga Bluetooth, espera 5 segundos y vuelve a '
      'encenderlo antes de intentar de nuevo.',
      TipoFalloBusquedaBle.sinCompatibilidad,
      codigo: 4,
    );
  }
  return FalloBusquedaBle(
    'El ${PlataformaApp.equipo} no pudo buscar por Bluetooth. Apágalo, espera 5 segundos, '
    'vuelve a encenderlo y pulsa «Intentar de nuevo».',
    codigo == 1
        ? TipoFalloBusquedaBle.inicioFallido
        : codigo != null || descripcion.contains('getbluetoothlescanner')
            ? TipoFalloBusquedaBle.interno
            : TipoFalloBusquedaBle.desconocido,
    codigo: codigo,
  );
}

class _BusquedaBle {
  final cancelacion = Completer<void>();
  late final StreamController<List<LectorCercano>> salida;
  bool cancelada = false;
  bool terminada = false;
  Future<void>? detencion;
}

/// Cinco inicios por ventana de 30 s, compartidos entre asistentes. Usa un
/// reloj monotónico para que ajustar la hora del teléfono no cambie la pausa.
class LimiteBusquedasBle {
  LimiteBusquedasBle({Duration Function()? tiempo}) {
    final reloj = Stopwatch()..start();
    _tiempo = tiempo ?? (() => reloj.elapsed);
  }

  late final Duration Function() _tiempo;
  final _inicios = <Duration>[];

  bool reservarInicio() {
    final ahora = _tiempo();
    _inicios.removeWhere((t) => ahora - t >= const Duration(seconds: 30));
    if (_inicios.length >= 5) return false;
    _inicios.add(ahora);
    return true;
  }
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
  LectorBleService({RegistroBusquedaLector? registro, bool? usarBleWindows})
      : registroBusqueda = registro ?? RegistroBusquedaLector.instance,
        // Linux también: con FlutterBluePlus, BlueZ no vuelve a anunciar un
        // lector que ya vio, y una segunda búsqueda no lo encontraría.
        _usarBleWindows = usarBleWindows ??
            (!kIsWeb && (Platform.isWindows || Platform.isLinux));

  final RegistroBusquedaLector registroBusqueda;
  _BusquedaBle? _busqueda;
  // FlutterBluePlus tiene un único escáner por aplicación. El intento viejo
  // debe terminar antes de instalar los listeners del siguiente.
  static _BusquedaBle? _duenoEscaneo;
  static Future<void> _colaDueno = Future<void>.value();
  static final _limiteAndroid = LimiteBusquedasBle();
  final bool _usarBleWindows;
  bool get _windows => _usarBleWindows;
  DispositivoLectorBle? _dispositivo;
  CaracteristicaLectorBle? _chRedes;
  CaracteristicaLectorBle? _chSsid;
  CaracteristicaLectorBle? _chClave;
  CaracteristicaLectorBle? _chGym;
  CaracteristicaLectorBle? _chOrden;
  CaracteristicaLectorBle? _chEstado;
  CaracteristicaLectorBle? _chSesion;
  final String _tokenSesion = const Uuid().v4();
  Timer? _renovarSesion;
  bool _soportaSesiones = false;
  String? get tokenSesion => _soportaSesiones ? _tokenSesion : null;

  /// Firmware 6.7+: mantiene la reserva mientras se elige y escribe. El
  /// anuncio sigue visible para que otros dispositivos vean «ocupado».
  bool get sesionExclusiva => _chSesion != null;

  /// Deja el Bluetooth listo para buscar, o explica por qué no se puede.
  Future<void> prepararBluetooth() async {
    if (kIsWeb) {
      throw const FalloBusquedaBle(
          'Configura el lector de tarjetas desde la app de macOS, Windows, Linux o tu celular. '
          'El escáner de códigos USB funciona en esta página como teclado.',
          TipoFalloBusquedaBle.sinCompatibilidad);
    }
    if (_windows) {
      final estado =
          await universal.UniversalBle.getBluetoothAvailabilityState();
      if (estado == universal.AvailabilityState.poweredOn) return;
      if (estado == universal.AvailabilityState.unauthorized) {
        throw FalloBusquedaBle(
            'Permite el acceso a Bluetooth en los ajustes de $_sistemaUniversal.',
            TipoFalloBusquedaBle.permisoBluetooth);
      }
      throw FalloBusquedaBle(
          estado == universal.AvailabilityState.poweredOff
              ? 'Enciende Bluetooth en $_sistemaUniversal. Si este equipo no tiene adaptador, configura el lector desde tu celular con la misma cuenta y red del gimnasio.'
              : 'No hay Bluetooth BLE disponible. Usa un adaptador USB compatible con $_sistemaUniversal o configura el lector desde tu celular con la misma cuenta. '
                  'Después, esta computadora lo encontrará en la red del gimnasio.',
          estado == universal.AvailabilityState.poweredOff
              ? TipoFalloBusquedaBle.bluetoothApagado
              : TipoFalloBusquedaBle.sinCompatibilidad);
    }
    if (!await FlutterBluePlus.isSupported) {
      throw FalloBusquedaBle(
          PlataformaApp.escritorio
              ? 'Este equipo no tiene Bluetooth compatible. Configura el lector '
                  'desde tu celular con la misma cuenta y red del gimnasio, o usa un adaptador BLE USB compatible. '
                  'Después podrás usar el lector desde esta computadora por la red.'
              : 'Este dispositivo no tiene Bluetooth compatible. Configura el lector '
                  'desde tu celular con la misma cuenta y red del gimnasio, o usa un adaptador BLE USB compatible. '
                  'Después podrás usar el lector desde esta computadora por la red.',
          TipoFalloBusquedaBle.sinCompatibilidad);
    }

    var estado = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 5),
            onTimeout: () => BluetoothAdapterState.unknown);

    if (estado == BluetoothAdapterState.off && Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
        estado = await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 5),
                onTimeout: () => BluetoothAdapterState.unknown);
      } catch (_) {}
    }

    if (estado == BluetoothAdapterState.unauthorized) {
      throw FalloBusquedaBle(
          PlataformaApp.escritorio
              ? 'La app no tiene permiso para usar Bluetooth. Actívalo en '
                  '$_ajustesBluetooth.'
              : 'La app no tiene permiso para usar Bluetooth. Actívalo en los '
                  'ajustes ${PlataformaApp.delAparato}.',
          TipoFalloBusquedaBle.permisoBluetooth);
    }
    if (estado != BluetoothAdapterState.on) {
      throw FalloBusquedaBle(
          estado == BluetoothAdapterState.off
              ? 'Enciende el Bluetooth del ${PlataformaApp.equipo} para encontrar el lector.'
              : 'El Bluetooth del ${PlataformaApp.equipo} aún no está listo. Espera un '
                  'momento y vuelve a intentar.',
          estado == BluetoothAdapterState.off
              ? TipoFalloBusquedaBle.bluetoothApagado
              : TipoFalloBusquedaBle.bluetoothNoListo);
    }
  }

  /// Busca lectores cercanos en modo configuración.
  ///
  /// Emite la lista cada vez que aparece uno nuevo, ordenada por cercanía.
  Stream<List<LectorCercano>> buscar({
    Duration duracion = const Duration(seconds: 15),
  }) {
    final busqueda = _BusquedaBle();
    busqueda.salida = StreamController<List<LectorCercano>>(
      onListen: () => unawaited(_buscar(busqueda, duracion)),
      onCancel: () => _cancelarBusqueda(busqueda),
    );
    return busqueda.salida.stream;
  }

  Future<void> _buscar(_BusquedaBle busqueda, Duration duracion) async {
    if (_windows) {
      await _buscarWindows(busqueda, duracion);
      return;
    }
    _busqueda = busqueda;
    final reloj = Stopwatch()..start();
    unawaited(registroBusqueda.registrar(EventoBusquedaLector.inicio));
    final encontrados = <String, LectorCercano>{};
    final fin = Completer<void>();
    Object? fallo;
    bool comenzo = false;
    StreamSubscription<List<ScanResult>>? resultadosSub;
    StreamSubscription<bool>? escaneoSub;
    StreamSubscription<BluetoothAdapterState>? adaptadorSub;
    void terminar([Object? error]) {
      fallo ??= error;
      if (!fin.isCompleted) fin.complete();
    }

    try {
      await _tomarEscaner(busqueda);
      if (busqueda.cancelada) return;
      await prepararBluetooth();
      if (busqueda.cancelada) return;
      await FlutterBluePlus.stopScan();
      if (busqueda.cancelada) return;

      // Android limita los inicios frecuentes: no provocar otro bloqueo al
      // pulsar varias veces ni al hacer el único reintento automático.
      if (Platform.isAndroid) {
        if (!_limiteAndroid.reservarInicio()) {
          throw FalloBusquedaBle(
              '${_Frase.mayuscula(PlataformaApp.elAparato)} necesita una pausa '
              'entre búsquedas. Espera 30 segundos y pulsa «Intentar de '
              'nuevo».',
              TipoFalloBusquedaBle.demasiadosIntentos);
        }
      }

      resultadosSub = FlutterBluePlus.onScanResults.listen((resultados) {
        if (busqueda.cancelada || busqueda.terminada) return;
        final cantidadAnterior = encontrados.length;
        for (final r in resultados) {
          // Además del filtro nativo, no aceptar resultados almacenados de
          // otro servicio o búsqueda por nombre.
          if (!r.advertisementData.serviceUuids.contains(_servicioUuid)) {
            continue;
          }
          final nombre = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : (r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : 'Lector GymOne');
          encontrados[r.device.remoteId.str] = LectorCercano(
              r.device, nombre, r.rssi,
              ocupado:
                  lectorOcupadoEnAnuncio(r.advertisementData.manufacturerData));
        }
        if (encontrados.isEmpty) return;
        if (encontrados.length != cantidadAnterior) {
          unawaited(registroBusqueda.registrar(EventoBusquedaLector.encontrados,
              lectores: encontrados.length));
        }
        final lista = encontrados.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        busqueda.salida.add(lista);
      }, onError: (Object error, StackTrace _) => terminar(error));
      escaneoSub = FlutterBluePlus.isScanning.listen((escaneando) {
        if (escaneando) comenzo = true;
        if (!escaneando && comenzo) {
          // El plugin publica false y el error/estado del adaptador en el
          // mismo turno. Dejar que llegue el motivo antes de cerrar vacío.
          unawaited(Future<void>.delayed(Duration.zero, terminar));
        }
      });
      adaptadorSub = FlutterBluePlus.adapterState.listen((estado) {
        if (estado == BluetoothAdapterState.off ||
            estado == BluetoothAdapterState.turningOff) {
          terminar(FalloBusquedaBle(
              'Se apagó el Bluetooth del ${PlataformaApp.equipo}. Enciéndelo y pulsa '
              '«Intentar de nuevo».',
              TipoFalloBusquedaBle.bluetoothApagado));
        } else if (estado == BluetoothAdapterState.unauthorized) {
          terminar(FalloBusquedaBle(
              'La app perdió el permiso de Bluetooth. Actívalo en '
              '$_ajustesBluetooth y vuelve a intentar.',
              TipoFalloBusquedaBle.permisoBluetooth));
        }
      });
      await FlutterBluePlus.startScan(
        withServices: [_servicioUuid],
        timeout: duracion,
        // El firmware anuncia paquetes BLE clásicos. Buscar solo esos
        // evita depender de los modos extendidos de cada teléfono Android.
        androidLegacy: true,
      );
      unawaited(
          registroBusqueda.registrar(EventoBusquedaLector.escaneoIniciado));
      await Future.any([fin.future, busqueda.cancelacion.future]).timeout(
          duracion + const Duration(seconds: 2),
          onTimeout: () => terminar(FalloBusquedaBle(
              'El ${PlataformaApp.equipo} no terminó la búsqueda Bluetooth. Apaga Bluetooth, '
              'espera 5 segundos y vuelve a encenderlo para intentar de nuevo.',
              TipoFalloBusquedaBle.interno)));
      if (fallo != null) throw fallo!;
      if (!busqueda.cancelada) {
        unawaited(registroBusqueda.registrar(
            encontrados.isEmpty
                ? EventoBusquedaLector.sinLectores
                : EventoBusquedaLector.completada,
            lectores: encontrados.length,
            milisegundos: reloj.elapsedMilliseconds));
      }
    } catch (error) {
      if (!busqueda.cancelada) {
        final explicado = explicarFalloBusquedaBle(error);
        unawaited(registroBusqueda.registrar(EventoBusquedaLector.fallo,
            categoria: explicado.tipo.name,
            codigo: explicado.codigo,
            milisegundos: reloj.elapsedMilliseconds));
        busqueda.salida.addError(explicado);
      }
    } finally {
      busqueda.terminada = true;
      await resultadosSub?.cancel();
      await escaneoSub?.cancel();
      await adaptadorSub?.cancel();
      if (identical(_duenoEscaneo, busqueda)) {
        await _detenerEscaneoNativo();
        if (identical(_duenoEscaneo, busqueda)) _duenoEscaneo = null;
      }
      if (identical(_busqueda, busqueda)) _busqueda = null;
      unawaited(busqueda.salida.close());
    }
  }

  Future<void> _buscarWindows(_BusquedaBle busqueda, Duration duracion) async {
    _busqueda = busqueda;
    final encontrados = <String, LectorCercano>{};
    StreamSubscription<universal.BleDevice>? resultados;
    StreamSubscription<universal.AvailabilityState>? adaptador;
    final fin = Completer<void>();
    // Puede fallar antes de empezar a esperar el fin.
    unawaited(fin.future.then((_) {}, onError: (Object _) {}));
    try {
      await _tomarEscaner(busqueda);
      if (busqueda.cancelada) return;
      await prepararBluetooth();
      if (busqueda.cancelada) return;
      await universal.UniversalBle.stopScan();
      if (busqueda.cancelada) return;
      resultados = universal.UniversalBle.scanStream.listen((d) {
        if (busqueda.cancelada ||
            busqueda.terminada ||
            !d.services.any((s) => Guid(s) == _servicioUuid)) {
          return;
        }
        encontrados[d.deviceId] = LectorCercano(
            BluetoothDevice.fromId(d.deviceId),
            d.name?.isNotEmpty == true ? d.name! : 'Lector GymOne',
            d.rssi ?? -100,
            ocupado: lectorOcupadoEnAnuncio({
              for (final m in d.manufacturerDataList)
                m.companyId: m.payload.toList()
            }));
        busqueda.salida.add(encontrados.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi)));
      }, onError: (Object error) {
        if (!fin.isCompleted) fin.completeError(error);
      });
      adaptador = universal.UniversalBle.availabilityStream.listen((estado) {
        if (estado != universal.AvailabilityState.poweredOn &&
            !fin.isCompleted) {
          fin.completeError(FalloBusquedaBle(
              'Bluetooth dejó de estar disponible. Revisa el adaptador de $_sistemaUniversal.',
              TipoFalloBusquedaBle.bluetoothNoListo));
        }
      });
      await universal.UniversalBle.startScan(
          scanFilter: universal.ScanFilter(withServices: [_servicioUuid.str]));
      if (busqueda.cancelada) return;
      await Future.any([
        fin.future,
        busqueda.cancelacion.future,
        Future<void>.delayed(duracion)
      ]);
    } catch (error) {
      if (!busqueda.cancelada) {
        busqueda.salida.addError(explicarFalloBusquedaBle(error));
      }
    } finally {
      busqueda.terminada = true;
      await resultados?.cancel();
      await adaptador?.cancel();
      if (identical(_duenoEscaneo, busqueda)) {
        await _detenerEscaneoNativo();
        if (identical(_duenoEscaneo, busqueda)) _duenoEscaneo = null;
      }
      if (identical(_busqueda, busqueda)) _busqueda = null;
      unawaited(busqueda.salida.close());
    }
  }

  Future<void> _tomarEscaner(_BusquedaBle busqueda) {
    final turno = _colaDueno.then((_) async {
      if (busqueda.cancelada) return;
      final anterior = _duenoEscaneo;
      if (anterior != null) await _cancelarBusqueda(anterior);
      if (!busqueda.cancelada) _duenoEscaneo = busqueda;
    });
    _colaDueno = turno.then((_) {}, onError: (Object _, StackTrace __) {});
    return turno;
  }

  Future<void> _cancelarBusqueda(_BusquedaBle busqueda) {
    if (busqueda.detencion != null) return busqueda.detencion!;
    if (busqueda.terminada) return Future<void>.value();
    busqueda.cancelada = true;
    busqueda.cancelacion.complete();
    unawaited(registroBusqueda.registrar(EventoBusquedaLector.cancelada));
    return busqueda.detencion = identical(_duenoEscaneo, busqueda)
        ? _detenerEscaneoNativo()
        : Future<void>.value();
  }

  Future<void> _detenerEscaneoNativo() async {
    try {
      if (_windows) {
        await universal.UniversalBle.stopScan();
      } else if (!kIsWeb) {
        await FlutterBluePlus.stopScan();
      }
    } catch (error) {
      AppLogger.error('LectorBleService', 'Al detener la búsqueda', error);
      final explicado = explicarFalloBusquedaBle(error);
      unawaited(registroBusqueda.registrar(EventoBusquedaLector.fallo,
          categoria: explicado.tipo.name, codigo: explicado.codigo));
    }
  }

  Future<void> detenerBusqueda() async {
    final busqueda = _busqueda;
    if (busqueda != null) await _cancelarBusqueda(busqueda);
  }

  /// Se conecta al [lector] y localiza sus características.
  Future<void> conectar(LectorCercano lector) async {
    if (lector.ocupado) throw const LectorOcupadoException();
    await detenerBusqueda();
    await desconectar();
    _dispositivo = DispositivoLectorBle(lector.dispositivo, windows: _windows);
    await _conectarDispositivo();
  }

  bool get conectado =>
      _chEstado != null && (_dispositivo?.isConnected ?? false);

  /// Vuelve a conectarse al lector elegido (p. ej. para reintentar tras un
  /// error, después de haber soltado el Bluetooth).
  Future<void> asegurarConexion() async {
    if (conectado) {
      await _tomarSesion();
      return;
    }
    await _conectarDispositivo();
  }

  Future<void> _conectarDispositivo() async {
    final d = _dispositivo;
    if (d == null) throw const LectorBleException('No hay lector elegido.');

    try {
      await d.connect(timeout: const Duration(seconds: 8));
      await _prepararCaracteristicas(d);
    } on LectorOcupadoException {
      await desconectar();
      rethrow;
    } on LectorBleException {
      await desconectar();
      rethrow;
    } catch (e) {
      AppLogger.error('LectorBleService', 'No se pudo conectar', e);
      await desconectar();
      throw LectorBleException(
          'No se pudo conectar con el lector. Acerca el ${PlataformaApp.equipo} y reintenta.');
    }
  }

  /// Localiza el servicio y las características del lector ya conectado.
  Future<void> _prepararCaracteristicas(DispositivoLectorBle d) async {
    final servicios = await d.discoverServices();
    final servicio = servicios.firstWhere(
      (s) => s.uuid == _servicioUuid,
      orElse: () =>
          throw const LectorBleException('Ese aparato no es un lector GymOne.'),
    );

    CaracteristicaLectorBle ch(Guid uuid) =>
        servicio.characteristics.firstWhere((c) => c.uuid == uuid,
            orElse: () => throw const LectorBleException(
                'El lector tiene un programa distinto. Actualízalo.'));

    _chRedes = ch(_redesUuid);
    _chSsid = ch(_ssidUuid);
    _chClave = ch(_claveUuid);
    _chGym = ch(_gymUuid);
    _chOrden = ch(_ordenUuid);
    _chEstado = ch(_estadoUuid);
    _chSesion = servicio.characteristics
        .where((c) => c.uuid == _sesionUuid)
        .firstOrNull;
    _soportaSesiones = _chSesion != null;
    await _tomarSesion();

    _renovarSesion?.cancel();
    if (_chSesion != null) {
      _renovarSesion = Timer.periodic(const Duration(seconds: 20), (_) async {
        final sesion = _chSesion;
        if (sesion == null || !d.isConnected) return;
        try {
          // Leer renueva solo la reserva de esta conexión, nunca la ajena.
          await sesion.read(timeout: 3);
        } catch (_) {}
      });
    }

    // Las notificaciones son un extra: si fallan, la relectura periódica
    // de `estado` basta.
    try {
      await _chEstado!.setNotifyValue(true);
    } catch (e) {
      AppLogger.warning('LectorBleService', 'Sin notificaciones: $e');
    }
  }

  Future<void> _tomarSesion() async {
    final sesion = _chSesion;
    if (sesion == null) return; // Firmware anterior, sin reserva explícita.
    await sesion.write(utf8.encode('tomar:$_tokenSesion'), timeout: 3);
    final estado = utf8.decode(await sesion.read(timeout: 3));
    if (estado != 'tuya') throw const LectorOcupadoException();
  }

  /// Al cerrar el asistente se libera la reserva, sin esperar su vencimiento.
  Future<void> liberarSesion() async {
    _renovarSesion?.cancel();
    final sesion = _chSesion;
    if (sesion != null && (_dispositivo?.isConnected ?? false)) {
      try {
        await sesion.write(utf8.encode('soltar:$_tokenSesion'), timeout: 2);
      } catch (_) {}
    }
    await desconectar();
  }

  /// Las redes que ve el lector.
  ///
  /// El lector busca redes solo al entrar en modo configuración, así que al
  /// conectarse normalmente ya las tiene (o las está buscando): se leen sin
  /// pedir otra búsqueda. Pedirla mientras buscaba no servía (el lector la
  /// descartaba) y la app se quedaba esperando hasta agotar el tiempo y
  /// reintentar, una y otra vez. [buscarDeNuevo] ("Buscar de nuevo") sí pide
  /// una búsqueda nueva.
  Future<List<RedWifi>> leerRedes({bool buscarDeNuevo = false}) async {
    await asegurarConexion();
    return _conReintento(() async {
      final actual = await _leerEstado();
      if (actual.fase == FaseConfig.buscandoRedes) {
        await _esperarFinDeBusqueda();
      } else if (buscarDeNuevo) {
        await _pedirBusqueda();
      }

      var redes = await _leerListaDeRedes();
      // Sin nada guardado todavía (o la búsqueda no vio redes): una más.
      if (redes.isEmpty && !buscarDeNuevo) {
        await _pedirBusqueda();
        redes = await _leerListaDeRedes();
      }
      return redes;
    });
  }

  Future<EstadoConfig> _leerEstado() async {
    final bytes = await _chEstado!.read(timeout: 5);
    return EstadoConfig.parse(utf8.decode(bytes, allowMalformed: true));
  }

  /// La búsqueda de redes del lector tarda ~3-5 s.
  Future<void> _esperarFinDeBusqueda({bool ignorarPrimero = false}) =>
      _esperarEstado(
        (e) => e.fase != FaseConfig.buscandoRedes,
        timeout: const Duration(seconds: 20),
        ignorarPrimero: ignorarPrimero,
      );

  Future<void> _pedirBusqueda() async {
    await _escribir(_chOrden, 'escanear');
    await _esperarFinDeBusqueda(ignorarPrimero: true);
  }

  Future<List<RedWifi>> _leerListaDeRedes() async {
    final bytes = await _chRedes!.read(timeout: 10);
    return parsearRedes(utf8.decode(bytes, allowMalformed: true));
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

    if (respuesta != null &&
        respuesta.fase.esFinal &&
        respuesta.fase != FaseConfig.ok &&
        sesionExclusiva) {
      return respuesta;
    }
    // Se suelta el Bluetooth para que el lector pruebe el WiFi sin él.
    await desconectar();

    if (respuesta != null && respuesta.fase.esFinal) return respuesta;
    return null;
  }

  /// Espera el resultado del intento después de [enviarWifi].
  ///
  /// Si el lector falla, vuelve a anunciarse por Bluetooth: se reconecta y
  /// se lee el error. Si lo logra, apaga Bluetooth y no vuelve a
  /// aparecer aquí: eso lo detecta quien lo busque en la red. Por eso esto
  /// devuelve null si llega [hasta] o [cancelado] sin saber nada.
  Future<EstadoConfig?> esperarResultado({
    required DateTime hasta,
    required bool Function() cancelado,
  }) async {
    final d = _dispositivo;
    if (d == null) return null;

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
      } on LectorOcupadoException {
        return const EstadoConfig(FaseConfig.ocupado);
      } catch (_) {
        // No se anunció todavía (sigue probando, o ya se conectó y reinició).
      }
      if (cancelado()) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// Suelta el Bluetooth (se recuerda cuál es el lector, para volver a
  /// conectarse con [asegurarConexion]).
  ///
  /// Al probar WiFi se suelta el enlace, conservando la reserva. Al salir
  /// del asistente se usa [liberarSesion], que también libera esa reserva.
  Future<void> desconectar() async {
    _renovarSesion?.cancel();
    try {
      // Cancela una reconexión pendiente; en la cola podía esperar hasta
      // 15 s aunque la búsqueda por WiFi ya hubiera confirmado el lector.
      await _dispositivo?.disconnect(queue: false, timeout: 3);
    } catch (_) {}
    _chRedes = _chSsid = _chClave = _chGym = _chOrden = _chEstado = null;
    _chSesion = null;
  }

  // ─────────────────────────────────────────────────────────

  Future<void> _escribir(CaracteristicaLectorBle? c, String valor) async {
    if (c == null) throw const LectorBleException('No hay lector conectado.');
    await c.write(utf8.encode(valor), allowLongWrite: true, timeout: 10);
  }

  /// Ejecuta [accion]; si falla porque se cayó la conexión, reconecta una
  /// vez y la repite.
  Future<T> _conReintento<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on LectorOcupadoException {
      rethrow;
    } on LectorBleException {
      rethrow;
    } catch (e) {
      AppLogger.warning('LectorBleService', 'Reintentando tras: $e');
      await _conectarDispositivo();
      try {
        return await accion();
      } catch (e) {
        if (e is LectorBleException) rethrow;
        throw LectorBleException(
            'Se perdió la conexión con el lector. Acerca el ${PlataformaApp.equipo} y '
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

/// Pasa a mayúscula la primera letra de un texto que empieza una oración
/// ("el teléfono" → "El teléfono").
abstract final class _Frase {
  static String mayuscula(String texto) =>
      texto[0].toUpperCase() + texto.substring(1);
}

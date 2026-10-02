import 'package:gymads/app/core/utils/plataforma_app.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/config/rfid_config.dart';
import '../../../data/services/lector_ble_service.dart';
import '../../../data/services/lector_red_service.dart';
import '../../../data/services/espera_configuracion_lector.dart';
import '../../../data/services/estado_configuracion_lector.dart';
import '../../../data/services/registro_busqueda_lector.dart';
import 'configuracion_controller.dart';

/// Los pasos del asistente, en orden.
enum PasoAgregar {
  /// Buscando lectores por Bluetooth.
  buscando,

  /// Conectado al lector, pidiéndole las redes que ve.
  preparando,

  /// La persona toca la red WiFi del gimnasio en la lista.
  elegirRed,

  /// Ya eligió la red: escribe la contraseña (o el nombre, con "Otra red").
  escribirClave,

  /// El lector está probando el WiFi, con el Bluetooth en pausa. Se espera
  /// el resultado: en la red si funcionó, por Bluetooth si falló.
  conectando,

  /// El lector dijo que sí: se le busca en la red para confirmarlo.
  comprobando,

  listo,

  /// Algo impide seguir (sin Bluetooth, no apareció ningún lector...).
  fallo,
}

/// Asistente para agregar un lector, o cambiarle el WiFi, sin tocar IPs.
///
/// Por Bluetooth le manda el WiFi y el gimnasio; el lector se conecta, se
/// apaga el Bluetooth y a partir de ahí trabaja por WiFi.
class AgregarLectorController extends GetxController {
  AgregarLectorController({LectorBleService? ble})
      : _ble = ble ?? LectorBleService();

  final LectorBleService _ble;

  final paso = PasoAgregar.buscando.obs;
  final lectores = <LectorCercano>[].obs;
  final redes = <RedWifi>[].obs;

  /// El nombre de la red elegida. No se preselecciona ninguna: en un edificio
  /// con muchas redes, la de mejor señal no siempre es la del gimnasio, y con
  /// la contraseña de otra el módem la rechaza.
  final redElegida = RxnString();
  final usarOtraRed = false.obs;
  final mostrarClave = false.obs;

  /// "Buscar de nuevo" en marcha: el lector tarda unos segundos en escanear.
  final buscandoRedes = false.obs;

  /// Separa el envío de los datos de la espera real de respuesta.
  final esperandoRespuesta = false.obs;
  final guardandoLector = false.obs;
  final avisoFinal = RxnString();
  final lectorOcupado = false.obs;
  final falloAlBuscar = false.obs;

  /// Mensaje para la persona en el paso actual. Null si todo va bien.
  final mensaje = RxnString();

  final claveCtrl = TextEditingController();
  final otraRedCtrl = TextEditingController();

  LectorCercano? _lector;
  StreamSubscription<List<LectorCercano>>? _busqueda;
  Timer? _reintentoBusqueda;
  int _generacionBusqueda = 0;
  bool _iniciandoBusqueda = false;
  bool _cerrado = false;
  Completer<void>? _cancelarRed;

  String? get nombreLector => _lector?.nombre;

  /// El último paso antes de [PasoAgregar.fallo]: la animación marca en rojo
  /// el Bluetooth o el WiFi según dónde se cayó.
  PasoAgregar? pasoAntesDelFallo;

  @override
  void onInit() {
    super.onInit();
    ever<PasoAgregar>(paso, (p) {
      if (p != PasoAgregar.fallo) pasoAntesDelFallo = p;
    });
  }

  @override
  void onReady() {
    super.onReady();
    buscar();
  }

  @override
  void onClose() {
    _cerrado = true;
    _generacionBusqueda++;
    _reintentoBusqueda?.cancel();
    if (_cancelarRed?.isCompleted == false) _cancelarRed!.complete();
    _busqueda?.cancel();
    _ble.detenerBusqueda();
    unawaited(_ble.liberarSesion());
    claveCtrl.dispose();
    otraRedCtrl.dispose();
    super.onClose();
  }

  /// Paso 1: encontrar el lector por Bluetooth.
  Future<void> buscar() async {
    if (_cerrado || _iniciandoBusqueda) return;
    _iniciandoBusqueda = true;
    final generacion = ++_generacionBusqueda;
    _reintentoBusqueda?.cancel();
    try {
      await _busqueda?.cancel();
      await _ble.detenerBusqueda();
      await _ble.liberarSesion();
      if (_cerrado || generacion != _generacionBusqueda) return;
      _lector = null;
      lectores.clear();
      mensaje.value = null;
      lectorOcupado.value = false;
      falloAlBuscar.value = false;
      paso.value = PasoAgregar.buscando;
      _escucharBusqueda(generacion, reintento: false);
    } finally {
      _iniciandoBusqueda = false;
    }
  }

  void _escucharBusqueda(int generacion, {required bool reintento}) {
    bool vigente() => !_cerrado && generacion == _generacionBusqueda;
    _busqueda = _ble.buscar().listen(
      (encontrados) {
        if (!vigente()) return;
        mensaje.value = null;
        lectores.assignAll(encontrados);
        // Lo normal es un solo lector: se toma el primero que aparece, sin
        // hacer elegir. Si hay varios, la pantalla deja escoger.
        if (_lector == null && encontrados.length == 1) {
          elegirLector(encontrados.first);
        }
      },
      onError: (Object e) {
        if (!vigente()) return;
        if (!reintento && e is FalloBusquedaBle && e.reintentable) {
          mensaje.value = 'El Bluetooth del ${PlataformaApp.equipo} no respondió. '
              'Intentando una vez más…';
          unawaited(_ble.registroBusqueda.registrar(
              EventoBusquedaLector.reintento,
              categoria: e.tipo.name));
          _reintentoBusqueda = Timer(const Duration(milliseconds: 700), () {
            if (vigente() && paso.value == PasoAgregar.buscando) {
              _escucharBusqueda(generacion, reintento: true);
            }
          });
          return;
        }
        mensaje.value = e is LectorBleException
            ? e.mensaje
            : 'No se pudo buscar por Bluetooth. Apágalo, espera 5 segundos '
                'y vuelve a encenderlo antes de intentar de nuevo.';
        falloAlBuscar.value = true;
        paso.value = PasoAgregar.fallo;
      },
      onDone: () {
        if (!vigente()) return;
        if (_lector == null && paso.value == PasoAgregar.buscando) {
          if (lectores.isEmpty) {
            mensaje.value = 'No apareció ningún lector. Revisa que esté '
                'conectado a la corriente y que su luz parpadee rápido. '
                'Si otro dispositivo lo está configurando, espera a que termine. '
                'Si sigue sin aparecer, apaga el Bluetooth del ${PlataformaApp.equipo}, '
                'espera 5 segundos y vuelve a encenderlo.';
            falloAlBuscar.value = true;
            paso.value = PasoAgregar.fallo;
          }
          // Con varios, se quedan en pantalla para elegir.
        }
      },
      cancelOnError: true,
    );
  }

  Future<bool> copiarDiagnosticoBusqueda() async {
    try {
      final texto = await _ble.registroBusqueda.exportar();
      await Clipboard.setData(ClipboardData(text: texto));
      return true;
    } catch (e) {
      AppLogger.error('AgregarLectorController', 'Al copiar diagnóstico', e);
      return false;
    }
  }

  /// Paso 2: conectarse al lector y pedirle las redes que ve.
  Future<void> elegirLector(LectorCercano lector) async {
    if (_cerrado ||
        paso.value == PasoAgregar.preparando ||
        paso.value == PasoAgregar.conectando ||
        paso.value == PasoAgregar.comprobando) {
      return;
    }
    final generacion = _generacionBusqueda;
    bool vigente() => !_cerrado && generacion == _generacionBusqueda;
    _lector = lector;
    mensaje.value = null;
    lectorOcupado.value = false;
    paso.value = PasoAgregar.preparando;
    await _busqueda?.cancel();
    if (!vigente()) return;

    try {
      if (lector.ocupado) throw const LectorOcupadoException();
      await _ble.conectar(lector);
      if (!vigente()) return;
      await cargarRedes();
      if (!vigente()) return;
      paso.value = PasoAgregar.elegirRed;
    } on LectorOcupadoException {
      if (!vigente()) return;
      _mostrarOcupado();
    } on LectorBleException catch (e) {
      if (!vigente()) return;
      mensaje.value = e.mensaje;
      paso.value = PasoAgregar.fallo;
    } catch (e) {
      if (!vigente()) return;
      AppLogger.error('AgregarLectorController', 'Al preparar el lector', e);
      mensaje.value = 'No se pudo hablar con el lector. Acerca el ${PlataformaApp.equipo} y '
          'reintenta.';
      paso.value = PasoAgregar.fallo;
    } finally {
      // El firmware nuevo anuncia «ocupado» y conserva la sesión mientras
      // se escribe. Con el anterior se sigue soltando como antes.
      if (!vigente()) {
        await _ble.liberarSesion();
      } else if (!_ble.sesionExclusiva || paso.value == PasoAgregar.fallo) {
        await _ble.desconectar();
      }
    }
  }

  /// Lee las redes que ve el lector. [buscarDeNuevo] le pide otra búsqueda.
  Future<void> cargarRedes({bool buscarDeNuevo = false}) async {
    final generacion = _generacionBusqueda;
    final vistas = await _ble.leerRedes(buscarDeNuevo: buscarDeNuevo);
    if (_cerrado || generacion != _generacionBusqueda) return;
    redes.assignAll(vistas);
  }

  /// Tocó una red de la lista: pasa a escribir su contraseña.
  ///
  /// Una red que el lector no puede usar (pide usuario, o WEP) no avanza: se
  /// explica ahí mismo, en la lista.
  void elegirRed(RedWifi red) {
    if (!red.compatible) {
      mensaje.value = red.seguridad == SeguridadRed.empresarial
          ? '"${red.ssid}" pide usuario y contraseña (red de empresa o '
              'escuela). El lector no puede usarla: elige otra red.'
          : '"${red.ssid}" usa una seguridad antigua (WEP) que el lector no '
              'admite. Elige otra red o cambia la seguridad del módem a WPA2.';
      return;
    }
    redElegida.value = red.ssid;
    usarOtraRed.value = false;
    claveCtrl.clear();
    mostrarClave.value = false;
    mensaje.value = null;
    paso.value = PasoAgregar.escribirClave;
  }

  /// La red no está en la lista (oculta, o no se alcanzó a ver): se escribe
  /// su nombre a mano.
  void elegirOtraRed() {
    redElegida.value = null;
    usarOtraRed.value = true;
    otraRedCtrl.clear();
    claveCtrl.clear();
    mostrarClave.value = false;
    mensaje.value = null;
    paso.value = PasoAgregar.escribirClave;
  }

  /// "Cambiar de red": de vuelta a la lista, sin elegir ninguna.
  void volverARedes() {
    redElegida.value = null;
    usarOtraRed.value = false;
    claveCtrl.clear();
    mensaje.value = null;
    paso.value = PasoAgregar.elegirRed;
  }

  /// La red elegida de la lista (null con "Otra red").
  RedWifi? get redSeleccionada {
    if (usarOtraRed.value) return null;
    final ssid = redElegida.value;
    return redes.firstWhereOrNull((r) => r.ssid == ssid);
  }

  /// Las redes abiertas no llevan contraseña.
  bool get pideClave => redSeleccionada?.pideClave ?? true;

  Future<void> actualizarRedes() async {
    if (buscandoRedes.value) return;
    buscandoRedes.value = true;
    mensaje.value = null;
    try {
      await cargarRedes(buscarDeNuevo: true);
    } on LectorOcupadoException {
      _mostrarOcupado();
    } on LectorBleException catch (e) {
      mensaje.value = e.mensaje;
    } catch (_) {
      mensaje.value = 'No se pudieron buscar las redes. Acerca el ${PlataformaApp.equipo} al '
          'lector y vuelve a intentar.';
    } finally {
      if (!_ble.sesionExclusiva) await _ble.desconectar();
      buscandoRedes.value = false;
    }
  }

  /// El nombre tal cual: algunos módems traen espacios al final, y quitarlos
  /// haría que el lector no la encontrara. Solo el escrito a mano se limpia.
  String get _ssid =>
      usarOtraRed.value ? otraRedCtrl.text.trim() : (redElegida.value ?? '');

  bool get puedeConectar =>
      _ssid.isNotEmpty && (redSeleccionada?.compatible ?? true);

  /// Paso 3: mandar el WiFi y esperar a que el lector conecte.
  ///
  /// El lector prueba el WiFi con el Bluetooth en pausa (comparten antena, y
  /// con el teléfono conectado la negociación de la contraseña fallaba). Así
  /// que se manda la orden, se suelta el Bluetooth y se espera por dos
  /// lados a la vez: si funcionó, el lector aparece en la red; si falló,
  /// vuelve a anunciarse por Bluetooth y se lee el motivo.
  Future<void> conectar() async {
    if (paso.value == PasoAgregar.conectando ||
        paso.value == PasoAgregar.comprobando) {
      return;
    }
    final gymId = RfidConfig.gymIdActual();
    if (gymId == null || gymId.isEmpty) {
      mensaje.value = 'No hay un gimnasio en esta sesión.';
      return;
    }
    if (!puedeConectar) {
      mensaje.value = usarOtraRed.value
          ? 'Escribe el nombre de la red.'
          : 'Elige la red WiFi del gimnasio.';
      return;
    }

    mensaje.value = null;
    avisoFinal.value = null;
    esperandoRespuesta.value = false;
    guardandoLector.value = false;
    paso.value = PasoAgregar.conectando;

    EstadoConfig? rechazo;
    try {
      rechazo = await _ble.enviarWifi(
        ssid: _ssid,
        clave: pideClave ? claveCtrl.text : '',
        gymId: gymId,
      );
    } on LectorOcupadoException {
      _mostrarOcupado();
      return;
    } on LectorBleException catch (e) {
      await _ble.desconectar();
      mensaje.value = e.mensaje;
      paso.value = PasoAgregar.escribirClave;
      return;
    }

    // Rechazado al instante (datos incompletos, es de otro gimnasio).
    if (rechazo != null) {
      _mostrarFallo(rechazo.fase);
      return;
    }

    if (isClosed) return;
    esperandoRespuesta.value = true;
    final resultado = await _esperarResultado(gymId, _ssid);
    // Con reserva se conserva la sesión si hay que corregir la contraseña.
    if (resultado is! EstadoConfig ||
        resultado.fase == FaseConfig.ok ||
        !_ble.sesionExclusiva) {
      await _ble.desconectar();
    }
    if (isClosed || RfidConfig.gymIdActual() != gymId) return;

    if (resultado is LectorEnRed) {
      await _terminar(resultado);
    } else if (resultado is EstadoConfig) {
      if (resultado.fase == FaseConfig.ok) {
        await _comprobarEnRed(resultado.ip);
      } else {
        _mostrarFallo(resultado.fase);
      }
    } else {
      mensaje.value = 'No se pudo confirmar si el lector se conectó. Revisa '
          'que este ${PlataformaApp.equipo} esté en el mismo WiFi que elegiste y busca el '
          'lector desde la pantalla anterior.';
      paso.value = PasoAgregar.fallo;
    }
  }

  /// Espera lo que llegue primero: el lector en la red (funcionó) o su
  /// respuesta por Bluetooth (falló). Null si no se supo nada a tiempo.
  ///
  /// En la red solo cuenta si aparece conectado a [ssid]: al cambiarle el
  /// WiFi, si la red nueva falla vuelve a la anterior, y encontrarlo ahí no
  /// significa que el cambio funcionó.
  Future<Object?> _esperarResultado(String gymId, String ssid) async {
    // El lector tarda hasta ~30 s en probar, más ~10 s en reiniciarse y
    // conectarse si funcionó.
    final hasta = DateTime.now().add(const Duration(seconds: 75));
    var cancelado = false;
    final cancelarRed = _cancelarRed = Completer<void>();
    final red = RfidConfig.servicioRed(gymId);

    final ganador = Completer<Object?>();
    void llegar(Object? valor) {
      if (valor != null && !ganador.isCompleted) ganador.complete(valor);
    }

    final futuros = [
      esperarLectorConfigurado(
        red: red,
        ssid: ssid,
        nombre: nombreLector,
        ip: RfidConfig.getCurrentIP(),
        seguir: () => !isClosed && !cancelado,
        cancelar: cancelarRed.future,
      ).then(llegar),
      _ble
          .esperarResultado(
              hasta: hasta, cancelado: () => cancelado || isClosed)
          .then(llegar),
    ];
    unawaited(Future.wait(futuros).then((_) {
      if (!ganador.isCompleted) ganador.complete(null);
    }));

    final resultado = await ganador.future;
    cancelado = true;
    if (!cancelarRed.isCompleted) cancelarRed.complete();
    _cancelarRed = null;
    return resultado;
  }

  /// Tras un intento fallido se vuelve a la contraseña con la misma red
  /// elegida, para corregirla sin tener que buscarla otra vez en la lista.
  void _mostrarFallo(FaseConfig fase) {
    switch (fase) {
      case FaseConfig.ocupado:
        _mostrarOcupado();
      case FaseConfig.errorClave:
        mensaje.value = 'El módem rechazó la contraseña. Revisa mayúsculas, '
            'minúsculas y números, y que sea la de la red elegida.';
        paso.value = PasoAgregar.escribirClave;
      case FaseConfig.errorSinRed:
        mensaje.value = 'El lector no alcanza esa red. Acércalo al módem o '
            'revisa que el nombre esté bien escrito.';
        paso.value = PasoAgregar.escribirClave;
      case FaseConfig.errorSinIp:
        mensaje.value = 'La contraseña es correcta, pero el módem no le dio '
            'dirección al lector. Reinicia el módem y vuelve a intentar.';
        paso.value = PasoAgregar.escribirClave;
      case FaseConfig.errorSeguridad:
        mensaje.value = 'Esa red usa una seguridad que el lector no admite '
            '(por ejemplo, con usuario y contraseña). Usa otra red del '
            'gimnasio.';
        // Esa red no sirve: de vuelta a la lista.
        redElegida.value = null;
        paso.value = PasoAgregar.elegirRed;
      case FaseConfig.errorNoConecta:
        mensaje.value = 'El lector no logró conectarse a esa red. Acércalo '
            'al módem y vuelve a intentar.';
        paso.value = PasoAgregar.escribirClave;
      case FaseConfig.errorOtroGimnasio:
        mensaje.value = 'Este lector pertenece a otro gimnasio. Su dueño '
            'tiene que liberarlo, o hay que reiniciarlo de fábrica con el '
            'botón BOOT.';
        paso.value = PasoAgregar.fallo;
      default:
        mensaje.value = 'El lector no recibió bien los datos. Vuelve a '
            'intentar.';
        paso.value = PasoAgregar.escribirClave;
    }
  }

  /// Paso 4: el lector dijo "ok" pero todavía no se le encontró en la red
  /// (se está reiniciando). Se le busca ahí para confirmarlo.
  Future<void> _comprobarEnRed(String? ip) async {
    paso.value = PasoAgregar.comprobando;
    await _ble.desconectar();

    final gymId = RfidConfig.gymIdActual();
    if (gymId == null) return;
    final cancelarRed = _cancelarRed = Completer<void>();
    final lector = await esperarLectorConfigurado(
      red: RfidConfig.servicioRed(gymId),
      ssid: _ssid,
      nombre: nombreLector,
      ip: ip,
      seguir: () => !isClosed,
      cancelar: cancelarRed.future,
      limite: const Duration(seconds: 35),
    );
    _cancelarRed = null;
    if (isClosed || RfidConfig.gymIdActual() != gymId) return;

    if (lector != null) {
      await _terminar(lector);
      return;
    }

    mensaje.value = 'El lector se conectó, pero no aparece en la red de este '
        '${PlataformaApp.equipo}. Revisa que el ${PlataformaApp.equipo} esté en el mismo WiFi.';
    paso.value = PasoAgregar.fallo;
  }

  void _mostrarOcupado() {
    lectorOcupado.value = true;
    mensaje.value = mensajeLectorOcupado;
    paso.value = PasoAgregar.fallo;
    unawaited(_ble.desconectar());
  }

  Future<void> _terminar(LectorEnRed lector) async {
    if (isClosed) return;
    final gymId = RfidConfig.gymIdActual();
    if (gymId == null) return;
    paso.value = PasoAgregar.comprobando;
    guardandoLector.value = true;
    try {
      if (Get.isRegistered<ConfiguracionController>()) {
        await Get.find<ConfiguracionController>().lectorAgregado(lector);
      } else {
        await RfidConfig.guardarLector(lector, esperarRegistro: false);
      }
      if (isClosed) return;
      if (RfidConfig.gymIdActual() != gymId) return;
      final confirmacion = await RfidConfig.servicioRed(gymId)
          .confirmarConfiguracion(lector,
              intento: const Uuid().v4(), sesion: _ble.tokenSesion);
      if (isClosed || RfidConfig.gymIdActual() != gymId) return;
      avisoFinal.value = switch (confirmacion) {
        ConfirmacionLector.confirmada => null,
        ConfirmacionLector.sinSoporte =>
          'El lector quedó configurado. Actualiza el lector para escuchar '
              'el aviso al terminar.',
        ConfirmacionLector.sinRespuesta =>
          'El lector quedó configurado, pero no confirmó el aviso sonoro. '
              'Puedes comprobarlo con «Probar lector».',
      };
      paso.value = PasoAgregar.listo;
    } catch (e) {
      AppLogger.error('AgregarLectorController', 'Al guardar el lector', e);
      if (isClosed) return;
      mensaje.value = 'El lector respondió, pero no se pudo guardar la '
          'configuración. Vuelve a intentar.';
      paso.value = PasoAgregar.fallo;
    } finally {
      guardandoLector.value = false;
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/config/rfid_config.dart';
import '../../../data/services/lector_ble_service.dart';
import '../../../data/services/lector_red_service.dart';
import '../../../data/services/tenant_context_service.dart';
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
/// reinicia con el Bluetooth apagado y a partir de ahí trabaja por WiFi.
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

  /// Mensaje para la persona en el paso actual. Null si todo va bien.
  final mensaje = RxnString();

  final claveCtrl = TextEditingController();
  final otraRedCtrl = TextEditingController();

  LectorCercano? _lector;
  StreamSubscription<List<LectorCercano>>? _busqueda;

  String? get nombreLector => _lector?.nombre;

  @override
  void onReady() {
    super.onReady();
    buscar();
  }

  @override
  void onClose() {
    _busqueda?.cancel();
    _ble.detenerBusqueda();
    _ble.desconectar();
    claveCtrl.dispose();
    otraRedCtrl.dispose();
    super.onClose();
  }

  /// Paso 1: encontrar el lector por Bluetooth.
  Future<void> buscar() async {
    await _busqueda?.cancel();
    await _ble.desconectar();
    _lector = null;
    lectores.clear();
    mensaje.value = null;
    paso.value = PasoAgregar.buscando;

    _busqueda = _ble.buscar().listen(
      (encontrados) {
        lectores.assignAll(encontrados);
        // Lo normal es un solo lector: se toma el primero que aparece, sin
        // hacer elegir. Si hay varios, la pantalla deja escoger.
        if (_lector == null && encontrados.length == 1) {
          elegirLector(encontrados.first);
        }
      },
      onError: (Object e) {
        mensaje.value = e is LectorBleException
            ? e.mensaje
            : 'No se pudo buscar por Bluetooth.';
        paso.value = PasoAgregar.fallo;
      },
      onDone: () {
        if (_lector == null && paso.value == PasoAgregar.buscando) {
          if (lectores.isEmpty) {
            mensaje.value = 'No apareció ningún lector. Revisa que esté '
                'conectado a la corriente y que su luz parpadee rápido.';
            paso.value = PasoAgregar.fallo;
          }
          // Con varios, se quedan en pantalla para elegir.
        }
      },
      cancelOnError: true,
    );
  }

  /// Paso 2: conectarse al lector y pedirle las redes que ve.
  Future<void> elegirLector(LectorCercano lector) async {
    _lector = lector;
    await _busqueda?.cancel();
    mensaje.value = null;
    paso.value = PasoAgregar.preparando;

    try {
      await _ble.conectar(lector);
      await cargarRedes();
      paso.value = PasoAgregar.elegirRed;
    } on LectorBleException catch (e) {
      mensaje.value = e.mensaje;
      paso.value = PasoAgregar.fallo;
    } catch (e) {
      AppLogger.error('AgregarLectorController', 'Al preparar el lector', e);
      mensaje.value = 'No se pudo hablar con el lector. Acerca el teléfono y '
          'reintenta.';
      paso.value = PasoAgregar.fallo;
    }
  }

  Future<void> cargarRedes() async {
    final vistas = await _ble.leerRedes();
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
      await cargarRedes();
    } on LectorBleException catch (e) {
      mensaje.value = e.mensaje;
    } catch (_) {
      mensaje.value = 'No se pudieron buscar las redes. Acerca el teléfono al '
          'lector y vuelve a intentar.';
    } finally {
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
    final gymId = TenantContextService.to.currentGymId;
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
    paso.value = PasoAgregar.conectando;

    EstadoConfig? rechazo;
    try {
      rechazo = await _ble.enviarWifi(
        ssid: _ssid,
        clave: pideClave ? claveCtrl.text : '',
        gymId: gymId,
      );
    } on LectorBleException catch (e) {
      mensaje.value = e.mensaje;
      paso.value = PasoAgregar.escribirClave;
      return;
    }

    // Rechazado al instante (datos incompletos, es de otro gimnasio).
    if (rechazo != null) {
      _mostrarFallo(rechazo.fase);
      return;
    }

    final resultado = await _esperarResultado(gymId, _ssid);
    if (isClosed) return;

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
          'que este teléfono esté en el mismo WiFi que elegiste y busca el '
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
    final red = LectorRedService(gymId: gymId);

    Future<LectorEnRed?> porRed() async {
      await Future<void>.delayed(const Duration(seconds: 8));
      while (!cancelado && DateTime.now().isBefore(hasta)) {
        final lector =
            await red.buscarMio(tiempoMdns: const Duration(seconds: 3));
        if (lector != null && (lector.ssid == null || lector.ssid == ssid)) {
          return lector;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      return null;
    }

    final ganador = Completer<Object?>();
    void llegar(Object? valor) {
      if (valor != null && !ganador.isCompleted) ganador.complete(valor);
    }

    final futuros = [
      porRed().then(llegar),
      _ble
          .esperarResultado(hasta: hasta, cancelado: () => cancelado)
          .then(llegar),
    ];
    unawaited(Future.wait(futuros).then((_) {
      if (!ganador.isCompleted) ganador.complete(null);
    }));

    final resultado = await ganador.future;
    cancelado = true;
    return resultado;
  }

  /// Tras un intento fallido se vuelve a la contraseña con la misma red
  /// elegida, para corregirla sin tener que buscarla otra vez en la lista.
  void _mostrarFallo(FaseConfig fase) {
    switch (fase) {
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

    final red = LectorRedService(gymId: TenantContextService.to.currentGymId);
    LectorEnRed? lector;

    // Tarda ~5-10 s en reiniciar y conectarse.
    final limite = DateTime.now().add(const Duration(seconds: 35));
    while (lector == null && DateTime.now().isBefore(limite)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (isClosed) return;
      if (ip != null) {
        final l = await red.consultar(ip);
        if (l != null && l.mine) lector = l;
      }
    }

    // Sin IP, o el router le dio otra: se barre la red.
    lector ??= await red.buscarMio();
    if (isClosed) return;

    if (lector != null) {
      await _terminar(lector);
      return;
    }

    mensaje.value = 'El lector se conectó, pero no aparece en la red de este '
        'teléfono. Revisa que el teléfono esté en el mismo WiFi.';
    paso.value = PasoAgregar.fallo;
  }

  Future<void> _terminar(LectorEnRed lector) async {
    if (Get.isRegistered<ConfiguracionController>()) {
      await Get.find<ConfiguracionController>().lectorAgregado(lector);
    } else {
      await RfidConfig.guardarLector(lector);
    }
    paso.value = PasoAgregar.listo;
  }
}

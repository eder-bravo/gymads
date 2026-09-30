import 'dart:async';

import 'lector_red_service.dart';

/// Busca desde el primer momento, consultando la IP conocida a la vez que
/// descubre por mDNS/subred. Solo confirma la red elegida y el lector ya
/// trabajando normal; no acepta la red anterior. Firmware 6.7+ conserva
/// WiFi al apagar BLE, sin tener que reiniciar y volver a conectar.
Future<LectorEnRed?> esperarLectorConfigurado({
  required LectorRedService red,
  required String ssid,
  String? nombre,
  String? ip,
  required bool Function() seguir,
  Future<void>? cancelar,
  Duration limite = const Duration(seconds: 75),
}) async {
  if (!seguir()) return null;
  final resultado = Completer<LectorEnRed?>();
  bool buscando() => seguir() && !resultado.isCompleted;
  bool valido(LectorEnRed lector) =>
      lector.mine &&
      !lector.modoConfig &&
      (lector.ssid == null || lector.ssid == ssid) &&
      (nombre == null || lector.id == null || lector.nombre == nombre);
  void recibir(LectorEnRed? lector) {
    if (buscando() && lector != null && valido(lector)) {
      resultado.complete(lector);
    }
  }

  final reloj = Timer(limite, () {
    if (!resultado.isCompleted) resultado.complete(null);
  });
  cancelar?.then((_) {
    if (!resultado.isCompleted) resultado.complete(null);
  });

  Future<void> porIp() async {
    if (ip == null) return;
    while (buscando()) {
      recibir(
          await red.consultar(ip, timeout: const Duration(milliseconds: 800)));
      if (buscando()) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> descubrir() async {
    while (buscando()) {
      recibir(await red.buscarMio(
        tiempoMdns: const Duration(milliseconds: 800),
        aceptar: valido,
      ));
      if (buscando()) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  unawaited(Future.wait([porIp(), descubrir()]).then((_) {
    if (!resultado.isCompleted) resultado.complete(null);
  }, onError: (Object _, StackTrace __) {
    if (!resultado.isCompleted) resultado.complete(null);
  }));
  try {
    return await resultado.future;
  } finally {
    reloj.cancel();
  }
}

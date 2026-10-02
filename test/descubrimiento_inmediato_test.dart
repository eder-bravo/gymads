import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _lector = LectorEnRed(ip: '192.168.0.80', mine: true);

class _Red extends LectorRedService {
  _Red({required this.mdns, this.porBarrido = false})
      : super(
          gymId: 'gym-1',
          cliente: MockClient((r) async => http.Response(
              json.encode({
                'device_type': 'RFID_READER',
                'mine': r.url.host == _lector.ip,
              }),
              200)),
        );

  final String? mdns;
  final bool porBarrido;
  final barridoPendiente = Completer<LectorEnRed?>();
  bool mdnsCancelado = false;

  @override
  Future<List<String>> ipsPorMdns({
    Duration tiempo = const Duration(seconds: 4),
    void Function(String ip)? alEncontrar,
    Future<void>? cancelar,
  }) async {
    if (mdns != null) alEncontrar?.call(mdns!);
    await cancelar;
    mdnsCancelado = true;
    return [];
  }

  @override
  Future<LectorEnRed?> barrerSubred({
    bool Function(LectorEnRed)? parar,
    void Function(LectorEnRed)? alEncontrar,
    List<String>? ips,
    int concurrencia = 32,
    Duration timeoutPorIp = const Duration(milliseconds: 900),
  }) async {
    if (porBarrido) return _lector;
    return await barridoPendiente.future;
  }
}

void main() {
  test(
      'confirma al resolver mDNS, sin esperar el tiempo de búsqueda ni barrido',
      () async {
    final red = _Red(mdns: _lector.ip);
    final lector = await red
        .buscarMio(tiempoMdns: const Duration(seconds: 30))
        .timeout(const Duration(seconds: 1));
    expect(lector?.ip, _lector.ip);
    red.barridoPendiente.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(red.mdnsCancelado, isTrue);
  });

  test('el barrido no espera a que mDNS responda', () async {
    final red = _Red(mdns: null, porBarrido: true);
    final lector = await red
        .buscarMio(tiempoMdns: const Duration(seconds: 30))
        .timeout(const Duration(seconds: 1));
    expect(lector?.ip, _lector.ip);
    await Future<void>.delayed(Duration.zero);
    expect(red.mdnsCancelado, isTrue);
  });

  test('una respuesta de otro gimnasio no gana la búsqueda', () async {
    final red = _Red(mdns: '192.168.0.81', porBarrido: true);
    final lector = await red.buscarMio().timeout(const Duration(seconds: 1));
    expect(lector?.ip, _lector.ip);
  });
}

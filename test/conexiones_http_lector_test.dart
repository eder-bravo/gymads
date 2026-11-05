import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/lector_red_service.dart';
import 'package:http/http.dart' as http;

class _Cliente extends http.BaseClient {
  _Cliente(this.responder);
  final Future<http.StreamedResponse> Function(http.BaseRequest) responder;
  bool cerrado = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      responder(request);
  @override
  void close() {
    cerrado = true;
  }
}

http.StreamedResponse _respuesta(int codigo) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode({
      'device_id': 'ESP32_RFID_GYMONE',
      'id': '2805A532CD70',
      'claimed': true,
      'mine': true,
      'ok': true,
    }))),
    codigo);

void main() {
  test('un barrido cierra las conexiones vencidas antes de seguir preguntando',
      () async {
    final clientes = <_Cliente>[];
    final pendientes = <Completer<http.StreamedResponse>>[];
    final servicio = LectorRedService(
        gymId: 'gym',
        crearCliente: () {
          expect(clientes.where((c) => !c.cerrado).length, lessThan(2));
          final pendiente = Completer<http.StreamedResponse>();
          pendientes.add(pendiente);
          final cliente = _Cliente((_) => pendiente.future);
          clientes.add(cliente);
          return cliente;
        });
    final encontrados = await servicio.barrerSubred(
      ips: ['10.0.0.1', '10.0.0.2', '10.0.0.3', '10.0.0.4'],
      concurrencia: 2,
      timeoutPorIp: const Duration(milliseconds: 10),
    );
    expect(encontrados, isNull);
    expect(clientes, hasLength(4));
    expect(clientes.every((c) => c.cerrado), isTrue);
    for (final p in pendientes) {
      p.complete(_respuesta(200));
    }
  });

  test('una respuesta correcta también libera su conexión', () async {
    final cliente = _Cliente((_) async => _respuesta(200));
    final servicio =
        LectorRedService(gymId: 'gym', crearCliente: () => cliente);
    final lector = await servicio.consultar('192.168.10.104');
    expect(lector?.mine, isTrue);
    expect(cliente.cerrado, isTrue);
  });

  test('un error de transporte libera la conexión', () async {
    final cliente =
        _Cliente((_) async => throw http.ClientException('sin red'));
    final servicio = LectorRedService(crearCliente: () => cliente);
    expect(await servicio.consultar('192.168.10.104'), isNull);
    expect(cliente.cerrado, isTrue);
  });

  test('confirmar configuración libera la conexión incluso ante un rechazo',
      () async {
    final cliente = _Cliente((_) async => _respuesta(403));
    final servicio = LectorRedService(crearCliente: () => cliente);
    expect(
        await servicio.confirmarConfiguracion(
          const LectorEnRed(ip: '192.168.10.104'),
          intento: 'unico',
        ),
        ConfirmacionLector.sinRespuesta);
    expect(cliente.cerrado, isTrue);
  });

  test('un cliente prestado conserva la propiedad del que lo proporcionó',
      () async {
    final cliente = _Cliente((_) async => _respuesta(200));
    final servicio = LectorRedService(cliente: cliente);
    expect(await servicio.consultar('192.168.10.104'), isNotNull);
    expect(cliente.cerrado, isFalse);
    cliente.close();
  });
}

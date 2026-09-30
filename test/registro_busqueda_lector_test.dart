import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymads/app/data/services/registro_busqueda_lector.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, Object?>> _metadatos() async => {
      'plataforma': 'android',
      'fabricante': 'HUAWEI',
      'modelo': 'nova 8',
      'version': '10',
      'sdk': 29,
    };

RegistroBusquedaLector _registro() => RegistroBusquedaLector(
      obtenerMetadatos: _metadatos,
      ahora: () => DateTime.utc(2026, 9, 30, 18, 20),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persiste eventos y los conserva en una instancia nueva', () async {
    final registro = _registro();
    await registro.registrar(EventoBusquedaLector.inicio);
    await registro.registrar(EventoBusquedaLector.fallo,
        categoria: 'interno', codigo: 3, milisegundos: 1250);

    final preferencias = await SharedPreferences.getInstance();
    expect(
      preferencias.getString(RegistroBusquedaLector.claveAlmacenamiento),
      isNotNull,
    );
    final datos = jsonDecode(await _registro().exportar()) as Map;
    expect(datos['dispositivo'], await _metadatos());
    expect(datos['eventos'], [
      {'fecha': '2026-09-30T18:20:00.000Z', 'evento': 'inicio'},
      {
        'fecha': '2026-09-30T18:20:00.000Z',
        'evento': 'fallo',
        'categoria': 'interno',
        'codigo': 3,
        'milisegundos': 1250,
      },
    ]);
  });

  test('conserva solo los últimos 60 eventos', () async {
    final registro = _registro();
    for (var i = 0; i < 75; i++) {
      await registro.registrar(EventoBusquedaLector.encontrados, lectores: i);
    }
    final datos = jsonDecode(await _registro().exportar()) as Map;
    final eventos = datos['eventos'] as List;
    expect(eventos, hasLength(RegistroBusquedaLector.maxEventos));
    expect(eventos.first['lectores'], 15);
    expect(eventos.last['lectores'], 74);
  });

  test('serializa escrituras concurrentes sin perder ni reordenar eventos',
      () async {
    final registro = _registro();
    await Future.wait(List.generate(
      40,
      (i) => registro.registrar(EventoBusquedaLector.encontrados, lectores: i),
    ));
    final datos = jsonDecode(await _registro().exportar()) as Map;
    final eventos = datos['eventos'] as List;
    expect(eventos.map((e) => e['lectores']), List.generate(40, (i) => i));
  });

  test('exportar espera las escrituras encoladas', () async {
    final registro = _registro();
    // No se espera registrar, como sucede durante una búsqueda Bluetooth.
    registro.registrar(EventoBusquedaLector.inicio);
    registro.registrar(EventoBusquedaLector.reintento);
    final datos = jsonDecode(await registro.exportar()) as Map;
    expect((datos['eventos'] as List).map((e) => e['evento']),
        ['inicio', 'reintento']);
  });

  test('rechaza categorías y metadatos ajenos a la lista permitida', () async {
    final registro = RegistroBusquedaLector(
        obtenerMetadatos: () async => {
              ...await _metadatos(),
              'mac': 'MAC PRIVADA',
              'ssid': 'RED PRIVADA',
              'serial': 'SERIAL PRIVADO',
              'uid': 'TARJETA PRIVADA',
              'token': 'TOKEN PRIVADO',
            });
    await registro.registrar(EventoBusquedaLector.fallo,
        categoria: 'excepción con SSID PRIVADO',
        lectores: -1,
        milisegundos: -1);
    final exportado = await registro.exportar();
    expect(exportado, isNot(contains('PRIVAD')));
    final datos = jsonDecode(exportado) as Map;
    expect(datos['dispositivo'], await _metadatos());
    final evento = (datos['eventos'] as List).single as Map;
    expect(evento['categoria'], 'desconocido');
    expect(evento.containsKey('lectores'), isFalse);
    expect(evento.containsKey('milisegundos'), isFalse);
  });

  test('un fallo de preferencias o metadatos no falla la búsqueda', () async {
    final registro = RegistroBusquedaLector(
      obtenerPreferencias: () async => throw StateError('almacenamiento'),
      obtenerMetadatos: () async => throw StateError('plugin'),
    );
    await registro.registrar(EventoBusquedaLector.fallo, categoria: 'interno');
    await registro.registrar(EventoBusquedaLector.completada);
    final datos = jsonDecode(await registro.exportar()) as Map;
    expect(datos['dispositivo'], isEmpty);
    expect((datos['eventos'] as List).map((e) => e['evento']),
        ['fallo', 'completada']);
  });

  test('descarta un registro corrupto y vuelve a guardar datos válidos',
      () async {
    SharedPreferences.setMockInitialValues(
        {RegistroBusquedaLector.claveAlmacenamiento: '{json incompleto'});
    final registro = _registro();
    await registro.registrar(EventoBusquedaLector.inicio);
    final datos = jsonDecode(await _registro().exportar()) as Map;
    expect((datos['eventos'] as List).single['evento'], 'inicio');
  });

  test('al restaurar elimina campos desconocidos y categorías crudas',
      () async {
    SharedPreferences.setMockInitialValues({
      RegistroBusquedaLector.claveAlmacenamiento: jsonEncode({
        'version': 1,
        'dispositivo': {'plataforma': 'android', 'serial': 'SERIAL PRIVADO'},
        'eventos': [
          {
            'fecha': '2026-09-30T18:20:00Z',
            'evento': 'fallo',
            'categoria': 'SSID PRIVADO',
            'token': 'TOKEN PRIVADO',
          },
          {'fecha': 'UID PRIVADO', 'evento': 'fallo'},
          {'fecha': '2026-09-30T18:20:00Z', 'evento': 'EVENTO PRIVADO'},
        ],
      }),
    });
    final exportado = await _registro().exportar();
    expect(exportado, isNot(contains('PRIVAD')));
    final datos = jsonDecode(exportado) as Map;
    expect((datos['eventos'] as List), hasLength(1));
    expect((datos['eventos'] as List).single['categoria'], 'desconocido');
  });
}

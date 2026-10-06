import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/plataforma_app.dart';
import 'tema_service.dart';

/// Qué pasó con la tarjeta, dicho para el cliente.
enum TipoAviso { entrada, salida, vencida, noRegistrada }

/// Lo que ve el cliente en la pantalla para clientes cuando pasa su tarjeta.
///
/// Solo información: nunca el número de la tarjeta ni acciones del mostrador.
/// Viaja a la otra ventana como JSON (es otro motor de Flutter, no comparte
/// nada con la ventana principal).
@immutable
class AvisoParaClientes {
  const AvisoParaClientes({
    required this.id,
    required this.tipo,
    this.nombre = '',
    this.fotoUrl,
    this.diasRestantes = 0,
    this.vence,
    this.duracion = const Duration(seconds: 4),
  });

  /// Cambia en cada pase: un pase nuevo reemplaza al anterior.
  final int id;
  final TipoAviso tipo;
  final String nombre;

  /// Enlace ya firmado: la otra ventana no tiene Supabase.
  final String? fotoUrl;
  final int diasRestantes;
  final DateTime? vence;
  final Duration duracion;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'nombre': nombre,
        'fotoUrl': fotoUrl,
        'diasRestantes': diasRestantes,
        'vence': vence?.toIso8601String(),
        'duracionMs': duracion.inMilliseconds,
      };

  factory AvisoParaClientes.fromJson(Map<dynamic, dynamic> json) =>
      AvisoParaClientes(
        id: json['id'] as int? ?? 0,
        tipo: TipoAviso.values.firstWhere((t) => t.name == json['tipo'],
            orElse: () => TipoAviso.entrada),
        nombre: json['nombre'] as String? ?? '',
        fotoUrl: json['fotoUrl'] as String?,
        diasRestantes: json['diasRestantes'] as int? ?? 0,
        vence: DateTime.tryParse(json['vence'] as String? ?? ''),
        duracion: Duration(milliseconds: json['duracionMs'] as int? ?? 4000),
      );
}

/// La ventana para un monitor extra donde el cliente ve su aviso al pasar la
/// tarjeta. Solo en computadora. La abre el botón "Pantalla para clientes"
/// de Inicio; se cierra con su botón de cerrar o al cerrar la app.
abstract final class PantallaClientes {
  /// El argumento con el que arranca esa ventana (ver `main`). Lleva detrás
  /// el modo de la app ("pantalla_clientes:dark"): así abre ya con el tema
  /// claro u oscuro que se ve en la principal.
  static const argumento = 'pantalla_clientes';

  /// Si [argumentos] son los de la pantalla para clientes.
  static bool esSuyo(String argumentos) =>
      argumentos == argumento || argumentos.startsWith('$argumento:');

  /// El modo con que debe arrancar, según sus argumentos.
  static ThemeMode modoDe(String argumentos) {
    final nombre = argumentos.split(':').skip(1).firstOrNull;
    return ThemeMode.values.firstWhere((m) => m.name == nombre,
        orElse: () => ThemeMode.system);
  }

  /// Si está abierta ahora mismo.
  static final abierta = ValueNotifier<bool>(false);

  static WindowController? _ventana;
  static StreamSubscription<void>? _cambios;
  static Worker? _tema;
  static int _siguiente = 0;

  /// Para las pruebas: recibe lo que se mandaría a la ventana.
  @visibleForTesting
  static void Function(String metodo, Object? datos)? enviarPara;

  /// La abre, o la trae al frente si ya estaba abierta.
  static Future<void> abrir() async {
    if (!PlataformaApp.escritorio) return;
    _cambios ??= onWindowsChanged.listen((_) => _actualizar());
    // Si se cambia Apariencia con la ventana abierta, cambia también.
    final tema = TemaService.to;
    _tema ??= ever<ThemeMode>(tema.modo, cambiarModo);
    try {
      final existente = await _buscar();
      if (existente != null) {
        _ventana = existente;
        abierta.value = true;
        await existente.show();
        return;
      }
      final ventana = await WindowController.create(WindowConfiguration(
          arguments: '$argumento:${tema.modo.value.name}',
          hiddenAtLaunch: false));
      _ventana = ventana;
      abierta.value = true;
      await ventana.show();
    } catch (e) {
      AppLogger.error('PantallaClientes', 'No se pudo abrir', e);
    }
  }

  /// Sigue a la ventana: si el usuario la cerró, ya no se le manda nada.
  static Future<void> _actualizar() async {
    final ventana = await _buscar();
    _ventana = ventana;
    abierta.value = ventana != null;
  }

  static Future<WindowController?> _buscar() async {
    for (final ventana in await WindowController.getAll()) {
      if (esSuyo(ventana.arguments)) return ventana;
    }
    return null;
  }

  /// Muestra un pase. Sin la ventana abierta no hace nada.
  static void mostrar({
    required TipoAviso tipo,
    String nombre = '',
    String? fotoUrl,
    int diasRestantes = 0,
    DateTime? vence,
    required Duration duracion,
  }) {
    final aviso = AvisoParaClientes(
      id: ++_siguiente,
      tipo: tipo,
      nombre: nombre,
      fotoUrl: fotoUrl,
      diasRestantes: diasRestantes,
      vence: vence,
      duracion: duracion,
    );
    _enviar('aviso', aviso.toJson());
  }

  /// Claro, oscuro o el de la computadora, como la ventana principal.
  static void cambiarModo(ThemeMode modo) => _enviar('modo', modo.name);

  static void _enviar(String metodo, Object? datos) {
    final prueba = enviarPara;
    if (prueba != null) return prueba(metodo, datos);
    final ventana = _ventana;
    if (ventana == null || !abierta.value) return;
    // Si la ventana aún arranca o se acaba de cerrar, el aviso se pierde:
    // es solo informativo, el del mostrador sí sale.
    unawaited(ventana.invokeMethod<void>(metodo, datos).catchError((Object e) {
      AppLogger.warning('PantallaClientes', 'No llegó el aviso: $e');
    }));
  }
}

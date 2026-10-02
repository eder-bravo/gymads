import 'package:flutter/widgets.dart';

/// Qué pasó al pasar una tarjeta libre por el lector con el formulario
/// abierto.
enum ResultadoPase { asignada, cambiada, misma }

/// Cómo está la tarjeta del formulario respecto a la que tenía el cliente.
enum EstadoTarjeta {
  /// Sin tarjeta, y no tenía.
  vacia,

  /// Alta: ya hay una tarjeta puesta.
  lista,

  /// Alta: se pasó otra distinta a la que estaba puesta.
  cambiada,

  /// Edición: la misma que tenía.
  sinCambio,

  /// Edición: se pasó una distinta a la que tenía.
  nueva,

  /// Edición: tenía una y se quitó.
  quitada,
}

/// La tarjeta del formulario de cliente, para que se vea si cambió.
///
/// No guarda nada propio: lee y escribe el [controlador] de siempre, así el
/// guardado sigue tomando la tarjeta de ahí. Solo recuerda cuál tenía el
/// cliente al abrir ([original]) y si en un alta ya se cambió una vez.
class TarjetaDelFormulario {
  TarjetaDelFormulario(this.controlador, {String? original})
      : original = (original?.isEmpty ?? true) ? null : original;

  final TextEditingController controlador;

  /// La que tenía el cliente al abrir la edición. Null en un alta.
  final String? original;

  bool _cambiadaEnAlta = false;

  String get actual => controlador.text;
  bool get editando => original != null;

  EstadoTarjeta get estado {
    if (editando) {
      if (actual.isEmpty) return EstadoTarjeta.quitada;
      return actual == original ? EstadoTarjeta.sinCambio : EstadoTarjeta.nueva;
    }
    if (actual.isEmpty) return EstadoTarjeta.vacia;
    return _cambiadaEnAlta ? EstadoTarjeta.cambiada : EstadoTarjeta.lista;
  }

  /// Si [uid] es la que el cliente ya tenía (al editar). Pasarla no es la
  /// tarjeta de "otro cliente": es la suya.
  bool esLaOriginal(String uid) => original != null && uid == original;

  /// Pone [uid] como la tarjeta del cliente.
  ResultadoPase pasar(String uid) {
    if (uid == actual) return ResultadoPase.misma;
    final habia = actual.isNotEmpty;
    controlador.text = uid;
    if (!habia) return ResultadoPase.asignada;
    if (!editando) _cambiadaEnAlta = true;
    return ResultadoPase.cambiada;
  }

  void quitar() {
    controlador.clear();
    _cambiadaEnAlta = false;
  }

  /// Vuelve a la que tenía el cliente al abrir.
  void deshacer() => controlador.text = original ?? '';
}

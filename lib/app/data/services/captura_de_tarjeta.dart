import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

/// Recibe un pase del lector y dice si se lo queda. [dueno] es el cliente que
/// ya tiene esa tarjeta, o null si está libre.
typedef CapturadorTarjeta = bool Function(String uid, UserModel? dueno);

/// Quién recibe las tarjetas del lector mientras se registra o edita un
/// cliente.
///
/// El servicio de entradas sigue escuchando el lector con el formulario
/// abierto (antes se pausaba y un cliente que entraba en ese momento no
/// quedaba registrado). Antes de procesar un pase se lo ofrece al formulario:
/// si es una tarjeta libre, el formulario se la queda; si es de un cliente,
/// el formulario la deja pasar y se registra su entrada como siempre.
class CapturaDeTarjeta {
  CapturaDeTarjeta._();

  static CapturadorTarjeta? _actual;

  /// Empieza a recibir los pases. Devuelve cómo soltarlos.
  static VoidCallback tomar(CapturadorTarjeta capturador) {
    _actual = capturador;
    return () {
      if (identical(_actual, capturador)) _actual = null;
    };
  }

  /// Le ofrece el pase a quien esté capturando. True si se lo quedó y ya no
  /// hay que procesarlo como entrada.
  static bool ofrecer(String uid, UserModel? dueno) =>
      _actual?.call(uid, dueno) ?? false;
}

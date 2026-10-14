import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

/// Recibe un pase del lector y dice si se lo queda. [dueno] es el cliente que
/// ya tiene esa tarjeta, o null si está libre.
typedef CapturadorTarjeta = bool Function(String uid, UserModel? dueno);

/// Quién recibe las tarjetas del lector mientras se registra o edita un
/// cliente, o mientras se cobra en Abonar.
///
/// El servicio de entradas sigue escuchando el lector con el formulario
/// abierto (antes se pausaba y un cliente que entraba en ese momento no
/// quedaba registrado). Antes de procesar un pase se lo ofrece al formulario:
/// si es una tarjeta libre, el formulario se la queda; si es de un cliente,
/// el formulario la deja pasar y se registra su entrada como siempre.
///
/// Quien recibe el pase puede usarlo sin quedárselo: Abonar elige al cliente
/// de la tarjeta y la deja pasar, para que su entrada se registre igual.
///
/// Los capturadores se apilan y solo el último recibe el pase: con el
/// formulario abierto encima de Abonar, la tarjeta es del formulario; al
/// cerrarlo, vuelve a ser de Abonar.
class CapturaDeTarjeta {
  CapturaDeTarjeta._();

  static final _pila = <CapturadorTarjeta>[];

  /// Empieza a recibir los pases. Devuelve cómo soltarlos.
  static VoidCallback tomar(CapturadorTarjeta capturador) {
    _pila.add(capturador);
    return () => _pila.removeWhere((c) => identical(c, capturador));
  }

  /// Le ofrece el pase a quien esté capturando. True si se lo quedó y ya no
  /// hay que procesarlo como entrada.
  static bool ofrecer(String uid, UserModel? dueno) =>
      _pila.isEmpty ? false : _pila.last(uid, dueno);
}

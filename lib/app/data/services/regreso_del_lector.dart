import 'lector_red_service.dart';

/// Espera a que el lector vuelva a trabajar en la red después de salir de
/// "Cambiar WiFi" sin cambiarlo.
///
/// Para cambiarle el WiFi, el lector se reinicia ofreciéndose por Bluetooth y
/// retoma su red unos segundos después. Antes, al salir, la pantalla lo
/// buscaba una sola vez, justo en ese hueco, y decía "Tu lector no aparece":
/// parecía descompuesto y lo desconectaban de la corriente sin necesidad.
///
/// Ahora se le busca un rato ([buscar], con el número de intento). En cuanto
/// aparece todavía ofreciéndose por Bluetooth, se le pide que deje de hacerlo
/// ([terminar]): se reinicia y vuelve a trabajar normal en unos segundos, en
/// vez de reiniciarse de sorpresa a los 5 min.
///
/// [terminar] devuelve true si se va a reiniciar, false si no lo hará
/// (firmware anterior, o se ofrece por otro motivo) y null si no contestó:
/// ofreciéndose por Bluetooth, el WiFi del lector contesta a medias, y
/// rendirse a la primera lo dejaba así 5 min más. Entonces se le vuelve a
/// pedir en la siguiente vuelta.
///
/// Devuelve el lector ya trabajando. Si al cumplirse [limite] solo se le vio
/// todavía ofreciéndose por Bluetooth, ese (está en la red y pasa tarjetas);
/// null si no apareció (o si [seguir] dice que ya no hace falta).
Future<LectorEnRed?> esperarRegresoDelLector({
  required Future<LectorEnRed?> Function(int intento) buscar,
  required Future<bool?> Function(LectorEnRed lector) terminar,
  bool Function()? seguir,
  Duration limite = const Duration(seconds: 75),
  Duration pausa = const Duration(seconds: 2),
  DateTime Function() ahora = DateTime.now,
}) async {
  final hasta = ahora().add(limite);
  var pidioTerminar = false;
  LectorEnRed? visto;

  for (var intento = 0;; intento++) {
    if (seguir != null && !seguir()) return null;

    final lector = await buscar(intento);
    if (lector != null && lector.mine) {
      if (!lector.modoConfig) return lector;
      visto = lector;
      if (!pidioTerminar) {
        final reinicia = await terminar(lector);
        // No se va a reiniciar (firmware anterior, o alguien lo está
        // configurando): ya está en la red y pasa tarjetas. El modo
        // configuración se cierra solo.
        if (reinicia == false) return lector;
        pidioTerminar = reinicia == true;
      }
      // Pidió terminar y todavía no se reinicia: la siguiente vuelta ya lo
      // encuentra trabajando normal. Si no contestó, se le vuelve a pedir.
    }

    if (!ahora().isBefore(hasta)) return visto;
    await Future<void>.delayed(pausa);
  }
}

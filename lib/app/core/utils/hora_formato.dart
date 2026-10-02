/// Horas en formato de 12 horas con a.m. / p.m.
///
/// Único sitio donde se decide cómo se escribe una hora en la app, para que
/// la pantalla, el PDF y el registro no acaben cada uno con el suyo. Se
/// escribe a mano en vez de con `intl` para no depender de que el locale esté
/// cargado, igual que los nombres de mes de [PeriodoFiltroMixin].
class HoraFormato {
  HoraFormato._();

  /// "6:00 a.m." · "10:30 p.m." · "12:00 p.m." (mediodía)
  static String completa(int hora, int minuto) =>
      '${_hora12(hora)}:${minuto.toString().padLeft(2, '0')} ${sufijo(hora)}';

  /// Solo la hora en punto: "6 a.m." · "12 p.m."
  ///
  /// Para franjas horarias, donde los minutos siempre son cero y el ":00"
  /// solo ocupa espacio.
  static String enPunto(int hora) => '${_hora12(hora)} ${sufijo(hora)}';

  /// Rango entre dos horas en punto: "6 – 8 a.m." · "10 a.m. – 12 p.m."
  ///
  /// Cuando ambas caen en la misma mitad del día el sufijo se dice una sola
  /// vez: repetirlo alarga la etiqueta sin aportar nada.
  static String rango(int desde, int hasta) {
    if (sufijo(desde) == sufijo(hasta)) {
      return '${_hora12(desde)} – ${_hora12(hasta)} ${sufijo(desde)}';
    }
    return '${enPunto(desde)} – ${enPunto(hasta)}';
  }

  /// La hora de un momento concreto: "6:15 a.m."
  static String deFecha(DateTime fecha) => completa(fecha.hour, fecha.minute);

  /// Fecha y hora cortas: "27/05 6:15 a.m."
  static String fechaYHora(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')} ${deFecha(fecha)}';

  static String sufijo(int hora) => hora < 12 ? 'a.m.' : 'p.m.';

  /// Las 0 son las 12 a.m. y las 12 siguen siendo las 12 p.m.; el resto es el
  /// resto módulo 12.
  static int _hora12(int hora) {
    final h = hora % 12;
    return h == 0 ? 12 : h;
  }
}

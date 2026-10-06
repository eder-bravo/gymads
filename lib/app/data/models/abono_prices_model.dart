/// Precios fijos de abono por unidad de periodo, a nivel gimnasio.
///
/// Un valor nulo significa "sin precio configurado" para ese periodo; en ese
/// caso Abonar cae al modo de precio libre.
class AbonoPricesModel {
  final double? priceDay;
  final double? priceWeek;
  final double? priceMonth;
  final double? priceYear;

  /// Inscripción: se cobra una sola vez, a los clientes nuevos (que nunca
  /// han pagado), junto con su primer abono. Vale en costo fijo y en abono
  /// libre. Null: el gimnasio no cobra inscripción.
  final double? priceInscripcion;

  /// Modo de cobro del gimnasio: 'fijo' | 'libre'. Null significa que el
  /// asistente de configuración inicial aún está pendiente. Abonar no lo usa
  /// para decidir cómo abre: con precios configurados siempre abre en fijo.
  final String? paymentMode;

  const AbonoPricesModel({
    this.priceDay,
    this.priceWeek,
    this.priceMonth,
    this.priceYear,
    this.priceInscripcion,
    this.paymentMode,
  });

  factory AbonoPricesModel.fromJson(Map<String, dynamic> json) {
    return AbonoPricesModel(
      priceDay: _toDouble(json['price_day']),
      priceWeek: _toDouble(json['price_week']),
      priceMonth: _toDouble(json['price_month']),
      priceYear: _toDouble(json['price_year']),
      priceInscripcion: _toDouble(json['price_inscripcion']),
      paymentMode: json['payment_mode'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Los precios (los cuatro periodos y la inscripción). `payment_mode` queda
  /// fuera a propósito: este
  /// mapa lo consume `savePrices()`, que se llama desde Configuración con un
  /// modelo construido sin `paymentMode`; incluirlo aquí borraría el modo de
  /// cobro en cada guardado de precios. Para escribirlo usa
  /// `AbonoPricesRepository.savePaymentMode()`.
  Map<String, dynamic> toJson() => {
        'price_day': priceDay,
        'price_week': priceWeek,
        'price_month': priceMonth,
        'price_year': priceYear,
        'price_inscripcion': priceInscripcion,
      };

  /// Precio configurado para un tipo de periodo de `AbonarController.durationTypes`
  /// ('Días' | 'Semanas' | 'Meses' | 'Años'). Null si no hay precio.
  double? priceFor(String periodType) {
    switch (periodType) {
      case 'Días':
        return priceDay;
      case 'Semanas':
        return priceWeek;
      case 'Meses':
        return priceMonth;
      case 'Años':
        return priceYear;
      default:
        return null;
    }
  }

  /// Si el gimnasio cobra inscripción a los clientes nuevos.
  bool get cobraInscripcion => (priceInscripcion ?? 0) > 0;

  /// True si hay al menos un periodo con precio configurado. La inscripción
  /// no cuenta: sola no hace "costo fijo".
  bool get hasAnyPrice =>
      priceDay != null ||
      priceWeek != null ||
      priceMonth != null ||
      priceYear != null;
}

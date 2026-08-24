/// Precios fijos de abono por unidad de periodo, a nivel gimnasio.
///
/// Un valor nulo significa "sin precio configurado" para ese periodo; en ese
/// caso Abonar cae al modo de precio libre.
class AbonoPricesModel {
  final double? priceDay;
  final double? priceWeek;
  final double? priceMonth;
  final double? priceYear;

  /// Modo de cobro del gimnasio: 'fijo' | 'libre'. Null significa que el
  /// asistente de configuración inicial aún está pendiente.
  final String? paymentMode;

  const AbonoPricesModel({
    this.priceDay,
    this.priceWeek,
    this.priceMonth,
    this.priceYear,
    this.paymentMode,
  });

  factory AbonoPricesModel.fromJson(Map<String, dynamic> json) {
    return AbonoPricesModel(
      priceDay: _toDouble(json['price_day']),
      priceWeek: _toDouble(json['price_week']),
      priceMonth: _toDouble(json['price_month']),
      priceYear: _toDouble(json['price_year']),
      paymentMode: json['payment_mode'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Solo los cuatro precios. `payment_mode` queda fuera a propósito: este
  /// mapa lo consume `savePrices()`, que se llama desde Configuración con un
  /// modelo construido sin `paymentMode`; incluirlo aquí borraría el modo de
  /// cobro en cada guardado de precios. Para escribirlo usa
  /// `AbonoPricesRepository.savePaymentMode()`.
  Map<String, dynamic> toJson() => {
        'price_day': priceDay,
        'price_week': priceWeek,
        'price_month': priceMonth,
        'price_year': priceYear,
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

  /// True si hay al menos un periodo con precio configurado.
  bool get hasAnyPrice =>
      priceDay != null ||
      priceWeek != null ||
      priceMonth != null ||
      priceYear != null;
}

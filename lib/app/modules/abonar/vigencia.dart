import 'package:intl/intl.dart';

import '../../core/utils/periodo_filtro_mixin.dart';
import '../../data/models/user_model.dart';

/// Textos del cobro de membresía en palabras, para que se lean sin pensar:
/// "Pagado hasta el 15 de octubre" en vez de "Activo - 15/10/2026".

const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// "15 de diciembre", o con [conDia] "martes 15 de diciembre". El año solo
/// si no es el de [hoy] (por defecto, el actual).
String fechaLarga(DateTime d, {bool conDia = false, DateTime? hoy}) {
  final mes = PeriodoFiltroMixin.nombresMeses[d.month - 1].toLowerCase();
  final dia = conDia ? '${_dias[d.weekday - 1]} ' : '';
  final anio = d.year == (hoy ?? DateTime.now()).year ? '' : ' de ${d.year}';
  return '$dia${d.day} de $mes$anio';
}

/// "1 mes", "2 meses", "1 día", "3 semanas", "1 año". [tipo] es como se
/// guarda el periodo: Meses, Semanas, Días o Años.
String periodoEnPalabras(int n, String tipo) {
  final (uno, varios) = switch (tipo) {
    'Días' => ('día', 'días'),
    'Semanas' => ('semana', 'semanas'),
    'Años' => ('año', 'años'),
    _ => ('mes', 'meses'),
  };
  return '$n ${n == 1 ? uno : varios}';
}

/// Cómo está la membresía del cliente, en una línea principal y, si hace
/// falta, otra debajo.
typedef Situacion = ({String texto, String? detalle, bool vencido});

Situacion situacionDe(UserModel cliente, DateTime ahora) {
  final vence = cliente.expirationDate;
  if (vence == null) {
    return (texto: 'Cliente nuevo', detalle: null, vencido: false);
  }
  if (cliente.isActive && vence.isAfter(ahora)) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dias =
        DateTime(vence.year, vence.month, vence.day).difference(hoy).inDays;
    return (
      texto: 'Pagado hasta el ${fechaLarga(vence, hoy: ahora)}',
      detalle: dias <= 0
          ? 'Vence hoy'
          : dias == 1
              ? 'Le queda 1 día'
              : 'Le quedan $dias días',
      vencido: false,
    );
  }
  return (
    texto: 'Venció el ${fechaLarga(vence, hoy: ahora)}',
    detalle: null,
    vencido: true,
  );
}

/// Cuánto se cobra: con costo fijo, el precio del periodo por la cantidad;
/// con abono libre, lo que se escribió (ya es el total).
double totalDelCobro({
  required bool costoFijo,
  required double? precioPorPeriodo,
  required int cantidad,
  required double montoLibre,
}) =>
    costoFijo ? (precioPorPeriodo ?? 0) * cantidad : montoLibre;

/// Qué falta para poder cobrar, dicho como se le pide a la persona, o null
/// si ya se puede.
String? faltaParaCobrarDe({
  required bool costoFijo,
  required double? precioPorPeriodo,
  required int cantidad,
  required double montoLibre,
}) {
  if (cantidad <= 0) return 'Elige cuánto tiempo paga';
  if (costoFijo) {
    return (precioPorPeriodo ?? 0) > 0 ? null : 'Elige cuánto tiempo paga';
  }
  return montoLibre > 0 ? null : 'Escribe cuánto paga';
}

/// "\$1,000" para un monto redondo; con centavos, "\$1,000.50".
String pesos(double monto) {
  final redondo = monto == monto.roundToDouble();
  return NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: redondo ? 0 : 2,
  ).format(monto);
}

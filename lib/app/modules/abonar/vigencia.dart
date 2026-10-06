import 'dart:math' as math;

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

/// Con [resumida] (tableta y escritorio), lo que queda de una membresía
/// larga se dice en meses o años: "Le quedan 36499 días" no se entiende.
Situacion situacionDe(UserModel cliente, DateTime ahora,
    {bool resumida = false}) {
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
              : resumida
                  ? loQueLeQueda(hoy, vence, dias)
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

/// "Le quedan 45 días" hasta 60 días; después en meses y días ("Le quedan 2
/// meses y 29 días") y, desde dos años, en años ("Le quedan más de 99 años").
/// Contado en el calendario, como se cuentan los periodos al cobrar.
String loQueLeQueda(DateTime hoy, DateTime vence, int dias) {
  if (dias <= 60) return 'Le quedan $dias días';
  // En UTC: un cambio de horario no debe restar un día.
  final desde = DateTime.utc(hoy.year, hoy.month, hoy.day);
  final hasta = DateTime.utc(vence.year, vence.month, vence.day);
  // Meses completos con la misma regla que el cobro ([sumarMeses]): del 31
  // de enero al 28 de febrero ya es un mes.
  var meses = (hasta.year - desde.year) * 12 + hasta.month - desde.month;
  while (meses > 0 && sumarMeses(desde, meses).isAfter(hasta)) {
    meses--;
  }
  if (meses >= 24) {
    final anios = meses ~/ 12;
    final exacto = meses % 12 == 0 && sumarMeses(desde, meses) == hasta;
    return exacto ? 'Le quedan $anios años' : 'Le quedan más de $anios años';
  }
  final resto = hasta.difference(sumarMeses(desde, meses)).inDays;
  final enMeses = meses == 1 ? '1 mes' : '$meses meses';
  if (resto <= 0) {
    return meses == 1 ? 'Le queda 1 mes' : 'Le quedan $enMeses';
  }
  return 'Le quedan $enMeses y ${resto == 1 ? '1 día' : '$resto días'}';
}

/// La fecha [n] periodos después de [desde] ([tipo]: Días, Semanas, Meses o
/// Años, como en Abonar).
///
/// Meses y años van por calendario, como se cobra en un gimnasio: el mismo
/// día del mes (6 de octubre + 1 mes = 6 de noviembre; + 2 años = 6 de
/// octubre dos años después). Si el mes de llegada no tiene ese día, el
/// último ([sumarMeses]). Semanas y días suman días. Conserva la hora.
DateTime sumarPeriodo(DateTime desde, String tipo, int n) => switch (tipo) {
      'Días' => desde.add(Duration(days: n)),
      'Semanas' => desde.add(Duration(days: 7 * n)),
      'Años' => sumarMeses(desde, 12 * n),
      _ => sumarMeses(desde, n),
    };

/// [desde] más [meses] meses de calendario. Si el mes de llegada es más
/// corto, el último día: 31 de enero + 1 mes = 28 de febrero (29 en año
/// bisiesto); 29 de febrero + 1 año = 28 de febrero. Se suma de una vez, no
/// mes por mes: 31 de enero + 2 meses = 31 de marzo. Conserva la hora y si
/// la fecha es UTC.
DateTime sumarMeses(DateTime desde, int meses) {
  final total = desde.year * 12 + (desde.month - 1) + meses;
  final anio = total ~/ 12;
  final mes = total % 12 + 1;
  // El día 0 del mes siguiente es el último de este.
  final ultimoDia = DateTime.utc(anio, mes + 1, 0).day;
  final dia = math.min(desde.day, ultimoDia);
  return desde.isUtc
      ? DateTime.utc(anio, mes, dia, desde.hour, desde.minute, desde.second,
          desde.millisecond, desde.microsecond)
      : DateTime(anio, mes, dia, desde.hour, desde.minute, desde.second,
          desde.millisecond, desde.microsecond);
}

/// Cuánto se cobra: el precio de un periodo por la cantidad elegida, tanto
/// con costo fijo como con abono libre, más la [inscripcion] si va (clientes
/// nuevos).
double totalDelCobro({
  required bool costoFijo,
  required double? precioPorPeriodo,
  required int cantidad,
  required double montoLibre,
  double inscripcion = 0,
}) =>
    (costoFijo ? (precioPorPeriodo ?? 0) : montoLibre) * cantidad +
    inscripcion;

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
  return montoLibre > 0 ? null : 'Escribe el precio por periodo';
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

import '../../core/utils/hora_formato.dart';

/// Configuración de accesos del gimnasio: si se registran salidas y en qué
/// horario abre.
///
/// Vive como columnas de la tabla `gyms`, junto a los precios y al modo de
/// cobro, así que comparte sus políticas RLS: solo el dueño escribe.
class GymSettingsModel {
  const GymSettingsModel({
    this.registrarSalidas = false,
    this.horaApertura = const HoraDelDia(6, 0),
    this.horaCierre = const HoraDelDia(22, 0),
  });

  /// Si está activo, el segundo pase del día marca la salida del cliente.
  final bool registrarSalidas;

  final HoraDelDia horaApertura;
  final HoraDelDia horaCierre;

  factory GymSettingsModel.fromJson(Map<String, dynamic> json) {
    return GymSettingsModel(
      registrarSalidas: json['registrar_salidas'] as bool? ?? false,
      horaApertura:
          HoraDelDia.parse(json['hora_apertura'] as String?, fallback: 6),
      horaCierre:
          HoraDelDia.parse(json['hora_cierre'] as String?, fallback: 22),
    );
  }

  Map<String, dynamic> toJson() => {
        'registrar_salidas': registrarSalidas,
        'hora_apertura': horaApertura.toSql(),
        'hora_cierre': horaCierre.toSql(),
      };

  GymSettingsModel copyWith({
    bool? registrarSalidas,
    HoraDelDia? horaApertura,
    HoraDelDia? horaCierre,
  }) {
    return GymSettingsModel(
      registrarSalidas: registrarSalidas ?? this.registrarSalidas,
      horaApertura: horaApertura ?? this.horaApertura,
      horaCierre: horaCierre ?? this.horaCierre,
    );
  }

  /// Cuántas horas está abierto. Contempla el cierre pasada la medianoche
  /// (abre 06:00 y cierra 01:00 = 19 horas).
  int get horasAbierto {
    final duracion = horaCierre.enMinutos - horaApertura.enMinutos;
    final minutos = duracion > 0 ? duracion : duracion + 24 * 60;
    return (minutos / 60).ceil();
  }
}

/// Una hora del reloj, sin fecha. Equivale al tipo `time` de Postgres.
///
/// No se usa `TimeOfDay` de Flutter porque este modelo vive en la capa de
/// datos y no debe depender del framework de UI.
class HoraDelDia {
  const HoraDelDia(this.hora, this.minuto);

  final int hora;
  final int minuto;

  /// Lee el `time` de Postgres, que llega como "06:00:00".
  factory HoraDelDia.parse(String? valor, {required int fallback}) {
    if (valor == null || valor.isEmpty) return HoraDelDia(fallback, 0);
    final partes = valor.split(':');
    return HoraDelDia(
      int.tryParse(partes.first) ?? fallback,
      partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0,
    );
  }

  String toSql() =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}:00';

  /// Para mostrar: "6:00 a.m.". El `toSql()` de arriba sigue en 24 h, que es
  /// lo que espera el tipo `time` de Postgres.
  String get etiqueta => HoraFormato.completa(hora, minuto);

  int get enMinutos => hora * 60 + minuto;

  @override
  bool operator ==(Object other) =>
      other is HoraDelDia && other.hora == hora && other.minuto == minuto;

  @override
  int get hashCode => Object.hash(hora, minuto);

  @override
  String toString() => etiqueta;
}

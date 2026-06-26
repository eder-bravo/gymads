/// Modelo para representar un ingreso del gimnasio
class IngresoModel {
  final String? id;
  final String? clienteId;
  final String clienteNombre;
  final String concepto; // 'registro', 'renovacion', 'producto'
  final String tipoMembresia;
  final double montoBase;
  final double cuotaRegistro;
  final double descuento;
  final double montoFinal;
  final String metodoPago; // 'efectivo', 'tarjeta', 'transferencia'
  final DateTime fecha;
  final DateTime? periodoInicio;
  final DateTime? periodoFin;
  final String? notas;
  final String usuarioStaff;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IngresoModel({
    this.id,
    this.clienteId,
    required this.clienteNombre,
    required this.concepto,
    required this.tipoMembresia,
    required this.montoBase,
    this.cuotaRegistro = 0.0,
    this.descuento = 0.0,
    required this.montoFinal,
    required this.metodoPago,
    required this.fecha,
    this.periodoInicio,
    this.periodoFin,
    this.notas,
    required this.usuarioStaff,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory para crear desde JSON
  factory IngresoModel.fromJson(Map<String, dynamic> json) {
    return IngresoModel(
      id: json['id'],
      clienteId: json['cliente_id'],
      clienteNombre: json['cliente_nombre'] ?? '',
      concepto: json['concepto'] ?? '',
      tipoMembresia: json['tipo_membresia'] ?? '',
      montoBase: (json['monto_base'] ?? 0).toDouble(),
      cuotaRegistro: (json['cuota_registro'] ?? 0).toDouble(),
      descuento: (json['descuento'] ?? 0).toDouble(),
      montoFinal: (json['monto_final'] ?? 0).toDouble(),
      metodoPago: json['metodo_pago'] ?? 'efectivo',
      fecha: json['fecha'] != null 
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      periodoInicio: json['periodo_inicio'] != null 
          ? DateTime.parse(json['periodo_inicio'])
          : null,
      periodoFin: json['periodo_fin'] != null 
          ? DateTime.parse(json['periodo_fin'])
          : null,
      notas: json['notas'],
      usuarioStaff: json['usuario_staff'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Convierte a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'concepto': concepto,
      'tipo_membresia': tipoMembresia,
      'monto_base': montoBase,
      'cuota_registro': cuotaRegistro,
      'descuento': descuento,
      'monto_final': montoFinal,
      'metodo_pago': metodoPago,
      'fecha': fecha.toIso8601String(),
      'periodo_inicio': periodoInicio?.toIso8601String(),
      'periodo_fin': periodoFin?.toIso8601String(),
      'notas': notas,
      'usuario_staff': usuarioStaff,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copia el modelo con nuevos valores
  IngresoModel copyWith({
    String? id,
    String? clienteId,
    String? clienteNombre,
    String? concepto,
    String? tipoMembresia,
    double? montoBase,
    double? cuotaRegistro,
    double? descuento,
    double? montoFinal,
    String? metodoPago,
    DateTime? fecha,
    DateTime? periodoInicio,
    DateTime? periodoFin,
    String? notas,
    String? usuarioStaff,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IngresoModel(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      concepto: concepto ?? this.concepto,
      tipoMembresia: tipoMembresia ?? this.tipoMembresia,
      montoBase: montoBase ?? this.montoBase,
      cuotaRegistro: cuotaRegistro ?? this.cuotaRegistro,
      descuento: descuento ?? this.descuento,
      montoFinal: montoFinal ?? this.montoFinal,
      metodoPago: metodoPago ?? this.metodoPago,
      fecha: fecha ?? this.fecha,
      periodoInicio: periodoInicio ?? this.periodoInicio,
      periodoFin: periodoFin ?? this.periodoFin,
      notas: notas ?? this.notas,
      usuarioStaff: usuarioStaff ?? this.usuarioStaff,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Descripción legible del concepto
  String get conceptoDescripcion {
    switch (concepto) {
      case 'registro':
        return 'Registro nuevo';
      case 'renovacion':
        return 'Renovación';
      case 'producto':
        return 'Venta de producto';
      default:
        return concepto;
    }
  }

  /// Descripción del método de pago
  String get metodoPagoDescripcion {
    switch (metodoPago) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta':
        return 'Tarjeta';
      case 'transferencia':
        return 'Transferencia';
      default:
        return metodoPago;
    }
  }

  /// Indica si hubo descuento
  bool get tieneDescuento => descuento > 0;

  /// Porcentaje de descuento aplicado
  double get porcentajeDescuento {
    final montoTotal = montoBase + cuotaRegistro;
    if (montoTotal == 0) return 0;
    return (descuento / montoTotal) * 100;
  }

  /// Indica si hubo cuota de registro
  bool get tieneCuotaRegistro => cuotaRegistro > 0;

  @override
  String toString() {
    return 'IngresoModel(id: $id, concepto: $concepto, tipoMembresia: $tipoMembresia, montoFinal: $montoFinal, fecha: $fecha)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IngresoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Modelo para estadísticas de ingresos
class EstadisticasIngresos {
  final double totalIngresos;
  final double ingresosDiarios;
  final double ingresosSemanales;
  final double ingresosMensuales;
  final int totalTransacciones;
  final int registrosNuevos;
  final int renovaciones;
  final double promedioTransaccion;
  final Map<String, double> ingresosPorMetodo;
  final Map<String, double> ingresosPorConcepto;
  final List<IngresoModel> ultimosIngresos;

  EstadisticasIngresos({
    required this.totalIngresos,
    required this.ingresosDiarios,
    required this.ingresosSemanales,
    required this.ingresosMensuales,
    required this.totalTransacciones,
    required this.registrosNuevos,
    required this.renovaciones,
    required this.promedioTransaccion,
    required this.ingresosPorMetodo,
    required this.ingresosPorConcepto,
    required this.ultimosIngresos,
  });

  factory EstadisticasIngresos.empty() {
    return EstadisticasIngresos(
      totalIngresos: 0,
      ingresosDiarios: 0,
      ingresosSemanales: 0,
      ingresosMensuales: 0,
      totalTransacciones: 0,
      registrosNuevos: 0,
      renovaciones: 0,
      promedioTransaccion: 0,
      ingresosPorMetodo: {},
      ingresosPorConcepto: {},
      ultimosIngresos: [],
    );
  }
}

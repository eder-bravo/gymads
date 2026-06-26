/// Modelo para representar una venta
class Sale {
  final String? id;
  final String? clienteId; // Cambiado a opcional
  final String clienteNombre;
  final String concepto;
  final String tipoMembresia;
  final double montoBase;
  final double montoFinal;
  final String metodoPago;
  final DateTime? periodoInicio;
  final DateTime? periodoFin;
  final String? notas;
  final String usuarioStaff;
  final double cuotaRegistro;
  final double descuento;
  final DateTime fecha;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SaleItem> items;
  // Nuevos campos para ventas de productos
  final double impuestos;
  final double montoRecibido;
  final double cambio;
  final String ventaTipo;
  final double subtotal;

  Sale({
    this.id,
    this.clienteId, // Cambiado a opcional
    required this.clienteNombre,
    required this.concepto,
    required this.tipoMembresia,
    required this.montoBase,
    required this.montoFinal,
    required this.metodoPago,
    this.periodoInicio,
    this.periodoFin,
    this.notas,
    required this.usuarioStaff,
    this.cuotaRegistro = 0,
    this.descuento = 0,
    required this.fecha,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.impuestos = 0,
    this.montoRecibido = 0,
    this.cambio = 0,
    this.ventaTipo = 'membresia',
    this.subtotal = 0,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    List<SaleItem> saleItems = [];
    
    // Parsear items_detalle si existe
    if (json['items_detalle'] != null) {
      final itemsJson = json['items_detalle'];
      if (itemsJson is List) {
        saleItems = itemsJson.map((item) => SaleItem.fromJson(item)).toList();
      }
    }

    return Sale(
      id: json['id'],
      clienteId: json['cliente_id'] ?? '',
      clienteNombre: json['cliente_nombre'] ?? '',
      concepto: json['concepto'] ?? '',
      tipoMembresia: json['tipo_membresia'] ?? '',
      montoBase: (json['monto_base'] ?? 0).toDouble(),
      montoFinal: (json['monto_final'] ?? 0).toDouble(),
      metodoPago: json['metodo_pago'] ?? '',
      periodoInicio: json['periodo_inicio'] != null
          ? DateTime.parse(json['periodo_inicio'])
          : null,
      periodoFin: json['periodo_fin'] != null
          ? DateTime.parse(json['periodo_fin'])
          : null,
      notas: json['notas'],
      usuarioStaff: json['usuario_staff'] ?? '',
      cuotaRegistro: (json['cuota_registro'] ?? 0).toDouble(),
      descuento: (json['descuento'] ?? 0).toDouble(),
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      items: saleItems,
      impuestos: (json['impuestos'] ?? 0).toDouble(),
      montoRecibido: (json['monto_recibido'] ?? 0).toDouble(),
      cambio: (json['cambio'] ?? 0).toDouble(),
      ventaTipo: json['venta_tipo'] ?? 'membresia',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'cliente_nombre': clienteNombre,
      'concepto': concepto,
      'tipo_membresia': tipoMembresia,
      'monto_base': montoBase,
      'monto_final': montoFinal,
      'metodo_pago': metodoPago,
      'notas': notas,
      'usuario_staff': usuarioStaff,
      'cuota_registro': cuotaRegistro,
      'descuento': descuento,
      'fecha': fecha.toIso8601String(),
      'items_detalle': items.map((item) => item.toJson()).toList(),
      'impuestos': impuestos,
      'monto_recibido': montoRecibido,
      'cambio': cambio,
      'venta_tipo': ventaTipo,
      'subtotal': subtotal,
    };
    
    // Solo incluir el id si no es null (para updates)
    if (id != null) {
      json['id'] = id;
    }
    
    // Solo incluir cliente_id si no es null y no está vacío
    if (clienteId != null && clienteId!.isNotEmpty) {
      json['cliente_id'] = clienteId;
    }
    
    // Solo incluir campos opcionales si tienen valor
    if (periodoInicio != null) json['periodo_inicio'] = periodoInicio!.toIso8601String();
    if (periodoFin != null) json['periodo_fin'] = periodoFin!.toIso8601String();
    // No incluir created_at ni updated_at para que la BD use sus defaults
    
    return json;
  }

  Sale copyWith({
    String? id,
    String? clienteId,
    String? clienteNombre,
    String? concepto,
    String? tipoMembresia,
    double? montoBase,
    double? montoFinal,
    String? metodoPago,
    DateTime? periodoInicio,
    DateTime? periodoFin,
    String? notas,
    String? usuarioStaff,
    double? cuotaRegistro,
    double? descuento,
    DateTime? fecha,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      concepto: concepto ?? this.concepto,
      tipoMembresia: tipoMembresia ?? this.tipoMembresia,
      montoBase: montoBase ?? this.montoBase,
      montoFinal: montoFinal ?? this.montoFinal,
      metodoPago: metodoPago ?? this.metodoPago,
      periodoInicio: periodoInicio ?? this.periodoInicio,
      periodoFin: periodoFin ?? this.periodoFin,
      notas: notas ?? this.notas,
      usuarioStaff: usuarioStaff ?? this.usuarioStaff,
      cuotaRegistro: cuotaRegistro ?? this.cuotaRegistro,
      descuento: descuento ?? this.descuento,
      fecha: fecha ?? this.fecha,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      impuestos: impuestos,
      montoRecibido: montoRecibido,
      cambio: cambio,
      ventaTipo: ventaTipo,
      subtotal: subtotal,
    );
  }
}

/// Modelo para representar un item de venta
class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
    };
  }

  SaleItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? total,
  }) {
    return SaleItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? (this.unitPrice * (quantity ?? this.quantity)),
    );
  }
}

enum PaymentMethod {
  efectivo('Efectivo'),
  tarjeta('Tarjeta'),
  transferencia('Transferencia'),
  mixto('Mixto');

  const PaymentMethod(this.displayName);
  final String displayName;
}

class Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final bool isActive;

  /// Código de barras del fabricante (EAN/UPC), si el producto trae uno.
  ///
  /// Se guarda como texto y no como número: hay formatos de 8, 12, 13 y 14
  /// dígitos, los ceros a la izquierda son significativos, y algunos
  /// productos traen códigos internos alfanuméricos.
  final String? barcode;

  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.isActive,
    this.barcode,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Si tiene un código con el que se pueda escanear.
  bool get tieneBarcode => (barcode ?? '').isNotEmpty;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] is num) ? json['price'].toDouble() : 0.0,
      stock: json['stock'] ?? 0,
      isActive: json['is_active'] ?? true,
      barcode: (json['barcode'] as String?)?.trim().isEmpty == true
          ? null
          : json['barcode'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'is_active': isActive,
      'barcode': barcode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Método para insertar un nuevo producto (sin enviar el id)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'name': name,
      'price': price,
      'stock': stock,
      'is_active': isActive,
      'barcode': barcode,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? stock,
    bool? isActive,
    String? barcode,
    DateTime? createdAt,
    DateTime? updatedAt,
    /// Quitarle el código al producto. Hace falta porque `barcode ?? this.barcode`
    /// nunca puede dejarlo en null.
    bool limpiarBarcode = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      barcode: limpiarBarcode ? null : (barcode ?? this.barcode),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, stock: $stock)';
  }
}

class ProductTransaction {
  final String id;
  final String productId;
  final String productName;
  final TransactionType type;
  final int quantity;
  final double unitPrice;
  final String notes;
  final String staffUser;
  final DateTime transactionDate;
  final DateTime createdAt;

  ProductTransaction({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.notes,
    required this.staffUser,
    required this.transactionDate,
    required this.createdAt,
  });

  factory ProductTransaction.fromJson(Map<String, dynamic> json) {
    return ProductTransaction(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      type: _stringToTransactionType(json['type'] ?? 'entrada'),
      quantity: json['quantity'] ?? 0,
      unitPrice:
          (json['unit_price'] is num) ? json['unit_price'].toDouble() : 0.0,
      notes: json['notes'] ?? '',
      staffUser: json['staff_user'] ?? '',
      transactionDate: json['transaction_date'] != null
          ? DateTime.parse(json['transaction_date'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'type': type.toString().split('.').last,
      'quantity': quantity,
      'unit_price': unitPrice,
      'notes': notes,
      'staff_user': staffUser,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static TransactionType _stringToTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'entrada':
        return TransactionType.entrada;
      case 'salida':
        return TransactionType.salida;
      case 'ajuste':
        return TransactionType.ajuste;
      case 'venta':
        return TransactionType.venta;
      default:
        return TransactionType.entrada;
    }
  }
}

enum TransactionType { entrada, salida, ajuste, venta }

class Product {
  final String id;
  final String name;
  final String description;

  /// Id de la categoría (`product_categories.id`). El nombre ya no se guarda
  /// aquí: se resuelve con el mapa de categorías del controlador, así que
  /// renombrar una categoría se refleja al instante sin tocar los productos.
  final String? categoryId;
  final double price;
  final int stock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      categoryId: json['category_id'] as String?,
      price: (json['price'] is num) ? json['price'].toDouble() : 0.0,
      stock: json['stock'] ?? 0,
      isActive: json['is_active'] ?? true,
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
      'description': description,
      'category_id': categoryId,
      'price': price,
      'stock': stock,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Método para insertar un nuevo producto (sin enviar el id)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'name': name,
      'description': description,
      'category_id': categoryId,
      'price': price,
      'stock': stock,
      'is_active': isActive,
    };
  }

  /// Nota: al ser `categoryId` nullable, `categoryId ?? this.categoryId` no
  /// permite vaciar la categoría. Es aceptable porque el formulario la exige.
  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    double? price,
    int? stock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, categoryId: $categoryId, price: $price, stock: $stock)';
  }
}

class ProductCategory {
  final String id;
  final String name;
  final String description;

  /// Clave corta del icono. Se resuelve con `CategoryIcons.resolve`.
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final String? gymId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.sortOrder,
    required this.isActive,
    this.gymId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      gymId: json['gym_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  /// Payload de alta. No incluye `id` ni las marcas de tiempo: la base las
  /// genera (`gen_random_uuid()`, `now()`), y un reloj de dispositivo
  /// desviado produciría fechas erróneas.
  Map<String, dynamic> toJsonForInsert() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  /// Payload de edición. `updated_at` lo pone el trigger de la tabla.
  Map<String, dynamic> toJsonForUpdate() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'is_active': isActive,
    };
  }

  ProductCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    int? sortOrder,
    bool? isActive,
    String? gymId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      gymId: gymId ?? this.gymId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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

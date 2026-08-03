/// Plan de abono fijo (tipo membresía) configurado por gimnasio.
///
/// El [price] es el precio TOTAL del plan (no por periodo):
/// ej. "Trimestre" = 3 Meses por $1,350.
class MembershipPlanModel {
  final String id;
  final String name;
  final String periodType; // 'Meses' | 'Semanas' | 'Días' | 'Años'
  final int periodCount;
  final double price;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MembershipPlanModel({
    required this.id,
    required this.name,
    required this.periodType,
    required this.periodCount,
    required this.price,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MembershipPlanModel.fromJson(Map<String, dynamic> json) {
    return MembershipPlanModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      periodType: json['period_type'] ?? 'Meses',
      periodCount: json['period_count'] ?? 1,
      price: (json['price'] is num) ? json['price'].toDouble() : 0.0,
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
      'period_type': periodType,
      'period_count': periodCount,
      'price': price,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Método para insertar un nuevo plan (sin enviar el id ni timestamps)
  Map<String, dynamic> toJsonForInsert() {
    return {
      'name': name,
      'period_type': periodType,
      'period_count': periodCount,
      'price': price,
      'is_active': isActive,
    };
  }

  MembershipPlanModel copyWith({
    String? id,
    String? name,
    String? periodType,
    int? periodCount,
    double? price,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MembershipPlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      periodType: periodType ?? this.periodType,
      periodCount: periodCount ?? this.periodCount,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Descripción legible del periodo: "3 meses", "1 año", "2 semanas".
  String get descripcionPeriodo {
    final singular = {
      'Meses': 'mes',
      'Semanas': 'semana',
      'Días': 'día',
      'Años': 'año',
    };
    final plural = {
      'Meses': 'meses',
      'Semanas': 'semanas',
      'Días': 'días',
      'Años': 'años',
    };
    final unidad = periodCount == 1
        ? (singular[periodType] ?? periodType.toLowerCase())
        : (plural[periodType] ?? periodType.toLowerCase());
    return '$periodCount $unidad';
  }

  @override
  String toString() {
    return 'MembershipPlanModel(id: $id, name: $name, periodo: $descripcionPeriodo, price: $price)';
  }
}

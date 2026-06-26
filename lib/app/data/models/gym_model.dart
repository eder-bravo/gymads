/// Model for Gym (Empresa/Gimnasio)
class GymModel {
  final String id;
  final String name;
  final String? ownerUserId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  GymModel({
    required this.id,
    required this.name,
    this.ownerUserId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GymModel.fromJson(Map<String, dynamic> json) {
    return GymModel(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerUserId: json['owner_user_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_user_id': ownerUserId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  GymModel copyWith({
    String? id,
    String? name,
    String? ownerUserId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GymModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'GymModel(id: $id, name: $name)';
}

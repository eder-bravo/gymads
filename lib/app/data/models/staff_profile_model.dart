/// Model for Staff Profile (Staff user linked to a branch)
class StaffProfileModel {
  final String id;
  final String userId;
  final String gymId;
  final String branchId;
  final String role; // 'owner_admin' | 'branch_staff'
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Gym name (joined from gyms table)
  final String? gymName;
  // Gym creation date (joined from gyms table) — used as the lower bound
  // for date navigation (e.g. income months can't go before the account existed)
  final DateTime? gymCreatedAt;
  // Modo de cobro del gimnasio (joined from gyms table): 'fijo' | 'libre'.
  // Null significa que el asistente de configuración inicial está pendiente.
  final String? paymentMode;

  StaffProfileModel({
    required this.id,
    required this.userId,
    required this.gymId,
    required this.branchId,
    required this.role,
    this.firstName,
    this.lastName,
    this.displayName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.gymName,
    this.gymCreatedAt,
    this.paymentMode,
  });

  factory StaffProfileModel.fromJson(Map<String, dynamic> json) {
    // Handle joined gym data (from select with gyms(...))
    final gymData = json['gyms'] as Map<String, dynamic>?;
    return StaffProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gymId: json['gym_id'] as String,
      branchId: json['branch_id'] as String,
      role: json['role'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      gymName: gymData?['name'] as String? ?? json['gym_name'] as String?,
      gymCreatedAt:
          _parseDate(gymData?['created_at'] ?? json['gym_created_at']),
      paymentMode: gymData?['payment_mode'] as String? ??
          json['payment_mode'] as String?,
    );
  }

  /// Parsea una fecha que puede venir null o como String
  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'gym_id': gymId,
      'branch_id': branchId,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'gym_name': gymName,
      'gym_created_at': gymCreatedAt?.toIso8601String(),
      'payment_mode': paymentMode,
    };
  }

  /// Get full name composed from parts
  String get fullName {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    return parts.isNotEmpty ? parts.join(' ') : (displayName ?? '');
  }

  /// Check if user is owner_admin
  bool get isOwnerAdmin => role == 'owner_admin';

  /// Check if user is branch_staff
  bool get isBranchStaff => role == 'branch_staff';

  StaffProfileModel copyWith({
    String? id,
    String? userId,
    String? gymId,
    String? branchId,
    String? role,
    String? firstName,
    String? lastName,
    String? displayName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? gymName,
    DateTime? gymCreatedAt,
    String? paymentMode,
  }) {
    return StaffProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gymId: gymId ?? this.gymId,
      branchId: branchId ?? this.branchId,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      gymName: gymName ?? this.gymName,
      gymCreatedAt: gymCreatedAt ?? this.gymCreatedAt,
      paymentMode: paymentMode ?? this.paymentMode,
    );
  }

  @override
  String toString() =>
      'StaffProfileModel(id: $id, userId: $userId, role: $role, branchId: $branchId)';
}

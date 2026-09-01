/// Acceso de un empleado al gimnasio.
///
/// Cada fila representa a una persona del personal. El código en sí no se
/// guarda —solo su hash, y solo mientras está pendiente—, así que este modelo
/// nunca lo contiene: se muestra una única vez, al crearlo o regenerarlo.
class StaffAccesoModel {
  final String id;
  final String gymId;
  final String branchId;
  final String nombre;

  /// 'pendiente' | 'activo' | 'revocado'
  final String estado;

  /// auth.users del empleado, una vez que canjeó su código.
  final String? userId;
  final DateTime? redeemedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  StaffAccesoModel({
    required this.id,
    required this.gymId,
    required this.branchId,
    required this.nombre,
    required this.estado,
    this.userId,
    this.redeemedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffAccesoModel.fromJson(Map<String, dynamic> json) {
    return StaffAccesoModel(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      branchId: json['branch_id'] as String,
      nombre: json['nombre'] as String? ?? '',
      estado: json['estado'] as String? ?? 'pendiente',
      userId: json['user_id'] as String?,
      redeemedAt: _parseDate(json['redeemed_at']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  bool get estaPendiente => estado == 'pendiente';
  bool get estaActivo => estado == 'activo';
  bool get estaRevocado => estado == 'revocado';

  /// Texto para mostrar en la lista.
  String get estadoTexto {
    switch (estado) {
      case 'pendiente':
        return 'Código sin usar';
      case 'activo':
        return 'Acceso activo';
      case 'revocado':
        return 'Acceso revocado';
      default:
        return estado;
    }
  }

  StaffAccesoModel copyWith({
    String? nombre,
    String? estado,
    String? userId,
    DateTime? redeemedAt,
  }) {
    return StaffAccesoModel(
      id: id,
      gymId: gymId,
      branchId: branchId,
      nombre: nombre ?? this.nombre,
      estado: estado ?? this.estado,
      userId: userId ?? this.userId,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'StaffAccesoModel(id: $id, nombre: $nombre, estado: $estado)';
}

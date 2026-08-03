class AccessLogModel {
  final String id;
  final String userId;
  final String userName;
  final String userNumber;
  final String accessType; // 'entrada' o 'salida'
  final String method; // 'qr' o 'rfid'
  final String staffUser;
  final DateTime accessTime;
  final DateTime createdAt;

  AccessLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userNumber,
    required this.accessType,
    required this.method,
    required this.staffUser,
    required this.accessTime,
    required this.createdAt,
  });

  factory AccessLogModel.fromJson(Map<String, dynamic> json) {
    return AccessLogModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      userNumber: json['user_number']?.toString() ?? '',
      accessType: json['access_type']?.toString() ?? 'entrada',
      method: json['method']?.toString() ?? 'rfid',
      staffUser: json['staff_user']?.toString() ?? '',
      accessTime: _parseDateTime(json['access_time']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  /// Parsea de forma segura un DateTime desde un valor dinámico
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('⚠️ Error parseando fecha: $value - $e');
        return DateTime.now();
      }
    }
    
    if (value is DateTime) {
      return value;
    }
    
    // Si es un timestamp en milisegundos
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        print('⚠️ Error parseando timestamp: $value - $e');
        return DateTime.now();
      }
    }
    
    print('⚠️ Tipo de fecha no reconocido: ${value.runtimeType} - $value');
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_number': userNumber,
      'access_type': accessType,
      'method': method,
      'staff_user': staffUser,
      'access_time': accessTime.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crea una copia del modelo con valores actualizados
  AccessLogModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userNumber,
    String? accessType,
    String? method,
    String? staffUser,
    DateTime? accessTime,
    DateTime? createdAt,
  }) {
    return AccessLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userNumber: userNumber ?? this.userNumber,
      accessType: accessType ?? this.accessType,
      method: method ?? this.method,
      staffUser: staffUser ?? this.staffUser,
      accessTime: accessTime ?? this.accessTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Retorna una representación legible del tipo de acceso
  String get accessTypeDisplayText {
    switch (accessType.toLowerCase()) {
      case 'entrada':
        return 'Entrada';
      case 'salida':
        return 'Salida';
      default:
        return accessType;
    }
  }

  /// Retorna una representación legible del método
  String get methodDisplayText {
    switch (method.toLowerCase()) {
      case 'qr':
        return 'Código QR';
      case 'rfid':
        return 'Tarjeta RFID';
      default:
        return method;
    }
  }

  /// Retorna un icono apropiado para el tipo de acceso
  String get accessTypeIcon {
    switch (accessType.toLowerCase()) {
      case 'entrada':
        return '🟢'; // Verde para entrada
      case 'salida':
        return '🔴'; // Rojo para salida
      default:
        return '⚪'; // Blanco por defecto
    }
  }

  /// Retorna un icono apropiado para el método
  String get methodIcon {
    switch (method.toLowerCase()) {
      case 'qr':
        return '📱'; // Teléfono para QR
      case 'rfid':
        return '💳'; // Tarjeta para RFID
      default:
        return '🔍'; // Lupa por defecto
    }
  }

  /// Retorna true si es una entrada
  bool get isEntry => accessType.toLowerCase() == 'entrada';

  /// Retorna true si es una salida
  bool get isExit => accessType.toLowerCase() == 'salida';

  /// Retorna true si el método es QR
  bool get isQRMethod => method.toLowerCase() == 'qr';

  /// Retorna true si el método es RFID
  bool get isRFIDMethod => method.toLowerCase() == 'rfid';

  @override
  String toString() {
    return 'AccessLogModel(id: $id, userName: $userName, accessType: $accessType, method: $method, accessTime: $accessTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AccessLogModel &&
        other.id == id &&
        other.userId == userId &&
        other.userName == userName &&
        other.userNumber == userNumber &&
        other.accessType == accessType &&
        other.method == method &&
        other.staffUser == staffUser &&
        other.accessTime == accessTime &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        userName.hashCode ^
        userNumber.hashCode ^
        accessType.hashCode ^
        method.hashCode ^
        staffUser.hashCode ^
        accessTime.hashCode ^
        createdAt.hashCode;
  }
}

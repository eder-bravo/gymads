import 'package:gymads/app/core/utils/app_logger.dart';

class UserModel {
  final String? id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final DateTime joinDate;
  final DateTime? expirationDate;
  final bool isActive;
  final String? photoUrl;
  final String userNumber;
  final String? rfidCard;
  final List<dynamic> accessHistory;
  final DateTime? lastPaymentDate;
  final int daysRemaining;

  UserModel({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    required this.joinDate,
    this.expirationDate,
    this.isActive = true,
    this.photoUrl,
    this.rfidCard,
    required this.userNumber,
    this.accessHistory = const [],
    this.lastPaymentDate,
    this.daysRemaining = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {

    // Función para parsear fechas
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value);
      } catch (e) {
        AppLogger.error('UserModel', 'Error parseando fecha: $value - Error', e);
        return null;
      }
    }

    final DateTime? expDate =
        parseDateTime(json['expiration_date'] ?? json['expirationDate']);
    final DateTime joinDate =
        parseDateTime(json['join_date'] ?? json['joinDate']) ?? DateTime.now();
    final DateTime? lastPaymentDate =
        parseDateTime(json['last_payment_date'] ?? json['lastPaymentDate']);

    // Calcular días restantes
    int daysLeft = 0;
    if (expDate != null) {
      final now = DateTime.now();
      final difference = expDate.difference(now);
      daysLeft = difference.inHours > 0 ? (difference.inHours / 24).ceil() : 0;
    }

    return UserModel(
      id: json['id']?.toString(),
      name: (json['name'] ?? '').toString().trim(),
      phone: (json['phone'] ?? '').toString().trim(),
      email: json['email']?.toString().trim(),
      address: json['address']?.toString().trim(),
      joinDate: joinDate,
      expirationDate: expDate,
      isActive: json['is_active'] ?? json['isActive'] == true,
      photoUrl: (json['photo_url'] ?? json['photoUrl'])?.toString(),
      rfidCard: (json['rfid_card'] ?? json['rfidCard'])?.toString(),
      userNumber:
          ((json['user_number'] ?? json['userNumber'] ?? '')).toString().trim(),
      accessHistory: List<dynamic>.from(json['accessHistory'] ?? []),
      lastPaymentDate: lastPaymentDate,
      daysRemaining: daysLeft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'join_date': joinDate.toUtc().toIso8601String(),
      'expiration_date': expirationDate?.toUtc().toIso8601String(),
      'is_active': isActive,
      'photo_url': photoUrl,
      'rfid_card': rfidCard,
      'user_number': userNumber,
      'last_payment_date': lastPaymentDate?.toUtc().toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    DateTime? joinDate,
    DateTime? expirationDate,
    bool? isActive,
    String? photoUrl,
    String? rfidCard,
    String? userNumber,
    List<dynamic>? accessHistory,
    DateTime? lastPaymentDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      joinDate: joinDate ?? this.joinDate,
      expirationDate: expirationDate ?? this.expirationDate,
      isActive: isActive ?? this.isActive,
      photoUrl: photoUrl ?? this.photoUrl,
      rfidCard: rfidCard ?? this.rfidCard,
      userNumber: userNumber ?? this.userNumber,
      accessHistory: accessHistory ?? this.accessHistory,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
    );
  }

  UserModel addAccessRecord() {
    final now = DateTime.now();
    final newHistory = List<dynamic>.from(accessHistory);
    newHistory.add(now.toIso8601String());

    return copyWith(accessHistory: newHistory);
  }

  // Método para verificar si la membresía necesita renovación (5 días o menos)
  bool get needsRenewal => daysRemaining <= 5 && daysRemaining > 0;
}

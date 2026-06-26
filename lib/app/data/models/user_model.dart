import 'package:flutter/foundation.dart';

class UserModel {
  final String? id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? membershipType; // Ahora opcional/etiqueta
  final DateTime joinDate;
  final DateTime? expirationDate;
  final bool isActive;
  final String? photoUrl;
  final String? qrCode;
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
    this.membershipType,
    required this.joinDate,
    this.expirationDate,
    this.isActive = true,
    this.photoUrl,
    this.qrCode,
    this.rfidCard,
    required this.userNumber,
    this.accessHistory = const [],
    this.lastPaymentDate,
    this.daysRemaining = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Datos recibidos en fromJson: $json');
    }

    // Función para parsear fechas
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('Error parseando fecha: $value - Error: $e');
        }
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
      membershipType: json['membership_type']?.toString().trim() ?? json['membershipType']?.toString().trim(),
      joinDate: joinDate,
      expirationDate: expDate,
      isActive: json['is_active'] ?? json['isActive'] == true,
      photoUrl: (json['photo_url'] ?? json['photoUrl'])?.toString(),
      qrCode: (json['qr_code'] ?? json['qrCode'])?.toString(),
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
      'membership_type': membershipType,
      'join_date': joinDate.toUtc().toIso8601String(),
      'expiration_date': expirationDate?.toUtc().toIso8601String(),
      'is_active': isActive,
      'photo_url': photoUrl,
      'qr_code': qrCode,
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
    String? membershipType,
    DateTime? joinDate,
    DateTime? expirationDate,
    bool? isActive,
    String? photoUrl,
    String? qrCode,
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
      membershipType: membershipType ?? this.membershipType,
      joinDate: joinDate ?? this.joinDate,
      expirationDate: expirationDate ?? this.expirationDate,
      isActive: isActive ?? this.isActive,
      photoUrl: photoUrl ?? this.photoUrl,
      qrCode: qrCode ?? this.qrCode,
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/rfid_config.dart';

class RfidReaderService {
  // Método para verificar si hay un UID disponible desde el ESP32
  static Future<String?> checkForCard() async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        if (kDebugMode) {
          print('ESP32 no configurado - usando IP estática predeterminada');
        }
        return null;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        if (kDebugMode) {
          print('No hay URL configurada para el ESP32');
        }
        return null;
      }
      


      final response = await http.get(
        Uri.parse('$baseUrl/uid'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final responseText = response.body.trim();
        
        if (responseText.isNotEmpty && responseText != "NO_CARD") {
          if (kDebugMode) {
            print('UID detectado: $responseText');
          }
          return responseText;
        }
        return null;
      } else {
        if (kDebugMode) {
          print('Error al verificar tarjeta: ${response.statusCode}');
          print('Respuesta: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar tarjeta: $e');
        print('Verifique que el ESP32 esté encendido en la IP: ${RfidConfig.DEFAULT_ESP32_IP}');
      }
      return null;
    }
  }
  
  // Método silencioso para capturar UID sin activar LEDs ni buzzer
  // Usado exclusivamente para registrar nuevas tarjetas RFID
  static Future<String?> checkForCardSilent() async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        if (kDebugMode) {
          print('ESP32 no configurado');
        }
        return null;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        if (kDebugMode) {
          print('No hay URL configurada para el ESP32');
        }
        return null;
      }
      

      final response = await http.get(
        Uri.parse('$baseUrl/uid_only'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final responseText = response.body.trim();
        
        if (responseText.isNotEmpty && responseText != "NO_CARD") {
          if (kDebugMode) {
            print('🔇 UID detectado (silencioso): $responseText');
          }
          return responseText;
        }
        return null;
      } else {
        if (kDebugMode) {
          print('Error al verificar tarjeta (silencioso): ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar tarjeta (silencioso): $e');
      }
      return null;
    }
  }
  
  // Método para iniciar la lectura (verificación de conectividad del ESP32)
  static Future<bool> startReading() async {
    try {
      // Cargar configuración primero
      await RfidConfig.loadConfig();
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        if (kDebugMode) {
          print('No hay URL configurada para el ESP32, usando IP por defecto: ${RfidConfig.DEFAULT_ESP32_IP}');
        }
        return false;
      }
      
      if (kDebugMode) {
        print('Intentando conectar con ESP32 en: $baseUrl/status');
      }
      
      // Verificamos si podemos conectarnos al ESP32
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('ESP32 conectado exitosamente');
          print('Respuesta del ESP32: ${response.body}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('ESP32 respondió con código: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al comunicarse con el lector RFID: $e');
        print('Verificar que el ESP32 esté encendido en la IP: ${RfidConfig.DEFAULT_ESP32_IP}');
        print('Red WiFi: Asegúrese de que ambos dispositivos estén en la misma red');
      }
      return false;
    }
  }
  
  // Método para enviar el estado de membresía al ESP32
  static Future<bool> sendMembershipStatus(
    String uid, 
    String status, {
    String? userName,
    String? accessType,
    String? verificationType = 'qr',
  }) async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        if (kDebugMode) {
          print('ESP32 no configurado - no se puede enviar estado de membresía');
        }
        return false;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        if (kDebugMode) {
          print('No hay URL configurada para el ESP32');
        }
        return false;
      }
      
      if (kDebugMode) {
        print('Enviando estado de membresía al ESP32: UID=$uid, Status=$status, AccessType=$accessType');
      }

      final body = {
        'uid': uid,
        'status': status,
        'verification_type': verificationType,
      };
      
      // Agregar información adicional si está disponible
      if (userName != null) body['user_name'] = userName;
      if (accessType != null) body['access_type'] = accessType;

      final response = await http.post(
        Uri.parse('$baseUrl/membership'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Estado de membresía enviado correctamente');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Error al enviar estado de membresía: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al enviar estado de membresía: $e');
      }
      return false;
    }
  }
  
  // Este es el fin de la clase RfidReaderService
}

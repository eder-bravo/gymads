import 'dart:convert';
import 'package:gymads/app/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;
import '../config/rfid_config.dart';

class RfidReaderService {
  // Método para verificar si hay un UID disponible desde el ESP32
  static Future<String?> checkForCard() async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        AppLogger.info('RfidReaderService', 'ESP32 no configurado - usando IP estática predeterminada');
        return null;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/uid'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final responseText = response.body.trim();
        
        if (responseText.isNotEmpty && responseText != "NO_CARD") {
          AppLogger.info('RfidReaderService', 'UID detectado');
          return responseText;
        }
        return null;
      } else {
        AppLogger.error('RfidReaderService', 'Error al verificar tarjeta');
        return null;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al verificar tarjeta', e);
      AppLogger.info('RfidReaderService', 'Verifique que el ESP32 esté encendido en la IP');
      return null;
    }
  }
  
  // Método silencioso para capturar UID sin activar LEDs ni buzzer
  // Usado exclusivamente para registrar nuevas tarjetas RFID
  static Future<String?> checkForCardSilent() async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        AppLogger.info('RfidReaderService', 'ESP32 no configurado');
        return null;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/uid_only'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final responseText = response.body.trim();
        
        if (responseText.isNotEmpty && responseText != "NO_CARD") {
          AppLogger.info('RfidReaderService', 'UID detectado (silencioso)');
          return responseText;
        }
        return null;
      } else {
        AppLogger.error('RfidReaderService', 'Error al verificar tarjeta (silencioso)');
        return null;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al verificar tarjeta (silencioso)', e);
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
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32, usando IP por defecto');
        return false;
      }
      
      AppLogger.info('RfidReaderService', 'Intentando conectar con ESP32');
      
      // Verificamos si podemos conectarnos al ESP32
      final response = await http.get(
        Uri.parse('$baseUrl/status'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        AppLogger.info('RfidReaderService', 'ESP32 conectado exitosamente');
        AppLogger.info('RfidReaderService', 'Respuesta del ESP32');
        return true;
      } else {
        AppLogger.info('RfidReaderService', 'ESP32 respondió con código');
        return false;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al comunicarse con el lector RFID', e);
      AppLogger.info('RfidReaderService', 'Verificar que el ESP32 esté encendido en la IP');
      AppLogger.info('RfidReaderService', 'Red WiFi: Asegúrese de que ambos dispositivos estén en la misma red');
      return false;
    }
  }
  
  // Método para enviar el estado de membresía al ESP32
  static Future<bool> sendMembershipStatus(
    String uid, 
    String status, {
    String? userName,
    String? accessType,
    String? verificationType = 'rfid',
  }) async {
    try {
      // Verificar si hay configuración disponible
      if (!RfidConfig.isConfigured) {
        AppLogger.info('RfidReaderService', 'ESP32 no configurado - no se puede enviar estado de membresía');
        return false;
      }
      
      final baseUrl = RfidConfig.baseUrl;
      if (baseUrl == null) {
        AppLogger.warning('RfidReaderService', 'No hay URL configurada para el ESP32');
        return false;
      }
      
      AppLogger.info('RfidReaderService', 'Enviando estado de membresía al lector');

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
        AppLogger.info('RfidReaderService', 'Estado de membresía enviado correctamente');
        return true;
      } else {
        AppLogger.error('RfidReaderService', 'Error al enviar estado de membresía');
        return false;
      }
    } catch (e) {
      AppLogger.error('RfidReaderService', 'Error al enviar estado de membresía', e);
      return false;
    }
  }
  
  // Este es el fin de la clase RfidReaderService
}

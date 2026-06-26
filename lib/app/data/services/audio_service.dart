import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Servicio para manejar la reproducción de audio en la aplicación
class AudioService {
  static final AudioPlayer _welcomePlayer = AudioPlayer();
  static final AudioPlayer _deniedPlayer = AudioPlayer();
  static final AudioPlayer _errorPlayer = AudioPlayer();
  static final AudioPlayer _successPlayer = AudioPlayer();
  
  /// Reproduce el sonido de bienvenida cuando un usuario escanea exitosamente
  static Future<void> playWelcomeSound() async {
    try {
      if (kDebugMode) {
        print('🔊 Reproduciendo sonido de bienvenida...');
      }
      
      // Detener si estaba reproduciendo
      await _welcomePlayer.stop();
      
      // Cargar el archivo de audio de bienvenida
      await _welcomePlayer.setAsset('assets/audio/welcome.mp3');
      
      // Configurar volumen a 80%
      await _welcomePlayer.setVolume(0.8);
      
      // Configurar velocidad normal
      await _welcomePlayer.setSpeed(1.0);
      
      // Reproducir desde el inicio
      await _welcomePlayer.seek(Duration.zero);
      _welcomePlayer.play(); // Sin await para no bloquear
      
      if (kDebugMode) {
        print('✅ Sonido de bienvenida reproducido correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al reproducir sonido de bienvenida: $e');
      }
    }
  }
  
  /// Reproduce un sonido de error
  static Future<void> playErrorSound() async {
    try {
      if (kDebugMode) {
        print('🔊 Reproduciendo sonido de error...');
      }
      
      await _errorPlayer.stop();
      
      // Cargar el archivo de audio de bienvenida (usado como error)
      await _errorPlayer.setAsset('assets/audio/welcome.mp3');
      
      // Configurar para error (volumen más bajo y velocidad más lenta)
      await _errorPlayer.setVolume(0.6); // Más bajo para error
      await _errorPlayer.setSpeed(0.7); // Más lento para indicar error
      
      // Reproducir desde el inicio
      await _errorPlayer.seek(Duration.zero);
      _errorPlayer.play();
      
      if (kDebugMode) {
        print('✅ Sonido de error reproducido correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al reproducir sonido de error: $e');
      }
    }
  }
  
  /// Reproduce el sonido de acceso denegado cuando el usuario no está registrado
  static Future<void> playDeniedSound() async {
    try {
      if (kDebugMode) {
        print('🔊 Reproduciendo sonido de acceso denegado...');
      }
      
      await _deniedPlayer.stop();
      
      // Cargar el archivo de audio de denegado
      await _deniedPlayer.setAsset('assets/audio/denegado.mp3');
      
      // Configurar volumen a 85%
      await _deniedPlayer.setVolume(0.85);
      
      // Configurar velocidad normal
      await _deniedPlayer.setSpeed(1.0);
      
      // Reproducir desde el inicio
      await _deniedPlayer.seek(Duration.zero);
      _deniedPlayer.play();
      
      if (kDebugMode) {
        print('✅ Sonido de acceso denegado reproducido correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al reproducir sonido de acceso denegado: $e');
      }
    }
  }
  
  /// Reproduce un sonido de éxito con configuración específica
  static Future<void> playSuccessSound() async {
    try {
      if (kDebugMode) {
        print('🔊 Reproduciendo sonido de éxito...');
      }
      
      await _successPlayer.stop();
      
      // Cargar el archivo de audio de bienvenida
      await _successPlayer.setAsset('assets/audio/welcome.mp3');
      
      // Configurar para éxito (velocidad más rápida)
      await _successPlayer.setVolume(0.8);
      await _successPlayer.setSpeed(1.2); // Más rápido para indicar éxito
      
      // Reproducir desde el inicio
      await _successPlayer.seek(Duration.zero);
      _successPlayer.play();
      
      if (kDebugMode) {
        print('✅ Sonido de éxito reproducido correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al reproducir sonido de éxito: $e');
      }
    }
  }
  
  /// Detiene cualquier audio que se esté reproduciendo
  static Future<void> stopAudio() async {
    try {
      await Future.wait([
        _welcomePlayer.stop(),
        _deniedPlayer.stop(),
        _errorPlayer.stop(),
        _successPlayer.stop(),
      ]);
      if (kDebugMode) {
        print('🔇 Todo el audio detenido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al detener audio: $e');
      }
    }
  }
  
  /// Libera los recursos del reproductor de audio
  static Future<void> dispose() async {
    try {
      await Future.wait([
        _welcomePlayer.dispose(),
        _deniedPlayer.dispose(),
        _errorPlayer.dispose(),
        _successPlayer.dispose(),
      ]);
      if (kDebugMode) {
        print('🗑️ Recursos de audio liberados');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al liberar recursos de audio: $e');
      }
    }
  }
  
  /// Configura el volumen del audio (general, aunque afectaría solo si se guarda)
  static Future<void> setVolume(double volume) async {
    try {
      final v = volume.clamp(0.0, 1.0);
      await Future.wait([
        _welcomePlayer.setVolume(v),
        _deniedPlayer.setVolume(v),
        _errorPlayer.setVolume(v),
        _successPlayer.setVolume(v),
      ]);
      if (kDebugMode) {
        print('🔊 Volumen general configurado a: ${(v * 100).toInt()}%');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al configurar volumen: $e');
      }
    }
  }
}


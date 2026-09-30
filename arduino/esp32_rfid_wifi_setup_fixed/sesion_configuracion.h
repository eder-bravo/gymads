#pragma once

#include <stdint.h>
#include <string>

// Se usa bajo candadoBle. La reserva sobrevive a la desconexión necesaria
// para probar WiFi, pero se libera al salir o tras abandonar el asistente.
class SesionConfiguracion {
 public:
  static constexpr uint16_t sinConexion = UINT16_MAX;
  static constexpr uint32_t abandonoMs = 120000;

  bool conectar(uint16_t conexion, uint32_t ahora) {
    expirar(ahora);
    if (activa_) return conexion_ == conexion;
    activa_ = true;
    conexion_ = conexion;
    actividad_ = ahora;
    return true;
  }

  bool tomar(const std::string &token, uint16_t conexion, uint32_t ahora) {
    expirar(ahora);
    if (token.empty() || token.size() > 80) return false;
    if (activa_ && !((token_.empty() && conexion_ == conexion) ||
                      token_ == token)) return false;
    activa_ = true;
    token_ = token;
    conexion_ = conexion;
    actividad_ = ahora;
    return true;
  }

  bool permite(uint16_t conexion, uint32_t ahora) {
    expirar(ahora);
    if (!activa_ || conexion_ != conexion || conexion == sinConexion) {
      return false;
    }
    actividad_ = ahora;
    return true;
  }

  bool soltar(const std::string &token, uint16_t conexion, uint32_t ahora) {
    if (probando_ || !permite(conexion, ahora) || token_ != token) return false;
    liberar();
    return true;
  }

  void desconectar(uint16_t conexion, uint32_t ahora) {
    if (conexion_ != conexion) return;
    conexion_ = sinConexion;
    actividad_ = ahora;
    // Compatibilidad: una app antigua no tiene token para retomar la reserva.
    if (token_.empty() && !probando_) liberar();
  }

  void probar(bool probando, uint32_t ahora) {
    probando_ = probando;
    actividad_ = ahora;
    if (!probando && token_.empty() && conexion_ == sinConexion) liberar();
  }

  bool ocupada(uint32_t ahora) {
    expirar(ahora);
    return activa_;
  }

  bool confirmar(const std::string &token, uint32_t ahora) {
    expirar(ahora);
    if (activa_ && !token_.empty() && token_ != token) return false;
    liberar();
    return true;
  }

  void liberar() {
    activa_ = false;
    probando_ = false;
    conexion_ = sinConexion;
    token_.clear();
  }

 private:
  void expirar(uint32_t ahora) {
    if (activa_ && !probando_ && ahora - actividad_ >= abandonoMs) liberar();
  }

  bool activa_ = false;
  bool probando_ = false;
  uint16_t conexion_ = sinConexion;
  uint32_t actividad_ = 0;
  std::string token_;
};

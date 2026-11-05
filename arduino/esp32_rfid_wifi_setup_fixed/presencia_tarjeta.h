#pragma once

#include <stdint.h>
#include <string.h>

// Solo una ausencia confirmada rearma la misma tarjeta. Un error del bus
// no demuestra que la retiraron, y tampoco debe impedir revisar el chip.
class PresenciaTarjeta {
 public:
  bool detectar(const uint8_t *uid, uint8_t longitud, uint32_t ahora) {
    if (longitud != 4 && longitud != 7) return false;
    const bool nueva = longitud != longitud_ || memcmp(uid_, uid, longitud) != 0;
    memcpy(uid_, uid, longitud);
    longitud_ = longitud;
    ultimaDeteccion_ = ahora;
    esperandoAusencia_ = false;
    return nueva;
  }

  bool sinTarjeta(uint32_t ahora) {
    if (!presente()) return false;
    if (!esperandoAusencia_) {
      ausenciaDesde_ = ahora;
      esperandoAusencia_ = true;
    } else if (ahora - ausenciaDesde_ >= 1000) {
      longitud_ = 0;
      esperandoAusencia_ = false;
      return true;
    }
    return false;
  }

  void fallo() { esperandoAusencia_ = false; }
  bool presente() const { return longitud_ != 0; }
  bool detectadaRecientemente(uint32_t ahora, uint32_t plazo) const {
    return presente() && ahora - ultimaDeteccion_ < plazo;
  }

 private:
  uint8_t uid_[7] = {};
  uint8_t longitud_ = 0;
  uint32_t ultimaDeteccion_ = 0;
  uint32_t ausenciaDesde_ = 0;
  bool esperandoAusencia_ = false;
};

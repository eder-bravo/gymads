#pragma once

#include <stdint.h>

enum class SonidoConfig {
  inicio, redesListas, conectando, wifiGuardado, completado, error
};

// Una nota por vuelta, con duración y pausa. No usa delay() ni llena la cola
// de tone(): el WiFi, el Bluetooth y el watchdog siguen siendo atendidos.
class SonidosConfiguracion {
 public:
  using Tocar = void (*)(unsigned int, unsigned long);

  explicit SonidosConfiguracion(Tocar tocar) : tocar_(tocar) {}

  void iniciar(SonidoConfig sonido) {
    static const Nota inicio[] = {{2400, 110, 90}, {3200, 110, 0}};
    static const Nota redes[] = {{3400, 80, 120}, {3400, 80, 0}};
    static const Nota conectando[] = {
        {2600, 80, 100}, {2600, 80, 100}, {2600, 80, 0}};
    static const Nota wifiGuardado[] = {{2800, 90, 80}, {3500, 90, 0}};
    static const Nota completado[] = {
        {2400, 110, 70}, {3000, 140, 70}, {3600, 260, 0}};
    static const Nota error[] = {
        {3200, 240, 100}, {2400, 240, 100}, {1800, 380, 0}};

    switch (sonido) {
      case SonidoConfig::inicio: elegir(inicio); break;
      case SonidoConfig::redesListas: elegir(redes); break;
      case SonidoConfig::conectando: elegir(conectando); break;
      case SonidoConfig::wifiGuardado: elegir(wifiGuardado); break;
      case SonidoConfig::completado: elegir(completado); break;
      case SonidoConfig::error: elegir(error); break;
    }
    // El hito nuevo sustituye las notas pendientes del anterior. La nota
    // que ya está sonando termina antes de emitir la siguiente.
    siguiente_ = 0;
  }

  void actualizar(uint32_t ahora) {
    if (ocupado_ && ahora - desde_ < esperaMs_) return;
    ocupado_ = false;
    if (notas_ == nullptr || siguiente_ >= cantidad_) return;

    const Nota &nota = notas_[siguiente_++];
    tocar_(nota.hz, nota.duracionMs);
    desde_ = ahora;
    esperaMs_ = nota.duracionMs + nota.pausaMs;
    ocupado_ = true;
  }

  // Permite terminar la melodía de éxito antes del reinicio programado,
  // incluso si alguna consulta al chip de tarjetas demoró el loop.
  bool enCurso() const {
    return ocupado_ || (notas_ != nullptr && siguiente_ < cantidad_);
  }

  bool configuracionEnCurso() const {
    return notas_ != nullptr && enCurso();
  }

  // Los avisos actuales de tarjeta y reset tienen prioridad. Si había una
  // nota de configuración sonando, tone() termina esa nota antes del aviso.
  // Se reserva también ese tiempo para que nada se encole encima del aviso.
  void reservarAvisoActual(uint32_t ahora, uint32_t duracionMs) {
    uint32_t restante = ocupado_ && ahora - desde_ < esperaMs_
        ? esperaMs_ - (ahora - desde_) : 0;
    notas_ = nullptr;
    desde_ = ahora;
    esperaMs_ = restante + duracionMs;
    ocupado_ = true;
  }

 private:
  struct Nota {
    unsigned int hz;
    uint16_t duracionMs;
    uint16_t pausaMs;
  };

  template <unsigned int N>
  void elegir(const Nota (&notas)[N]) {
    notas_ = notas;
    cantidad_ = N;
  }

  Tocar tocar_;
  const Nota *notas_ = nullptr;
  unsigned int cantidad_ = 0;
  unsigned int siguiente_ = 0;
  uint32_t desde_ = 0;
  uint32_t esperaMs_ = 0;
  bool ocupado_ = false;
};

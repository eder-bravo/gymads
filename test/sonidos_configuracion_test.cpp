#include <assert.h>
#include <stdint.h>
#include <iostream>
#include <vector>

#include "../arduino/esp32_rfid_wifi_setup_fixed/sonidos_configuracion.h"

struct Tono {
  uint32_t en;
  unsigned int hz;
  unsigned long duracionMs;
};

static uint32_t ahora;
static std::vector<Tono> emitidos;

static void tocar(unsigned int hz, unsigned long duracionMs) {
  emitidos.push_back({ahora, hz, duracionMs});
}

static void avanzar(SonidosConfiguracion &sonidos, uint32_t ms) {
  ahora += ms;
  sonidos.actualizar(ahora);
}

static std::vector<Tono> reproducir(SonidoConfig tipo) {
  ahora = 0;
  emitidos.clear();
  SonidosConfiguracion sonidos(tocar);
  sonidos.iniciar(tipo);
  sonidos.actualizar(ahora);
  for (int ms = 0; ms < 2000; ms++) avanzar(sonidos, 1);
  assert(!sonidos.enCurso());
  return emitidos;
}

int main() {
  // Todos se distinguen del pitido único de tarjeta y entre ellos.
  const SonidoConfig tipos[] = {
      SonidoConfig::inicio, SonidoConfig::redesListas,
      SonidoConfig::conectando, SonidoConfig::completado, SonidoConfig::error,
      SonidoConfig::wifiGuardado};
  std::vector<std::vector<Tono>> patrones;
  for (SonidoConfig tipo : tipos) {
    const auto patron = reproducir(tipo);
    assert(patron.size() >= 2);
    for (unsigned int i = 1; i < patron.size(); i++) {
      assert(patron[i].en > patron[i - 1].en + patron[i - 1].duracionMs);
    }
    for (const auto &previo : patrones) {
      bool igual = previo.size() == patron.size();
      for (unsigned int i = 0; igual && i < patron.size(); i++) {
        igual = previo[i].hz == patron[i].hz &&
                previo[i].en == patron[i].en &&
                previo[i].duracionMs == patron[i].duracionMs;
      }
      assert(!igual);
    }
    patrones.push_back(patron);
  }
  assert(patrones[3].front().hz < patrones[3].back().hz);  // Éxito sube.
  assert(patrones[4].front().hz > patrones[4].back().hz);  // Error baja.

  // Consultar seguido no encola notas encima de la que está sonando.
  ahora = 0;
  emitidos.clear();
  SonidosConfiguracion sonidos(tocar);
  sonidos.iniciar(SonidoConfig::inicio);
  sonidos.actualizar(ahora);
  for (int i = 0; i < 50; i++) sonidos.actualizar(ahora);
  assert(emitidos.size() == 1);

  // Un aviso actual cancela la melodía pendiente. Un nuevo hito espera a
  // que terminen la nota en curso y todo el aviso reservado (reset largo).
  avanzar(sonidos, 50);
  sonidos.reservarAvisoActual(ahora, 2000);
  sonidos.iniciar(SonidoConfig::completado);
  avanzar(sonidos, 2000);
  assert(emitidos.size() == 1);
  avanzar(sonidos, 150);
  assert(emitidos.size() == 2);
  assert(emitidos.back().hz == patrones[3].front().hz);

  // Un fallo sustituye el resto del aviso de conexión, sin cortar la nota
  // que ya se estaba reproduciendo.
  ahora = 0;
  emitidos.clear();
  SonidosConfiguracion fallo(tocar);
  fallo.iniciar(SonidoConfig::conectando);
  fallo.actualizar(ahora);
  fallo.iniciar(SonidoConfig::error);
  avanzar(fallo, 1);
  assert(emitidos.size() == 1);
  avanzar(fallo, 2000);
  assert(emitidos.size() == 2);
  assert(emitidos.back().hz == patrones[4].front().hz);

  // Aunque el loop tarde, no da por terminada la melodía después de la
  // primera nota: cada nota final debe emitirse antes de poder reiniciar.
  ahora = 0;
  emitidos.clear();
  SonidosConfiguracion lento(tocar);
  lento.iniciar(SonidoConfig::completado);
  lento.actualizar(ahora);
  avanzar(lento, 2500);
  assert(lento.enCurso());
  assert(emitidos.size() == 2);
  avanzar(lento, 1000);
  assert(lento.enCurso());
  assert(emitidos.size() == 3);
  avanzar(lento, 1000);
  assert(!lento.enCurso());

  // millis() puede dar la vuelta sin saltarse la pausa entre las notas.
  ahora = UINT32_MAX - 50;
  emitidos.clear();
  SonidosConfiguracion rollover(tocar);
  rollover.iniciar(SonidoConfig::inicio);
  rollover.actualizar(ahora);
  avanzar(rollover, 100);
  assert(emitidos.size() == 1);
  avanzar(rollover, 100);
  assert(emitidos.size() == 2);

  std::cout << "Sonidos: patrones distintos, pausas, prioridad de avisos, "
               "fallo, reinicio y rollover verificados.\n";
}

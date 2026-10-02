#include <assert.h>
#include <stdint.h>
#include <iostream>

#include "../arduino/esp32_rfid_wifi_setup_fixed/sesion_configuracion.h"

int main() {
  SesionConfiguracion sesion;
  assert(sesion.conectar(1, 0));
  assert(sesion.tomar("telefono-A", 1, 1));
  // Dos dispositivos llegan antes de que el loop procese nada: gana A.
  assert(!sesion.conectar(2, 2));
  assert(!sesion.tomar("telefono-B", 2, 3));
  assert(!sesion.permite(2, 4));
  assert(sesion.permite(1, 5));
  assert(!sesion.soltar("telefono-A", 2, 6));

  // Soltar el enlace para probar WiFi no deja entrar a otro dispositivo.
  sesion.probar(true, 10);
  sesion.desconectar(1, 11);
  assert(sesion.ocupada(200000));
  assert(!sesion.tomar("telefono-B", 2, 200001));
  assert(sesion.tomar("telefono-A", 3, 200002));
  assert(!sesion.soltar("telefono-A", 3, 200003));
  sesion.probar(false, 200004);  // Falló WiFi; A puede corregir la clave.
  assert(sesion.permite(3, 200005));
  assert(!sesion.permite(2, 200006));

  // Salir libera inmediatamente; una conexión ajena no libera la reserva.
  sesion.desconectar(2, 200007);
  assert(sesion.ocupada(200008));
  assert(sesion.soltar("telefono-A", 3, 200009));
  assert(!sesion.ocupada(200010));
  assert(!sesion.permite(3, 200011));
  assert(sesion.conectar(2, 200012));
  assert(sesion.tomar("telefono-B", 2, 200013));

  // Una app que desaparece no puede dejar bloqueado el lector para siempre.
  sesion.desconectar(2, 200014);
  assert(sesion.ocupada(200014 + SesionConfiguracion::abandonoMs - 1));
  assert(!sesion.ocupada(200014 + SesionConfiguracion::abandonoMs));
  assert(sesion.conectar(4, 400000));
  assert(sesion.permite(4, 400001)); // App antigua, sin token.
  sesion.desconectar(4, 400002);
  assert(!sesion.ocupada(400003));

  // Los latidos mantienen la reserva mientras una persona escribe despacio.
  assert(sesion.conectar(5, 500000));
  assert(sesion.tomar("telefono-lento", 5, 500001));
  for (uint32_t ahora = 520000; ahora < 1000000; ahora += 20000) {
    assert(sesion.permite(5, ahora));
    assert(!sesion.conectar(6, ahora + 1));
  }
  sesion.liberar();

  // Vuelta de millis(), tokens inválidos y reutilización de conn_id.
  assert(!sesion.tomar("", 1, 0));
  assert(!sesion.tomar(std::string(81, 'x'), 1, 0));
  assert(sesion.conectar(1, UINT32_MAX - 50));
  assert(sesion.tomar("rollover", 1, UINT32_MAX - 49));
  sesion.desconectar(1, UINT32_MAX - 48);
  assert(!sesion.conectar(1, 100));
  assert(!sesion.tomar("otro-telefono", 1, 101));
  assert(sesion.tomar("rollover", 1, 102));
  assert(sesion.permite(1, 103));
  // Al apagar BLE se retiene la reserva hasta el 100% de la misma app.
  sesion.desconectar(1, 104);
  sesion.probar(false, 105);
  assert(!sesion.confirmar("otro-telefono", 106));
  assert(sesion.ocupada(107));
  assert(sesion.confirmar("rollover", 108));
  assert(!sesion.ocupada(109));
  std::cout << "Sesión: dos teléfonos, datos aislados, reconexión, salida, "
               "abandono, latidos y rollover verificados.\n";
}

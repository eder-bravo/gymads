#include <assert.h>
#include <iostream>
#include "../arduino/esp32_rfid_wifi_setup_fixed/servidor_lector.h"

uint32_t relojSimulado = 0;
unsigned int NetworkClient::cerrados = 0;
bool socketBloqueado = false;
bool socketRoto = false;
std::deque<int> enviosParciales;
std::string bytesEnviados;

class ServidorPrueba : public ServidorLector {
 public:
  ServidorPrueba() : ServidorLector(80) {}
  void conectar(int datos = 0) {
    _currentClient.vivo = true;
    _currentClient.datos = datos;
    _currentStatus = HC_WAIT_READ;
    _statusChange = millis();
  }
  bool conectado() { return _currentClient.connected(); }
  bool sinDemora() { return _currentClient.sinDemora; }
  size_t escribir(const char *texto, size_t n) { return _currentClientWrite(texto, n); }
  size_t escribirFlash(const char *texto, size_t n) { return _currentClientWrite_P(texto, n); }
};

int main() {
  ServidorPrueba servidor;
  servidor.conectar();
  relojSimulado = 749;
  servidor.handleClient();
  assert(servidor.conectado() && servidor.clientesSinPeticion == 0);
  relojSimulado = 750;
  servidor.handleClient();
  assert(!servidor.conectado() && servidor.clientesSinPeticion == 1);
  assert(servidor.vueltas == 2); // Sigue atendiendo después de soltar al anterior.

  servidor.conectar(40); // Una petición que ya llegó no se corta por este límite.
  relojSimulado += 800;
  servidor.handleClient();
  assert(servidor.conectado() && servidor.clientesSinPeticion == 1);
  servidor.close();
  assert(!servidor.conectado() && servidor.escuchaCerrada);

  servidor.conectar();
  enviosParciales = {2, 1};
  assert(servidor.escribir("abcdef", 6) == 6);
  assert(servidor.sinDemora() && bytesEnviados == "abcdef");
  assert(servidor.fallosEnvio == 0);
  assert(servidor.escribirFlash("ghi", 3) == 3);
  assert(bytesEnviados == "abcdefghi");

  socketBloqueado = true;
  auto inicio = millis();
  assert(servidor.escribir("sin sitio", 9) == 0);
  assert(millis() - inicio == ServidorLector::esperaEnvioMs);
  assert(!servidor.conectado() && servidor.fallosEnvio == 1);
  socketBloqueado = false;

  servidor.conectar();
  socketRoto = true;
  assert(servidor.escribir("abc", 3) == 0);
  assert(!servidor.conectado() && servidor.fallosEnvio == 2);
  socketRoto = false;
  servidor.demora = 1200;
  servidor.handleClient();
  assert(servidor.maximoAtendiendoMs == 1200);

  relojSimulado = UINT32_MAX - 100;
  servidor.demora = 0;
  servidor.conectar();
  relojSimulado = 648;
  servidor.handleClient();
  assert(servidor.conectado());
  relojSimulado = 649;
  servidor.handleClient();
  assert(!servidor.conectado());
  servidor.conectar();
  socketBloqueado = true;
  relojSimulado = UINT32_MAX - 100;
  assert(servidor.escribir("abc", 3) == 0);
  assert(relojSimulado == 899);
  servidor.demora = 1;
  servidor.handleClient();
  assert(servidor.maximoAtendiendoMs == 1200);

  std::cout << "HTTP: cliente sin petición, cierre, envío parcial, memoria flash, "
               "socket bloqueado/roto, rollover y diagnóstico verificados.\n";
}

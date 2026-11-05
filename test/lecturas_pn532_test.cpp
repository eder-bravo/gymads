// Compilar desde la raíz según arduino/BLUETOOTH_ARCHITECTURE.md.
#include <assert.h>
#include <algorithm>
#include <iostream>
#include <vector>
#include "Arduino.h"
#include "PN532.h"
#include "PN532_I2C.h"
#include "../arduino/esp32_rfid_wifi_setup_fixed/presencia_tarjeta.h"

uint32_t relojSimulado = 0;

class ChipSimulado : public PN532Interface {
 public:
  std::vector<uint8_t> datos;
  int16_t error = 0;
  int8_t errorComando = 0;
  void begin() override {}
  void wakeup() override {}
  int8_t writeCommand(const uint8_t *, uint8_t, const uint8_t *, uint8_t) override {
    return errorComando;
  }
  int16_t readResponse(uint8_t *buf, uint8_t len, uint16_t) override {
    if (error < 0) return error;
    assert(datos.size() <= len);
    std::copy(datos.begin(), datos.end(), buf);
    return datos.size();
  }
};

static std::vector<uint8_t> tarjeta(std::vector<uint8_t> uid) {
  std::vector<uint8_t> trama = {1, 1, 0, 4, 8, uint8_t(uid.size())};
  trama.insert(trama.end(), uid.begin(), uid.end());
  return trama;
}

static std::vector<uint8_t> cabecera(uint8_t longitud) {
  return {1, 0, 0, 0xff, longitud, uint8_t(-longitud)};
}

int main() {
  ChipSimulado chip;
  PN532 nfc(chip);
  struct { uint8_t antes = 0x55; uint8_t uid[7] = {}; uint8_t despues = 0xaa; } salida;
  uint8_t longitud = 0;
  bool valida = false;
  const std::vector<uint8_t> uid = {0xcb, 0x25, 0x3b, 0x05};
  chip.datos = tarjeta(uid);
  assert(nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
  assert(valida && longitud == 4 && std::equal(uid.begin(), uid.end(), salida.uid));

  // Una trama corta después de una válida nunca repite el UID guardado.
  for (int tamano = 0; tamano < 10; ++tamano) {
    chip.datos = tarjeta(uid);
    chip.datos.resize(tamano);
    assert(!nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
    assert(!valida && longitud == 0);
  }
  // Longitudes arbitrarias no desbordan el búfer de 7 bytes.
  for (int n = 0; n <= 255; ++n) {
    if (n == 4 || n == 7) continue;
    chip.datos = {1, 1, 0, 4, 8, uint8_t(n)};
    chip.datos.resize(64, 0xab);
    assert(!nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
    assert(!valida && longitud == 0);
    assert(salida.antes == 0x55 && salida.despues == 0xaa);
  }
  chip.datos = tarjeta({1, 2, 3, 4, 5, 6, 7});
  assert(nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
  assert(longitud == 7 && valida);
  chip.datos = {0};
  assert(!nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
  assert(valida && longitud == 0);
  chip.datos = {0, 0xab}; // Ausencia con carga extra inesperada.
  assert(!nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
  assert(!valida && longitud == 0);
  chip.error = PN532_TIMEOUT;
  assert(!nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
  assert(!valida && longitud == 0);
  chip.error = 0;
  chip.errorComando = PN532_INVALID_ACK;
  assert(!nfc.readPassiveTargetID(0, salida.uid, &longitud, 200, &valida));
  assert(!valida && longitud == 0);
  chip.errorComando = 0;
  // SAMConfig y RFConfiguration responden sin carga útil: cero es éxito.
  chip.datos.clear();
  assert(nfc.SAMConfig() && nfc.setPassiveActivationRetries(0));
  chip.error = PN532_TIMEOUT;
  assert(!nfc.SAMConfig() && !nfc.setPassiveActivationRetries(0));
  chip.error = 0;
  chip.datos = {0x32, 1, 6, 7};
  assert(nfc.getFirmwareVersion() == 0x32010607);
  chip.datos = {0x32};
  assert(nfc.getFirmwareVersion() == 0);

  PresenciaTarjeta presencia;
  assert(presencia.detectar(uid.data(), uid.size(), 0));
  // Reproduce las 383 463 repeticiones del registro: solo el primer pase.
  for (uint32_t i = 1; i <= 383463; ++i) {
    if (i % 5 == 0) presencia.fallo();
    assert(!presencia.detectar(uid.data(), uid.size(), i * 50));
  }
  assert(!presencia.sinTarjeta(20000000));
  presencia.fallo();
  assert(!presencia.sinTarjeta(20002000));
  assert(!presencia.detectar(uid.data(), uid.size(), 20002001));
  assert(!presencia.sinTarjeta(20003000));
  assert(presencia.sinTarjeta(20004000));
  assert(presencia.detectar(uid.data(), uid.size(), 20004001));
  assert(presencia.detectadaRecientemente(20004002, 10000));
  assert(!presencia.detectadaRecientemente(20014001, 10000));
  const uint8_t otra[] = {1, 2, 3, 4};
  assert(presencia.detectar(otra, 4, UINT32_MAX - 500));
  assert(!presencia.sinTarjeta(UINT32_MAX - 499));
  assert(!presencia.sinTarjeta(499));
  assert(presencia.sinTarjeta(500));

  uint8_t buffer[64] = {};
  TwoWire wire;
  PN532_I2C transporte(wire);
  wire.demora = 50;  // Bus que tarda realmente 50 ms por consulta.
  relojSimulado = 0;
  assert(transporte.readResponse(buffer, sizeof(buffer), 200) == PN532_TIMEOUT);
  assert(relojSimulado <= 250);
  for (int pedido : wire.pedidos) assert(pedido == 6); // Sin segunda espera de 255 bytes.

  wire.demora = 0;
  wire.pedidos.clear();
  wire.respuestas = {cabecera(12)};
  assert(transporte.readResponse(buffer, sizeof(buffer), 200) == PN532_TIMEOUT);
  wire.respuestas = {{1, 0, 0, 0xff, 12, 0}}; // Checksum de longitud inválido.
  assert(transporte.readResponse(buffer, sizeof(buffer), 200) == PN532_INVALID_FRAME);
  wire.respuestas = {cabecera(1)}; // No caben TFI + comando.
  assert(transporte.readResponse(buffer, sizeof(buffer), 200) == PN532_INVALID_FRAME);
  wire.respuestas = {cabecera(255)};
  assert(transporte.readResponse(buffer, sizeof(buffer), 200) == PN532_INVALID_FRAME);

  // Ejercita el transporte real: ACK y respuesta válida de tarjeta.
  wire.respuestas = {{1, 0, 0, 0xff, 0, 0xff, 0}};
  const uint8_t comando[] = {0x4a, 1, 0};
  assert(transporte.writeCommand(comando, 3) == 0);
  auto datos = tarjeta(uid);
  auto trama = cabecera(datos.size() + 2);
  trama.push_back(0xd5);
  trama.push_back(0x4b);
  uint8_t suma = uint8_t(0xd5 + 0x4b);
  for (auto b : datos) { trama.push_back(b); suma += b; }
  trama.push_back(uint8_t(-suma));
  trama.push_back(0);
  wire.respuestas = {cabecera(12), trama};
  assert(transporte.readResponse(buffer, sizeof(buffer), 200) == 10);
  assert(std::equal(datos.begin(), datos.end(), buffer));
  trama.pop_back(); // Trama truncada, aunque diga que está lista.
  wire.respuestas = {cabecera(12), trama};
  assert(transporte.readResponse(buffer, sizeof(buffer), 200) == PN532_TIMEOUT);
  wire.errorEnvio = 2;
  assert(transporte.writeCommand(comando, 3) == PN532_INVALID_FRAME);

  std::cout << "PN532: tramas cortas, UID, ausencia, errores, duplicados, "
               "recuperación, rollover y límites I2C verificados.\n";
}

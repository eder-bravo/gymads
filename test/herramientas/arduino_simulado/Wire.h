#pragma once
#include "Arduino.h"
#include <deque>
#include <vector>

class TwoWire {
 public:
  std::deque<std::vector<uint8_t>> respuestas;
  std::deque<uint8_t> leyendo;
  std::vector<int> pedidos;
  uint32_t demora = 0;
  uint8_t errorEnvio = 0;
  void begin() {}
  void beginTransmission(int) {}
  size_t write(uint8_t) { return 1; }
  uint8_t endTransmission() { return errorEnvio; }
  uint8_t requestFrom(int, int cantidad) {
    pedidos.push_back(cantidad);
    relojSimulado += demora;
    leyendo.clear();
    if (respuestas.empty()) return 0;
    for (auto b : respuestas.front()) leyendo.push_back(b);
    respuestas.pop_front();
    return leyendo.size();
  }
  int read() {
    if (leyendo.empty()) return -1;
    int b = leyendo.front();
    leyendo.pop_front();
    return b;
  }
};

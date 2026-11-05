#pragma once
#include <stdint.h>
#include <string.h>
#define ARDUINO 10800
#define HEX 16

extern uint32_t relojSimulado;
inline unsigned long millis() { return relojSimulado; }
inline void delay(unsigned long ms) { relojSimulado += ms; }
struct PuertoSerialSimulado {
  template <typename T> void print(T, int = 10) {}
  template <typename T> void println(T) {}
};
static PuertoSerialSimulado Serial;

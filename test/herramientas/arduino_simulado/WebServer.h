#pragma once
#include "Arduino.h"

using PGM_P = const char *;
enum HTTPClientStatus { HC_NONE, HC_WAIT_READ, HC_WAIT_CLOSE };

class NetworkClient {
 public:
  bool vivo = false;
  bool sinDemora = false;
  int datos = 0;
  static unsigned int cerrados;
  bool connected() const { return vivo; }
  int available() const { return datos; }
  void stop() {
    if (vivo) cerrados++;
    vivo = false;
  }
  int fd() const { return vivo ? 7 : -1; }
  void setNoDelay(bool activo) { sinDemora = activo; }
};

class WebServer {
 public:
  explicit WebServer(int) {}
  virtual ~WebServer() = default;
  unsigned int vueltas = 0;
  unsigned long demora = 0;
  bool escuchaCerrada = false;
  virtual void handleClient() { vueltas++; delay(demora); }
  virtual void close() { escuchaCerrada = true; _currentStatus = HC_NONE; }
  void send(int, const char *, const char *) {} // Como el core: oculta ::send.
 protected:
  virtual size_t _currentClientWrite(const char *, size_t) { return 0; }
  virtual size_t _currentClientWrite_P(PGM_P, size_t) { return 0; }
  NetworkClient _currentClient;
  HTTPClientStatus _currentStatus = HC_NONE;
  unsigned long _statusChange = 0;
};

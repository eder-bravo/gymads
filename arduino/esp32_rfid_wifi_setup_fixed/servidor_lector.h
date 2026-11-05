#pragma once

#include <WebServer.h>
#include <errno.h>
#include <lwip/sockets.h>

// El WebServer del core atiende un solo cliente a la vez. Una conexión TCP
// abierta que no envía HTTP no debe consumir los 5 s durante los que la app
// ya agotó su propia espera (3 s). Conserva las rutas y el parser del core.
class ServidorLector : public WebServer {
 public:
  explicit ServidorLector(int puerto) : WebServer(puerto) {}

  static constexpr unsigned long esperaSinPeticionMs = 750;
  static constexpr unsigned long esperaEnvioMs = 1000;

  void handleClient() override {
    if (_currentStatus == HC_WAIT_READ && _currentClient.connected() &&
        !_currentClient.available() &&
        static_cast<uint32_t>(millis() - _statusChange) >= esperaSinPeticionMs) {
      _currentClient.stop();
      _currentClient = NetworkClient();
      _currentStatus = HC_NONE;
      clientesSinPeticion++;
    }
    const uint32_t inicio = millis();
    WebServer::handleClient();
    const uint32_t duracion = millis() - inicio;
    if (duracion > maximoAtendiendoMs) maximoAtendiendoMs = duracion;
  }

  void close() override {
    // WebServer::close() solo cierra la escucha: soltar también al cliente
    // actual al recuperar el servidor o al perder WiFi.
    _currentClient.stop();
    WebServer::close();
  }

  uint32_t clientesSinPeticion = 0;
  uint32_t fallosEnvio = 0;
  unsigned long maximoAtendiendoMs = 0;

 protected:
  size_t _currentClientWrite(const char *datos, size_t longitud) override {
    return escribirAcotado(datos, longitud);
  }

  size_t _currentClientWrite_P(PGM_P datos, size_t longitud) override {
    // En ESP32 la memoria de programa está mapeada; NetworkClient::write_P
    // también la envía como bytes normales.
    return escribirAcotado(datos, longitud);
  }

 private:
  size_t escribirAcotado(const char *datos, size_t longitud) {
    // Cabecera y JSON pequeños deben salir inmediatamente, sin esperar a
    // reunir paquetes.
    _currentClient.setNoDelay(true);
    // setTimeout() solo afecta a Stream. NetworkClient::write() puede
    // reintentar 10 veces con select de 1 s, así que el límite se aplica al
    // envío no bloqueante completo, incluyendo escrituras parciales.
    const uint32_t inicio = millis();
    size_t enviados = 0;
    const int socket = _currentClient.fd();
    while (socket >= 0 && enviados < longitud &&
           static_cast<uint32_t>(millis() - inicio) < esperaEnvioMs) {
      const int n = ::send(socket, datos + enviados, longitud - enviados, MSG_DONTWAIT);
      if (n > 0) {
        enviados += n;
      } else if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)) {
        delay(1);
      } else {
        break;
      }
    }
    if (enviados != longitud) {
      fallosEnvio++;
      _currentClient.stop();
    }
    return enviados;
  }
};

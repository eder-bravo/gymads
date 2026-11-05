#pragma once
#include <errno.h>
#include <deque>
#include <string>

#define MSG_DONTWAIT 1
extern bool socketBloqueado;
extern bool socketRoto;
extern std::deque<int> enviosParciales;
extern std::string bytesEnviados;

inline int send(int, const void *datos, size_t longitud, int flags) {
  if (flags != MSG_DONTWAIT) return 0;
  if (socketBloqueado || socketRoto) {
    errno = socketRoto ? EPIPE : EAGAIN;
    return -1;
  }
  int n = longitud;
  if (!enviosParciales.empty()) {
    n = enviosParciales.front();
    enviosParciales.pop_front();
    if (n > (int)longitud) n = longitud;
  }
  bytesEnviados.append(static_cast<const char *>(datos), n);
  return n;
}

# camera_desktop (copia local, solo Linux)

Copia de [camera_desktop 2.0.0](https://pub.dev/packages/camera_desktop)
(licencia MIT, ver `LICENSE`) que GymOne usa **solo en Linux**: la cámara
de escritorio (fotos de clientes) con GStreamer + V4L2.

Se dejó declarada únicamente la plataforma Linux en `pubspec.yaml`. El paquete
original también implementa macOS y Windows, y eso chocaba con
`camera_windows` ("Plugin camera:windows has conflicting direct dependency
implementations"). En Windows sigue `camera_windows` y en macOS `camera_macos`.

Para compilar en Linux hacen falta las librerías de GStreamer:

```
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good
```

Para actualizar: copiar `lib/`, `linux/`, `LICENSE` y `CHANGELOG.md` de la
nueva versión y volver a dejar solo `linux` en `flutter.plugin.platforms`.

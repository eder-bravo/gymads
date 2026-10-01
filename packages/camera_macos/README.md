# camera_macos: parche de GymOne

Código de [camera_macos 0.1.1](https://pub.dev/packages/camera_macos/versions/0.1.1),
con su licencia MIT original. Se incluyen solo `lib`, `macos`, manifiesto y licencia.

`AVCaptureDevice+Extension.swift` agrega los tipos `external`, `continuityCamera`
y `deskViewCamera` desde macOS 14 a la enumeración y apertura. El código publicado
abre solo `builtInWideAngleCamera`/`externalUnknown`; una cámara listada puede quedar
fuera de la lista usada para abrirla. Ambas rutas ahora descubren los mismos tipos.
En macOS anteriores se conserva el comportamiento original.

La app usa `enableAudio: false` y JPEG, sin pedir permiso de micrófono.
El `Info.plist` de Runner declara `NSCameraUseContinuityCameraDeviceType`.

Al actualizar desde upstream, conservar o verificar este cambio y compilar macOS.

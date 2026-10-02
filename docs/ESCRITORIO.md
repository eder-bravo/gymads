# GymOne en macOS y Windows

Rama de trabajo: `feat/version_escritorio`. Revisión: 1 de octubre de 2026.
Las versiones exactas resueltas están en `pubspec.lock`.

## Diseño de escritorio

macOS y Windows mantienen los colores, degradados, tipografía, formas y la
navegación de la app (Inicio → pantallas). El contenido tiene anchos máximos
según su uso: formularios de 720–800 puntos, configuración de 880, historiales
(ingresos y entradas) de 960 e inicio/listados de 1200. El fondo llena la
ventana y las barras, los campos, los botones al pie y las acciones flotantes
quedan alineados con el contenido. La cabecera de Inicio ocupa todo el ancho
y alinea su título con la columna de opciones.

Patrones propios de escritorio (en el teléfono no cambian):

- **Formularios largos como ventana modal**: alta y edición de cliente,
  producto, cobrar visita y nuevo acceso de personal se abren con
  `abrirFormulario()` sobre la pantalla de origen (720×680 como máximo,
  ajustada a la ventana). Un clic fuera no la cierra; se cierra con su botón.
- **Hojas inferiores como diálogo**: cobro de venta, detalle de ingreso,
  productos vendidos, apariencia y acciones de teléfono usan
  `mostrarHojaAdaptable()`; en escritorio no muestran asa.
- **Botón principal a la derecha**: `PieDeFormulario` y `BotonGuardar` toman
  el ancho de su texto (mínimo 200) en vez de cruzar la pantalla. El detalle
  de cliente agrupa Eliminar, Editar y Abonar en una fila.
- **Mouse**: cursor de mano y borde resaltado al pasar sobre los accesos de
  Inicio; clic derecho fija un producto en venta; las categorías se arrastran
  directamente para reordenarlas. Sin "jalar para refrescar": cada pantalla
  tiene su botón de recargar. En venta, un clic en la ficha agrega el
  producto y su borde se resalta al pasar el mouse (`AlPasarMouse`).
- **Configuración en dos columnas**, con Cerrar sesión aparte y a todo lo
  ancho debajo de las opciones.
- **Historiales alineados**: en ingresos y entradas el importe y el estado van
  al borde derecho de cada ficha, con cifras tabulares.

Clientes e inventario colocan tantas tarjetas por fila como quepan con al
menos 420 puntos (hasta tres), con altura natural; con texto grande pasan a
una columna. Punto de venta mantiene el catálogo y un carrito lateral de 380
puntos en ventanas amplias; vuelve al resumen inferior cuando falta ancho o
altura. El carrito lateral permite cambiar cantidades y usa el mismo cobro de
la app.

**Escala automática.** La interfaz está diseñada para una ventana de
1280×800 y crece en proporción cuando la ventana es mayor: textos, íconos,
tarjetas, espacios, diálogos y ventanas modales, en pasos de 5 % y hasta
160 % (`VentanaEscritorio.escalaPara`). Maximizada en un monitor de 2560×1440
se ve como una pantalla de 1600×880 ampliada; en 1920×1080, al 130 %. Las
pantallas reciben el tamaño lógico, así que sus anchos máximos y columnas no
cambian. Se respeta además la escala de texto del sistema y los formularios
siguen desplazándose con poca altura. La búsqueda, el foco, los datos del
formulario y el carrito se conservan al redimensionar o cambiar de escala; la
captura automática del lector continúa funcionando y se pausa mientras hay
una ventana modal abierta.

**Fácil de usar para cualquiera** (revisión con ui-ux-pro-max, solo en
escritorio; el teléfono queda idéntico):

- **Acciones con texto, nada escondido en íconos.** La acción principal de
  cada pantalla va en la barra con su nombre (`AccionDeBarra`: "Nuevo
  cliente", "Nuevo producto", "Nueva categoría", "Nuevo acceso"); Categorías
  y Personal ya no usan botón flotante. En las filas, las acciones más usadas
  se ven como botones ("Editar", "Stock", "Cambiar rol", "Código nuevo") y el
  resto va en "Más" (`AccionesDeFila`). Clic en un producto lo abre para
  editar. Mi cuenta y Control de accesos dicen "Editar" y "Cambiar hora".
- **Botones a su ancho y en fila** (`FilaDeBotones`): Lector, Permisos,
  Escáner, asistente del lector y el cobro de venta. Los formularios en
  ventana tienen "Cancelar" junto a guardar, y Escape los cierra.
- **Letra legible:** ningún texto informativo por debajo de 14 (`legible()`).
- **Títulos y textos uniformes** (`PlataformaApp.elegir`): minúscula inicial
  ("Mi cuenta", "Detalle del cliente", "Registro"), importes con separador de
  miles (`dinero()`), "1 transacción".
- **Configuración del lector:** botón "Cancelar" en cada paso del asistente,
  la computadora como primer ícono, errores en un recuadro, botones de "Buscar
  de nuevo" / "Escribir otra red" que bajan de renglón con texto grande (antes
  se salían de la pantalla). Los interruptores del lector explican qué hacen.
- **Escáner de códigos:** tres formas de conectarlo con ícono; prefijo,
  sufijo y modo serie dentro de "Opciones avanzadas".
- **Otros:** precios en dos columnas, tooltips en los íconos que no tenían,
  "Subir" y "Bajar" como alternativa a arrastrar categorías, la cámara con
  ancho de lectura y el error técnico en "Ver detalles".

`test/escritorio_compacto_test.dart` genera capturas de 37 pantallas,
diálogos y pasos del asistente: escritorio maximizado (`pantallas/`), laptop
(`laptop/`) y teléfono (`build/capturas_movil/<carpeta>`). Las del teléfono
se generan aparte (`--plain-name 390`) y se comparan con
`test/herramientas/comparar_capturas.py ANTES DESPUES 0`: tras esta revisión
las 72 pantallas que existen en el teléfono quedaron idénticas píxel a píxel
(solo cambió la cámara de escritorio, que el teléfono no usa).

**Inicio de escritorio** (`home/views/inicio_escritorio.dart`) es una rejilla
"bento" que llena la ventana, siguiendo la recomendación de ui-ux-pro-max
para tableros:

- Vender, el módulo del mostrador, en una tarjeta grande; Abonar, Clientes e
  Inventario alrededor, con los degradados del teléfono, el ícono como marca
  de agua y una ligera ampliación al pasar el mouse. Si el rol no ve algún
  módulo, la rejilla se reacomoda (1 a 4 tarjetas).
- Debajo, los números de hoy (`ResumenDelDia`): ingresos cobrados, entradas
  y membresías que vencen en 7 días. Cada uno solo aparece con su permiso
  (ver ingresos, ver accesos, gestionar clientes), se vuelve a pedir cada vez
  que Inicio regresa al frente y abre su pantalla con un clic. Si un dato no
  carga se muestra "—" sin afectar a los demás.
- Configuración pasa a un botón en la cabecera, junto a la fecha.
- Atajos: ⌘/Ctrl + 1…6 abren las tarjetas en orden de lectura y
  ⌘/Ctrl + coma abre Configuración. Cada tarjeta muestra su atajo.

El recorrido de bienvenida conserva sus pasos: los números de ingresos y
entradas y el botón de Configuración llevan las claves de antes. En una
ventana de menos de 720 puntos se usa la lista del teléfono.

Los textos hablan del equipo y no del teléfono (`PlataformaApp.equipo`):
apariencia "Según el sistema", "Recibir avisos en este equipo", el asistente
del lector y los mensajes de Bluetooth. Los permisos de Bluetooth remiten a
Ajustes del Sistema › Privacidad y seguridad › Bluetooth. Las instrucciones
de los recorridos dicen "Haz clic" en lugar de "Toca".

`test/escritorio_layout_test.dart` verifica ambos destinos simulados con
ventanas de 1920×1000 hasta el mínimo, texto hasta el 200 %, cambios de
cantidad, cobro, lectura física tras redimensionar y el formulario como
ventana modal. Para generar capturas opcionales del render de Flutter con
datos de prueba, ejecutar ese archivo (o `test/escritorio_compacto_test.dart`,
que guarda las 26 pantallas maximizadas, en claro y oscuro y con sombras
reales, en `build/capturas_escritorio/pantallas`) con
`--dart-define=CAPTURAS_ESCRITORIO=true` y `FUENTES_CAPTURA` apuntando a
`bin/cache/artifacts/material_fonts` del SDK de Flutter. Se guardan en
`build/capturas_escritorio`.

### Tamaño de la ventana

La ventana se puede redimensionar y maximizar, con un contenido mínimo de
**960×600 puntos**: cabe en pantallas de 1366×768 y de 1920×1080 al 150 %,
descontando barras de tareas y de título. macOS lo aplica mediante
`contentMinSize`; Windows calcula el marco y la barra de título según el DPI
del monitor en `WM_GETMINMAXINFO`.

La primera vez abre en 1280×800, centrada y limitada al área visible del
monitor. macOS recuerda después el tamaño y la posición (`VentanaPrincipal`);
Windows centra la ventana en el área de trabajo en cada inicio.

`VentanaEscritorio` aplica además el mínimo dentro de Flutter, sobre el
navegador de la app. Si el sistema entrega un tamaño menor durante resize, o
se usa una ventana abierta antes de recompilar el runner, conserva un área de
960×600 y permite desplazarla horizontal y verticalmente. Mantiene montadas
las rutas y los diálogos al cruzar el límite, conservando campos y foco. Esta
protección solo se aplica a macOS y Windows. Los cambios nativos del tamaño
requieren detener la app y volver a ejecutarla; hot restart no los aplica.

Las pantallas conservan sus variantes compactas (resúmenes en varias filas,
fichas con el importe debajo del nombre, botón de cobro en su propia fila)
para texto grande y para el respaldo de `VentanaEscritorio`.
`test/escritorio_compacto_test.dart` cubre 26 pantallas/estados, el
formulario de producto y la selección de clientes en Abonar en macOS y Windows
simulados, con texto al 100, 130 y 200 % y ciclos desde 1920×1000 hasta
103×120 puntos.

Verificación de esta revisión: 534 pruebas aprobadas de la batería completa
(la falla restante es la preexistente de `test/widget_test.dart`), análisis
sin incidencias nuevas y compilación de macOS, con capturas a 2560×1410
(`*-maximizada.png`). En macOS la app abrió en 1280×800 centrada. La compilación nativa de Windows queda pendiente de una
computadora Windows.

## Escáner de códigos de barras

En macOS y Windows, **Punto de venta e Inventario escuchan el lector físico al
entrar**, sin botón de escanear ni pantalla adicional. En venta, cada lectura
agrega una unidad al carrito usando las mismas comprobaciones de existencias
del móvil. En inventario abre el ajuste de stock; un código nuevo ofrece dar
de alta el producto con el código ya puesto, según los permisos del usuario.
Un aviso junto al buscador muestra el resultado de la última lectura.

El formulario de productos, la prueba del escáner y la versión web conservan
su pantalla de lector físico. Android/iOS conservan el botón y el escaneo por
cámara.

Se admiten lectores en modo **HID/teclado**. USB, Bluetooth HID y receptores USB
compatibles introducen texto en el campo de lectura. GymOne no necesita abrir
un puerto USB ni buscar el escáner con BLE. El emparejamiento Bluetooth lo hace
el sistema operativo. La ventana de GymOne debe estar activa.

La captura automática de escritorio reconoce los caracteres rápidos que envía
el lector y su terminador Enter o Tab (incluye Enter numérico), con hasta
100 ms entre teclas. Conserva ceros iniciales, prefijo/sufijo y lecturas
repetidas. Si se escanea con el buscador seleccionado, recupera la búsqueda
anterior. Ahí los códigos de menos de tres caracteres deben estar registrados
o llevar el prefijo configurado, para distinguirlos de la escritura normal.

En **Configuración → Escáner de códigos** se guarda por equipo:

- Terminador Enter o Tab (incluye Enter del teclado numérico).
- Prefijo y sufijo literales que se quitan del código recibido.
- Prueba de lectura sin modificar productos o ventas.

Cada lectura terminada cuenta una vez. Escanear el mismo producto dos veces
cuenta dos unidades; las lecturas que llegan al campo mientras se procesa una
se encolan. La captura automática se pausa al abrir otro diálogo, el cobro,
un formulario, otra pantalla o el tour; se recupera al volver. No cambia el
stock sin confirmar el ajuste ni procesa códigos en campos de cantidad o
notas. Las lecturas pendientes se descartan al salir de la pantalla. En la
pantalla de prueba y el formulario de productos, el campo de lectura debe
estar enfocado.

Estos ajustes adaptan la app al lector; **no reprograman su firmware**.
Para cambiar HID/serie, idioma del teclado, terminador o simbologías se usan los
códigos del manual de cada fabricante. Aún falta identificar los modelos del
hardware del usuario. Los lectores configurados exclusivamente como serie/COM,
SPP o BLE GATT necesitan un transporte específico y no están cubiertos por HID.

| Equipo sin Bluetooth | Estrategia |
| --- | --- |
| Escáner USB con cable | Conectar y seleccionar HID/teclado; es la ruta principal. |
| Lector inalámbrico con receptor | Usar su receptor USB compatible; un receptor de 2.4 GHz no es un adaptador Bluetooth universal. |
| Lector únicamente Bluetooth HID | Adaptador Bluetooth USB compatible con el sistema y emparejamiento como teclado. |
| Lector RFID GymOne | Configurarlo desde el celular con la misma cuenta/gimnasio y conectarlo a la red local. La computadora lo descubre después por red. Como alternativa, usar un adaptador USB con BLE. |

## Cámaras para fotos de clientes

La pantalla de escritorio enumera las cámaras publicadas por el sistema,
permite elegir una, recuerda su identificador y permite actualizar la lista al
conectar una nueva. Si falta la cámara guardada, elige otra disponible. Ya no
exige una cámara trasera. No solicita micrófono.

Una aplicación que convierte el celular en webcam debe estar instalada y activa
en el sistema. La cámara debe aparecer como dispositivo de captura; una app de
streaming que solo ofrece una URL no se convierte automáticamente en webcam.
En Windows se enumeran los dispositivos de captura que expone Media Foundation.
En macOS se incluyen cámaras integradas, externas, virtuales y, desde macOS 14,
los tipos Continuity Camera y Desk View. La disponibilidad real depende del
sistema, controladores y requisitos de la aplicación que provee la webcam.

Las fotos se confirman con **Usar foto** o **Repetir**. La versión circular
recorta la misma región que muestra la guía. Los controladores se liberan al
cambiar cámara y al cerrar, incluso si la inicialización termina después.

## Permisos y lector RFID

| Plataforma | Comportamiento |
| --- | --- |
| macOS | Cámara, notificaciones y Bluetooth consultados/solicitados con APIs nativas TCC. Se agregaron descripción de Bluetooth, tipos Bonjour y entitlement Bluetooth en Debug/Release. |
| Windows | No pide Bluetooth Scan, Bluetooth Connect ni ubicación de Android. La webcam se habilita en Privacidad, incluyendo acceso para aplicaciones de escritorio. Se muestra Sin confirmar: el plugin de permisos existente devuelve granted sin comprobar ese bloqueo. |
| Web | No pide permisos nativos de móvil. El lector de barras es HID. El asistente BLE del RFID remite a las apps nativas. |

En macOS se solicitan primero cámara y Bluetooth. Las notificaciones se
solicitan sin esperar a que se conteste el aviso del sistema: una autorización
pendiente aparece como **Sin confirmar**, nunca como concedida. Las consultas
nativas tienen un límite de 5 segundos, y los diálogos de cámara/Bluetooth de
45 segundos; Dart también limita la espera si el canal no responde. Al volver
de los ajustes se consultan los estados otra vez.

**Continuar sin esperar** permanece disponible durante la solicitud. Detiene
los permisos que aún no se pidieron e ignora respuestas tardías al cerrar la
pantalla. Un diálogo que el sistema ya abrió se contesta en el propio sistema.
Los errores de permisos permiten continuar. En Windows se ofrece **Comprobar**
y el enlace a Privacidad; no se espera un diálogo de permiso de Android/iOS.
Después de modificar el código nativo de macOS hay que cerrar y volver a
ejecutar la app: hot reload/hot restart no recompilan Swift ni los entitlements.

El RFID sigue usando el protocolo de configuración del firmware por BLE y,
después, trabaja por la red del gimnasio. `flutter_blue_plus` se conserva para
móviles/macOS; Windows usa `universal_ble` sobre WinRT mediante un transporte
común. Se preservan UUIDs, reserva exclusiva, renovación, liberación y reintento.
Bluetooth HID del escáner de barras y BLE del RFID son dos conexiones distintas.

La búsqueda de red usa Bonjour/mDNS y HTTP. En escritorio considera las subredes
privadas de las interfaces activas, para equipos con Ethernet y WiFi. El fallback
sigue suponiendo redes /24, como el código previo; para redes con otra máscara
o adaptadores VPN pueden hacer falta ajustes adicionales. El firewall debe
permitir la red local. No se implementó provisión del RFID por cable: conectar
USB a ese firmware no lo convierte en escáner HID ni en canal de configuración.

## Renderizador de macOS

`macos/Runner/Info.plist` fija `FLTEnableImpeller` en `false`. Flutter 3.47.5
activa Impeller por defecto, y el cierre con `The texture and its descriptor
disagree about its size` coincide con un fallo del motor al reutilizar superficies
de tamaños distintos al cambiar la ventana. Se usa temporalmente **Skia sobre
Metal**, manteniendo la aceleración gráfica, hasta validar un SDK con el arreglo.
Este ajuste solo afecta a macOS; el backend Metal del registro no existe en Windows.

La opción se aplica al arrancar un binario recompilado, incluyendo Release.
Cerrar y volver a ejecutar; hot reload/hot restart no actualizan `Info.plist`.
Para depurar explícitamente con esta configuración:

```sh
flutter run -d macos --no-enable-impeller
```

No usar `--enable-impeller`, que sobrescribe el ajuste de la app. Un `try/catch`
de Dart no puede recuperar un cierre nativo del hilo de renderizado.

Referencias: [opción oficial de Flutter](https://docs.flutter.dev/perf/impeller#macos)
y [corrección propuesta para superficies de tamaño incorrecto](https://github.com/flutter/flutter/pull/192522).

Validación: en una app aislada que usa la vista previa real, el registro confirmó
`Using the Skia rendering backend (Metal)` sin pasar flags. El PDF siguió visible
al entrar/salir de pantalla completa y al ampliar/restaurar la ventana; el panel
de impresión abrió y canceló sin bloqueo ni errores de render. Pasaron las seis
pruebas de `test/impresion_pdf_test.dart`. Esta comprobación no envió trabajos a
una impresora física ni reproduce todos los posibles desencadenantes del cierre.

## Impresión de reportes

Los reportes son A4 fijos. La vista previa usa `dynamicLayout: false` para que
`printing` reciba el PDF antes de abrir el panel de impresión. El modo dinámico
de `PrintJob.knowsPageRange` en `printing` 5.14.3 espera con un semáforo en el
hilo principal de macOS, lo que puede bloquear Flutter al compartir ese hilo.
El documento se guarda una sola vez al abrir la vista previa y esos mismos
bytes se usan para visualizar, imprimir y compartir.

El aviso de `printing`/`share_plus` sobre Swift Package Manager es de
compatibilidad futura; la compilación actual los integra por CocoaPods y el
aviso permanece. No se modificaron los permisos de impresión, ya presentes
en Debug/Profile y Release.

Verificación de esta corrección: 12 pruebas dirigidas de impresión, caché del
PDF, fuentes y Material de Configuración/Lector; análisis de los archivos
afectados y compilación de macOS. En una app aislada con documento de prueba
se abrió y canceló dos veces el panel nativo sin bloqueo. No se envió un
trabajo a una impresora física. Se corrigieron además las superficies
Material que provocaban las excepciones `ListTile` del registro del usuario.

Antecedente del plugin: [bloqueo de impresión en macOS](https://github.com/DavBfr/dart_pdf/issues/1865).

## Auditoría de dependencias directas

| Dependencias | Decisión para escritorio |
| --- | --- |
| `camera`, `camera_windows`, `camera_macos` | `camera_windows` registrado para Windows. macOS usa un parche local de `camera_macos` 0.1.1 para descubrir/abrir también Continuity y Desk View; licencia y origen conservados en `packages/camera_macos`. |
| `image_picker` | Conservado para móviles/selección de archivos. No se usa su `ImageSource.camera` como fallback de escritorio: no trae UI de cámara por defecto. |
| `permission_handler` | Conservado para móviles. macOS usa el canal nativo; Windows evita respuestas granted ficticias. |
| `mobile_scanner` | Conservado para móviles; no se crea su controlador en escritorio/web. |
| `google_mlkit_text_recognition` | Solo Android/iOS. En escritorio/web se escribe el folio manualmente y se ocultan botones OCR. El servicio también comprueba la plataforma antes de crear el modelo. |
| `intl_phone_number_input` | Su plugin de teléfono se evita en escritorio. Campo Dart con validación de formato internacional y lada +52 para los 10 dígitos locales de México. |
| `flutter_blue_plus`, `universal_ble` | FBP para móviles/macOS; Universal BLE para Windows. Mismo protocolo del lector. |
| `just_audio`, `just_audio_windows` | Backend Windows añadido; macOS usa la implementación existente. |
| `flutter_local_notifications` | Inicialización/detalles específicos de macOS y Windows añadidos para avisos cuando la app está abierta en segundo plano. Windows tiene AUMID y GUID estables. |
| `flutter_foreground_task` | Solo Android; su servicio no se llama en escritorio. El sondeo de escritorio necesita que la app siga abierta y el equipo despierto. |
| `device_info_plus` | Soporta los sistemas de escritorio; diagnóstico BLE incluye versión/modelo de macOS y versión/build de Windows. |
| `bonsoir` | Discovery nativo en macOS/Windows; web no tiene mDNS nativo. |
| `shared_preferences`, `get_storage`, `path_provider` | Persistencia local; ajustes de escáner/cámara por dispositivo. No requieren permisos de almacenamiento de Android. |
| `flutter_cache_manager`, `cached_network_image` | Se conservan; la versión resuelta usa repositorio JSON en Windows, por lo que no necesita agregar SQLite FFI. |
| `google_sign_in`, `url_launcher`, `win32_registry` | El login de escritorio ya usa OAuth por navegador. Registro de protocolo de Windows separado mediante importación condicional para que web no importe FFI. |
| `share_plus`, `printing`, `pdf` | Compartir y reportes conservados con implementaciones de escritorio. Entitlement de impresión/archivos ya presente en macOS. |
| `flutter`, `flutter_localizations`, `cupertino_icons`, `get`, `http`, `intl`, `material_design_icons_flutter`, `flutter_dotenv`, `supabase_flutter`, `uuid`, `path`, `image`, `crypto`, `showcaseview` | Código Flutter/Dart sin backend móvil exclusivo en los flujos revisados. No requieren reemplazo por cambiar a escritorio. |
| `fluttertoast`, `network_info_plus` | Eliminados: no tienen usos en `lib` ni pruebas; se usan avisos Flutter y las interfaces de red del sistema. |
| `flutter_test`, `flutter_lints`, `flutter_launcher_icons` | Herramientas de desarrollo; se conservan. |

La revisión se hizo sobre manifiestos, código y documentación de los paquetes;
no equivale a probar cada dispositivo físico ni cada módulo de negocio.

## Construcción y verificación

Se utilizó Flutter 3.47.5 / Dart 3.13.4. El proyecto de macOS quedó con la
integración Swift Package Manager generada por este Flutter y sus resoluciones.
macOS mantiene mínimo 12.0. Windows necesita Visual Studio con el componente
Desktop development with C++, SDK de Windows y CMake 3.21+ (Universal BLE).
La primera compilación de WinRT puede descargar CppWinRT mediante NuGet.

```sh
flutter pub get
flutter analyze
flutter test test/escaner_automatico_test.dart test/escaner_fisico_test.dart test/permisos_escritorio_test.dart test/lector_windows_test.dart test/camaras_escritorio_test.dart
flutter build macos --debug
# Ejecutar en una computadora Windows:
flutter build windows --debug
# Verificación del código de barras web, sin desplegar:
flutter build web --debug
```

Pruebas cubren terminadores, repetición/cola, ceros iniciales, persistencia,
ausencia de escáner de cámara en escritorio, permisos TCC/Windows, falta de BLE,
filtro de lectores, reserva y liberación del firmware, cámaras virtuales,
selección guardada, cámara desconectada y cierre durante inicialización.
Las regresiones de permisos simulan un canal sin respuesta, errores de plugin,
cancelación antes del siguiente permiso y salida con una respuesta tardía.
`RunnerTests` comprueba el límite nativo y que Flutter reciba una sola respuesta.

Verificación local: compilaron macOS y web; las 21 pruebas nuevas pasaron.
La adaptación visual pasó 92 pruebas dirigidas (12 de escritorio para
macOS/Windows simulados y 80 regresiones), análisis de los 32 archivos
afectados sin incidencias y una nueva compilación de macOS. Se inspeccionaron
capturas de inicio, inventario, venta y formulario con datos de prueba.
La lectura automática pasó 44 pruebas dirigidas de escáner, inventario y carrito
(29 nuevas para captura automática, ejecutadas con macOS/Windows simulados).
La corrección posterior del bloqueo pasó las 21 pruebas de permisos (7 nuevas),
dos pruebas nativas de `RunnerTests`, el análisis de los archivos afectados sin
incidencias y una nueva compilación de macOS. Los diálogos de privacidad reales
y Windows todavía deben comprobarse en los equipos de destino.
La batería completa, antes de agregar la última prueba del envío WiFi, dio
380 aprobadas y una falla preexistente en `test/widget_test.dart`: el test del
contador conserva comentado `pumpWidget` y busca un contador que la app no tiene.
El análisis conserva tres warnings previos de almacenamiento/login, sin errores.
La compilación nativa de Windows y las pruebas físicas siguen pendientes.

Antes de distribuir: compilar en Windows y comprobar con los escáneres reales,
webcam externa y cámara virtual; probar venta, inventario, foto y configuración
RFID en cada sistema. La web compila, pero esta tarea no migró todas las rutas
previas que usan archivos `dart:io` o la red local a APIs de navegador.

Fuentes: [camera_windows](https://pub.dev/packages/camera_windows),
[camera_macos](https://pub.dev/packages/camera_macos),
[Universal BLE](https://pub.dev/packages/universal_ble),
[Image Picker: escritorio](https://pub.dev/packages/image_picker),
[Just Audio Windows](https://pub.dev/packages/just_audio_windows),
[notificaciones](https://pub.dev/packages/flutter_local_notifications),
[Continuity Camera](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/continuitycamera).

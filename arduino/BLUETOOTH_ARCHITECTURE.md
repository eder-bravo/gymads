# Lector GymOne: Bluetooth solo para configurar

Firmware: `esp32_rfid_wifi_setup_fixed/` (v6.7.0). App: `LectorBleService`,
`LectorRedService`, `LectorRepository` y el asistente `AgregarLectorView`.

## Cómo funciona

1. **Lector nuevo o formateado** → no tiene WiFi guardado → se anuncia por
   Bluetooth como `GymOne-XXXX` (últimos 4 de su MAC) y su LED parpadea rápido.
2. En la app: Configuración → Lector de tarjetas → **Agregar lector**. La app lo
   encuentra, le pide las redes que ve, la persona elige la del gimnasio y
   escribe la contraseña.
3. La app manda la orden y **suelta el Bluetooth**. El lector prueba la red con
   el Bluetooth en pausa (comparten antena: con el teléfono conectado, la
   negociación de la contraseña fallaba y parecía contraseña incorrecta).
   - Si conecta: guarda WiFi + gimnasio y **apaga Bluetooth conservando
     la conexión WiFi**, sin reiniciar ni pedir otra IP al módem.
   - Si falla: vuelve a anunciarse; la app se reconecta y lee el motivo.
4. La app espera las dos cosas a la vez: el lector en la red (mDNS
   `_gymone._tcp`, o barriendo la subred) o su respuesta por Bluetooth.
5. El lector queda registrado en el servidor (tabla `lectores`: id = MAC,
   última IP). Así cualquier teléfono del gimnasio sabe que hay lector y lo
   encuentra aunque el router le cambie la IP.

El trabajo diario (leer tarjetas) es por WiFi/HTTP, igual que antes.

### Sonidos de configuración

| Momento confirmado por el lector | Sonido |
|---|---|
| Se ofrece para configurar por Bluetooth | Dos notas cortas que suben de tono |
| Terminó de buscar y encontró redes WiFi | Dos pitidos agudos cortos |
| Recibió y aceptó los datos para conectar | Tres pitidos cortos |
| Se conectó y guardó el WiFi | Dos notas ascendentes breves |
| La app confirmó y guardó el lector (100%), o quedó vinculado por HTTP | Melodía de tres notas ascendentes, con final más largo |
| Falló la configuración o no encontró redes | Tres notas descendentes, más largas |

Las señales se emiten una vez por hito, sin bloquear el proceso ni sonar por
cada porcentaje estimado de la app. El pitido de tarjeta (3000 Hz, 120 ms) y
los avisos de reset conservan su tono y duración y tienen prioridad. El éxito
final se pide con `POST /api/confirmar_config {"gym_id": "...", "intento":
"token único"}` después de guardar en el teléfono. Solo lo acepta el dueño
cuando el lector ya trabaja normal. Repetir el token no repite la melodía.
La app muestra 100% al recibir esa confirmación; si el firmware es anterior,
avisa que se debe actualizar para escuchar el sonido final.

La búsqueda empieza sin la espera fija de 8 s y consulta la IP conocida en
paralelo con mDNS/subred. mDNS confirma desde que resuelve la dirección y el
barrido empieza a la vez. Cancelar la reconexión Bluetooth usa `queue:false`:
no espera un intento pendiente de hasta 15 s. El registro en el servidor continúa en segundo
plano: no retrasa la confirmación del lector conectado por la red local.

### Un dispositivo configura a la vez

El primero que abre una conexión obtiene la reserva; detectarlo en un
escaneo no lo reserva. La app 6.7+ conserva el enlace mientras se elige red
y escribe la contraseña. El anuncio sigue visible, con una bandera «ocupado»
en los datos de fabricante (`0xFFFF`, firma `GO`, formato 1). El segundo
dispositivo recibe «Otro dispositivo está configurando este lector».

La característica nueva `6b1a0008-5c1e-4f7a-9d2e-47796d416473` acepta
`tomar:token` y `soltar:token`; al leer responde `tuya`, `ocupado` o `libre`.
El token aleatorio no sale en lecturas ni anuncios. La app lo incluye como
`sesion` al pedir `/api/confirmar_config`: la reserva termina con el 100% de
esa misma app, no solo al apagar BLE. Todas las escrituras de
WiFi se autorizan por conexión, bajo el mismo mutex: dos dispositivos no
pueden mezclar nombre de red, contraseña y gimnasio. La reserva sobrevive
a la pausa de Bluetooth al probar WiFi y a un fallo para corregir la clave.

Salir mientras se elige o escribe libera la reserva. Leer la sesión cada 20 s la renueva;
sin actividad se libera a los 2 min, salvo durante la prueba de WiFi. Así
una persona puede escribir despacio y una app que desapareció, incluso
después de mandar la orden de conexión, no bloquea
el lector para siempre. `/api/discover` solo informa `config_ocupada`;
`/api/configurar` y `/api/terminar_config` devuelven 409 mientras hay reserva,
para que otro dispositivo no cierre ni modifique una configuración activa.
Durante la prueba de WiFi el anuncio Bluetooth está en pausa para dejar la
antena libre. Si otro dispositivo entra justo ahí sin haber detectado el
lector, la búsqueda explica que también puede estar siendo configurado.

Con firmware anterior, la app conserva el flujo sin reserva explícita.
Para el aviso y la protección completos se deben actualizar app y firmware.
El apagado de BLE se ejecuta desde `loop()` con `BLEDevice::deinit(false)`
(core ESP32 3.3.12), que permite volver a inicializarlo al cambiar de red.

### Cuándo se ofrece por Bluetooth (LED parpadeando rápido)
- **Sin WiFi guardado:** nuevo, reset con BOOT o desvinculado. Sale al
  configurarlo.
- **No encuentra su red:** a los **30 s** si recién encendió y nunca la
  encontró (lo cambiaron de lugar); a los **2 min** si ya estaba funcionando
  (un módem que se reinicia no debe disparar nada). Conserva WiFi y gimnasio y
  sigue reintentando: si la red vuelve, se reinicia y sigue normal.
- **Conectado pero sin gimnasio** (lo formatearon desde la red): para que
  "Agregar lector" también lo encuentre. Al reclamarlo se reinicia sin
  Bluetooth.
- **La app lo pide** con `POST /api/configurar {"gym_id": ...}` (solo el
  dueño, "Cambiar WiFi del lector"): 5 min.

### Desvincular, formatear y reset
| Acción | Quién | Olvida | Después |
|---|---|---|---|
| Desvincular (`POST /api/unclaim`) | solo el dueño | gimnasio **y WiFi** | se reinicia y se ofrece por Bluetooth: listo para agregarse en cualquier lugar |
| Formatear (`POST /api/reset`) | cualquiera en la red (pita) | solo el gimnasio | sigue en la red y se ofrece por Bluetooth; el nuevo gimnasio lo vincula por la red |
| Botón BOOT 3 s (en los primeros 10 s) | quien lo tiene en la mano | todo | como nuevo |

El WiFi se guarda solo en las preferencias del firmware (`WiFi.persistent(false)`);
al olvidarlo también se borra la copia que dejaron versiones anteriores en la
memoria del driver (`esp_wifi_restore()`). La contraseña del WiFi no viaja
dentro del aparato cuando se lo llevan.

## Protocolo (servicio `6b1a0001-5c1e-4f7a-9d2e-47796d416473`)

Todo en texto UTF-8. Cada valor en su propia característica.

| UUID (…-5c1e-4f7a-9d2e-47796d416473) | Nombre | Acceso | Contenido |
|---|---|---|---|
| `6b1a0002` | redes | leer | una red por línea, mejor señal primero (máx. 15): `<dBm>\t<seguridad>\t<nombre>`, seguridad = `abierta` \| `clave` \| `empresarial` \| `wep` |
| `6b1a0003` | ssid | escribir | red elegida |
| `6b1a0004` | clave | escribir | contraseña (vacía si es abierta) |
| `6b1a0005` | gym | escribir | gym_id |
| `6b1a0006` | orden | escribir | `escanear` \| `conectar` |
| `6b1a0007` | estado | leer + notificar | `listo`, `buscando_redes`, `conectando`, `ok:<ip>`, `error:clave`, `error:sin_red`, `error:sin_ip`, `error:seguridad`, `error:no_conecta`, `error:datos`, `error:otro_gimnasio` |

Tras escribir `conectar` la app **debe desconectarse** (si no, el lector la
corta a los 3 s). Cómo decide el lector:

- `error:clave`: la negociación de la contraseña falló 3 veces sin Bluetooth
  de por medio (o 2, al agotar los 30 s).
- `error:sin_ip`: la contraseña pasó (hubo asociación) pero el módem no dio
  dirección en 15 s.
- `error:sin_red` / `error:seguridad`: no encontró la red / la red usa una
  seguridad no compatible.
- `error:no_conecta`: cualquier otra cosa al agotar los 30 s.

Se conecta a la antena de **mejor señal** con ese nombre (busca en todos los
canales); antes tomaba la primera que encontraba, aunque fuera la lejana.

## Por qué se cayó la versión anterior (v3.1, commit f5e6fb5)

- Mandaba JSON de hasta 2 KB en **una** notificación. BLE entrega ~20-180
  bytes por paquete: el JSON llegaba cortado y la app esperaba la `}` para
  siempre. Ahora son valores cortos en características separadas.
- Conectaba el WiFi con `delay()` **dentro del callback BLE**: se congelaba la
  pila Bluetooth y el teléfono cortaba. Ahora el callback solo anota el pedido
  y `loop()` hace el trabajo sin bloquear.
- El Bluetooth estaba **siempre encendido**, compartiendo la radio de 2.4 GHz
  con el WiFi. Ahora solo existe en modo configuración.
- La app solo escuchaba notificaciones. Ahora también relee `estado` cada
  segundo, y si la conexión se cae a la mitad reconecta una vez.
- (v6.0.x) Probaba el WiFi con el teléfono conectado por Bluetooth y llamaba a
  `WiFi.begin()` encima de los reintentos del propio WiFi: los fallos por
  antena ocupada se contaban como contraseña incorrecta. Corregido en 6.1.0.

## Compilar

WiFi + BLE + servidor no caben en la partición por defecto (1.2 MB):

```
arduino-cli compile --fqbn esp32:esp32:esp32:PartitionScheme=huge_app \
  --libraries arduino/user_dir/libraries arduino/esp32_rfid_wifi_setup_fixed
```

En el IDE de Arduino: Herramientas → Partition Scheme → "Huge APP (3MB No OTA)".

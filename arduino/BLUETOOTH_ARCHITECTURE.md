# Lector GymOne: Bluetooth solo para configurar

Firmware: `esp32_rfid_wifi_setup_fixed/` (v6.4.0). App: `LectorBleService`,
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
   - Si conecta: guarda WiFi + gimnasio y se **reinicia** sin Bluetooth.
   - Si falla: vuelve a anunciarse; la app se reconecta y lee el motivo.
4. La app espera las dos cosas a la vez: el lector en la red (mDNS
   `_gymone._tcp`, o barriendo la subred) o su respuesta por Bluetooth.
5. El lector queda registrado en el servidor (tabla `lectores`: id = MAC,
   última IP). Así cualquier teléfono del gimnasio sabe que hay lector y lo
   encuentra aunque el router le cambie la IP.

El trabajo diario (leer tarjetas) es por WiFi/HTTP, igual que antes.

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

/*
 * GYMONE - ESP32 RFID Reader con WiFi
 * LECTOR RFID CON CONEXIÓN WIFI AUTOMÁTICA PARA GYMONE
 *
 * Versión 6.7.0 - WiFi para trabajar, Bluetooth solo para configurar
 * Dispositivo: ESP32 (clásico, con BLE)
 *
 * Compilar con una partición grande: WiFi + BLE + servidor no caben en la
 * de 1.2 MB que trae por defecto.
 *   arduino-cli compile --fqbn esp32:esp32:esp32:PartitionScheme=huge_app
 *
 * CAMBIOS v6.7.0:
 * - Sale del modo configuración apagando BLE sin reiniciar el WiFi.
 * - Una sesión reserva el lector para un dispositivo; los demás ven
 *   ocupado en el anuncio y no pueden mezclar ni sobrescribir los datos.
 *
 * CAMBIOS v6.6.1:
 * - La melodía final se pide por /api/confirmar_config, solo por el dueño,
 *   cuando la app termina y muestra 100%. Reintentar no la repite.
 * - Un aviso corto confirma el WiFi guardado antes del reinicio. Durante
 *   las melodías se pospone la consulta al chip para respetar las pausas.
 *
 * CAMBIOS v6.6.0:
 * - Sonidos propios para inicio, redes encontradas, datos recibidos,
 *   configuración correcta y errores. Las melodías avanzan desde loop(),
 *   sin detener la conexión ni alterar los pitidos de tarjetas y reset.
 *
 * CAMBIOS v6.5.2:
 * - Con la red de antes guardada pero ya fuera de alcance (lo cambiaron de
 *   lugar), la red nueva nunca conectaba: "la red está lejos" una y otra
 *   vez, hasta borrarlo con BOOT. El WiFi seguía buscando la vieja y no
 *   aceptaba la nueva mientras tanto. Ahora primero se corta ese intento, se
 *   comprueba que la nueva quedó puesta, y solo entonces cuentan los fallos.
 * - En modo configuración la red guardada ya no se busca en bucle (solo el
 *   reintento cada 30 s): el bucle ocupaba la antena que usa el Bluetooth.
 *
 * CAMBIOS v6.5.1:
 * - Soltaba al teléfono en el mismo instante en que se conectaba por
 *   Bluetooth ("sin actividad") y la app decía "No se pudo conectar con el
 *   lector". Los tiempos anotados por el Bluetooth, el WiFi o una petición a
 *   media vuelta del loop quedaban "en el futuro" y la resta daba 49 días
 *   (ver msDesde). Lo mismo reconectaba el WiFi "por silencio" justo después
 *   de contestar, y podía dar "sin_ip" al instante de conectar.
 * - Anuncio por Bluetooth cada 100-150 ms (antes 20-40 ms): en su red y
 *   ofreciéndose a la vez, al WiFi casi no le tocaba la antena y no
 *   contestaba a la app ("El lector no respondió", "Tu lector no aparece").
 * - /api/terminar_config con el teléfono aún soltando el Bluetooth: se
 *   reinicia en cuanto lo suelta (antes no hacía nada y se quedaba 5 min más
 *   ofreciéndose).
 * - Sin WiFi revisa la conexión cada medio segundo (antes cada 5 s): tras
 *   reiniciarse abre el servidor en cuanto hay red y la app lo encuentra
 *   antes.
 *
 * CAMBIOS v6.5.0:
 * - Salir de "Cambiar WiFi" sin cambiarlo ya no deja el lector "perdido":
 *     - en cuanto la app suelta el Bluetooth vuelve a su red de siempre
 *       (antes esperaba hasta 30 s), y sigue pasando tarjetas;
 *     - nuevo POST /api/terminar_config (solo el dueño): la app lo manda al
 *       salir y el lector se reinicia normal en unos segundos, sin esperar
 *       los 5 min del modo configuración.
 * - El chip de tarjetas (PN532) se revisa cada 10 s. Si deja de contestar
 *   se reinicia su conexión, y si no vuelve, el lector completo. Antes el
 *   lector seguía en la red pero ya no leía tarjetas hasta desconectarlo de
 *   la corriente.
 * - Sin el ahorro de energía del WiFi mientras el Bluetooth está apagado
 *   (el trabajo normal): contesta más rápido y no se pierde los mensajes con
 *   que la app lo busca en la red.
 * - Conectado pero sin que nadie le pregunte nada en 5 min: se reconecta al
 *   WiFi, por si quedó conectado solo en apariencia.
 * - Se reinicia también si la memoria queda muy fragmentada (no solo si
 *   queda poca), y /api/status dice por qué arrancó la última vez.
 *
 * CAMBIOS v6.4.2:
 * - "Cambiar WiFi" (POST /api/configurar) ya no enciende el Bluetooth
 *   encima del WiFi, el servidor y el mDNS en marcha: ahí el Bluetooth podía
 *   quedarse sin memoria y no anunciarse, y la app decía "no apareció ningún
 *   lector" aunque estuviera conectado. Ahora anota el pedido, se reinicia y
 *   arranca directo en modo configuración, igual que un lector nuevo: el
 *   Bluetooth primero y la red guardada después. Si nadie lo usa en 5 min,
 *   se reinicia y vuelve a trabajar normal.
 *
 * CAMBIOS v6.4.1:
 * - En modo configuración el lector dejaba de verse por Bluetooth al rato
 *   (sobre todo después de que un teléfono se conectaba y se iba), y solo
 *   volvía desconectándolo de la corriente. Se volvía a anunciar DENTRO del
 *   aviso de desconexión, cuando el Bluetooth todavía estaba cerrando el
 *   enlace: si ese arranque fallaba (y su único reintento también), el
 *   anuncio quedaba apagado para siempre. Ahora:
 *     - vuelve a anunciarse desde el loop, 500 ms después de la
 *       desconexión (como los ejemplos de Espressif);
 *     - mientras nadie está conectado, cada 30 s se asegura de que el
 *       anuncio siga activo;
 *     - si pasan 10 min sin que nadie se conecte, se reinicia solo (lo
 *       mismo que desconectarlo y volver a conectarlo);
 *     - un teléfono que se queda conectado 3 min sin mandar nada se suelta:
 *       mientras está conectado, el lector no se anuncia y ningún otro
 *       teléfono lo encontraba.
 * - Sin el "TWDT already initialized" al arrancar: el core ya trae el
 *   watchdog iniciado; ahora se reconfigura directamente.
 *
 * CAMBIOS v6.4.0:
 * - El lector se llama GymOne, como la app: por Bluetooth se anuncia como
 *   GymOne-XXXX, en la red como _gymone._tcp (gymone-xxxx.local) y en
 *   /api/discover responde device_id ESP32_RFID_GYMONE. La app sigue
 *   encontrando también a los lectores que aún no se actualizan.
 *
 * CAMBIOS v6.3.0:
 * - Los pases ya no se pierden. Cada vez que se acerca una tarjeta recibe un
 *   número de secuencia y se guardan los últimos 8; la app pregunta con
 *   GET /api/lecturas?desde=N qué pasó desde la última vez. Antes solo había
 *   "la última tarjeta", que se borraba 1 s después de retirarla: si la app
 *   no preguntaba justo en ese segundo (p. ej. mientras mostraba el aviso del
 *   pase anterior), el pase se perdía.
 * - Un pase por cada vez que se acerca la tarjeta: apoyada no se repite ni
 *   vuelve a pitar cada 3 s.
 * - /api/uid se conserva para versiones anteriores de la app.
 *
 * CAMBIOS v6.2.0:
 * - Desvincular (POST /api/unclaim, solo el dueño) deja el lector COMO NUEVO:
 *   olvida gimnasio y WiFi, se reinicia y se ofrece por Bluetooth. Antes
 *   conservaba el WiFi: no se podía agregar desde otra red y la contraseña
 *   del gimnasio se iba dentro del aparato.
 * - El WiFi ya no se guarda en la memoria propia del driver
 *   (WiFi.persistent(false)): olvidarlo lo borra de verdad.
 * - Recién encendido y sin encontrar su red (lo cambiaron de lugar), se
 *   ofrece por Bluetooth a los 30 s en vez de 2 min. Con el lector ya
 *   funcionando se siguen esperando 2 min (un módem que se reinicia).
 * - Conectado pero sin gimnasio (tras "Formatear", que conserva el WiFi):
 *   también se ofrece por Bluetooth. Al reclamarlo se reinicia sin él.
 * - El modo configuración sabe por qué se abrió y sale por la regla que le
 *   toca (antes un lector sin dueño con WiFi se habría reiniciado en bucle).
 *
 * CAMBIOS v6.1.0:
 * - El WiFi nuevo se prueba con el Bluetooth EN PAUSA. Comparten antena, y
 *   con el teléfono conectado la negociación de la contraseña fallaba por
 *   tiempo agotado: el lector decía "contraseña incorrecta" sin serlo. La
 *   app suelta el Bluetooth tras mandar la orden y vuelve a conectarse para
 *   leer el resultado; si funcionó, lo encuentra en la red.
 * - Ya no se llama a WiFi.begin() encima de los reintentos del propio WiFi
 *   (se estorbaban y cada choque contaba como un fallo de contraseña).
 * - Busca en todos los canales y se conecta a la antena de MEJOR señal. Antes
 *   tomaba la primera que encontraba con ese nombre, aunque fuera la lejana.
 * - Acepta módems con WPA (antes solo WPA2 o superior).
 * - "redes" incluye señal y tipo de seguridad: "<dBm>\t<seguridad>\t<nombre>".
 * - Nuevos errores: error:sin_ip (la contraseña pasó pero el módem no dio
 *   dirección) y error:seguridad (la red usa una seguridad no compatible).
 * - El nombre de la red ya no se recorta (hay módems con espacios al final).
 * - Los callbacks de Bluetooth usan un mutex en vez de una sección crítica.
 *
 * CAMBIOS v6.0.2:
 * - El watchdog reiniciaba el lector en modo configuración ("IDLE1 did not
 *   reset the watchdog"): vigilaba la tarea de reposo del núcleo 1 y el
 *   loop, sin WiFi, no le dejaba correr. Ahora solo vigila la del núcleo 0
 *   y el loop cede 1 ms por vuelta.
 *
 * CAMBIOS v6.0.1:
 * - Hasta 4 intentos con la red nueva antes de decidir. Con el Bluetooth
 *   activo el primer intento suele fallar por tiempo agotado, y la v6.0.0 lo
 *   tomaba como "contraseña incorrecta".
 * - Nuevo error:no_conecta para los fallos que no son de contraseña.
 * - La MAC se lee del eFuse: antes salía 000000000000 y todos los lectores
 *   terminaban en "-0000".
 *
 * CAMBIOS v6.0.0:
 * - Ya NO trae el WiFi escrito en el código ni una IP fija. El WiFi se
 *   configura desde la app por Bluetooth y la IP la da el router (DHCP).
 * - Modo configuración (Bluetooth LE) cuando:
 *     1. no hay WiFi guardado (lector nuevo, reset con BOOT o desvinculado),
 *     2. no encuentra su red: a los 30 s recién encendido, o a los 2 min si
 *        ya estaba funcionando (sin olvidar el gimnasio),
 *     3. está conectado pero sin gimnasio (lo formatearon),
 *     4. la app lo pide con POST /api/configurar (solo el dueño).
 * - El Bluetooth vive SOLO en ese modo. Para salir, el lector se reinicia:
 *   así, cuando el WiFi funciona, el Bluetooth ni siquiera se enciende y no
 *   le roba antena al WiFi (comparten la misma radio de 2.4 GHz).
 * - Se anuncia en la red por mDNS para que la app lo encuentre sin saber
 *   su IP.
 * - Las rutas HTTP se registran UNA vez. Antes se volvían a registrar en cada
 *   reinicio preventivo del servidor (cada 5 min) y la memoria se iba
 *   perdiendo poco a poco.
 * - Eliminado POST /api/network (IP fija por aparato): ya no hace falta.
 *
 * Por qué el Bluetooth anterior (v3.1) se desconectaba, y qué se hizo:
 * - Mandaba JSON largos en una sola notificación: BLE entrega ~20-180 bytes,
 *   el JSON llegaba cortado y la app esperaba para siempre. Ahora cada dato
 *   va en su propia característica, en texto corto.
 * - Conectaba el WiFi con delay() DENTRO del callback de BLE: la pila
 *   Bluetooth se congelaba y el teléfono cortaba. Ahora el callback solo
 *   anota el pedido y el loop hace el trabajo sin bloquear.
 * - Tenía el Bluetooth encendido siempre, compitiendo con el WiFi.
 *
 * Protocolo Bluetooth (servicio GYMONE_SERVICE_UUID, todo texto UTF-8):
 *   redes  (leer)            "<dBm>\t<seguridad>\t<nombre>" por línea, la
 *                            mejor señal primero. seguridad: abierta | clave |
 *                            empresarial | wep
 *   ssid   (escribir)        nombre de la red elegida
 *   clave  (escribir)        contraseña (vacía si la red es abierta)
 *   gym    (escribir)        gym_id del gimnasio que configura
 *   orden  (escribir)        "escanear" | "conectar"
 *   estado (leer, notificar) listo | buscando_redes | conectando | ok:<ip> |
 *                            error:clave | error:sin_red | error:sin_ip |
 *                            error:seguridad | error:no_conecta |
 *                            error:datos | error:otro_gimnasio
 *
 *   Tras escribir "conectar" la app DEBE desconectarse: el WiFi se prueba
 *   con el Bluetooth en pausa. Si falla, el lector vuelve a anunciarse y la
 *   app se reconecta para leer `estado`. Si funciona, se reinicia sin
 *   Bluetooth y la app lo encuentra en la red.
 *
 * CAMBIOS v5.2.0:
 * - El lector se VINCULA a un solo gimnasio (gym_id guardado en NVS)
 * - /api/uid y /api/uid_only exigen el gym_id correcto (403 si no)
 * - /api/discover dice "claimed" y "mine" SIN revelar nunca el gym_id guardado
 * - Reset de fábrica: mantener BOOT (GPIO0) 3 s en los primeros 10 s tras
 *   encender
 *
 * CAMBIOS v5.1.0:
 * - Buzzer en GPIO25: beep corto al detectar una tarjeta durante el escaneo
 *
 * MEJORAS HEREDADAS v4.3.0:
 * - Watchdog Timer, reconexión WiFi, reinicio preventivo del servidor HTTP,
 *   monitoreo de memoria
 */

#include <Wire.h>
#include <PN532_I2C.h>
#include <PN532.h>

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>  // Watchdog Timer
#include <Preferences.h>   // Memoria permanente (NVS): dueño del lector y WiFi
#include <esp_mac.h>       // MAC de fábrica (eFuse)
#include <esp_wifi.h>      // esp_wifi_restore()

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "sonidos_configuracion.h"
#include "sesion_configuracion.h"

#define FIRMWARE_VERSION "6.7.0"


// =================== CONFIGURACIÓN DEL BUZZER ===================
// tone() con duración no bloquea: en arduino-esp32 3.x corre en su propia
// tarea de FreeRTOS y se apaga sola.
#define BUZZER_BEEP_HZ   3000   // la más fuerte del barrido de prueba
#define BUZZER_BEEP_MS   120

// El barrido de frecuencias ya cumplió su propósito. Se deja apagado por si
// hace falta volver a afinarlo con otro buzzer.
#define BUZZER_MODO_PRUEBA false

// =================== CONFIGURACIÓN DE WATCHDOG Y RECOVERY ===================
#define WDT_TIMEOUT_SECONDS 30          // Reiniciar si no hay actividad por 30 segundos
#define WIFI_RECONNECT_INTERVAL 5000    // Verificar WiFi cada 5 segundos
#define WIFI_CHECK_SIN_RED 500          // ...y cada medio segundo mientras no hay
#define SERVER_RESTART_INTERVAL 300000  // Reiniciar servidor HTTP cada 5 minutos
#define HEARTBEAT_INTERVAL 1000         // Parpadeo de heartbeat cada 1 segundo
#define MEMORY_CHECK_INTERVAL 60000     // Verificar memoria cada 60 segundos
#define MIN_FREE_HEAP 10000             // Reiniciar si la memoria libre es menor a 10KB
// Aunque sobre memoria, si el bloque libre más grande es menor que esto ya no
// caben las respuestas ni los paquetes de red (memoria fragmentada).
#define MIN_BLOQUE_LIBRE 6000

// Conectado, pero nadie le pregunta nada en este tiempo. Con la app abierta
// pregunta cada segundo; tanto silencio puede ser que el WiFi quedó
// conectado solo en apariencia (el lector no se entera de que el módem ya
// no le pasa nada). Reconectarse cuesta unos segundos y lo arregla.
#define SILENCIO_ANTES_DE_RECONECTAR_MS 300000  // 5 min

// Revisión del chip de tarjetas (PN532), ver revisarPn532().
#define REVISAR_PN532_CADA_MS 10000
#define PN532_FALLOS_ANTES_DE_REINICIAR 3

// =================== MODO CONFIGURACIÓN (BLUETOOTH) ===================
// Sin WiFi durante este tiempo, el lector vuelve a ofrecerse por Bluetooth
// para que le cambien la red (p. ej. cambiaron la contraseña del módem).
// Con el lector ya funcionando se espera más: un módem que se reinicia tarda
// uno o dos minutos y no es motivo para reconfigurar nada.
#define SIN_WIFI_ANTES_DE_CONFIG_MS  120000  // 2 min
// Recién encendido y sin haber encontrado su red: casi seguro lo cambiaron
// de lugar. Se ofrece mucho antes.
#define SIN_WIFI_AL_ARRANCAR_MS      30000   // 30 s
// Cuánto dura el modo cuando lo pide la app estando conectado.
#define CONFIG_PEDIDA_DURACION_MS    300000  // 5 min
// Tiempo máximo para que el WiFi nuevo conecte.
#define CONECTAR_TIMEOUT_MS          30000   // 30 s

// UUIDs propios. La app filtra el escaneo por el del servicio, así solo
// aparecen lectores GymOne y no los audífonos del vecino. Sus valores NO se
// cambian: son como la app reconoce a los lectores, también a los que aún
// tienen un firmware anterior. No se ven en ninguna parte.
#define GYMONE_SERVICE_UUID  "6b1a0001-5c1e-4f7a-9d2e-47796d416473"
#define CHAR_REDES_UUID      "6b1a0002-5c1e-4f7a-9d2e-47796d416473"
#define CHAR_SSID_UUID       "6b1a0003-5c1e-4f7a-9d2e-47796d416473"
#define CHAR_CLAVE_UUID      "6b1a0004-5c1e-4f7a-9d2e-47796d416473"
#define CHAR_GYM_UUID        "6b1a0005-5c1e-4f7a-9d2e-47796d416473"
#define CHAR_ORDEN_UUID      "6b1a0006-5c1e-4f7a-9d2e-47796d416473"
#define CHAR_ESTADO_UUID     "6b1a0007-5c1e-4f7a-9d2e-47796d416473"
#define CHAR_SESION_UUID     "6b1a0008-5c1e-4f7a-9d2e-47796d416473"

#define MAX_REDES 15

// =================== PINES DEL HARDWARE ===================
#define PN532_SDA     26
#define PN532_SCL     27
#define LED_WIFI      2    // LED integrado del ESP32
#define BUZZER_PIN    25

void tocarNotaConfig(unsigned int hz, unsigned long duracionMs);
SonidosConfiguracion sonidosConfig(tocarNotaConfig);

// Botón BOOT de la placa, para el reset de fábrica.
//
// OJO: GPIO0 es un pin de "strapping". Si está en LOW en el momento del
// arranque, el ESP32 entra en modo de descarga y el programa ni siquiera
// corre. Por eso el gesto es mantenerlo pulsado con el equipo YA ENCENDIDO.
#define BOTON_RESET_PIN       0
#define RESET_MANTENER_MS     3000   // 3 s pulsado para borrar todo

// El botón solo hace algo durante los primeros segundos tras encender, para
// que un dedo curioso en plena jornada no borre la configuración.
#define RESET_VENTANA_MS      10000  // 10 s desde el arranque

// =================== VARIABLES GLOBALES ===================
PN532_I2C *pn532i2c;
PN532 *nfc;
WebServer server(80);
Preferences prefs;

// gym_id del dueño. Vacío = lector sin vincular. NUNCA se devuelve en
// ninguna respuesta: si se filtrara, otro gimnasio podría suplantar al dueño.
String gymIdVinculado = "";

// WiFi guardado en NVS. Vacío = lector sin configurar.
String wifiSsid = "";
String wifiClave = "";

// Identidad del aparato: la MAC sin ":". Va en mDNS y en /api/discover para
// que la app reconozca SU lector aunque cambie de IP.
String idLector = "";
String nombreCorto = "";  // últimos 4 de la MAC, para "GymOne-XXXX"

unsigned long botonPulsadoDesde = 0;

// Reinicio diferido: nunca se reinicia dentro de un handler, para que la
// respuesta alcance a salir.
unsigned long reinicioPendienteEn = 0;

// Estado de red
bool wifiConnected = false;
bool serverRunning = false;
bool mdnsActivo = false;
unsigned long desconectadoDesde = 0;  // 0 = conectado (o nunca intentó)
// Último empujón a la red guardada (ver revisarWifi).
unsigned long ultimoReintentoWifi = 0;
// La última vez que alguien le preguntó algo por la red.
unsigned long ultimaPeticionEn = 0;

// Chip de tarjetas: si contesta, y si llegó a funcionar desde que encendió
// (sin eso, un chip desconectado reiniciaría el lector en bucle).
bool pn532Ok = false;
bool pn532FuncionoDesdeArranque = false;
uint8_t fallosPn532 = 0;
unsigned long ultimaRevisionPn532 = 0;

// Motivo de la última desconexión, lo llena el evento de WiFi.
volatile uint8_t ultimaRazonDesconexion = 0;

// RFID
String lastUid = "NO_CARD";

// Registro de pases. Cada vez que se ACERCA una tarjeta se le da un número
// de secuencia y se guarda. La app pregunta "¿qué pasó desde el número N?"
// (GET /api/lecturas), así que un pase no se pierde aunque la tarjeta se
// retire antes de que la app vuelva a preguntar, ni aunque pasen dos
// tarjetas seguidas. Antes solo existía "la última tarjeta", que se borraba
// 1 s después de retirarla.
#define LECTURAS_GUARDADAS 8
struct Lectura {
  uint32_t seq;
  char uid[21];
  unsigned long en;  // millis() del pase
};
Lectura lecturas[LECTURAS_GUARDADAS];
uint32_t lecturaSeq = 0;
unsigned long sinTarjetaDesde = 0;  // 0 = hay tarjeta (o nunca hubo)
unsigned long lastCardReadTime = 0;
String lastScannedCard = "";

// Monitoreo
unsigned long lastWiFiCheck = 0;
unsigned long lastServerRestart = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastMemoryCheck = 0;
unsigned long systemUptime = 0;

// =================== ESTADO DEL MODO CONFIGURACIÓN ===================
bool modoConfig = false;
unsigned long modoConfigHasta = 0;   // solo con CONFIG_PEDIDO_APP

// Por qué está en modo configuración. Decide cuándo sale.
enum MotivoConfig {
  CONFIG_SIN_RED_GUARDADA,  // nuevo, reset con BOOT o desvinculado: sale al configurarlo
  CONFIG_SIN_CONEXION,      // no encuentra su red: sale si vuelve
  CONFIG_SIN_DUENO,         // conectado pero sin gimnasio: sale al reclamarlo
  CONFIG_PEDIDO_APP,        // "Cambiar WiFi" desde la app: sale a los 5 min
};
MotivoConfig motivoConfig = CONFIG_SIN_RED_GUARDADA;

// Si desde que encendió llegó a conectarse. Sin conectar nunca, lo más
// probable es que lo hayan llevado a otro lugar.
bool yaConectoDesdeArranque = false;

// Al reiniciar, borrar también la copia del WiFi que guarda el propio driver
// (desvincular y reset con BOOT).
bool borrarWifiAlReiniciar = false;
bool bleIniciado = false;
volatile bool clienteBleConectado = false;

// Guardián del anuncio por Bluetooth (ver cuidarAnuncioBle).
#define REANUNCIAR_TRAS_DESCONEXION_MS 500
#define REFRESCAR_ANUNCIO_MS 30000
#define REINICIO_SIN_USO_CONFIG_MS 600000  // 10 min
#define SOLTAR_CLIENTE_INACTIVO_MS 180000  // 3 min
// Cuándo se fue la app (lo pone el callback; el loop vuelve a anunciar).
volatile unsigned long bleDesconectadoEn = 0;
// La última vez que una app se conectó, escribió algo o se fue.
volatile unsigned long ultimaActividadBle = 0;
unsigned long ultimoRefrescoAnuncio = 0;

// /api/terminar_config llegó con un teléfono todavía conectado por
// Bluetooth: casi siempre el mismo que acaba de salir, que aún lo está
// soltando. Si lo suelta en este plazo, se reinicia (ver cuidarAnuncioBle);
// si sigue conectado más, es que alguien lo está configurando.
#define TERMINAR_AL_SOLTAR_MS 10000
unsigned long terminarPedidoEn = 0;  // 0 = no se pidió

BLEServer *servidorBle = nullptr;
BLECharacteristic *chRedes = nullptr;
BLECharacteristic *chEstado = nullptr;
BLECharacteristic *chSesion = nullptr;
String estadoConfigActual = "listo";
SesionConfiguracion sesionConfig;
bool anuncioOcupado = false;
volatile bool refrescarAnuncio = false;
bool cerrarBlePendiente = false;

// Lo que escribe la app. Los callbacks de BLE corren en otra tarea: solo
// copian el valor y levantan una bandera; el loop hace el trabajo.
//
// Un mutex y no una sección crítica: copiar un String reserva memoria, y eso
// no se puede hacer con las interrupciones apagadas.
SemaphoreHandle_t candadoBle = nullptr;
String bleSsid = "";
String bleClave = "";
String bleGym = "";
volatile bool pedidoEscanear = false;
volatile bool pedidoConectar = false;
bool conectarPendiente = false;  // llegó "conectar" con un escaneo en curso

// Intento de conexión con el WiFi nuevo.
//
// El WiFi y el Bluetooth del ESP32 comparten antena. Con el teléfono
// conectado por Bluetooth, la negociación de la contraseña con el módem
// pierde paquetes y falla por "tiempo agotado", que es exactamente lo que
// pasa con una contraseña equivocada: el lector acusaba a la contraseña sin
// serlo. Por eso el intento se hace con el Bluetooth EN PAUSA: la app se
// desconecta después de mandar la orden y vuelve a conectarse para leer el
// resultado (si falló; si funcionó, lo encuentra en la red).
enum FaseConexion {
  CONEXION_INACTIVA,
  CONEXION_ESPERANDO_BLE,  // esperando a que la app suelte el Bluetooth
  CONEXION_SOLTANDO_WIFI,  // cortando el intento con la red vieja (ver abajo)
  CONEXION_PROBANDO,       // probando el WiFi con el Bluetooth en pausa
};
FaseConexion faseConexion = CONEXION_INACTIVA;
unsigned long faseDesde = 0;
String nuevoSsid = "";
String nuevaClave = "";
String nuevoGym = "";

// Lo que pasó durante el intento. Lo llena el evento de WiFi (otra tarea).
volatile bool intentoAsociado = false;  // la contraseña pasó (STA_CONNECTED)
volatile unsigned long asociadoEn = 0;
volatile uint8_t fallosClave = 0;       // la negociación de la clave falló
volatile uint8_t fallosSinRed = 0;      // no encontró la red
volatile uint8_t fallosSeguridad = 0;   // la red usa una seguridad no compatible
volatile uint8_t fallosOtros = 0;
volatile bool hayFalloNuevo = false;
volatile uint8_t razonFalloNuevo = 0;
int reintentosPropios = 0;
unsigned long reintentarEn = 0;

// Tras un "ok" ya no se aceptan más órdenes: el lector se reinicia.
unsigned long okDesde = 0;
String ultimaConfirmacionConfig = "";

bool escaneando = false;

// =================== DECLARACIONES ===================
void cargarConfiguracion();
void iniciarWifiGuardado();
void alConectarWifi();
void revisarWifi(unsigned long ahora);
void setupServerRoutes();
void iniciarServidor();
void iniciarMdns();
void handleGetUid();
void handleGetUidOnly();
void handleLecturas();
void registrarLectura(const String &uid);
void handleStatus();
void handleDiscover();
void handleClaim();
void handleUnclaim();
void handleReset();
void handleConfigurar();
void handleTerminarConfig();
void handleConfirmarConfig();
void anotarPeticion();
const char *motivoDeArranque();
bool peticionAutorizada();
void responderNoAutorizado();
String gymIdDeLaPeticion();
void entrarModoConfig(MotivoConfig motivo, unsigned long duracionMs = 0);
void iniciarBle();
void actualizarAnuncioBle();
void desconectarClientesBle();
void salirModoConfig();
bool configuracionOcupada();
void publicarEstado(const String &estado);
void atenderModoConfig(unsigned long ahora);
void cuidarAnuncioBle(unsigned long ahora);
void empezarEscaneo();
void revisarEscaneo();
void empezarConexionNueva();
void revisarConexionNueva(unsigned long ahora);
void terminarIntentoFallido(const char *veredicto);
void alEventoWifi(WiFiEvent_t evento, WiFiEventInfo_t info);
const char *tipoSeguridad(wifi_auth_mode_t modo);
void revisarBotonReset();
void handleStatusLeds();
void beepLectura();
void sonarAvisoActual(unsigned long duracionMs);
void sonarConfiguracion(SonidoConfig sonido);
void pruebaVolumenBuzzer();
void leerTarjetas();
bool iniciarPn532();
void revisarPn532(unsigned long ahora);
String getCardUID(uint8_t *uid, uint8_t uidLength);

// =================== TIEMPOS ===================

// Milisegundos desde [momento], con millis() leído DESPUÉS de [momento].
//
// No se resta del `ahora` que el loop toma al principio de cada vuelta:
// varios momentos los anota otra tarea (los callbacks de Bluetooth y de WiFi
// corren en el otro núcleo) o un handler HTTP a media vuelta, y quedaban
// "en el futuro". La resta sin signo daba la vuelta y parecía que habían
// pasado 49 días: el lector soltaba al teléfono en el mismo instante en que
// se conectaba ("sin actividad"), o se reconectaba al WiFi "por silencio"
// justo después de contestar. Un momento en el futuro cuenta como 0.
unsigned long msDesde(unsigned long momento) {
  long transcurrido = (long)(millis() - momento);
  return transcurrido < 0 ? 0 : (unsigned long)transcurrido;
}

// =================== CALLBACKS DE BLUETOOTH ===================

class ServidorCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *servidor, esp_ble_gatts_cb_param_t *param) override {
    clienteBleConectado = true;
    bleDesconectadoEn = 0;
    ultimaActividadBle = millis();
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
      bool estabaOcupada = sesionConfig.ocupada(millis());
      if (sesionConfig.conectar(param->connect.conn_id, millis()) &&
          !estabaOcupada) {
        bleSsid = bleClave = bleGym = "";
        pedidoEscanear = pedidoConectar = false;
      }
      xSemaphoreGive(candadoBle);
    }
    refrescarAnuncio = true;
    Serial.println("[BLE] App conectada");
    // Intervalo de conexión más holgado (60-120 ms en vez de los ~30 ms de
    // iOS): el Bluetooth ocupa menos la antena mientras el WiFi busca redes.
    // Está dentro de lo que aceptan iOS y Android.
    servidor->updateConnParams(param->connect.remote_bda, 48, 96, 0, 400);
  }

  void onDisconnect(BLEServer *servidor,
                    esp_ble_gatts_cb_param_t *param) override {
    // El SDK actualiza el contador después del callback.
    clienteBleConectado = servidor->getConnectedCount() > 1;
    ultimaActividadBle = millis();
    Serial.println("[BLE] App desconectada");
    // Aquí NO se vuelve a anunciar: el Bluetooth todavía está cerrando el
    // enlace y el arranque puede fallar sin aviso (el lector quedaba
    // invisible hasta desconectarlo). Lo hace el loop medio segundo después
    // (cuidarAnuncioBle), y no mientras se prueba el WiFi.
    unsigned long ahora = millis();
    if (!clienteBleConectado) bleDesconectadoEn = ahora == 0 ? 1 : ahora;
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
      sesionConfig.desconectar(param->disconnect.conn_id, ahora);
      xSemaphoreGive(candadoBle);
    }
  }
};

// Un solo callback para las características que se escriben. Solo copia el
// valor: nada de WiFi ni delay() aquí dentro, o se congela la pila BLE.
class EscrituraCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c, esp_ble_gatts_cb_param_t *param) override {
    ultimaActividadBle = millis();
    String valor = c->getValue();
    String uuid = c->getUUID().toString();

    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) != pdTRUE) return;
    if (!sesionConfig.permite(param->write.conn_id, millis())) {
      xSemaphoreGive(candadoBle);
      return;
    }
    if (uuid == CHAR_SSID_UUID) {
      bleSsid = valor;
    } else if (uuid == CHAR_CLAVE_UUID) {
      bleClave = valor;
    } else if (uuid == CHAR_GYM_UUID) {
      bleGym = valor;
    } else if (uuid == CHAR_ORDEN_UUID) {
      if (valor == "escanear") pedidoEscanear = true;
      if (valor == "conectar") {
        pedidoConectar = true;
        // Protege también el hueco entre este callback y la vuelta del loop.
        sesionConfig.probar(true, millis());
      }
    }
    xSemaphoreGive(candadoBle);
  }
};

class SesionCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c, esp_ble_gatts_cb_param_t *param) override {
    String valor = c->getValue();
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) != pdTRUE) return;
    if (valor.startsWith("tomar:")) {
      sesionConfig.tomar(valor.substring(6).c_str(), param->write.conn_id, millis());
    } else if (valor.startsWith("soltar:")) {
      if (sesionConfig.soltar(valor.substring(7).c_str(),
                             param->write.conn_id, millis())) {
        bleSsid = bleClave = bleGym = "";
        refrescarAnuncio = true;
      }
    }
    xSemaphoreGive(candadoBle);
  }

  void onRead(BLECharacteristic *c, esp_ble_gatts_cb_param_t *param) override {
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) != pdTRUE) {
      c->setValue("ocupado");
      return;
    }
    bool propia = sesionConfig.permite(param->read.conn_id, millis());
    if (propia) ultimaActividadBle = millis();
    bool ocupada = sesionConfig.ocupada(millis());
    c->setValue(propia ? "tuya" : (ocupada ? "ocupado" : "libre"));
    xSemaphoreGive(candadoBle);
  }
};

class EstadoCallbacks : public BLECharacteristicCallbacks {
  void onRead(BLECharacteristic *c, esp_ble_gatts_cb_param_t *param) override {
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) != pdTRUE) return;
    bool propia = sesionConfig.permite(param->read.conn_id, millis());
    if (propia) ultimaActividadBle = millis();
    c->setValue(propia ? estadoConfigActual : "ocupado");
    xSemaphoreGive(candadoBle);
  }
};

// =================== SETUP ===================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("=== GYMONE v" FIRMWARE_VERSION " ===");
  Serial.printf("Arranque por: %s\n", motivoDeArranque());

  esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT_SECONDS * 1000,
    // Solo la tarea de reposo del núcleo 0 (WiFi y Bluetooth). La del
    // núcleo 1 comparte núcleo con loop(): vigilarla hacía saltar el
    // watchdog cada vez que el loop giraba sin pausas, aunque nada estuviera
    // colgado. El loop se vigila aparte con esp_task_wdt_add(NULL).
    .idle_core_mask = (1 << 0),
    .trigger_panic = true
  };
  // El core ya arranca el watchdog: se reconfigura, y solo si no estaba se
  // inicia (al revés imprimía "TWDT already initialized" en cada arranque).
  if (esp_task_wdt_reconfigure(&wdt_config) != ESP_OK) {
    esp_task_wdt_init(&wdt_config);
  }
  esp_task_wdt_add(NULL);

  pinMode(LED_WIFI, OUTPUT);
  digitalWrite(LED_WIFI, LOW);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  pinMode(BOTON_RESET_PIN, INPUT_PULLUP);

  cargarConfiguracion();

#if BUZZER_MODO_PRUEBA
  pruebaVolumenBuzzer();
#endif

  // Lector de tarjetas
  Wire.begin(PN532_SDA, PN532_SCL);
  Wire.setClock(100000);
  delay(500);
  pn532i2c = new PN532_I2C(Wire);
  nfc = new PN532(*pn532i2c);
  if (iniciarPn532()) {
    pn532FuncionoDesdeArranque = true;
  } else {
    Serial.println("ERROR: PN532 no encontrado");
  }
  ultimaRevisionPn532 = millis();

  // WiFi en modo estación. El ahorro de energía del módem arranca activo (es
  // el predeterminado): el core lo exige mientras WiFi y Bluetooth conviven.
  // Trabajando normal, sin Bluetooth, se apaga al conectar (alConectarWifi).
  // El WiFi se guarda SOLO en nuestras preferencias ("gymone"), que se borran
  // al desvincular o con el reset. Si el driver guardara su propia copia, la
  // contraseña del gimnasio viajaría dentro del aparato aunque se lo lleven.
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  // Con varias antenas del mismo nombre (oficinas, campus, repetidores), el
  // modo por defecto se conecta a la PRIMERA que encuentra, aunque sea la
  // más lejana: la negociación falla por señal débil y parece contraseña
  // mala. Así busca en todos los canales y elige la de mejor señal.
  WiFi.setScanMethod(WIFI_ALL_CHANNEL_SCAN);
  WiFi.setSortMethod(WIFI_CONNECT_AP_BY_SIGNAL);
  // Acepta también módems viejos con WPA (sin el 2). Por defecto solo WPA2
  // o superior, y con uno de esos no conectaba nunca.
  WiFi.setMinSecurity(WIFI_AUTH_WPA_PSK);
  WiFi.onEvent(alEventoWifi);

  candadoBle = xSemaphoreCreateMutex();

  // La MAC de fábrica, leída del eFuse. WiFi.macAddress() devuelve ceros
  // hasta que la estación WiFi arranca, y todos los lectores salían como
  // "GymOne-0000".
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char macTexto[13];
  snprintf(macTexto, sizeof(macTexto), "%02X%02X%02X%02X%02X%02X", mac[0],
           mac[1], mac[2], mac[3], mac[4], mac[5]);
  idLector = String(macTexto);
  nombreCorto = idLector.substring(idLector.length() - 4);
  Serial.println("ID del lector: " + idLector);

  // Rutas HTTP: se registran UNA sola vez.
  setupServerRoutes();

  // "Cambiar WiFi" desde la app: se pidió antes de reiniciar. Se usa una
  // sola vez.
  prefs.begin("gymone", false);
  bool configPedida = prefs.getBool("abrir_config", false);
  if (configPedida) prefs.remove("abrir_config");
  prefs.end();

  if (wifiSsid.length() == 0) {
    // Recién salido de la caja (o formateado): directo a configuración.
    entrarModoConfig(CONFIG_SIN_RED_GUARDADA);
  } else if (configPedida) {
    // El Bluetooth primero, como un lector nuevo. La red guardada se retoma
    // sola (revisarWifi) en cuanto no haya un teléfono conectado ni una
    // búsqueda de redes en marcha.
    entrarModoConfig(CONFIG_PEDIDO_APP, CONFIG_PEDIDA_DURACION_MS);
    desconectadoDesde = millis();
  } else {
    iniciarWifiGuardado();
    desconectadoDesde = millis();
  }

  lastWiFiCheck = millis();
  lastServerRestart = millis();
  lastHeartbeat = millis();
  lastMemoryCheck = millis();
  systemUptime = millis();

  Serial.println("=== SISTEMA LISTO ===");
  Serial.print("Heap libre: ");
  Serial.println(ESP.getFreeHeap());
}

// =================== LOOP ===================

void loop() {
  esp_task_wdt_reset();
  unsigned long ahora = millis();
  sonidosConfig.actualizar(ahora);
  if (cerrarBlePendiente) salirModoConfig();

  if (ahora - lastMemoryCheck >= MEMORY_CHECK_INTERVAL) {
    lastMemoryCheck = ahora;
    uint32_t freeHeap = ESP.getFreeHeap();
    uint32_t bloque = ESP.getMaxAllocHeap();
    Serial.printf("[STATUS] Uptime: %lus, Heap: %u (bloque %u), WiFi: %s "
                  "(%d dBm), Config: %s, Tarjetas: %s, Última petición: "
                  "hace %lus\n",
                  (ahora - systemUptime) / 1000, freeHeap, bloque,
                  wifiConnected ? "OK" : "NO",
                  wifiConnected ? WiFi.RSSI() : 0, modoConfig ? "SI" : "NO",
                  pn532Ok ? "OK" : "NO",
                  ultimaPeticionEn == 0 ? 0 : msDesde(ultimaPeticionEn) / 1000);
    if (freeHeap < MIN_FREE_HEAP || bloque < MIN_BLOQUE_LIBRE) {
      Serial.println("[WARNING] Memoria baja - Reiniciando...");
      delay(500);
      ESP.restart();
    }
  }

  if (wifiConnected && serverRunning) {
    server.handleClient();
  }

  handleStatusLeds();
  revisarBotonReset();

  // Completar el aviso de éxito o reset antes de reiniciar. La lectura del
  // chip de tarjetas puede demorar una vuelta del secuenciador.
  if (reinicioPendienteEn != 0 && millis() >= reinicioPendienteEn &&
      !sonidosConfig.enCurso()) {
    if (borrarWifiAlReiniciar) {
      // La copia que pudo dejar una versión anterior del firmware en la
      // memoria permanente del driver (antes de WiFi.persistent(false)).
      // WiFi.disconnect(…, true) no basta: sin persistencia solo borra la RAM.
      esp_wifi_restore();
      delay(100);
    }
    ESP.restart();
  }

  if (wifiConnected && serverRunning && !sonidosConfig.configuracionEnCurso()) {
    leerTarjetas();
  }
  if (!sonidosConfig.configuracionEnCurso()) revisarPn532(ahora);

  if (modoConfig) {
    atenderModoConfig(ahora);
  }

  // Sin red se revisa más seguido: al arrancar (o al volver de un corte) el
  // servidor abre en cuanto hay WiFi, no hasta 5 s después.
  unsigned long revisarCada =
      wifiConnected ? WIFI_RECONNECT_INTERVAL : WIFI_CHECK_SIN_RED;
  if (ahora - lastWiFiCheck >= revisarCada) {
    lastWiFiCheck = ahora;
    revisarWifi(ahora);
  }

  // Cede el procesador 1 ms en cada vuelta. En modo configuración (sin
  // WiFi) no hay lectura de tarjetas ni servidor que hagan pausas, y el
  // loop giraba sin parar: acaparaba el núcleo y le quitaba tiempo a las
  // tareas de WiFi y Bluetooth.
  delay(1);
}

// =================== WIFI ===================

void cargarConfiguracion() {
  prefs.begin("gymone", true);
  gymIdVinculado = prefs.getString("gym_id", "");
  wifiSsid = prefs.getString("ssid", "");
  wifiClave = prefs.getString("pass", "");
  prefs.end();

  Serial.println(gymIdVinculado.length() > 0
                     ? "[VINCULACION] Lector vinculado a un gimnasio."
                     : "[VINCULACION] Lector SIN vincular.");
  Serial.println(wifiSsid.length() > 0
                     ? "[WiFi] Red guardada: " + wifiSsid
                     : "[WiFi] Sin red guardada.");
}

// Arranca la conexión con la red guardada y vuelve de inmediato. El loop
// revisa el resultado: aquí no se espera con delay().
void iniciarWifiGuardado() {
  if (wifiSsid.length() == 0) return;
  Serial.println("[WiFi] Conectando a " + wifiSsid + "...");
  // En modo configuración, sin reconexión automática: si la red ya no está
  // (lo cambiaron de lugar), el WiFi la buscaba sin parar, ocupando la antena
  // que necesita el Bluetooth. Ahí basta el reintento cada 30 s (revisarWifi).
  WiFi.setAutoReconnect(!modoConfig);
  WiFi.begin(wifiSsid.c_str(), wifiClave.c_str());
}

// Lo que hay que hacer cada vez que el WiFi queda arriba.
void alConectarWifi() {
  wifiConnected = true;
  yaConectoDesdeArranque = true;
  desconectadoDesde = 0;
  ultimaPeticionEn = millis();
  digitalWrite(LED_WIFI, HIGH);
  Serial.print("[WiFi] Conectado - IP: ");
  Serial.println(WiFi.localIP());

  // Sin Bluetooth, sin ahorro de energía: dormido a ratos, el WiFi tardaba en
  // contestar y a veces no oía cuando la app lo buscaba en la red. Con el
  // Bluetooth encendido no se puede: el core lo exige para que convivan.
  if (!bleIniciado) WiFi.setSleep(false);

  iniciarServidor();
  iniciarMdns();
}

void iniciarServidor() {
  // Siempre se cierra antes: tras probar una red nueva, el servidor pudo
  // quedar abierto de la conexión anterior aunque el lector lo diera por
  // cerrado.
  server.close();
  server.begin();
  serverRunning = true;
  lastServerRestart = millis();
}

// Se anuncia como _gymone._tcp con su id. Así la app lo encuentra aunque el
// router le cambie la IP.
void iniciarMdns() {
  if (mdnsActivo) MDNS.end();
  String host = "gymone-" + nombreCorto;
  host.toLowerCase();
  if (MDNS.begin(host.c_str())) {
    MDNS.addService("gymone", "tcp", 80);
    MDNS.addServiceTxt("gymone", "tcp", "id", idLector);
    MDNS.addServiceTxt("gymone", "tcp", "version", FIRMWARE_VERSION);
    mdnsActivo = true;
  } else {
    Serial.println("[mDNS] No se pudo iniciar");
    mdnsActivo = false;
  }
}

void revisarWifi(unsigned long ahora) {
  // Mientras se prueba una red nueva, el resultado lo decide
  // revisarConexionNueva(); aquí no se toca nada.
  if (faseConexion != CONEXION_INACTIVA) return;

  if (WiFi.status() == WL_CONNECTED) {
    if (!wifiConnected) alConectarWifi();

    // El WiFi volvió solo mientras se ofrecía configuración por culpa de un
    // corte: si nadie está configurando, se sale reiniciando.
    if (modoConfig && motivoConfig == CONFIG_SIN_CONEXION &&
        !clienteBleConectado && okDesde == 0) {
      Serial.println("[CONFIG] El WiFi volvió: saliendo del modo configuración");
      reinicioPendienteEn = millis() + 500;
      return;
    }

    // Conectado pero sin gimnasio (lo formatearon desde la red): se ofrece
    // también por Bluetooth, para que "Agregar lector" lo encuentre. Sale al
    // reclamarlo (ver handleClaim).
    if (!modoConfig && gymIdVinculado.length() == 0 && okDesde == 0 &&
        reinicioPendienteEn == 0) {
      entrarModoConfig(CONFIG_SIN_DUENO);
    }

    if (serverRunning && msDesde(lastServerRestart) >= SERVER_RESTART_INTERVAL) {
      // Reinicio preventivo. Las rutas ya están registradas: solo se
      // cierra y se abre el socket.
      server.close();
      server.begin();
      lastServerRestart = millis();
    }

    // Nadie le pregunta nada hace rato: se reconecta por si el WiFi quedó
    // conectado solo en apariencia. No mientras se ofrece por Bluetooth (ahí
    // la red la maneja el modo configuración).
    if (!modoConfig && msDesde(ultimaPeticionEn) >= SILENCIO_ANTES_DE_RECONECTAR_MS) {
      Serial.println("[WiFi] 5 min sin que nadie pregunte: reconectando por "
                     "si quedó colgado");
      ultimaPeticionEn = millis();
      WiFi.disconnect(false, false);
      iniciarWifiGuardado();
      ultimoReintentoWifi = ahora;
    }
    return;
  }

  // Desconectado
  if (wifiConnected) {
    Serial.printf("[WiFi] Desconectado (razón %u)\n", ultimaRazonDesconexion);
    wifiConnected = false;
    serverRunning = false;
    server.close();
    digitalWrite(LED_WIFI, LOW);
  }

  if (wifiSsid.length() == 0) return;  // nada que reintentar
  if (desconectadoDesde == 0) desconectadoDesde = ahora;

  // Sin WiFi un buen rato: se ofrece por Bluetooth para que le cambien la
  // red, pero conserva la actual y el gimnasio. Si la red vuelve, se va solo.
  // Recién encendido y sin haberla encontrado nunca, espera mucho menos: lo
  // más probable es que lo hayan llevado a otro lugar.
  unsigned long espera = yaConectoDesdeArranque ? SIN_WIFI_ANTES_DE_CONFIG_MS
                                                : SIN_WIFI_AL_ARRANCAR_MS;
  if (!modoConfig && msDesde(desconectadoDesde) >= espera) {
    entrarModoConfig(CONFIG_SIN_CONEXION);
  }

  // La reconexión automática del WiFi se encarga de los cortes normales. Esto
  // es un empujón cada 30 s por si se quedó quieto; más seguido cortaría un
  // intento que todavía está negociando.
  //
  // Mientras la app está conectada por Bluetooth, o se están buscando redes,
  // no se reintenta: los intentos de conexión abortan el escaneo.
  if (!clienteBleConectado && !escaneando &&
      msDesde(ultimoReintentoWifi) >= 30000) {
    ultimoReintentoWifi = ahora;
    iniciarWifiGuardado();
  }
}

// =================== MODO CONFIGURACIÓN ===================

void entrarModoConfig(MotivoConfig motivo, unsigned long duracionMs) {
  static const char *textos[] = {"sin WiFi guardado", "no encuentra su red",
                                 "sin gimnasio", "pedido por la app"};
  Serial.printf("[CONFIG] Entrando en modo configuración: %s\n",
                textos[motivo]);
  modoConfig = true;
  motivoConfig = motivo;
  modoConfigHasta = duracionMs > 0 ? millis() + duracionMs : 0;
  ultimaActividadBle = millis();
  ultimoRefrescoAnuncio = millis();
  if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
    sesionConfig.liberar();
    xSemaphoreGive(candadoBle);
  }

  iniciarBle();
  sonarConfiguracion(SonidoConfig::inicio);
  publicarEstado("listo");
  empezarEscaneo();
}

void iniciarBle() {
  if (bleIniciado) {
    BLEDevice::startAdvertising();
    return;
  }

  // Con el ahorro de energía del WiFi apagado (ver alConectarWifi) el core no
  // deja convivir WiFi y Bluetooth: se vuelve a encender antes.
  WiFi.setSleep(true);

  String nombre = "GymOne-" + nombreCorto;
  BLEDevice::init(nombre);
  // MTU grande: la contraseña y la lista de redes pasan en menos paquetes.
  // iOS negocia hasta ~185; Android hasta 517.
  BLEDevice::setMTU(247);

  BLEServer *servidor = BLEDevice::createServer();
  static ServidorCallbacks callbacksServidor;
  servidor->setCallbacks(&callbacksServidor);
  servidorBle = servidor;

  // 8 características: cada una ocupa ~3 handles, más el servicio.
  BLEService *servicio = servidor->createService(BLEUUID(GYMONE_SERVICE_UUID), 30);

  chRedes = servicio->createCharacteristic(
      CHAR_REDES_UUID, BLECharacteristic::PROPERTY_READ);
  chRedes->setValue("");

  static EscrituraCallbacks escritura;
  const char *escribibles[] = {CHAR_SSID_UUID, CHAR_CLAVE_UUID, CHAR_GYM_UUID,
                               CHAR_ORDEN_UUID};
  for (const char *uuid : escribibles) {
    BLECharacteristic *c = servicio->createCharacteristic(
        uuid, BLECharacteristic::PROPERTY_WRITE);
    c->setCallbacks(&escritura);
  }

  chEstado = servicio->createCharacteristic(
      CHAR_ESTADO_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  // Bluedroid no crea solo el descriptor que habilita las notificaciones.
  chEstado->addDescriptor(new BLE2902());
  chEstado->setValue("listo");
  static EstadoCallbacks callbacksEstado;
  chEstado->setCallbacks(&callbacksEstado);
  chSesion = servicio->createCharacteristic(
      CHAR_SESION_UUID, BLECharacteristic::PROPERTY_READ |
                           BLECharacteristic::PROPERTY_WRITE);
  static SesionCallbacks callbacksSesion;
  chSesion->setCallbacks(&callbacksSesion);
  chSesion->setValue("libre");

  servicio->start();

  // Anuncio a mano: el UUID de 128 bits (18 bytes) y el nombre no caben
  // juntos en los 31 bytes del paquete. El UUID va en el anuncio (la app
  // filtra por él) y el nombre en la respuesta al escaneo.
  BLEAdvertising *anuncio = BLEDevice::getAdvertising();
  BLEAdvertisementData datos;
  datos.setFlags(0x06);  // general discoverable, sin BR/EDR
  datos.setCompleteServices(BLEUUID(GYMONE_SERVICE_UUID));
  std::string fabricante("\xff\xffGO\x01\x00", 6);
  datos.setManufacturerData(String(fabricante.c_str(), fabricante.size()));
  anuncio->setAdvertisementData(datos);

  BLEAdvertisementData respuesta;
  respuesta.setName(nombre);
  anuncio->setScanResponseData(respuesta);

  // Cada 100-150 ms y no cada 20-40 ms (lo predeterminado). WiFi y Bluetooth
  // se turnan la antena: anunciando tan seguido, al WiFi casi no le tocaba,
  // y con el lector en su red y ofreciéndose a la vez ("Cambiar WiFi") la
  // app le preguntaba y no contestaba. El teléfono lo encuentra igual en un
  // segundo. En pasos de 0,625 ms.
  anuncio->setMinInterval(0xA0);  // 100 ms
  anuncio->setMaxInterval(0xF0);  // 150 ms

  BLEDevice::startAdvertising();
  bleIniciado = true;
  Serial.println("[BLE] Anunciando como " + nombre);
}

bool configuracionOcupada() {
  if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) != pdTRUE) return true;
  bool ocupada = sesionConfig.ocupada(millis());
  xSemaphoreGive(candadoBle);
  return ocupada;
}

void actualizarAnuncioBle() {
  anuncioOcupado = configuracionOcupada();
  BLEAdvertisementData datos;
  datos.setFlags(0x06);
  datos.setCompleteServices(BLEUUID(GYMONE_SERVICE_UUID));
  std::string fabricante("\xff\xffGO\x01\x00", 6);
  fabricante[5] = anuncioOcupado ? 1 : 0;
  datos.setManufacturerData(String(fabricante.c_str(), fabricante.size()));
  BLEDevice::getAdvertising()->setAdvertisementData(datos);
  refrescarAnuncio = false;
}

void desconectarClientesBle() {
  if (servidorBle == nullptr) return;
  for (const auto &cliente : servidorBle->getPeerDevices(false)) {
    servidorBle->disconnect(cliente.first);
  }
}

// Corre solo desde loop(), nunca desde un callback. El core 3.3.12 permite
// deinit(false) y volver a inicializar BLE si luego se cambia otra vez de red.
// Se conserva la conexión WiFi que ya pasó todas las comprobaciones.
void salirModoConfig() {
  if (!cerrarBlePendiente) return;
  if (bleIniciado) {
    BLEDevice::stopAdvertising();
    if (servidorBle != nullptr && servidorBle->getConnectedCount() > 0) {
      desconectarClientesBle();
      return;
    }
    BLEDevice::deinit(false);
  }
  servidorBle = nullptr;
  chRedes = chEstado = chSesion = nullptr;
  bleIniciado = clienteBleConectado = false;
  modoConfig = cerrarBlePendiente = false;
  okDesde = terminarPedidoEn = bleDesconectadoEn = 0;
  if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
    // La reserva termina cuando esta misma app confirma el 100%. Si la app
    // desapareció, vence sola; mientras tanto otro teléfono no cambia el WiFi.
    sesionConfig.probar(false, millis());
    bleSsid = bleClave = bleGym = "";
    xSemaphoreGive(candadoBle);
  }
  WiFi.setAutoReconnect(true);
  WiFi.setSleep(false);
  Serial.println("[CONFIG] Listo para trabajar: Bluetooth apagado, WiFi conservado");
}

void publicarEstado(const String &estado) {
  if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
    estadoConfigActual = estado;
    xSemaphoreGive(candadoBle);
  }
  if (estado == "conectando") {
    sonarConfiguracion(SonidoConfig::conectando);
  } else if (estado.startsWith("ok:")) {
    sonarConfiguracion(SonidoConfig::wifiGuardado);
  } else if (estado.startsWith("error:")) {
    sonarConfiguracion(SonidoConfig::error);
  }
  if (chEstado == nullptr) return;
  chEstado->setValue(estado.c_str());
  if (clienteBleConectado) chEstado->notify();
  Serial.println("[CONFIG] Estado: " + estado);
}

void atenderModoConfig(unsigned long ahora) {
  // Pedidos de la app, copiados con el candado.
  bool escanear = false;
  bool conectar = false;
  if (xSemaphoreTake(candadoBle, 0) == pdTRUE) {
    escanear = pedidoEscanear;
    conectar = pedidoConectar;
    pedidoEscanear = false;
    pedidoConectar = false;
    xSemaphoreGive(candadoBle);
  }

  bool libre = faseConexion == CONEXION_INACTIVA && okDesde == 0;
  if (escanear && libre) empezarEscaneo();
  if (conectar && libre) {
    // Con un escaneo en marcha el WiFi no puede conectar: se espera a que
    // termine.
    if (escaneando) {
      conectarPendiente = true;
    } else {
      empezarConexionNueva();
    }
  }

  revisarEscaneo();
  if (conectarPendiente && !escaneando && faseConexion == CONEXION_INACTIVA) {
    conectarPendiente = false;
    empezarConexionNueva();
  }

  if (faseConexion != CONEXION_INACTIVA) revisarConexionNueva(ahora);

  // Modo pedido por la app con tiempo límite, y nadie lo usó.
  if (motivoConfig == CONFIG_PEDIDO_APP && okDesde == 0 &&
      !clienteBleConectado && faseConexion == CONEXION_INACTIVA &&
      ahora > modoConfigHasta) {
    Serial.println("[CONFIG] Se acabó el tiempo sin cambios. Reiniciando...");
    reinicioPendienteEn = millis() + 500;
  }

  cuidarAnuncioBle(ahora);
}

// Que el lector siga visible por Bluetooth mientras espera que lo configuren.
//
// Sin esto, si el anuncio se caía (un arranque fallido justo tras una
// desconexión, por ejemplo) ya no volvía: los teléfonos no lo encontraban
// hasta desconectarlo de la corriente.
void cuidarAnuncioBle(unsigned long ahora) {
  if (!bleIniciado) return;
  if (cerrarBlePendiente || faseConexion != CONEXION_INACTIVA || okDesde != 0) {
    return;
  }

  if (refrescarAnuncio || anuncioOcupado != configuracionOcupada()) {
    if (clienteBleConectado || bleDesconectadoEn == 0 ||
        msDesde(bleDesconectadoEn) >= REANUNCIAR_TRAS_DESCONEXION_MS) {
      actualizarAnuncioBle();
      BLEDevice::startAdvertising();
    }
  }

  if (clienteBleConectado) {
    // Un teléfono conectado que no manda nada (la app se cerró a medias, o
    // se quedó en otra pantalla): se le suelta para volver a anunciarse. No
    // mientras se buscan redes o se prueba el WiFi, que tardan.
    if (faseConexion == CONEXION_INACTIVA && !escaneando &&
        msDesde(ultimaActividadBle) >= SOLTAR_CLIENTE_INACTIVO_MS &&
        servidorBle != nullptr) {
      Serial.println("[BLE] Teléfono conectado sin actividad: soltándolo");
      ultimaActividadBle = millis();
      desconectarClientesBle();
    }
    return;
  }
  // Probando el WiFi el Bluetooth está en pausa a propósito; con la red nueva
  // funcionando, o con un reinicio en camino, no hay nada que cuidar.
  if (faseConexion != CONEXION_INACTIVA || okDesde != 0 ||
      reinicioPendienteEn != 0) {
    return;
  }

  // Una app se acaba de ir: se vuelve a anunciar medio segundo después, ya
  // con el enlace cerrado.
  unsigned long desconectado = bleDesconectadoEn;
  if (desconectado != 0) {
    if (msDesde(desconectado) < REANUNCIAR_TRAS_DESCONEXION_MS) return;
    bleDesconectadoEn = 0;

    // La app pidió terminar (/api/terminar_config) mientras soltaba el
    // Bluetooth: ya lo soltó, se reinicia para trabajar normal.
    if (terminarPedidoEn != 0 &&
        msDesde(terminarPedidoEn) < TERMINAR_AL_SOLTAR_MS) {
      terminarPedidoEn = 0;
      Serial.println("[CONFIG] La app soltó el Bluetooth: reiniciando para "
                     "trabajar normal");
      reinicioPendienteEn = millis() + 200;
      return;
    }

    Serial.println("[BLE] Anunciando de nuevo tras la desconexión");
    BLEDevice::startAdvertising();
    ultimoRefrescoAnuncio = ahora;

    // La app soltó el Bluetooth: ya tiene las redes (la persona está
    // eligiendo) o salió sin cambiar nada. Se vuelve a la red de siempre YA,
    // sin esperar el siguiente reintento (hasta 30 s): así sigue pasando
    // tarjetas y la app lo encuentra en cuanto sale de "Cambiar WiFi". Si
    // luego manda una red nueva, se prueba encima de esta.
    if (!wifiConnected && wifiSsid.length() > 0 && !escaneando) {
      Serial.println("[CONFIG] Volviendo a la red guardada mientras tanto");
      iniciarWifiGuardado();
      ultimoReintentoWifi = ahora;
    }
    return;
  }

  // Cada 30 s sin nadie conectado, se reinicia el anuncio por si se cayó.
  if (msDesde(ultimoRefrescoAnuncio) >= REFRESCAR_ANUNCIO_MS) {
    ultimoRefrescoAnuncio = millis();
    BLEDevice::stopAdvertising();
    BLEDevice::startAdvertising();
  }

  // Último recurso: 10 min sin que nadie se conecte. Reiniciarse deja el
  // Bluetooth como recién encendido, que es lo que hacía desconectarlo.
  if (msDesde(ultimaActividadBle) >= REINICIO_SIN_USO_CONFIG_MS) {
    Serial.println("[BLE] 10 min sin que nadie se conecte: reiniciando para "
                   "refrescar el Bluetooth");
    reinicioPendienteEn = millis() + 200;
  }
}

void empezarEscaneo() {
  if (escaneando) return;

  // Si está intentando reconectar a la red guardada, el escaneo falla. Se
  // corta el intento (volverá a intentarlo al salir del modo).
  if (!wifiConnected && WiFi.status() != WL_IDLE_STATUS) {
    WiFi.disconnect(false, false);
  }

  if (WiFi.scanNetworks(true) == WIFI_SCAN_FAILED) {
    Serial.println("[CONFIG] No se pudo iniciar el escaneo de redes");
    sonarConfiguracion(SonidoConfig::error);
    return;
  }
  escaneando = true;
  publicarEstado("buscando_redes");
}

void revisarEscaneo() {
  if (!escaneando) return;

  int n = WiFi.scanComplete();
  if (n == WIFI_SCAN_RUNNING) return;
  escaneando = false;

  // Una línea por red, la de mejor señal primero, sin repetir (un mismo
  // nombre suele venir de varios repetidores) y sin redes ocultas.
  //
  // Formato: <señal dBm>\t<seguridad>\t<nombre>. El nombre va al final
  // porque es lo único que puede traer caracteres raros.
  String lista = "";
  int agregadas = 0;
  if (n > 0) {
    bool usada[n];
    for (int i = 0; i < n; i++) usada[i] = false;

    while (agregadas < MAX_REDES) {
      int mejor = -1;
      for (int i = 0; i < n; i++) {
        if (usada[i] || WiFi.SSID(i).length() == 0) continue;
        if (mejor == -1 || WiFi.RSSI(i) > WiFi.RSSI(mejor)) mejor = i;
      }
      if (mejor == -1) break;

      String ssid = WiFi.SSID(mejor);
      for (int i = 0; i < n; i++) {
        if (WiFi.SSID(i) == ssid) usada[i] = true;
      }
      String linea = String(WiFi.RSSI(mejor)) + "\t" +
                     tipoSeguridad(WiFi.encryptionType(mejor)) + "\t" + ssid;
      // Tope del valor de la característica: 512 bytes.
      if (lista.length() + linea.length() + 1 > 500) break;
      if (lista.length() > 0) lista += "\n";
      lista += linea;
      agregadas++;
    }
  }
  WiFi.scanDelete();

  if (chRedes != nullptr) chRedes->setValue(lista.c_str());
  Serial.printf("[CONFIG] %d redes encontradas\n", agregadas);
  sonarConfiguracion(agregadas > 0 ? SonidoConfig::redesListas
                                 : SonidoConfig::error);
  publicarEstado("listo");

  // Si no está la app y hay red guardada, se sigue intentando reconectar.
  if (!clienteBleConectado && !wifiConnected && wifiSsid.length() > 0) {
    iniciarWifiGuardado();
  }
}

// Cómo se le describe a la app la seguridad de una red.
const char *tipoSeguridad(wifi_auth_mode_t modo) {
  switch (modo) {
    case WIFI_AUTH_OPEN:
    case WIFI_AUTH_OWE:
      return "abierta";
    case WIFI_AUTH_WEP:
      return "wep";  // obsoleta: el lector no la usa
    case WIFI_AUTH_ENTERPRISE:
    case WIFI_AUTH_WPA3_ENT_192:
    case WIFI_AUTH_WPA3_ENTERPRISE:
    case WIFI_AUTH_WPA2_WPA3_ENTERPRISE:
    case WIFI_AUTH_WPA_ENTERPRISE:
      return "empresarial";  // pide usuario además de contraseña
    default:
      return "clave";
  }
}

bool esRazonDeClave(uint8_t razon) {
  return razon == WIFI_REASON_AUTH_FAIL ||
         razon == WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT ||
         razon == WIFI_REASON_HANDSHAKE_TIMEOUT ||
         razon == WIFI_REASON_MIC_FAILURE ||
         razon == WIFI_REASON_802_1X_AUTH_FAILED;
}

// Corre en la tarea de eventos del WiFi: solo anota. El loop decide.
void alEventoWifi(WiFiEvent_t evento, WiFiEventInfo_t info) {
  if (evento == ARDUINO_EVENT_WIFI_STA_CONNECTED) {
    // Llega DESPUÉS de negociar la contraseña con el módem: si hubo
    // asociación, la contraseña es correcta.
    // La hora primero: el loop (en el otro núcleo) mira intentoAsociado y
    // luego asociadoEn; al revés podía verla aún en 0 y dar "sin_ip" al
    // instante.
    if (faseConexion == CONEXION_PROBANDO && !intentoAsociado) {
      asociadoEn = millis();
      intentoAsociado = true;
    }
    return;
  }
  if (evento != ARDUINO_EVENT_WIFI_STA_DISCONNECTED) return;

  uint8_t razon = info.wifi_sta_disconnected.reason;
  ultimaRazonDesconexion = razon;

  // La desconexión que provoca el propio disconnect() no es un fallo.
  if (faseConexion != CONEXION_PROBANDO || razon == WIFI_REASON_ASSOC_LEAVE) {
    return;
  }

  if (razon == WIFI_REASON_NO_AP_FOUND ||
      razon == WIFI_REASON_NO_AP_FOUND_IN_RSSI_THRESHOLD) {
    fallosSinRed++;
  } else if (razon == WIFI_REASON_NO_AP_FOUND_W_COMPATIBLE_SECURITY ||
             razon == WIFI_REASON_NO_AP_FOUND_IN_AUTHMODE_THRESHOLD) {
    fallosSeguridad++;
  } else if (esRazonDeClave(razon)) {
    fallosClave++;
  } else {
    fallosOtros++;
  }
  razonFalloNuevo = razon;
  hayFalloNuevo = true;
}

// Llegó la orden "conectar". Se valida y se espera a que la app suelte el
// Bluetooth antes de tocar el WiFi.
void empezarConexionNueva() {
  if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) != pdTRUE) return;
  nuevoSsid = bleSsid;
  nuevaClave = bleClave;
  nuevoGym = bleGym;
  xSemaphoreGive(candadoBle);

  // El nombre de la red NO se recorta: algunos módems traen espacios al
  // final, y quitarlos haría que no la encontrara nunca.
  nuevoGym.trim();

  if (nuevoSsid.length() == 0 || nuevoGym.length() == 0) {
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
      sesionConfig.probar(false, millis());
      xSemaphoreGive(candadoBle);
    }
    publicarEstado("error:datos");
    return;
  }

  // Un lector con dueño no se deja reconfigurar por otro gimnasio: la salida
  // legítima es que el dueño lo formatee, o el reset con el botón.
  if (gymIdVinculado.length() > 0 && nuevoGym != gymIdVinculado) {
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
      sesionConfig.probar(false, millis());
      xSemaphoreGive(candadoBle);
    }
    publicarEstado("error:otro_gimnasio");
    return;
  }

  Serial.printf("[CONFIG] Red recibida: \"%s\" (clave de %u caracteres)\n",
                nuevoSsid.c_str(), nuevaClave.length());
  faseConexion = CONEXION_ESPERANDO_BLE;
  faseDesde = millis();
  publicarEstado("conectando");
}

void revisarConexionNueva(unsigned long ahora) {
  // ── 1. Esperar a que la app suelte el Bluetooth ──
  if (faseConexion == CONEXION_ESPERANDO_BLE) {
    // La app se desconecta sola en cuanto manda la orden. Si no lo hace (una
    // versión vieja), se le corta a los 3 s.
    if (clienteBleConectado && msDesde(faseDesde) < 3000) return;
    if (clienteBleConectado && servidorBle != nullptr) {
      desconectarClientesBle();
    }
    BLEDevice::stopAdvertising();

    // Se corta lo que el WiFi esté haciendo con la red vieja. Si esa red ya
    // no está (lo cambiaron de lugar), el WiFi la busca sin parar, y mientras
    // busca NO acepta otra red: begin() con la nueva fallaba sin aviso, seguía
    // buscando la vieja, y cada "no la encuentro" contaba contra la nueva. El
    // lector decía "la red está lejos" una y otra vez, hasta borrarlo con BOOT.
    WiFi.setAutoReconnect(false);
    WiFi.disconnect(false, false);
    wifiConnected = false;
    serverRunning = false;
    faseConexion = CONEXION_SOLTANDO_WIFI;
    faseDesde = millis();
    return;
  }

  // ── 2. Con el WiFi quieto, arrancar la red nueva ──
  if (faseConexion == CONEXION_SOLTANDO_WIFI) {
    // Medio segundo para que el WiFi termine de soltar el intento anterior.
    if (msDesde(faseDesde) < 500) return;

    // Con reconexión automática el propio WiFi reintenta ante fallos
    // pasajeros (tiempo agotado, antena ocupada). No se le llama a begin()
    // por encima: dos intentos a la vez se estorban y cada choque parece un
    // fallo más.
    WiFi.setAutoReconnect(true);
    if (WiFi.begin(nuevoSsid.c_str(), nuevaClave.c_str()) == WL_CONNECT_FAILED) {
      // Todavía no la aceptó. Se reintenta; a los 5 s se da por perdido.
      if (msDesde(faseDesde) < 5000) {
        WiFi.setAutoReconnect(false);
        WiFi.disconnect(false, false);
        return;
      }
      Serial.println("[CONFIG] El WiFi no aceptó la red nueva");
      terminarIntentoFallido("error:no_conecta");
      return;
    }

    Serial.println("[CONFIG] Probando la red con el Bluetooth en pausa...");
    intentoAsociado = false;
    asociadoEn = 0;
    fallosClave = fallosSinRed = fallosSeguridad = fallosOtros = 0;
    hayFalloNuevo = false;
    reintentosPropios = 0;
    reintentarEn = 0;

    // Solo desde aquí cuentan los fallos (ver alEventoWifi): los de la red
    // vieja ya pasaron.
    faseConexion = CONEXION_PROBANDO;
    faseDesde = millis();
    return;
  }

  // ── 3. Probando ──
  if (WiFi.status() == WL_CONNECTED) {
    faseConexion = CONEXION_INACTIVA;

    // Se guarda TODO solo cuando la red nueva funcionó: si la contraseña era
    // mala, el lector conserva la configuración anterior.
    prefs.begin("gymone", false);
    prefs.putString("ssid", nuevoSsid);
    prefs.putString("pass", nuevaClave);
    if (gymIdVinculado.length() == 0) prefs.putString("gym_id", nuevoGym);
    prefs.end();
    wifiSsid = nuevoSsid;
    wifiClave = nuevaClave;
    gymIdVinculado = nuevoGym;

    alConectarWifi();
    okDesde = millis();
    publicarEstado("ok:" + WiFi.localIP().toString());

    // Ya está en la red correcta. Apagar BLE conserva esa conexión: no
    // necesita reiniciar, negociar la clave y obtener DHCP por segunda vez.
    cerrarBlePendiente = true;
    return;
  }

  if (hayFalloNuevo) {
    hayFalloNuevo = false;
    uint8_t razon = razonFalloNuevo;
    Serial.printf("[CONFIG] Intento fallido: razón %u (%s)\n", razon,
                  WiFi.STA.disconnectReasonName((wifi_err_reason_t)razon));

    // El WiFi reintenta solo casi todo, pero no un rechazo de autenticación
    // (AUTH_FAIL): ese reintento va por cuenta propia.
    if (razon == WIFI_REASON_AUTH_FAIL && reintentosPropios < 2) {
      reintentarEn = ahora + 1000;
    }
  }

  if (reintentarEn != 0 && ahora >= reintentarEn) {
    reintentarEn = 0;
    reintentosPropios++;
    WiFi.begin(nuevoSsid.c_str(), nuevaClave.c_str());
    return;
  }

  // Veredicto. Solo se culpa a la contraseña cuando la negociación falló
  // varias veces SIN Bluetooth de por medio y la red sí aparece.
  unsigned long transcurrido = msDesde(faseDesde);
  const char *veredicto = nullptr;

  if (intentoAsociado && msDesde(asociadoEn) >= 15000) {
    // La contraseña pasó, pero el módem no le dio dirección (DHCP).
    veredicto = "error:sin_ip";
  } else if (!intentoAsociado && fallosClave >= 3) {
    veredicto = "error:clave";
  } else if (!intentoAsociado && fallosSeguridad >= 2) {
    veredicto = "error:seguridad";
  } else if (!intentoAsociado && fallosSinRed >= 3 && fallosClave == 0) {
    veredicto = "error:sin_red";
  } else if (transcurrido >= CONECTAR_TIMEOUT_MS) {
    if (intentoAsociado) {
      veredicto = "error:sin_ip";
    } else if (fallosClave >= 2) {
      veredicto = "error:clave";
    } else if (fallosSeguridad > 0 && fallosClave == 0) {
      veredicto = "error:seguridad";
    } else if (fallosSinRed > 0 && fallosClave == 0) {
      veredicto = "error:sin_red";
    } else {
      veredicto = "error:no_conecta";
    }
  }

  if (veredicto != nullptr) terminarIntentoFallido(veredicto);
}

// Deja el WiFi como estaba y vuelve a ofrecerse por Bluetooth para que la
// app lea el resultado y se pueda reintentar.
void terminarIntentoFallido(const char *veredicto) {
  if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) == pdTRUE) {
    sesionConfig.probar(false, millis());
    xSemaphoreGive(candadoBle);
  }
  Serial.printf("[CONFIG] Sin conexión. Clave: %u, sin red: %u, seguridad: %u, "
                "otros: %u, se asoció: %s\n",
                fallosClave, fallosSinRed, fallosSeguridad, fallosOtros,
                intentoAsociado ? "sí" : "no");
  faseConexion = CONEXION_INACTIVA;

  // Sin esto el WiFi seguiría reintentando la red mala por su cuenta,
  // ocupando la antena mientras la app se reconecta.
  WiFi.setAutoReconnect(false);
  WiFi.disconnect(false, false);

  publicarEstado(veredicto);
  // La desconexión de la app ya pasó hace rato (se fue al mandar la orden):
  // se anuncia aquí, en el loop, y el guardián no lo repite.
  bleDesconectadoEn = 0;
  ultimoRefrescoAnuncio = millis();
  BLEDevice::startAdvertising();

  // Se vuelve a la red de antes, si había una.
  if (wifiSsid.length() > 0) {
    desconectadoDesde = millis();
    iniciarWifiGuardado();
  }
}

// =================== SERVIDOR HTTP ===================

void setupServerRoutes() {
  server.on("/api/uid", HTTP_GET, handleGetUid);
  server.on("/api/uid_only", HTTP_GET, handleGetUidOnly);
  server.on("/api/lecturas", HTTP_GET, handleLecturas);
  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/discover", HTTP_GET, handleDiscover);

  server.on("/api/claim", HTTP_POST, handleClaim);
  server.on("/api/unclaim", HTTP_POST, handleUnclaim);
  server.on("/api/reset", HTTP_POST, handleReset);
  server.on("/api/configurar", HTTP_POST, handleConfigurar);
  server.on("/api/terminar_config", HTTP_POST, handleTerminarConfig);
  server.on("/api/confirmar_config", HTTP_POST, handleConfirmarConfig);

  server.enableCORS(true);
}

// Cualquier petición que llega prueba que la red funciona (ver
// SILENCIO_ANTES_DE_RECONECTAR_MS).
void anotarPeticion() {
  ultimaPeticionEn = millis();
}

// Por qué arrancó el lector la última vez: para saber, en el monitor serie
// o en /api/status, si se reinició solo y por qué.
const char *motivoDeArranque() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON: return "encendido";
    case ESP_RST_SW: return "reinicio pedido";
    case ESP_RST_PANIC: return "fallo del programa";
    case ESP_RST_INT_WDT:
    case ESP_RST_TASK_WDT:
    case ESP_RST_WDT: return "watchdog (se trabó)";
    case ESP_RST_BROWNOUT: return "bajón de corriente";
    case ESP_RST_DEEPSLEEP: return "despertó";
    default: return "otro";
  }
}

void handleGetUid() {
  anotarPeticion();
  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", lastUid);
}

void handleGetUidOnly() {
  anotarPeticion();
  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }
  server.send(200, "text/plain", lastUid);
}

void handleStatus() {
  anotarPeticion();
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");

  DynamicJsonDocument doc(400);
  doc["status"] = "OK";
  doc["wifi_connected"] = wifiConnected;
  // Sin `last_uid`: este endpoint está abierto y no debe repartir pases.
  doc["claimed"] = gymIdVinculado.length() > 0;
  doc["ip_address"] = WiFi.localIP().toString();
  doc["network_type"] = "dhcp";
  doc["uptime_seconds"] = (millis() - systemUptime) / 1000;
  doc["free_heap"] = ESP.getFreeHeap();
  doc["server_running"] = serverRunning;
  doc["version"] = FIRMWARE_VERSION;
  doc["lector_tarjetas_ok"] = pn532Ok;
  doc["arranque"] = motivoDeArranque();
  doc["senal"] = WiFi.RSSI();

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleDiscover() {
  anotarPeticion();
  DynamicJsonDocument doc(768);
  doc["device_id"] = "ESP32_RFID_GYMONE";
  doc["device_type"] = "RFID_READER";
  doc["version"] = FIRMWARE_VERSION;
  // Identidad del APARATO (su MAC), no del dueño: sirve para que la app
  // reconozca su lector cuando le cambia la IP.
  doc["id"] = idLector;

  // `claimed` y `mine` responden SÍ/NO; el gym_id guardado nunca sale.
  doc["claimed"] = gymIdVinculado.length() > 0;
  doc["mine"] = peticionAutorizada();
  doc["modo_config"] = modoConfig;
  doc["config_ocupada"] = configuracionOcupada();
  doc["rfid_reader"] = "PN532";
  doc["manufacturer"] = "GYMONE";
  doc["wifi_connected"] = wifiConnected;
  doc["status"] = "ONLINE";
  doc["uptime"] = millis();
  doc["uptime_seconds"] = (millis() - systemUptime) / 1000;
  doc["free_heap"] = ESP.getFreeHeap();
  doc["network_type"] = "dhcp";
  doc["server_running"] = serverRunning;

  if (wifiConnected) {
    doc["ip_address"] = WiFi.localIP().toString();
    doc["gateway"] = WiFi.gatewayIP().toString();
    doc["subnet"] = WiFi.subnetMask().toString();
    doc["mac_address"] = WiFi.macAddress();
    doc["signal_strength"] = WiFi.RSSI();
    doc["ssid"] = WiFi.SSID();
  }

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

// =================== VINCULACIÓN CON UN GIMNASIO ===================

// El gym_id que manda quien pregunta, por query (?gym_id=) o en el cuerpo
// JSON del POST. Devuelve "" si no vino.
String gymIdDeLaPeticion() {
  if (server.hasArg("gym_id")) {
    return server.arg("gym_id");
  }
  if (server.hasArg("plain")) {
    DynamicJsonDocument doc(256);
    if (deserializeJson(doc, server.arg("plain")) == DeserializationError::Ok) {
      const char *valor = doc["gym_id"];
      if (valor != nullptr) return String(valor);
    }
  }
  return "";
}

// Un lector sin vincular no autoriza a nadie: primero hay que reclamarlo.
bool peticionAutorizada() {
  if (gymIdVinculado.length() == 0) return false;
  return gymIdDeLaPeticion() == gymIdVinculado;
}

void responderNoAutorizado() {
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");

  DynamicJsonDocument doc(192);
  doc["error"] = "forbidden";
  doc["claimed"] = gymIdVinculado.length() > 0;
  doc["message"] = gymIdVinculado.length() > 0
      ? "Este lector pertenece a otro gimnasio"
      : "Este lector todavia no esta vinculado a ningun gimnasio";

  String respuesta;
  serializeJson(doc, respuesta);
  server.send(403, "application/json", respuesta);
}

// POST /api/claim {"gym_id": "..."} — reclamar un lector libre.
void handleClaim() {
  anotarPeticion();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  String gymId = gymIdDeLaPeticion();

  if (gymId.length() == 0) {
    server.send(400, "application/json", "{\"error\":\"falta gym_id\"}");
    return;
  }

  if (gymIdVinculado.length() > 0) {
    if (gymId == gymIdVinculado) {
      server.send(200, "application/json", "{\"ok\":true,\"already\":true}");
      return;
    }
    server.send(409, "application/json",
                "{\"error\":\"claimed\",\"message\":\"Ya pertenece a otro gimnasio\"}");
    return;
  }

  prefs.begin("gymone", false);
  prefs.putString("gym_id", gymId);
  prefs.end();
  gymIdVinculado = gymId;

  Serial.println("[VINCULACION] Lector vinculado correctamente.");
  sonarConfiguracion(SonidoConfig::completado);
  server.send(200, "application/json", "{\"ok\":true}");

  // Estaba ofreciéndose por Bluetooth por no tener dueño: se reinicia para
  // apagarlo. Con margen, para que la app alcance a preguntarle quién es.
  if (modoConfig && faseConexion == CONEXION_INACTIVA) {
    reinicioPendienteEn = millis() + 3000;
  }
}

// POST /api/unclaim {"gym_id": "..."} — liberar el lector. Solo el dueño.
void handleUnclaim() {
  anotarPeticion();
  server.sendHeader("Access-Control-Allow-Origin", "*");

  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }

  // Desvincular deja el lector como nuevo: sin gimnasio Y sin WiFi. Así se
  // puede llevar a cualquier lugar (al reiniciar se ofrece por Bluetooth) y
  // la contraseña del WiFi de este gimnasio no se va dentro del aparato.
  prefs.begin("gymone", false);
  prefs.remove("gym_id");
  prefs.remove("ssid");
  prefs.remove("pass");
  prefs.end();
  gymIdVinculado = "";
  wifiSsid = "";
  wifiClave = "";

  Serial.println("[VINCULACION] Desvinculado: olvidando gimnasio y WiFi. "
                 "Reiniciando...");
  sonarAvisoActual(600);
  server.sendHeader("Connection", "close");
  server.send(200, "application/json", "{\"ok\":true,\"reboot_in_ms\":1500}");

  // Nunca se reinicia dentro del handler: la respuesta tiene que salir.
  borrarWifiAlReiniciar = true;
  reinicioPendienteEn = millis() + 1500;
}

// POST /api/reset — libera el lector SIN comprobar quién lo pide.
//
// Existe para recuperar un lector vinculado a un gimnasio al que ya no se
// tiene acceso. El precio: cualquiera en la red puede formatearlo; por eso
// pita, para que no pase desapercibido.
//
// NO borra el WiFi: el lector sigue en la red y el nuevo dueño lo encuentra.
void handleReset() {
  anotarPeticion();
  server.sendHeader("Access-Control-Allow-Origin", "*");

  prefs.begin("gymone", false);
  prefs.remove("gym_id");
  prefs.end();
  gymIdVinculado = "";

  Serial.println("[RESET] Lector formateado desde la red: queda sin dueño.");
  sonarAvisoActual(2000);
  server.send(200, "application/json", "{\"ok\":true}");
}

// POST /api/configurar {"gym_id": "..."} — abre el modo configuración por
// Bluetooth durante 5 min, para cambiarle el WiFi sin tocar el aparato.
// Solo el dueño. El lector sigue funcionando mientras tanto.
void handleConfigurar() {
  anotarPeticion();
  server.sendHeader("Access-Control-Allow-Origin", "*");

  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }

  if (configuracionOcupada()) {
    server.send(409, "application/json", "{\"error\":\"config_ocupada\"}");
    return;
  }

  if (modoConfig) {
    // Ya se está ofreciendo por Bluetooth: solo se alarga el plazo (y se
    // olvida un "terminar" pendiente: la persona volvió a entrar).
    if (motivoConfig == CONFIG_PEDIDO_APP) {
      modoConfigHasta = millis() + CONFIG_PEDIDA_DURACION_MS;
    }
    terminarPedidoEn = 0;
    server.sendHeader("Connection", "close");
    server.send(200, "application/json", "{\"ok\":true}");
    return;
  }

  // No se enciende el Bluetooth aquí, encima del WiFi, el servidor y el mDNS:
  // podía quedarse sin memoria y no anunciarse. Se anota el pedido y se
  // reinicia: al arrancar entra en modo configuración antes que nada.
  prefs.begin("gymone", false);
  prefs.putBool("abrir_config", true);
  prefs.end();

  Serial.println("[CONFIG] Cambio de WiFi pedido: reiniciando en modo "
                 "configuración...");
  server.sendHeader("Connection", "close");
  server.send(200, "application/json", "{\"ok\":true,\"reboot_in_ms\":800}");
  // Nunca se reinicia dentro del handler: la respuesta tiene que salir.
  reinicioPendienteEn = millis() + 800;
}

// POST /api/terminar_config {"gym_id": "..."} — la persona salió de
// "Cambiar WiFi" sin cambiarlo. El lector ya volvió a su red, pero seguía
// ofreciéndose por Bluetooth hasta cumplir los 5 min, y ahí se reiniciaba de
// sorpresa. Ahora se reinicia ya y vuelve a trabajar normal en unos
// segundos. Solo el dueño.
//
// Solo cierra el modo que abrió la app: si se está ofreciendo porque perdió
// su red o no tiene dueño, eso lo resuelve configurarlo. Tampoco probando
// una red: alguien lo está configurando.
//
// Con un teléfono conectado por Bluetooth se reinicia en cuanto lo suelte,
// si es pronto (TERMINAR_AL_SOLTAR_MS): casi siempre es el de la misma app,
// que salió del asistente y aún lo está soltando. Antes contestaba que no y
// se quedaba 5 min más ofreciéndose, con el WiFi a medias.
void handleTerminarConfig() {
  anotarPeticion();
  server.sendHeader("Access-Control-Allow-Origin", "*");

  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }

  // Salir del asistente de otro teléfono no puede cerrar la sesión activa.
  if (modoConfig && configuracionOcupada()) {
    server.send(409, "application/json", "{\"error\":\"config_ocupada\"}");
    return;
  }

  bool reinicia = modoConfig && motivoConfig == CONFIG_PEDIDO_APP &&
                  faseConexion == CONEXION_INACTIVA && okDesde == 0 &&
                  reinicioPendienteEn == 0;

  server.sendHeader("Connection", "close");
  if (!reinicia) {
    server.send(200, "application/json", "{\"ok\":true,\"reinicia\":false}");
    return;
  }

  if (clienteBleConectado) {
    Serial.println("[CONFIG] La app salió sin cambiar el WiFi: reinicio al "
                   "soltar el Bluetooth");
    unsigned long ahora = millis();
    terminarPedidoEn = ahora == 0 ? 1 : ahora;
    server.send(200, "application/json", "{\"ok\":true,\"reinicia\":true}");
    return;
  }

  Serial.println("[CONFIG] La app salió sin cambiar el WiFi: reiniciando "
                 "para trabajar normal");
  server.send(200, "application/json",
              "{\"ok\":true,\"reinicia\":true,\"reboot_in_ms\":500}");
  reinicioPendienteEn = millis() + 500;
}

// La app confirmó la red y guardó el lector. Solo el dueño puede pedir el
// aviso de 100%, y solamente con el lector trabajando normal con BLE apagado.
void handleConfirmarConfig() {
  anotarPeticion();
  server.sendHeader("Connection", "close");
  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }
  if (modoConfig || !wifiConnected || reinicioPendienteEn != 0) {
    server.send(409, "application/json", "{\"error\":\"lector_no_listo\"}");
    return;
  }
  StaticJsonDocument<256> datos;
  if (deserializeJson(datos, server.arg("plain")) ||
      !datos["intento"].is<const char *>()) {
    server.send(400, "application/json", "{\"error\":\"falta_intento\"}");
    return;
  }
  String intento = datos["intento"].as<String>();
  if (intento.length() == 0 || intento.length() > 80) {
    server.send(400, "application/json", "{\"error\":\"intento_invalido\"}");
    return;
  }
  if (intento != ultimaConfirmacionConfig) {
    if (xSemaphoreTake(candadoBle, pdMS_TO_TICKS(200)) != pdTRUE) {
      server.send(409, "application/json", "{\"error\":\"config_ocupada\"}");
      return;
    }
    bool propia = sesionConfig.confirmar(datos["sesion"] | "", millis());
    xSemaphoreGive(candadoBle);
    if (!propia) {
      server.send(409, "application/json", "{\"error\":\"config_ocupada\"}");
      return;
    }
    ultimaConfirmacionConfig = intento;
    sonarConfiguracion(SonidoConfig::completado);
    Serial.println("[CONFIG] App confirmó la configuración: aviso final");
  }
  server.send(200, "application/json", "{\"ok\":true}");
}

// =================== BOTÓN DE RESET DE FÁBRICA ===================

// Mantener BOOT 3 s dentro de los primeros 10 s tras encender. Borra el
// gimnasio Y el WiFi: el lector vuelve a estar como nuevo, en modo
// configuración.
void revisarBotonReset() {
  if (millis() - systemUptime > RESET_VENTANA_MS) {
    botonPulsadoDesde = 0;
    return;
  }

  bool pulsado = (digitalRead(BOTON_RESET_PIN) == LOW);
  if (!pulsado) {
    botonPulsadoDesde = 0;
    return;
  }

  if (botonPulsadoDesde == 0) {
    botonPulsadoDesde = millis();
    sonarAvisoActual(80);  // "te estoy oyendo"
    return;
  }

  if (millis() - botonPulsadoDesde >= RESET_MANTENER_MS) {
    Serial.println("[RESET] Borrando vinculación y WiFi...");
    prefs.begin("gymone", false);
    prefs.clear();
    prefs.end();

    sonarAvisoActual(600);
    borrarWifiAlReiniciar = true;
    reinicioPendienteEn = millis() + 800;
    botonPulsadoDesde = 0;
  }
}

// =================== RFID ===================

void leerTarjetas() {
  uint8_t uid[] = {0, 0, 0, 0, 0, 0, 0};
  uint8_t uidLength;

  if (nfc->readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength)) {
    sinTarjetaDesde = 0;
    String cardUid = getCardUID(uid, uidLength);

    // Un pase por cada vez que se acerca la tarjeta. Si se queda apoyada, no
    // se repite (antes se volvía a aceptar, y a pitar, cada 3 s).
    if (cardUid != lastScannedCard) {
      lastScannedCard = cardUid;
      lastCardReadTime = millis();
      lastUid = cardUid;
      beepLectura();
      registrarLectura(cardUid);
      Serial.print("[RFID] UID: ");
      Serial.println(cardUid);
    }
  } else if (lastScannedCard.length() > 0) {
    // 1 s sin leerla = la retiraron. Un fallo suelto de lectura con la
    // tarjeta apoyada dura mucho menos.
    if (sinTarjetaDesde == 0) {
      sinTarjetaDesde = millis();
    } else if (millis() - sinTarjetaDesde > 1000) {
      lastUid = "NO_CARD";
      lastScannedCard = "";
      sinTarjetaDesde = 0;
    }
  }
}

// Arranca el chip de tarjetas. False si no contesta.
bool iniciarPn532() {
  nfc->begin();  // espera medio segundo a que el chip despierte
  delay(100);
  uint32_t version = nfc->getFirmwareVersion();
  if (!version) {
    pn532Ok = false;
    return false;
  }
  Serial.printf("PN532 OK - FW v%u.%u\n", (unsigned)((version >> 16) & 0xFF),
                (unsigned)((version >> 8) & 0xFF));
  nfc->SAMConfig();
  // Reintentos MUY bajos para no bloquear el loop
  nfc->setPassiveActivationRetries(0x01);
  pn532Ok = true;
  return true;
}

// Que el chip de tarjetas siga contestando.
//
// A veces deja de contestar (un bajón de corriente, ruido en los cables, el
// bus I2C que se traba): el lector seguía en la red y la app lo veía
// conectado, pero ya no leía ninguna tarjeta hasta desconectarlo de la
// corriente. Cada 10 s sin tarjeta se le pide su versión (unos milisegundos);
// si no contesta se reinicia el bus y el chip, y si tras varios intentos
// sigue igual, el lector completo.
void revisarPn532(unsigned long ahora) {
  // Con una tarjeta apoyada no se le interrumpe.
  if (lastScannedCard.length() > 0) return;
  if (ahora - ultimaRevisionPn532 < REVISAR_PN532_CADA_MS) return;
  ultimaRevisionPn532 = ahora;

  if (nfc->getFirmwareVersion() != 0) {
    if (!pn532Ok) Serial.println("[RFID] El chip de tarjetas volvió a contestar");
    pn532Ok = true;
    pn532FuncionoDesdeArranque = true;
    fallosPn532 = 0;
    return;
  }

  pn532Ok = false;
  fallosPn532++;
  Serial.printf("[RFID] El chip de tarjetas no contesta (intento %u): "
                "reiniciándolo\n", fallosPn532);

  // Solo si llegó a funcionar desde que encendió: con el chip desconectado
  // o dañado, reiniciar no lo arregla y el lector se reiniciaría en bucle
  // (y dejaría de verse en la red a ratos). Tampoco mientras se configura.
  if (fallosPn532 >= PN532_FALLOS_ANTES_DE_REINICIAR &&
      pn532FuncionoDesdeArranque && !modoConfig && reinicioPendienteEn == 0) {
    Serial.println("[RFID] No se recuperó: reiniciando el lector");
    reinicioPendienteEn = millis() + 200;
    return;
  }

  // El bus I2C desde cero (si se trabó a medio mensaje, el chip se queda
  // esperando) y el chip otra vez.
  Wire.end();
  Wire.begin(PN532_SDA, PN532_SCL);
  Wire.setClock(100000);
  if (iniciarPn532()) {
    Serial.println("[RFID] Chip de tarjetas recuperado");
    pn532FuncionoDesdeArranque = true;
    fallosPn532 = 0;
  }
}

void registrarLectura(const String &uid) {
  lecturaSeq++;
  Lectura &l = lecturas[lecturaSeq % LECTURAS_GUARDADAS];
  l.seq = lecturaSeq;
  strncpy(l.uid, uid.c_str(), sizeof(l.uid) - 1);
  l.uid[sizeof(l.uid) - 1] = '\0';
  l.en = millis();
}

// GET /api/lecturas?gym_id=...&desde=N — los pases posteriores a N, del más
// viejo al más nuevo. Solo el dueño.
//   {"seq": 18, "lecturas": [{"seq": 17, "uid": "EA7F8005", "hace_ms": 830}]}
// "seq" es el último número dado: la app lo guarda para la siguiente vez. Si
// es MENOR que el que tenía, el lector se reinició.
void handleLecturas() {
  anotarPeticion();
  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }

  uint32_t desde = 0;
  if (server.hasArg("desde")) {
    desde = strtoul(server.arg("desde").c_str(), nullptr, 10);
  }

  DynamicJsonDocument doc(1024);
  doc["seq"] = lecturaSeq;
  JsonArray lista = doc.createNestedArray("lecturas");

  uint32_t primera = lecturaSeq > LECTURAS_GUARDADAS
                         ? lecturaSeq - LECTURAS_GUARDADAS + 1
                         : 1;
  unsigned long ahora = millis();
  for (uint32_t n = primera; n <= lecturaSeq; n++) {
    if (n <= desde) continue;
    const Lectura &l = lecturas[n % LECTURAS_GUARDADAS];
    if (l.seq != n) continue;
    JsonObject o = lista.createNestedObject();
    o["seq"] = l.seq;
    o["uid"] = l.uid;
    o["hace_ms"] = ahora - l.en;
  }

  String respuesta;
  serializeJson(doc, respuesta);
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", respuesta);
}

// =================== SONIDO ===================

void tocarNotaConfig(unsigned int hz, unsigned long duracionMs) {
  tone(BUZZER_PIN, hz, duracionMs);
}

void beepLectura() {
  sonarAvisoActual(BUZZER_BEEP_MS);
}

void sonarAvisoActual(unsigned long duracionMs) {
  sonidosConfig.reservarAvisoActual(millis(), duracionMs);
  tone(BUZZER_PIN, BUZZER_BEEP_HZ, duracionMs);
}

void sonarConfiguracion(SonidoConfig sonido) {
  sonidosConfig.iniciar(sonido);
  sonidosConfig.actualizar(millis());
}

#if BUZZER_MODO_PRUEBA
void pruebaVolumenBuzzer() {
  const int frecuencias[] = {3500, 3650, 3800, 3950, 4100, 4250, 4400, 4550, 4700, 4850, 5000};
  const int cantidad = sizeof(frecuencias) / sizeof(frecuencias[0]);
  for (int i = 0; i < cantidad; i++) {
    esp_task_wdt_reset();
    Serial.printf("[BUZZER] Sonando ahora: %d Hz\n", frecuencias[i]);
    tone(BUZZER_PIN, frecuencias[i], 250);
    delay(400);
  }
}
#endif

// =================== LED ===================

// - Fijo: conectado al WiFi, trabajando.
// - Parpadeo RÁPIDO: modo configuración, esperando a la app.
// - Parpadeo lento: sin WiFi, reintentando.
void handleStatusLeds() {
  static unsigned long ultimoCambio = 0;
  unsigned long ahora = millis();

  if (modoConfig) {
    if (ahora - ultimoCambio > 150) {
      digitalWrite(LED_WIFI, !digitalRead(LED_WIFI));
      ultimoCambio = ahora;
    }
  } else if (wifiConnected) {
    digitalWrite(LED_WIFI, HIGH);
  } else if (ahora - ultimoCambio > 1000) {
    digitalWrite(LED_WIFI, !digitalRead(LED_WIFI));
    ultimoCambio = ahora;
  }
}

// =================== UTILIDADES ===================

String getCardUID(uint8_t *uid, uint8_t uidLength) {
  String cardString = "";
  char buf[3];
  for (byte i = 0; i < uidLength; i++) {
    snprintf(buf, sizeof(buf), "%02X", uid[i]);
    cardString += buf;
  }
  return cardString;
}

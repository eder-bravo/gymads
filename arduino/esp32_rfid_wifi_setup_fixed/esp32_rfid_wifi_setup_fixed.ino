/*
 * GYMADS - ESP32 RFID Reader con WiFi
 * LECTOR RFID CON CONEXIÓN WIFI AUTOMÁTICA PARA GYMADS
 * 
 * Versión 5.2.0 - Solo WiFi - PN532 RFID Only + Auto-Recovery + Buzzer + Vinculación
 * Dispositivo: ESP32
 * 
 * Función: Leer tarjetas RFID físicas y llaveros NFC
 * Sistema simplificado para lectura de tarjetas RFID con conectividad WiFi
 * Versión: 5.2.0 - WiFi robusto con reconexión automática + Watchdog + Keep-alive
 * 
 * CAMBIOS v5.2.0:
 * - El lector se VINCULA a un solo gimnasio (gym_id guardado en NVS)
 * - /api/uid y /api/uid_only exigen el gym_id correcto (403 si no)
 * - /api/status deja de filtrar el UID de la tarjeta
 * - /api/discover dice "claimed" y "mine" SIN revelar nunca el gym_id guardado
 * - Nuevos: POST /api/claim, /api/unclaim y /api/network
 * - IP estática configurable por aparato (antes todos salían con la misma)
 * - Reset de fábrica: mantener BOOT (GPIO0) 5 s con el equipo ENCENDIDO
 *
 * CAMBIOS v5.1.0:
 * - Buzzer en GPIO25: beep corto al detectar una tarjeta durante el escaneo
 * - Usa tone()/noTone(): no bloquea el loop (corre en su propia tarea)
 *
 * CAMBIOS v5.0.0:
 * - Eliminada emulación HCE (Host Card Emulation)
 * - Solo lectura de tarjetas y llaveros RFID físicos
 * - Simplificado el flujo de lectura RFID
 * - Eliminadas constantes APDU y funciones HCE
 * - ELIMINADO SOPORTE PARA LEDS EXTERNOS (SOLO LED WIFI)
 * 
 * MEJORAS HEREDADAS v4.3.0:
 * - Watchdog Timer para reinicio automático si el sistema se congela
 * - Reconexión WiFi mejorada y más frecuente
 * - Keep-alive para mantener conexiones activas
 * - Reinicio automático del servidor HTTP si deja de responder
 * - Monitoreo de memoria libre
 * - Auto-reinicio después de múltiples fallos de conexión
 */

#include <Wire.h>
#include <PN532_I2C.h>
#include <PN532.h>

#include <WiFi.h>
#include <WebServer.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>  // Watchdog Timer
#include <Preferences.h>   // Memoria permanente (NVS): dueño del lector e IP

// =================== CONFIGURACIÓN WIFI ===================
// TODO: Cambiar estas credenciales por las de tu red WiFi
const char* WIFI_SSID = "TD Campus_C";
const char* WIFI_PASSWORD = "1Gestudio";

//const char* WIFI_SSID = "FamiliaBlanco_2.4";
//const char* WIFI_PASSWORD = "*E2d0e0r46";

//const char* WIFI_SSID = "Totalplay-2.4G-2368";
//const char* WIFI_PASSWORD = "N5q6aS55GGjDsYt7";


// =================== CONFIGURACIÓN DE ESCANEO RFID ===================
// Intervalo mínimo entre lecturas de la misma tarjeta (en milisegundos)
// Aumenta este valor si necesitas más tiempo entre lecturas
// Por defecto: 3000 ms (3 segundos)
const unsigned long CARD_READ_INTERVAL_MS = 3000;

// =================== CONFIGURACIÓN DEL BUZZER ===================
// Beep corto que confirma cada lectura de tarjeta. tone() con duración no
// bloquea: en este core (arduino-esp32 3.x) corre en su propia tarea de
// FreeRTOS y se apaga sola, así que el watchdog y el servidor HTTP siguen
// respondiendo mientras suena.
#define BUZZER_BEEP_HZ   3000   // Frecuencia del beep (Hz) — la más fuerte del barrido de prueba
#define BUZZER_BEEP_MS   120    // Duración del beep (ms)

// El barrido de frecuencias ya cumplió su propósito: 3000 Hz fue la más
// fuerte de las que se probaron. Se deja el modo aquí, apagado, por si hace
// falta volver a afinarlo con otro buzzer más adelante.
#define BUZZER_MODO_PRUEBA false

// =================== CONFIGURACIÓN DE IP ESTÁTICA ===================
// Configuración de IP estática
bool useStaticIP = true;  // Establecer a false para usar DHCP
IPAddress staticIP(192, 168, 1, 100);  // IP estática que quieres asignar al ESP32
IPAddress gateway(192, 168, 1, 1);     // IP del router (puerta de enlace) - CORREGIDO
IPAddress subnet(255, 255, 255, 0);    // Máscara de subred
IPAddress dns(8, 8, 8, 8);             // Servidor DNS (Google)

// =================== CONFIGURACIÓN DE WATCHDOG Y RECOVERY ===================
#define WDT_TIMEOUT_SECONDS 30          // Reiniciar si no hay actividad por 30 segundos
#define WIFI_RECONNECT_INTERVAL 5000    // Verificar WiFi cada 5 segundos
#define SERVER_RESTART_INTERVAL 300000  // Reiniciar servidor HTTP cada 5 minutos
#define MAX_WIFI_FAILURES 10            // Reiniciar ESP32 después de 10 fallos consecutivos
#define HEARTBEAT_INTERVAL 1000         // Parpadeo de heartbeat cada 1 segundo
#define MEMORY_CHECK_INTERVAL 60000     // Verificar memoria cada 60 segundos
#define MIN_FREE_HEAP 10000             // Reiniciar si la memoria libre es menor a 10KB

// =================== PINES DEL HARDWARE ===================
// Pines del lector RFID PN532 (I2C)
#define PN532_SDA     26   // GPIO 26
#define PN532_SCL     27   // GPIO 27

// Pines de LEDs indicadores
#define LED_WIFI      2    // LED integrado del ESP32

// Pin del buzzer (activo o pasivo: tone() funciona con ambos)
#define BUZZER_PIN    25   // GPIO 25

// Botón BOOT de la placa, para el reset de fábrica.
//
// OJO: GPIO0 es un pin de "strapping". Si está en LOW en el momento del
// arranque, el ESP32 entra en modo de descarga y el programa ni siquiera
// corre. Por eso el gesto de reset es mantenerlo pulsado con el equipo YA
// ENCENDIDO, nunca al encenderlo.
#define BOTON_RESET_PIN       0      // GPIO 0 (BOOT)
#define RESET_MANTENER_MS     3000   // 3 s pulsado para borrar la vinculación

// El botón solo hace algo durante los primeros segundos tras encender.
// Pasada esa ventana se ignora, para que un cable pinzado o un dedo curioso
// en plena jornada no desvincule el gimnasio sin que nadie se entere: el
// lector dejaría de funcionar y no habría forma de saber por qué.
#define RESET_VENTANA_MS      10000  // 10 s desde el arranque

// =================== ESTADOS DE MEMBRESÍA ===================
#define MEMBERSHIP_ACTIVE      "active"
#define MEMBERSHIP_EXPIRING    "expiring"
#define MEMBERSHIP_EXPIRED     "expired"
#define MEMBERSHIP_NOT_FOUND   "not_found"

// =================== VARIABLES GLOBALES ===================
// Objetos principales
// IMPORTANTE: PN532_I2C debe inicializarse DESPUÉS de Wire.begin()
// Por eso se inicializa en setup(), aquí solo declaramos los punteros
PN532_I2C *pn532i2c;
PN532 *nfc;
WebServer server(80);

// =================== VINCULACIÓN CON UN GIMNASIO ===================
// El lector pertenece a UN gimnasio. Sin esto, cualquier app de la red que
// preguntara por /api/uid se llevaba los pases de tarjeta: dos gimnasios en
// la misma WiFi recibían la alerta del mismo pase.
Preferences prefs;

// gym_id del dueño. Vacío = lector sin vincular, listo para que alguien lo
// reclame. NUNCA se devuelve en ninguna respuesta HTTP: si se filtrara, el
// gimnasio de al lado podría copiarlo y suplantar al dueño.
String gymIdVinculado = "";

// Control del botón de reset de fábrica (sin bloquear el loop).
unsigned long botonPulsadoDesde = 0;

// Reinicio diferido. Nunca se llama a ESP.restart() dentro de un handler
// HTTP: el servidor no habría terminado de vaciar el socket y el cliente
// vería la conexión rota en vez de la confirmación, sin poder distinguir
// "se aplicó" de "se perdió la petición" — y sin saber a qué IP buscarlo.
unsigned long reinicioPendienteEn = 0;

// Variables de estado
bool wifiConnected = false;
String lastUid = "NO_CARD";
String networkType = "none";  // Tipo de red: "static", "dhcp", "none"
bool staticIPConfigured = false; // Indica si se aplicó correctamente la IP estática

// Variables para control de escaneo RFID (evitar lecturas duplicadas)
unsigned long lastCardReadTime = 0;
String lastScannedCard = "";

// Variables para reintento de conexión WiFi
const unsigned long WIFI_CHECK_INTERVAL = 10000; // 10 segundos
const int MAX_CONNECTION_RETRIES = 3; // Número máximo de reintentos antes de recurrir a DHCP
int connectionRetries = 0;

// Variables para auto-recovery y monitoreo
unsigned long lastWiFiCheck = 0;
unsigned long lastServerRestart = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastMemoryCheck = 0;
int consecutiveWiFiFailures = 0;
bool serverRunning = false;
unsigned long systemUptime = 0;

// =================== DECLARACIONES DE FUNCIONES ===================
void connectToWiFi();
bool setupStaticIP();
void setupServerRoutes();
void handleGetUid();
void handleGetUidOnly();
void handleStatus();
void handleDiscover();
void handleStatusLeds();
void beepLectura();
void pruebaVolumenBuzzer();
void cargarVinculacion();
bool peticionAutorizada();
void responderNoAutorizado();
void handleClaim();
void handleUnclaim();
void handleReset();
void handleNetwork();
void revisarBotonReset();
String gymIdDeLaPeticion();
String getCardUID(uint8_t* uid, uint8_t uidLength);
bool isStaticIPConfigured();

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("=== GYMADS v5.2.0 ===");
  Serial.println("PN532 RFID Only + Auto-Recovery");

  // Inicializar Watchdog Timer para auto-reinicio si el sistema se congela
  Serial.println("Init Watchdog Timer...");
  esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT_SECONDS * 1000,
    .idle_core_mask = (1 << portNUM_PROCESSORS) - 1,  // Monitorear todos los cores
    .trigger_panic = true  // Reinicio automático habilitado
  };
  
  esp_err_t err = esp_task_wdt_init(&wdt_config);
  if (err != ESP_OK) {
    // Si ya estaba inicializado, intentamos reconfigurarlo al nuevo timeout
    esp_task_wdt_reconfigure(&wdt_config);
  }
  esp_task_wdt_add(NULL);  // Añadir la tarea actual al WDT

  // Configurar LEDs
  pinMode(LED_WIFI, OUTPUT);

  // Apagar todos los LEDs al inicio
  digitalWrite(LED_WIFI, LOW);

  // Configurar buzzer (apagado al inicio)
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Botón BOOT para el reset de fábrica (lleva pull-up en la placa)
  pinMode(BOTON_RESET_PIN, INPUT_PULLUP);

  // A qué gimnasio pertenece este lector, y qué IP tiene asignada
  cargarVinculacion();

#if BUZZER_MODO_PRUEBA
  pruebaVolumenBuzzer();
#endif

  // Inicializar I2C para PN532
  Serial.println("Init I2C...");
  Wire.begin(PN532_SDA, PN532_SCL);
  Wire.setClock(100000);
  delay(500);  // Delay más largo para que el PN532 se inicialice
  
  // IMPORTANTE: Crear los objetos PN532 DESPUÉS de Wire.begin()
  Serial.println("Init PN532 objects...");
  pn532i2c = new PN532_I2C(Wire);
  nfc = new PN532(*pn532i2c);
  
  // Inicializar lector RFID PN532
  Serial.println("Init PN532...");
  nfc->begin();
  delay(500);
  
  uint32_t versiondata = nfc->getFirmwareVersion();
  if (!versiondata) {
    Serial.println("ERROR: PN532 no encontrado");
    Serial.println("Verifica: SDA->21, SCL->22, VCC->3.3V");
  } else {
    Serial.print("PN532 OK - FW v");
    Serial.print((versiondata >> 16) & 0xFF);
    Serial.print(".");
    Serial.println((versiondata >> 8) & 0xFF);
    nfc->SAMConfig();
    // Configurar reintentos MUY bajos para NO bloquear el loop y que el servidor HTTP responda
    nfc->setPassiveActivationRetries(0x01);
  }

  // Conectar a WiFi
  connectToWiFi();

  // Configurar servidor HTTP si está conectado
  if (wifiConnected) {
    setupServerRoutes();
    server.begin();
    serverRunning = true;
    Serial.print("HTTP Server: ");
    Serial.println(WiFi.localIP());
  }

  // Inicializar tiempos de monitoreo
  lastWiFiCheck = millis();
  lastServerRestart = millis();
  lastHeartbeat = millis();
  lastMemoryCheck = millis();
  systemUptime = millis();

  if (wifiConnected) {
    digitalWrite(LED_WIFI, HIGH);
  }
  
  Serial.println("=== SISTEMA LISTO ===");
  Serial.print("Heap libre: ");
  Serial.print(ESP.getFreeHeap());
  Serial.println(" bytes");
}

void loop() {
  // CRÍTICO: Alimentar el Watchdog Timer para evitar reinicio
  esp_task_wdt_reset();
  
  unsigned long currentMillis = millis();
  
  // Heartbeat LED (sin delay bloqueante)
  if (currentMillis - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = currentMillis;
    if (wifiConnected) {
      // Toggle rápido sin delay
      static bool heartbeatState = true;
      heartbeatState = !heartbeatState;
      digitalWrite(LED_WIFI, heartbeatState ? HIGH : LOW);
    }
  }
  
  // Monitoreo de memoria - reiniciar si hay poca memoria disponible
  if (currentMillis - lastMemoryCheck >= MEMORY_CHECK_INTERVAL) {
    lastMemoryCheck = currentMillis;
    uint32_t freeHeap = ESP.getFreeHeap();
    
    // Log de estado periódico
    Serial.print("[STATUS] Uptime: ");
    Serial.print((currentMillis - systemUptime) / 1000);
    Serial.print("s, Heap: ");
    Serial.print(freeHeap);
    Serial.print(", WiFi: ");
    Serial.print(wifiConnected ? "OK" : "DISCONNECTED");
    Serial.print(", Server: ");
    Serial.println(serverRunning ? "OK" : "STOPPED");
    
    if (freeHeap < MIN_FREE_HEAP) {
      Serial.println("[WARNING] Memoria baja detectada - Reiniciando...");
      delay(500);
      ESP.restart();
    }
  }
  
  // Manejar solicitudes del servidor HTTP (si WiFi está conectado)
  if (wifiConnected && serverRunning) {
    server.handleClient();
  }

  // Manejar LEDs de estado
  handleStatusLeds();

  // Reset de fábrica si se mantiene pulsado el botón BOOT
  revisarBotonReset();

  // Reinicio programado por un cambio de IP o un reset de fábrica. Se hace
  // aquí y no dentro del handler para que la respuesta HTTP alcance a salir.
  if (reinicioPendienteEn != 0 && millis() >= reinicioPendienteEn) {
    ESP.restart();
  }

  // Solo procesar RFID si estamos conectados a WiFi
  if (wifiConnected && serverRunning) {
    uint8_t uid[] = { 0, 0, 0, 0, 0, 0, 0 };
    uint8_t uidLength;
    
    // Leer tarjeta/llavero RFID
    if (nfc->readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength)) {
      String cardUid = getCardUID(uid, uidLength);
      unsigned long currentTime = millis();

      // Permitir lectura si es tarjeta nueva o si pasó el tiempo de espera
      if (cardUid != lastScannedCard || (currentTime - lastCardReadTime >= CARD_READ_INTERVAL_MS)) {
        lastScannedCard = cardUid;
        lastCardReadTime = currentTime;
        beepLectura();

        if (cardUid != lastUid) {
          lastUid = cardUid;
          Serial.print("[RFID] UID: ");
          Serial.println(cardUid);
        }
      }
    } else {
      // No hay tarjeta presente, resetear el UID después de un tiempo
      static unsigned long lastNoCardTime = 0;
      
      if (lastUid != "NO_CARD") {
        if (lastNoCardTime == 0) {
          lastNoCardTime = millis();
        } else if (millis() - lastNoCardTime > 1000) { // 1 segundo sin tarjeta
          lastUid = "NO_CARD";
          lastScannedCard = "";
          lastNoCardTime = 0;
        }
      } else {
        lastNoCardTime = 0;
      }
    }
  }

  // Verificar estado de conexión WiFi periódicamente con auto-recovery mejorado
  if (currentMillis - lastWiFiCheck >= WIFI_RECONNECT_INTERVAL) {
    lastWiFiCheck = currentMillis;
    
    if (WiFi.status() != WL_CONNECTED) {
      consecutiveWiFiFailures++;
      Serial.print("[WiFi] Desconectado. Intentos fallidos: ");
      Serial.println(consecutiveWiFiFailures);
      
      if (wifiConnected) {
        wifiConnected = false;
        serverRunning = false;
        digitalWrite(LED_WIFI, LOW);
      }
      
      // Si hay muchos fallos consecutivos, reiniciar el ESP32
      if (consecutiveWiFiFailures >= MAX_WIFI_FAILURES) {
        Serial.println("[WiFi] Máximo de fallos alcanzado - Reiniciando ESP32...");
        delay(500);
        ESP.restart();
      }
      
      // Intentar reconectar
      connectToWiFi();
      
      // Si se reconectó, reiniciar el servidor
      if (wifiConnected) {
        Serial.println("[WiFi] Reconectado. Reiniciando servidor HTTP...");
        server.close();
        delay(100);
        setupServerRoutes();
        server.begin();
        serverRunning = true;
        consecutiveWiFiFailures = 0;
        Serial.print("[Server] Escuchando en: ");
        Serial.println(WiFi.localIP());
      }
    } else {
      // WiFi conectado correctamente
      if (!wifiConnected) {
        wifiConnected = true;
        digitalWrite(LED_WIFI, HIGH);
        consecutiveWiFiFailures = 0;
      }
      
      // Verificar si el servidor necesita reiniciarse
      // Reiniciar preventivamente el servidor cada SERVER_RESTART_INTERVAL
      if (serverRunning && (currentMillis - lastServerRestart >= SERVER_RESTART_INTERVAL)) {
        Serial.println("[Server] Reinicio preventivo del servidor HTTP...");
        server.close();
        delay(100);
        setupServerRoutes();
        server.begin();
        lastServerRestart = currentMillis;
        Serial.println("[Server] Servidor reiniciado correctamente");
      }
    }
  }
}

// =================== FUNCIONES WIFI ===================

// Configuración de IP estática
bool setupStaticIP() {
  // Si este aparato tiene una IP propia guardada, se usa esa. Antes todos
  // los lectores salían con la misma IP compilada, así que dos en la misma
  // red chocaban. La compilada queda solo como respaldo de fábrica.
  prefs.begin("gymone", true);
  String ipGuardada = prefs.getString("ip", "");
  String gwGuardado = prefs.getString("gw", "");
  prefs.end();

  if (ipGuardada.length() > 0) {
    IPAddress ipPropia;
    if (ipPropia.fromString(ipGuardada)) {
      staticIP = ipPropia;
      Serial.println("[RED] Usando la IP guardada en este aparato.");
    }
  }
  if (gwGuardado.length() > 0) {
    IPAddress gwPropio;
    if (gwPropio.fromString(gwGuardado)) gateway = gwPropio;
  }

  Serial.println("Configurando IP estática: " + staticIP.toString());
  
  // Primer intento directo
  if (!WiFi.config(staticIP, gateway, subnet, dns)) {
    Serial.println("Error: La configuración de IP estática falló en el primer intento");
    
    // Segundo intento con desconexión previa
    WiFi.disconnect(true);
    delay(1000);
    if (!WiFi.config(staticIP, gateway, subnet, dns)) {
      Serial.println("Error: La configuración de IP estática falló en el segundo intento");
      return false;
    }
  }
  
  Serial.println("IP estática configurada correctamente");
  networkType = "static";
  staticIPConfigured = true;
  return true;
}

// Verificar si la IP estática se aplicó correctamente
bool isStaticIPConfigured() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }
  
  // Compara la IP actual con la IP estática solicitada
  IPAddress currentIP = WiFi.localIP();
  return currentIP == staticIP;
}

// Conectar a WiFi
void connectToWiFi() {
  Serial.print("WiFi: ");
  Serial.print(WIFI_SSID);

  // Reiniciar contadores si este es un nuevo intento de conexión
  if (!wifiConnected) {
    connectionRetries = 0;
  }

  // Configurar modo WiFi
  WiFi.mode(WIFI_STA);
  
  // Configurar IP estática si está habilitada
  bool staticIPSetupSuccess = false;
  if (useStaticIP) {
    staticIPSetupSuccess = setupStaticIP();
    if (!staticIPSetupSuccess && connectionRetries >= MAX_CONNECTION_RETRIES) {
      Serial.println("ADVERTENCIA: Después de varios intentos, usando DHCP en lugar de IP estática");
      useStaticIP = false;
      networkType = "dhcp";
    }
  } else {
    networkType = "dhcp";
  }
  
  // Iniciar conexión
  WiFi.setAutoReconnect(true);  // Habilitar reconexión automática del stack WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  // LED parpadeando durante conexión
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    esp_task_wdt_reset(); // Alimentar el watchdog durante la espera
    delay(500);
    Serial.print(".");
    digitalWrite(LED_WIFI, !digitalRead(LED_WIFI)); // Parpadeo
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    digitalWrite(LED_WIFI, HIGH);
    Serial.print(" OK - ");
    Serial.println(WiFi.localIP());
    
    if (isStaticIPConfigured()) {
      networkType = "static";
      staticIPConfigured = true;
    } else if (useStaticIP) {
      networkType = "dhcp";
      staticIPConfigured = false;
      connectionRetries++;
      
      if (connectionRetries < MAX_CONNECTION_RETRIES) {
        WiFi.disconnect(true);
        delay(1000);
        connectToWiFi();
        return;
      }
    } else {
      networkType = "dhcp";
    }
  } else {
    wifiConnected = false;
    networkType = "none";
    digitalWrite(LED_WIFI, LOW);
    Serial.println(" FAIL");
  }
}

// =================== SERVIDOR HTTP ===================

// Configurar rutas del servidor HTTP
void setupServerRoutes() {
  // Rutas para comunicación con la aplicación Flutter
  server.on("/api/uid", HTTP_GET, handleGetUid);
  server.on("/api/uid_only", HTTP_GET, handleGetUidOnly);  // Endpoint silencioso
  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/discover", HTTP_GET, handleDiscover);

  // Vinculación del lector con un gimnasio
  server.on("/api/claim", HTTP_POST, handleClaim);
  server.on("/api/unclaim", HTTP_POST, handleUnclaim);
  server.on("/api/reset", HTTP_POST, handleReset);
  server.on("/api/network", HTTP_POST, handleNetwork);

  // Configurar headers CORS manualmente para mayor compatibilidad
  server.enableCORS(true);
}

// Manejador para la ruta /api/uid
void handleGetUid() {
  // El UID solo sale si quien pregunta es el gimnasio dueño del lector.
  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }

  // Solo enviar el UID, NO resetearlo
  // El reseteo se maneja en el loop principal
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", lastUid);
}

// Manejador para la ruta /api/uid_only - Solo devuelve el UID sin activar LEDs
// Usado para capturar tarjetas al agregar nuevos clientes
void handleGetUidOnly() {
  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }
  server.send(200, "text/plain", lastUid);
}

// Manejador para la ruta /api/status
void handleStatus() {
  // Agregar headers para evitar problemas de conexión
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  
  DynamicJsonDocument doc(400);
  doc["status"] = "OK";
  doc["wifi_connected"] = wifiConnected;
  // `last_uid` ya NO va aquí: este endpoint está abierto (hace falta para
  // encontrar el lector antes de vincularlo) y devolvía el UID de la última
  // tarjeta a cualquiera que preguntara, justo lo que /api/uid ya protege.
  doc["claimed"] = gymIdVinculado.length() > 0;
  doc["ip_address"] = WiFi.localIP().toString();
  doc["network_type"] = networkType;
  doc["static_ip_enabled"] = useStaticIP;
  doc["static_ip_configured"] = staticIPConfigured;
  doc["expected_ip"] = staticIP.toString();
  doc["uptime_seconds"] = (millis() - systemUptime) / 1000;
  doc["free_heap"] = ESP.getFreeHeap();
  doc["server_running"] = serverRunning;

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

// Manejador para la ruta /api/discover - Identificación del dispositivo
void handleDiscover() {
  DynamicJsonDocument doc(512);
  doc["device_id"] = "ESP32_RFID_GYMADS";
  doc["device_type"] = "RFID_READER";
  doc["version"] = "5.2.0";

  // Identidad del dueño, en forma de respuesta SÍ/NO.
  //
  // `claimed` dice si el lector ya tiene dueño; `mine` responde a "¿soy yo?"
  // comparando contra el gym_id que manda quien pregunta. El gym_id guardado
  // NO se incluye a propósito: devolverlo dejaría que el gimnasio de al lado
  // lo copiara y se hiciera pasar por el dueño, y la vinculación no serviría
  // de nada.
  doc["claimed"] = gymIdVinculado.length() > 0;
  doc["mine"] = peticionAutorizada();
  doc["rfid_reader"] = "PN532";
  doc["manufacturer"] = "GYMADS";
  doc["wifi_connected"] = wifiConnected;
  doc["status"] = "ONLINE";
  doc["uptime"] = millis();
  doc["uptime_seconds"] = (millis() - systemUptime) / 1000;
  doc["free_heap"] = ESP.getFreeHeap();
  doc["network_type"] = networkType;
  doc["static_ip_enabled"] = useStaticIP;
  doc["static_ip_configured"] = staticIPConfigured;
  doc["server_running"] = serverRunning;

  if (wifiConnected) {
    doc["ip_address"] = WiFi.localIP().toString();
    doc["gateway"] = WiFi.gatewayIP().toString();
    doc["subnet"] = WiFi.subnetMask().toString();
    doc["dns"] = WiFi.dnsIP().toString();
    doc["mac_address"] = WiFi.macAddress();
    doc["signal_strength"] = WiFi.RSSI();
    doc["ssid"] = WiFi.SSID();
  }

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

// =================== VINCULACIÓN CON UN GIMNASIO ===================

// Lee de NVS a qué gimnasio pertenece este lector. Se llama una vez al
// arrancar; el resto del programa consulta `gymIdVinculado`.
void cargarVinculacion() {
  prefs.begin("gymone", true);  // solo lectura
  gymIdVinculado = prefs.getString("gym_id", "");
  prefs.end();

  if (gymIdVinculado.length() > 0) {
    Serial.println("[VINCULACION] Lector vinculado a un gimnasio.");
  } else {
    Serial.println("[VINCULACION] Lector SIN vincular: listo para reclamar.");
  }
}

// El gym_id que manda quien pregunta, por query (?gym_id=) o en el cuerpo
// JSON del POST. Devuelve "" si no vino.
String gymIdDeLaPeticion() {
  if (server.hasArg("gym_id")) {
    return server.arg("gym_id");
  }

  // En un POST el cuerpo crudo llega como el argumento "plain".
  if (server.hasArg("plain")) {
    DynamicJsonDocument doc(256);
    if (deserializeJson(doc, server.arg("plain")) == DeserializationError::Ok) {
      const char* valor = doc["gym_id"];
      if (valor != nullptr) return String(valor);
    }
  }

  return "";
}

// ¿Quien pregunta es el dueño de este lector?
//
// Un lector sin vincular no autoriza a nadie: primero hay que reclamarlo.
// Así, un aparato recién sacado de la caja no reparte pases de tarjeta por
// toda la red mientras nadie lo configura.
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
  server.sendHeader("Access-Control-Allow-Origin", "*");
  String gymId = gymIdDeLaPeticion();

  if (gymId.length() == 0) {
    server.send(400, "application/json", "{\"error\":\"falta gym_id\"}");
    return;
  }

  // Ya tiene dueño: no se le puede quitar a otro gimnasio desde la red. La
  // salida legítima es que el dueño lo libere, o el reset físico de fábrica.
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
  beepLectura();  // confirmación audible de que quedó emparejado
  server.send(200, "application/json", "{\"ok\":true}");
}

// POST /api/unclaim {"gym_id": "..."} — liberar el lector. Solo el dueño.
void handleUnclaim() {
  server.sendHeader("Access-Control-Allow-Origin", "*");

  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }

  prefs.begin("gymone", false);
  prefs.remove("gym_id");
  prefs.end();
  gymIdVinculado = "";

  Serial.println("[VINCULACION] Lector liberado: queda sin dueño.");
  server.send(200, "application/json", "{\"ok\":true}");
}

// POST /api/reset — libera el lector SIN comprobar quién lo pide.
//
// Es lo único que lo separa de /api/unclaim, que sí exige ser el dueño. Existe
// para poder recuperar un lector que quedó vinculado a un gimnasio al que ya no
// se tiene acceso (una cuenta borrada, un encargado que se fue con el teléfono)
// sin depender del botón físico del aparato.
//
// El precio, asumido a propósito: cualquiera en la red puede formatear
// cualquier lector. Por eso pita mientras lo hace — un lector robado en
// silencio pasa desapercibido; uno que se pone a sonar, no.
//
// NO borra la IP guardada: si se borrara, el aparato saltaría a la IP de
// fábrica y podrías quedarte sin saber dónde encontrarlo.
void handleReset() {
  server.sendHeader("Access-Control-Allow-Origin", "*");

  prefs.begin("gymone", false);
  prefs.remove("gym_id");
  prefs.end();
  gymIdVinculado = "";

  Serial.println("[RESET] Lector formateado desde la red: queda sin dueño.");
  tone(BUZZER_PIN, BUZZER_BEEP_HZ, 2000);  // que se oiga quién lo suelta

  // Responde 200 aunque ya estuviera libre: así, si la app reintenta tras un
  // timeout, no se encuentra con un error de algo que en realidad ya salió bien.
  server.send(200, "application/json", "{\"ok\":true}");
}

// POST /api/network {"gym_id":"...","ip":"192.168.1.101","gateway":"192.168.1.1"}
//
// Le asigna a ESTE aparato su propia IP fija. Antes todos salían con la
// misma (192.168.1.100), así que dos lectores en una red chocaban y ninguno
// funcionaba bien. Solo el dueño puede cambiarla.
void handleNetwork() {
  server.sendHeader("Access-Control-Allow-Origin", "*");

  if (!peticionAutorizada()) {
    responderNoAutorizado();
    return;
  }

  DynamicJsonDocument doc(256);
  if (deserializeJson(doc, server.arg("plain")) != DeserializationError::Ok) {
    server.send(400, "application/json", "{\"error\":\"json invalido\"}");
    return;
  }

  const char* ipTexto = doc["ip"];
  if (ipTexto == nullptr) {
    server.send(400, "application/json", "{\"error\":\"falta ip\"}");
    return;
  }

  IPAddress nuevaIp;
  if (!nuevaIp.fromString(ipTexto)) {
    server.send(400, "application/json", "{\"error\":\"ip invalida\"}");
    return;
  }

  prefs.begin("gymone", false);
  prefs.putString("ip", ipTexto);
  const char* gwTexto = doc["gateway"];
  if (gwTexto != nullptr) {
    IPAddress nuevoGw;
    if (nuevoGw.fromString(gwTexto)) prefs.putString("gw", gwTexto);
  }
  prefs.end();

  // Se responde ANTES de reiniciar y el reinicio se deja programado: cambiar
  // la IP corta la conexión en curso, y sin este margen la app se quedaría
  // esperando una respuesta que nunca llega.
  server.sendHeader("Connection", "close");
  server.send(200, "application/json",
              "{\"ok\":true,\"reboot_in_ms\":1500}");
  reinicioPendienteEn = millis() + 1500;
}

// Reset de fábrica con el botón BOOT, revisado desde el loop sin bloquear.
//
// El gesto es mantenerlo pulsado 5 s con el equipo YA ENCENDIDO. No se puede
// hacer "pulsar al arrancar" porque GPIO0 es pin de strapping: en LOW durante
// el arranque, el ESP32 entra en modo de descarga y este programa no corre.
void revisarBotonReset() {
  // Fuera de la ventana de arranque el botón no hace nada.
  if (millis() - systemUptime > RESET_VENTANA_MS) {
    botonPulsadoDesde = 0;
    return;
  }

  // El botón lleva pull-up: pulsado = LOW.
  bool pulsado = (digitalRead(BOTON_RESET_PIN) == LOW);

  if (!pulsado) {
    botonPulsadoDesde = 0;  // lo soltó antes de tiempo
    return;
  }

  if (botonPulsadoDesde == 0) {
    botonPulsadoDesde = millis();
    tone(BUZZER_PIN, BUZZER_BEEP_HZ, 80);  // "te estoy oyendo"
    return;
  }

  if (millis() - botonPulsadoDesde >= RESET_MANTENER_MS) {
    Serial.println("[RESET] Borrando la vinculación y la IP guardada...");
    prefs.begin("gymone", false);
    prefs.clear();
    prefs.end();

    tone(BUZZER_PIN, BUZZER_BEEP_HZ, 600);  // confirmación larga
    reinicioPendienteEn = millis() + 800;
    botonPulsadoDesde = 0;
  }
}

// =================== CONTROL DE SONIDO ===================

// Beep corto de confirmación al leer una tarjeta durante el escaneo.
// No bloquea: tone() con duración se apaga sola en su propia tarea, así
// que el loop sigue su curso normal mientras suena.
void beepLectura() {
  tone(BUZZER_PIN, BUZZER_BEEP_HZ, BUZZER_BEEP_MS);
}

#if BUZZER_MODO_PRUEBA
// Barrido de frecuencias para encontrar dónde suena más fuerte este buzzer
// en concreto. Corre una sola vez, en el arranque, ANTES de conectar WiFi:
// bloquea unos 4 segundos con delay(), cosa que en cualquier otro punto del
// programa estaría prohibida, pero aquí el watchdog todavía tiene sus 30
// segundos completos por delante y no hay servidor HTTP que deba responder.
void pruebaVolumenBuzzer() {
  // Primer barrido (300-5000 Hz, a saltos de 300-500) dio los agudos como
  // rango más fuerte. Este segundo barrido peina 3500-5000 Hz a saltos de
  // 150 Hz para encontrar el pico exacto dentro de ese rango.
  const int frecuencias[] = {3500, 3650, 3800, 3950, 4100, 4250, 4400, 4550, 4700, 4850, 5000};
  const int cantidad = sizeof(frecuencias) / sizeof(frecuencias[0]);

  Serial.println("[BUZZER] Prueba de volumen (afinada): 11 frecuencias, una cada 400 ms.");
  Serial.println("[BUZZER] Escucha cuál suena MÁS FUERTE y avisa el número en Hz.");

  for (int i = 0; i < cantidad; i++) {
    esp_task_wdt_reset();  // el barrido bloquea, pero el watchdog sigue vivo
    Serial.print("[BUZZER] Sonando ahora: ");
    Serial.print(frecuencias[i]);
    Serial.println(" Hz");
    tone(BUZZER_PIN, frecuencias[i], 250);
    delay(400);
  }

  Serial.println("[BUZZER] Fin de la prueba.");
}
#endif

// =================== CONTROL DE LEDS ===================

// Manejar LEDs de estado
void handleStatusLeds() {
  // LED WiFi: fijo si conectado, apagado si no
  if (wifiConnected) {
    digitalWrite(LED_WIFI, HIGH);
  } else {
    // Parpadeo lento si no está conectado
    static unsigned long lastBlink = 0;
    if (millis() - lastBlink > 1000) {
      digitalWrite(LED_WIFI, !digitalRead(LED_WIFI));
      lastBlink = millis();
    }
  }
}

// =================== UTILIDADES ===================

// Convierte el UID de la tarjeta a formato String
String getCardUID(uint8_t* uid, uint8_t uidLength) {
  String cardString = "";
  char buf[3];
  for (byte i = 0; i < uidLength; i++) {
    snprintf(buf, sizeof(buf), "%02X", uid[i]);
    cardString += buf;
  }
  return cardString;
}

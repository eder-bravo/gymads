/*
 * GYMADS - ESP32 RFID Reader con WiFi
 * LECTOR RFID CON CONEXIÓN WIFI AUTOMÁTICA PARA GYMADS
 * 
 * Versión 5.0.0 - Solo WiFi (Sin Bluetooth) - PN532 RFID Only + Auto-Recovery
 * Dispositivo: ESP32
 * 
 * Función: Leer tarjetas RFID físicas y llaveros NFC
 * Sistema simplificado para lectura de tarjetas RFID con conectividad WiFi
 * Versión: 5.0.0 - WiFi robusto con reconexión automática + Watchdog + Keep-alive
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

// =================== CONFIGURACIÓN WIFI ===================
// TODO: Cambiar estas credenciales por las de tu red WiFi
//const char* WIFI_SSID = "TD Campus_C";
//const char* WIFI_PASSWORD = "1Gestudio";

const char* WIFI_SSID = "FamiliaBlanco_2.4";
const char* WIFI_PASSWORD = "*E2d0e0r46";

// =================== CONFIGURACIÓN DE ESCANEO RFID ===================
// Intervalo mínimo entre lecturas de la misma tarjeta (en milisegundos)
// Aumenta este valor si necesitas más tiempo entre lecturas
// Por defecto: 3000 ms (3 segundos)
const unsigned long CARD_READ_INTERVAL_MS = 3000;

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
#define PN532_SDA     26   // GPIO 21
#define PN532_SCL     27   // GPIO 22

// Pines de LEDs indicadores
#define LED_WIFI      2    // LED integrado del ESP32

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
String getCardUID(uint8_t* uid, uint8_t uidLength);
bool isStaticIPConfigured();

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("=== GYMADS v5.0.0 ===");
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

  // Configurar headers CORS manualmente para mayor compatibilidad
  server.enableCORS(true);
}

// Manejador para la ruta /api/uid
void handleGetUid() {
  // Solo enviar el UID, NO resetearlo
  // El reseteo se maneja en el loop principal
  server.sendHeader("Connection", "close");
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", lastUid);
}

// Manejador para la ruta /api/uid_only - Solo devuelve el UID sin activar LEDs
// Usado para capturar tarjetas al agregar nuevos clientes
void handleGetUidOnly() {
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
  doc["last_uid"] = lastUid;
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
  doc["version"] = "5.0.0";
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

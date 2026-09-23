/**
 * =========================================================================================
 * 🚨 ESP32 ALL-IN-ONE SMART SOS EMERGENCY DEVICE (GPS + BLE + WIFI CLOUD) 🚨
 * =========================================================================================
 * 
 * 📌 HINDI DESCRIPTION (विवरण):
 * यह एकल (Single) मास्टर कोड ESP32 के तीनों फीचर्स को एक साथ चलाता है:
 * 1. NEO-6M GPS Module से लाइव लोकेशन (Latitude & Longitude) पढ़ना।
 * 2. Push Button (GPIO 25) दबाते ही इमरजेंसी अलर्ट चालू होना और LED (GPIO 26) का तेजी से ब्लिंक करना।
 * 3. Flutter Mobile App से Bluetooth Low Energy (BLE) द्वारा कनेक्ट होना (SOS-LIFELINK-BTN)।
 *    - बटन दबने पर फोन को तुरंत GPS लोकेशन भेजना -> फोन पर लाउड सायरन बजना और SMS जाना।
 *    - फोन ऐप से "STOP ALARM" दबाने पर ESP32 की LED बंद होना।
 * 4. WiFi Direct Cloud Fallback: अगर WiFi कनेक्टेड है, तो सीधे Render Cloud Server
 *    (https://sos-emergency-backend-277q.onrender.com/api/iot/trigger) पर SOS भेजना।
 * 
 * =========================================================================================
 * 📌 HARDWARE PIN CONNECTIONS (सर्किट कनेक्शन):
 * =========================================================================================
 * 1. GPS Module (NEO-6M / U-Blox / Compatible):
 *    - GPS VCC   ---> ESP32 3.3V / 5V
 *    - GPS GND   ---> ESP32 GND
 *    - GPS TX    ---> ESP32 GPIO 16 (RX2)
 *    - GPS RX    ---> ESP32 GPIO 17 (TX2)
 * 
 * 2. Push Button (Emergency SOS Button):
 *    - Leg 1     ---> ESP32 GPIO 25 (Internal INPUT_PULLUP enabled)
 *    - Leg 2     ---> ESP32 GND
 * 
 * 3. Status LED (Emergency Blinker):
 *    - Anode (+) ---> 220Ω / 330Ω Resistor ---> ESP32 GPIO 26
 *    - Cathode(-)---> ESP32 GND
 * 
 * =========================================================================================
 * 📌 REQUIRED ARDUINO LIBRARIES (लाइब्रेरी इंस्टाल करें):
 * =========================================================================================
 * Arduino IDE -> Sketch -> Include Library -> Manage Libraries:
 * 1. "TinyGPSPlus" by Mikal Hart
 * 2. "ESP32 BLE Arduino" (ESP32 Board package में पहले से शामिल रहता है)
 * =========================================================================================
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>
#include <WiFi.h>
#include <HTTPClient.h>

// =========================================================================================
// ⚙️ CONFIGURATION SETTINGS (कॉन्फ़िगरेशन)
// =========================================================================================

// 1. BLE Service & Characteristic UUIDs (Must match the Flutter Mobile App)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define BLE_DEVICE_NAME     "SOS-LIFELINK-BTN"

// 2. Hardware GPIO Pin Definitions
#define GPS_RX_PIN          16   // ESP32 RX2 <- GPS TX
#define GPS_TX_PIN          17   // ESP32 TX2 -> GPS RX
#define BUTTON_PIN          25   // Push button to GND
#define LED_PIN             26   // Emergency Status LED

// 3. Live Render Cloud Backend Configuration (Direct WiFi Webhook Fallback)
const char* cloudServerUrl   = "https://sos-emergency-backend-277q.onrender.com/api/iot/trigger";
const char* deviceIdentifier = "SOS-LIFELINK-BTN";
const char* iotSecretKey     = "sos_iot_secure_device_secret_2026";

// 4. Optional WiFi Credentials
// (अगर फोन हॉटस्पॉट या होम वाईफाई देना चाहते हैं तो यहाँ भरें, अन्यथा खाली छोड़ दें)
const char* wifi_ssid        = "";  // e.g. "MyHotspot"
const char* wifi_password    = "";  // e.g. "12345678"

// =========================================================================================
// 📡 OBJECTS & GLOBAL VARIABLES
// =========================================================================================
TinyGPSPlus gps;
HardwareSerial GPS(2); // UART 2

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// SOS & Button state variables
bool sosActive = false;
unsigned long lastBlink = 0;
bool ledState = false;
unsigned long lastLocationPrint = 0;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;
int lastButtonState = HIGH;

// =========================================================================================
// 📱 BLE CALLBACKS
// =========================================================================================

// Callback for connection / disconnection with the Android App
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("\n[BLE] >>> Mobile App Connected Successfully! <<<");
    // Quick double blink on LED to signal phone connected
    digitalWrite(LED_PIN, HIGH);
    delay(150);
    digitalWrite(LED_PIN, LOW);
    delay(100);
    digitalWrite(LED_PIN, HIGH);
    delay(150);
    digitalWrite(LED_PIN, LOW);
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("\n[BLE] >>> Mobile App Disconnected! Restarting advertising... <<<");
    if (!sosActive) {
      digitalWrite(LED_PIN, LOW);
    }
  }
};

// Callback to receive commands from the mobile app (e.g. "STOP_SOS")
class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) {
    String value = pChar->getValue().c_str();
    if (value.length() > 0) {
      Serial.print("[BLE Command Received]: ");
      Serial.println(value);

      // Stop emergency alarm and turn off LED
      if (value.startsWith("STOP_SOS") || value.startsWith("CANCEL")) {
        sosActive = false;
        digitalWrite(LED_PIN, LOW);
        Serial.println(">>> 🛑 SOS ALARM STOPPED by Phone App! LED Turn OFF <<<");
      }
    }
  }
};

// =========================================================================================
// 🚨 EMERGENCY SOS TRIGGER FUNCTION
// =========================================================================================
void triggerEmergencyAlert() {
  sosActive = true;
  Serial.println();
  Serial.println("************************************************************");
  Serial.println("       🚨 SOS EMERGENCY TRIGGERED VIA PUSH BUTTON! 🚨       ");
  Serial.println("************************************************************");

  String blePayload = "SOS_TRIGGER:";

  // 1. Check if GPS fix is available from NEO-6M
  if (gps.location.isValid()) {
    double lat = gps.location.lat();
    double lng = gps.location.lng();
    blePayload += "LAT:" + String(lat, 6) + ",LNG:" + String(lng, 6);

    Serial.print("[GPS] Accurate Location Acquired -> Lat: ");
    Serial.print(lat, 6);
    Serial.print(" | Lng: ");
    Serial.println(lng, 6);
  } else {
    blePayload += "NO_GPS";
    Serial.println("[GPS] Satellite lock pending. Mobile Phone GPS will be used as fallback.");
  }

  // 2. Transmit BLE Notification to Mobile Phone App
  if (deviceConnected && pCharacteristic != NULL) {
    pCharacteristic->setValue(blePayload.c_str());
    pCharacteristic->notify();
    Serial.print("[BLE] Transmitted Emergency Packet to Mobile App: ");
    Serial.println(blePayload);
  } else {
    Serial.println("[BLE Warning] Button clicked but Phone is not connected via BLE!");
  }

  // 3. Fallback: If WiFi is connected, send directly to Render Cloud Backend
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("[WiFi] Dispatching HTTP POST directly to Render Cloud...");
    HTTPClient http;
    http.begin(cloudServerUrl);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("x-iot-key", iotSecretKey);

    String json = "{";
    json += "\"deviceIdentifier\":\"" + String(deviceIdentifier) + "\",";
    json += "\"secretKey\":\"" + String(iotSecretKey) + "\",";
    if (gps.location.isValid()) {
      json += "\"latitude\":" + String(gps.location.lat(), 6) + ",";
      json += "\"longitude\":" + String(gps.location.lng(), 6) + ",";
    }
    json += "\"batteryLevel\":95";
    json += "}";

    int httpCode = http.POST(json);
    Serial.printf("[WiFi Cloud] Render Server Response Code: %d\n", httpCode);
    if (httpCode > 0) {
      String resp = http.getString();
      Serial.println("[WiFi Cloud] Server Response: " + resp);
    }
    http.end();
  }
}

// =========================================================================================
// 🚀 ARDUINO SETUP
// =========================================================================================
void setup() {
  Serial.begin(115200);

  // Initialize Hardware UART for GPS (9600 baud standard for NEO-6M)
  GPS.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  // Initialize Button (Active LOW) and LED
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println();
  Serial.println("============================================================");
  Serial.println("     🚨 ESP32 ALL-IN-ONE SMART SOS EMERGENCY SYSTEM 🚨      ");
  Serial.println("============================================================");
  Serial.printf("GPS Serial initialized on RX: %d, TX: %d (9600 baud)\n", GPS_RX_PIN, GPS_TX_PIN);
  Serial.printf("Push Button configured on GPIO %d (INPUT_PULLUP)\n", BUTTON_PIN);
  Serial.printf("Status LED configured on GPIO %d\n", LED_PIN);
  Serial.println("Starting BLE Server advertising...");

  // Initialize BLE Device
  BLEDevice::init(BLE_DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ   |
    BLECharacteristic::PROPERTY_WRITE  |
    BLECharacteristic::PROPERTY_NOTIFY
  );

  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setValue("READY");

  pService->start();

  // Start BLE Advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Device is advertising as: 'SOS-LIFELINK-BTN'");
  Serial.println("[System] Ready! Waiting for phone connection & GPS fix.\n");

  // Optional: Connect to WiFi if credentials are set
  if (strlen(wifi_ssid) > 0) {
    Serial.printf("[WiFi] Connecting to %s ...\n", wifi_ssid);
    WiFi.begin(wifi_ssid, wifi_password);
  }
}

// =========================================================================================
// 🔄 ARDUINO MAIN LOOP
// =========================================================================================
void loop() {
  // 1. Read GPS NMEA sentences continuously from NEO-6M
  while (GPS.available()) {
    gps.encode(GPS.read());
  }

  // 2. Debounce and read physical push button (Active LOW)
  int reading = digitalRead(BUTTON_PIN);
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading == LOW) {
      // Button was pressed -> trigger SOS
      triggerEmergencyAlert();

      // Wait until button is released to prevent repeated trigger
      while (digitalRead(BUTTON_PIN) == LOW) {
        while (GPS.available()) {
          gps.encode(GPS.read());
        }
        delay(10);
      }
      delay(50);
    }
  }
  lastButtonState = reading;

  // 3. Emergency LED rapid blink when SOS is active
  if (sosActive) {
    if (millis() - lastBlink >= 150) {
      lastBlink = millis();
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState);
    }
  }

  // 4. Periodic GPS info printing to Serial Monitor (every 3 seconds)
  if (millis() - lastLocationPrint >= 3000) {
    lastLocationPrint = millis();

    if (gps.location.isValid()) {
      Serial.printf("[GPS Fix Active] Lat: %.6f | Lng: %.6f | Satellites: %d\n",
                    gps.location.lat(), gps.location.lng(), gps.satellites.value());
    } else {
      Serial.printf("[GPS] Searching for satellites... (Bytes processed: %u)\n",
                    gps.charsProcessed());
    }
  }

  // 5. Handle BLE reconnection advertising automatically
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] Restarted advertising after disconnect...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(10);
}

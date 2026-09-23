/**
 * =====================================================================
 * ESP32 GPS + BLE SMART SOS EMERGENCY BUTTON
 * =====================================================================
 * Pin Connections:
 * - GPS Module (NEO-6M / Compatible):
 *     ESP32 GPIO 16 (RX2) <- GPS TX
 *     ESP32 GPIO 17 (TX2) -> GPS RX
 * - Push Button: GPIO 25 (Connected to GND, INPUT_PULLUP)
 * - Status LED:  GPIO 26 (Connected to GND via 220-330 ohm resistor)
 *
 * Features:
 * 1. Reads TinyGPSPlus GPS fix continuously on HardwareSerial(2) at 9600 baud.
 * 2. Connects to the Android Mobile App via Bluetooth Low Energy (BLE).
 * 3. When physical button on GPIO 25 is pressed:
 *    - Transmits SOS alert to Android App with live GPS coordinates if available.
 *    - Activates rapid emergency blinking on LED PIN 26.
 * 4. Listens for BLE write commands from phone ("STOP_SOS") to silence/turn off LED.
 * 5. Serial Monitor prints detailed status at 115200 baud.
 * =====================================================================
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>

// BLE Service & Characteristic UUIDs (must match Flutter App constants)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Hardware Pin Definitions
#define GPS_RX 16   // ESP32 RX2 <- GPS TX
#define GPS_TX 17   // ESP32 TX2 -> GPS RX
#define BUTTON_PIN 25
#define LED_PIN 26

// GPS and Serial
TinyGPSPlus gps;
HardwareSerial GPS(2);

// BLE Server & Characteristic
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// SOS State Tracking
bool sosActive = false;
unsigned long lastBlink = 0;
bool ledState = false;
unsigned long lastLocationPrint = 0;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;
int lastButtonState = HIGH;

// BLE Server Callbacks
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("\n[BLE] >>> Mobile App Connected! <<<");
    // Turn LED on briefly to indicate connection
    digitalWrite(LED_PIN, HIGH);
    delay(200);
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

// BLE Characteristic Callbacks (to receive STOP_SOS from Android app)
class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) {
    String value = pChar->getValue().c_str();
    if (value.length() > 0) {
      Serial.print("[BLE Command Received]: ");
      Serial.println(value);

      if (value.startsWith("STOP_SOS") || value.startsWith("CANCEL")) {
        sosActive = false;
        digitalWrite(LED_PIN, LOW);
        Serial.println(">>> SOS DEACTIVATED by Android App <<<");
      }
    }
  }
};

void setup() {
  Serial.begin(115200);

  // GPS UART setup
  GPS.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);

  // Button and LED pins
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println();
  Serial.println("==================================================");
  Serial.println(" 🚨 ESP32 GPS + BLE SOS EMERGENCY SYSTEM 🚨");
  Serial.println("==================================================");
  Serial.println("GPS Serial initialized on RX: 16, TX: 17");
  Serial.println("Push Button initialized on GPIO 25");
  Serial.println("Status LED initialized on GPIO 26");
  Serial.println("Initializing BLE Server...");

  // Initialize BLE
  BLEDevice::init("SOS-LIFELINK-BTN");
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

  // Start Advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising started as 'SOS-LIFELINK-BTN'.");
  Serial.println("Waiting for mobile app to connect and GPS fix...\n");
}

void triggerEmergencyAlert() {
  sosActive = true;
  Serial.println();
  Serial.println("**************************************************");
  Serial.println("       🚨 SOS ACTIVATED VIA PUSH BUTTON! 🚨");
  Serial.println("**************************************************");

  String payload = "SOS_TRIGGER:";

  // Check if GPS fix is available
  if (gps.location.isValid()) {
    double lat = gps.location.lat();
    double lng = gps.location.lng();
    payload += "LAT:" + String(lat, 6) + ",LNG:" + String(lng, 6);

    Serial.print("GPS Fix Available -> Latitude: ");
    Serial.print(lat, 6);
    Serial.print(", Longitude: ");
    Serial.println(lng, 6);
  } else {
    payload += "NO_GPS";
    Serial.println("GPS fix not available yet. Phone GPS will be used as fallback.");
  }

  // Send BLE notification to phone
  if (deviceConnected && pCharacteristic != NULL) {
    pCharacteristic->setValue(payload.c_str());
    pCharacteristic->notify();
    Serial.print("[BLE] Sent Notification to Phone: ");
    Serial.println(payload);
  } else {
    Serial.println("[BLE Warning] Button pressed but phone is not connected via BLE!");
  }
}

void loop() {
  // 1. Read GPS data continuously
  while (GPS.available()) {
    gps.encode(GPS.read());
  }

  // 2. Debounce and read physical push button (GPIO 25)
  int reading = digitalRead(BUTTON_PIN);
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {
    // If button is pressed (Active LOW)
    if (reading == LOW) {
      triggerEmergencyAlert();

      // Wait until button is released
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

  // 3. LED rapid blinking during active SOS
  if (sosActive) {
    if (millis() - lastBlink >= 180) {
      lastBlink = millis();
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState);
    }
  }

  // 4. Periodic GPS info to Serial Monitor
  if (millis() - lastLocationPrint >= 3000) {
    lastLocationPrint = millis();

    if (gps.location.isValid()) {
      Serial.print("[GPS Live] Lat: ");
      Serial.print(gps.location.lat(), 6);
      Serial.print(" | Lng: ");
      Serial.print(gps.location.lng(), 6);
      Serial.print(" | Satellites: ");
      Serial.println(gps.satellites.value());
    } else {
      Serial.print("[GPS] Searching for satellites... (Chars processed: ");
      Serial.print(gps.charsProcessed());
      Serial.println(")");
    }
  }

  // 5. Handle BLE reconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] Resumed advertising...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(10);
}

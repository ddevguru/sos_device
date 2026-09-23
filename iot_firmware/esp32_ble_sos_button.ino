/**
 * =====================================================================
 * ESP32 BLE SOS EMERGENCY BUTTON
 * =====================================================================
 * This sketch runs on an ESP32 microcontroller board.
 * When the physical push-button is pressed, it transmits an instant
 * BLE notification characteristic to the paired Flutter mobile app.
 *
 * Requirements:
 * - ESP32 Dev Module (NodeMCU ESP32, WROOM, ESP32-C3/S3, etc.)
 * - Push Button connected between GPIO 4 and GND (Active LOW)
 * - Status LED connected to GPIO 2 (Built-in LED)
 * =====================================================================
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Unique UUIDs for SOS Service & Characteristic
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

#define BUTTON_PIN 4      // Physical Emergency Push Button Pin
#define LED_PIN    2      // Built-in Status LED

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Button debounce tracking
int lastButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("[BLE] Phone Connected!");
      digitalWrite(LED_PIN, HIGH);
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("[BLE] Phone Disconnected. Restarting advertising...");
      digitalWrite(LED_PIN, LOW);
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("========================================");
  Serial.println("🚨 ESP32 SOS BLE Emergency Button Starting...");
  Serial.println("========================================");

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize BLE Device with custom name
  BLEDevice::init("SOS-LIFELINK-BTN");

  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create BLE Characteristic with Notify capability
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setValue("READY");

  // Start the Service
  pService->start();

  // Start Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising started. Open Flutter App to pair!");
}

void loop() {
  int reading = digitalRead(BUTTON_PIN);

  // Debounce check
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {
    // If button was pressed (LOW because of INPUT_PULLUP)
    if (reading == LOW) {
      Serial.println("\n🚨 EMERGENCY BUTTON PRESSED! 🚨");
      
      // Flash LED rapidly 3 times
      for (int i = 0; i < 3; i++) {
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
        delay(100);
      }

      // If connected to phone, notify characteristic
      if (deviceConnected) {
        String payload = "SOS_TRIGGER:" + String(millis());
        pCharacteristic->setValue(payload.c_str());
        pCharacteristic->notify();
        Serial.println("[BLE] SOS trigger sent to Mobile App successfully!");
      } else {
        Serial.println("[BLE Warning] Button pressed but phone is not connected via BLE!");
      }

      // Wait 1 second before allowing next trigger to avoid multi-triggers
      delay(1000);
    }
  }

  lastButtonState = reading;

  // Disconnecting & Reconnecting handling
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Give Bluetooth stack time
    pServer->startAdvertising();
    Serial.println("[BLE] Resumed advertising...");
    oldDeviceConnected = deviceConnected;
  }
  
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(20);
}

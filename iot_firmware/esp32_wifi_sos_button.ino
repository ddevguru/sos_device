/**
 * =====================================================================
 * ESP32 WiFi / GSM SOS EMERGENCY BUTTON
 * =====================================================================
 * This sketch connects directly to WiFi and sends an HTTP POST request
 * to the Express.js Backend `/api/iot/trigger` endpoint when pressed.
 *
 * Requirements:
 * - ESP32 board
 * - Push Button connected between GPIO 4 and GND (Active LOW)
 * - Status LED connected to GPIO 2
 * =====================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>

// WiFi Credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Backend API URL (Replace with your local computer's IP or Cloud URL)
// e.g., http://192.168.1.100:5000/api/iot/trigger
const char* serverUrl = "http://192.168.1.100:5000/api/iot/trigger";

// Device Hardware Identifier & Secret Key
const char* deviceIdentifier = "ESP32-SOS-BTN-99";
const char* iotSecretKey = "sos_iot_secure_device_secret_2026";

#define BUTTON_PIN 4
#define LED_PIN    2

void connectToWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    digitalWrite(LED_PIN, !digitalRead(LED_PIN));
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] Connected successfully!");
    Serial.print("[WiFi] IP Address: ");
    Serial.println(WiFi.localIP());
    digitalWrite(LED_PIN, HIGH);
  } else {
    Serial.println("\n[WiFi] Connection failed. Will retry on next button click.");
    digitalWrite(LED_PIN, LOW);
  }
}

void sendSOSWebhook() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[Error] WiFi not connected. Trying to reconnect...");
    connectToWiFi();
    if (WiFi.status() != WL_CONNECTED) return;
  }

  HTTPClient http;
  http.begin(serverUrl);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-iot-key", iotSecretKey);

  // Construct JSON Payload
  String jsonPayload = "{";
  jsonPayload += "\"deviceIdentifier\":\"" + String(deviceIdentifier) + "\",";
  jsonPayload += "\"secretKey\":\"" + String(iotSecretKey) + "\",";
  jsonPayload += "\"batteryLevel\":95";
  jsonPayload += "}";

  Serial.println("\n🚨 Sending SOS Webhook to Server...");
  int httpResponseCode = http.POST(jsonPayload);

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.printf("[HTTP Success] Response Code: %d\n", httpResponseCode);
    Serial.println("Server Response: " + response);

    // Flash LED rapidly to confirm SMS dispatched
    for (int i = 0; i < 5; i++) {
      digitalWrite(LED_PIN, LOW);
      delay(80);
      digitalWrite(LED_PIN, HIGH);
      delay(80);
    }
  } else {
    Serial.printf("[HTTP Error] Failed to send POST request, error: %s\n", http.errorToString(httpResponseCode).c_str());
  }

  http.end();
}

void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  connectToWiFi();
}

void loop() {
  // Read button
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("\n[Hardware] SOS Button Pressed!");
    sendSOSWebhook();
    delay(2000); // Debounce / cooldown delay
  }
  delay(50);
}

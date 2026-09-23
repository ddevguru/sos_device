# IoT SOS Emergency Hardware Guide

This directory contains ready-to-flash Arduino C++ firmware for the **ESP32 Microcontroller** acting as an emergency SOS trigger device.

---

## 1. Hardware Connections (Pin Diagram)

```
+------------------------------------------------------------------------+
|                                ESP32                                   |
|                                                                        |
|  [GPIO 16 (RX2)] <------- [ GPS TX ]  (NEO-6M / Compatible)            |
|  [GPIO 17 (TX2)] -------> [ GPS RX ]                                   |
|  [3.3V or 5V]   --------> [ GPS VCC ]                                  |
|  [GND]          --------> [ GPS GND ]                                  |
|                                                                        |
|  [GPIO 25]      o-------[ SOS Push Button ]-------o  [GND]             |
|                                                                        |
|  [GPIO 26]      o-------[ 220Ω Resistor ]---|>|---o  [GND] (Status LED)|
+------------------------------------------------------------------------+
```

- **GPS Module**:
  - `GPS TX` -> ESP32 **GPIO 16** (Hardware Serial 2 RX)
  - `GPS RX` -> ESP32 **GPIO 17** (Hardware Serial 2 TX)
- **Emergency Push Button**:
  - One leg -> **GPIO 25** (Internal `INPUT_PULLUP` enabled)
  - Other leg -> **GND**
- **Status LED Indicator**:
  - Anode (+) -> **GPIO 26** (through 220-330Ω resistor)
  - Cathode (-) -> **GND**

---

## 2. Firmware Sketches

### Sketch 1: `esp32_gps_ble_sos.ino` (Recommended - Complete GPS + BLE System)
- **TinyGPSPlus Integration**: Reads continuous NMEA sentences from NEO-6M GPS at 9600 baud.
- **BLE Server**: Advertises as `SOS-LIFELINK-BTN` and pairs directly to the Android app.
- **Instant SOS Trigger**: When button on GPIO 25 is pressed:
  1. Sends BLE notification with live GPS coordinates (`LAT:xx,LNG:yy`) or fallback `NO_GPS`.
  2. The Android mobile app receives the event, triggers a **loud emergency siren alarm**, and sends SMS with the user's **custom predefined message** + Google Maps link to all emergency contacts!
  3. LED on GPIO 26 flashes rapidly.
  4. When user clicks "STOP ALARM" in the Android app, a BLE `STOP_SOS` command is sent back to turn off the LED!

### Sketch 2: `esp32_wifi_sos_button.ino` (WiFi Direct Webhook)
- Directly connects to WiFi and posts to the backend `/api/iot/trigger` endpoint.

---

## 3. Required Arduino Libraries
In Arduino IDE, open **Tools -> Manage Libraries...** and install:
1. **TinyGPSPlus** by Mikal Hart (for parsing GPS data).
2. **ESP32 BLE Arduino** (built into the ESP32 board package).

## 4. How to Flash Firmware
1. Open `esp32_gps_ble_sos.ino` in Arduino IDE.
2. Select Board: **ESP32 Dev Module**.
3. Select COM Port.
4. Set Baud Rate to **115200** in Serial Monitor.
5. Click **Upload**.

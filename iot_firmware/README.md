# 🚨 ESP32 All-In-One Smart SOS Device (Hardware Firmware)

This directory contains the single, unified Arduino C++ firmware for the **ESP32 Microcontroller** acting as an emergency SOS trigger device.

All features (NEO-6M GPS Module, Physical Push Button, Emergency LED, BLE Mobile App pairing, and Direct WiFi Cloud Webhook) are combined into **one single code**:
👉 **`esp32_smart_sos_device.ino`**

---

## 1. Hardware Pin Connections (सर्किट कनेक्शन)

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

| Component | ESP32 Pin | Details |
| :--- | :--- | :--- |
| **GPS TX** | **GPIO 16 (RX2)** | HardwareSerial(2) @ 9600 baud |
| **GPS RX** | **GPIO 17 (TX2)** | HardwareSerial(2) @ 9600 baud |
| **GPS VCC** | **3.3V / 5V** | Power supply |
| **GPS GND** | **GND** | Ground |
| **Push Button** | **GPIO 25 & GND** | Internal `INPUT_PULLUP` enabled |
| **Emergency LED** | **GPIO 26 (+220Ω)** | Anode to Pin 26, Cathode to GND |

---

## 2. All-in-One Firmware Features (`esp32_smart_sos_device.ino`)

1. **Continuous GPS Reading**: TinyGPSPlus reads latitude and longitude from NEO-6M continuously.
2. **Push Button Trigger**: Debounced detection on GPIO 25.
3. **Emergency LED Beacon**:
   - Double-blink on connection.
   - Rapid strobe blinking (150ms) during active SOS.
   - Turns OFF when user presses "STOP ALARM" in the mobile app.
4. **Bluetooth Low Energy (BLE)**:
   - Device Name: `SOS-LIFELINK-BTN`
   - Dispatches emergency packet with GPS coordinates to paired phone.
   - Listens for `STOP_SOS` command from the phone app.
5. **WiFi Direct Cloud Fallback**:
   - Posts directly to live Render cloud backend: `https://sos-emergency-backend-277q.onrender.com/api/iot/trigger`.

---

## 3. Required Arduino Libraries

In Arduino IDE, open **Tools -> Manage Libraries...** and install:
1. **TinyGPSPlus** by Mikal Hart.
2. **ESP32 BLE Arduino** (Included with ESP32 board support).

---

## 4. How to Flash Firmware

1. Open **`esp32_smart_sos_device.ino`** in Arduino IDE.
2. Select Board: **ESP32 Dev Module**.
3. Select your COM Port.
4. Set Baud Rate to **115200** in Serial Monitor.
5. Click **Upload** (Ctrl + U).

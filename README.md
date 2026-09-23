# 🚨 LifeLink SOS - Emergency Alert System with IoT Hardware Button

An integrated emergency response platform consisting of:
1. **Flutter Mobile Application** (iOS & Android)
2. **Node.js & Express.js Backend** with **PostgreSQL**
3. **ESP32 IoT Hardware Emergency Button** (Bluetooth Low Energy & WiFi)
4. **Automated SMS Dispatch Service** (Twilio / Fast2SMS / Dev Mock)

---

## 🏗️ System Workflow

```
[ ESP32 IoT Button Pressed ]
            │ (BLE Notification or WiFi Webhook)
            ▼
   [ Flutter Mobile App ] ──(Acquires High-Accuracy GPS)──┐
            │                                             │
            ▼                                             │
   [ Express.js Backend API ] <───────────────────────────┘
            │
            ├─► Saves Alert to PostgreSQL DB
            ├─► Retrieves User's Saved Emergency Contacts
            └─► Dispatches Emergency SMS with Live Google Maps Pin
```

---

## 📱 Mobile App Features (Flutter)
- **Splash Screen**: Animated glowing shield logo with automatic session detection.
- **Onboarding Carousel**: 3 interactive slides detailing instant SOS, IoT button pairing, and emergency SMS dispatch.
- **Login & Signup**: JWT authentication with email, password, phone, blood group, and vital medical notes.
- **Dashboard / Home**: Animated mega SOS button, live GPS coordinates, and quick emergency hotline dials (112, 108, 101).
- **Loud Alarm Siren**: Automatically sounds max-volume continuous alarm on phone upon trigger (App button, ESP32 button, or double clap) with "STOP ALARM" button.
- **24/7 Background Clap Detection**: Continuous acoustic listener using Android Foreground Service (`flutter_foreground_task`). Works even when the app is minimized, phone screen is locked, or app is swiped away from recents!
- **Custom Predefined SOS Message**: User can customize the emergency SMS template (e.g. `"🚨 DANGER! {name} needs help! Live GPS: {location}"`) from the Profile screen.
- **Emergency Contacts**: Add, view, call, and delete emergency contacts.
- **IoT Hardware Screen**: Pair ESP32 GPS + BLE button (`SOS-LIFELINK-BTN`), adjust clap sensitivity threshold (dB), and disable battery saver for 24/7 guard.
- **Profile Screen**: Edit vital medical information, blood group, phone number, custom SMS message, and backend server URL.

---

## 🚀 Getting Started

### 1. Backend Setup (`backend/`)

1. Open a terminal in `backend/`:
   ```bash
   cd backend
   npm install
   ```

2. Configure environment variables in `.env`:
   ```env
   PORT=5000
   JWT_SECRET=your_jwt_secret
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=postgres
   DB_PASSWORD=your_postgres_password
   DB_NAME=sos_db
   SMS_PROVIDER=mock   # options: 'mock', 'twilio', 'fast2sms'
   ```
   > **Note**: If PostgreSQL is not currently running or credentials are not yet set, the server automatically boots into **Fallback Mode** so you can immediately test all APIs and mobile screens without blocking.

3. Start the server:
   ```bash
   npm start
   # or for live reloading:
   npm run dev
   ```

4. Test end-to-end IoT button trigger simulation:
   ```bash
   npm run test:iot
   ```

---

### 2. Mobile App Setup (`mobile_app/`)

1. Make sure Flutter SDK is installed and configured on your machine.
2. Open a terminal in `mobile_app/`:
   ```bash
   cd mobile_app
   flutter pub get
   ```
3. Run the app on emulator or physical phone:
   ```bash
   flutter run
   ```
   > **Tip**: If running on a physical Android/iOS phone over WiFi, tap the **Settings icon** on the Login screen and change the Backend URL to `http://<YOUR_PC_LOCAL_IP>:5000/api`.

---

### 3. IoT Hardware Setup (`iot_firmware/`)

1. Open `iot_firmware/esp32_ble_sos_button.ino` in Arduino IDE.
2. Connect push-button between **GPIO 4** and **GND** on your ESP32 board.
3. Flash the code to your ESP32.
4. Open the Flutter app -> Navigate to **IoT Button** tab -> Click **Scan BLE**.
5. Once paired, pressing the physical button transmits a signal that automatically alerts your contacts via SMS!

---

## 📡 Key API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/auth/register` | Register new user with phone & medical info |
| `POST` | `/api/auth/login` | Login and receive JWT token |
| `GET` | `/api/auth/profile` | Get current user profile |
| `GET` | `/api/contacts` | Get user emergency contacts |
| `POST` | `/api/contacts` | Add a new emergency contact |
| `DELETE` | `/api/contacts/:id`| Remove emergency contact |
| `POST` | `/api/sos/trigger` | Trigger emergency SOS from mobile app |
| `POST` | `/api/iot/trigger` | Hardware webhook endpoint for IoT button |
| `POST` | `/api/iot/pair` | Pair hardware device MAC to user |
| `GET` | `/api/health` | Backend status check |

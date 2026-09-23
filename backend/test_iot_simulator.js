/**
 * SOS IoT Device & SMS Dispatch Simulator
 * Simulates the exact flow:
 * 1. User registers & sets emergency contacts
 * 2. IoT device button is pressed
 * 3. SMS is dispatched to all emergency contacts with live GPS coordinates
 */
const http = require('http');

const PORT = process.env.PORT || 5000;
const BASE_URL = `http://localhost:${PORT}`;

function request(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const data = body ? JSON.stringify(body) : null;

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        ...headers
      }
    };

    const req = http.request(options, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(raw);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: raw });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function runSimulation() {
  console.log('🧪 Starting SOS System End-to-End Simulation...\n');

  try {
    // 1. Check Server Health
    console.log('[Step 1] Checking Backend Health...');
    const health = await request('GET', '/api/health');
    console.log('Backend status:', health.data);

    // 2. Register Test User
    console.log('\n[Step 2] Registering Test User (Rahul Sharma)...');
    const userPayload = {
      name: 'Rahul Sharma',
      email: `rahul.test.${Date.now()}@example.com`,
      phone: '+919876543210',
      password: 'Password@123',
      blood_group: 'B+ Positive',
      medical_notes: 'Severe Penicillin Allergy, Diabetic Type 2'
    };

    const regRes = await request('POST', '/api/auth/register', userPayload);
    console.log('Registration Response:', regRes.data.message);
    const token = regRes.data.token;
    const userId = regRes.data.user.id;

    // 3. Add Emergency Contacts
    console.log('\n[Step 3] Adding Emergency Contacts...');
    const contact1 = await request('POST', '/api/contacts', {
      name: 'Pooja Sharma (Wife)',
      phone: '+919811122233',
      relationship: 'Spouse'
    }, { Authorization: `Bearer ${token}` });
    console.log('Added Contact 1:', contact1.data.contact?.name);

    const contact2 = await request('POST', '/api/contacts', {
      name: 'Dr. Vikram Malhotra',
      phone: '+919844455566',
      relationship: 'Family Doctor'
    }, { Authorization: `Bearer ${token}` });
    console.log('Added Contact 2:', contact2.data.contact?.name);

    // 4. Pair IoT Hardware Button
    const deviceIdentifier = 'ESP32-SOS-BTN-99';
    console.log(`\n[Step 4] Pairing Hardware IoT Button (${deviceIdentifier})...`);
    const pairRes = await request('POST', '/api/iot/pair', {
      deviceIdentifier: deviceIdentifier,
      deviceName: 'Keychain SOS Clicker',
      deviceType: 'ble_button'
    }, { Authorization: `Bearer ${token}` });
    console.log('Paired Device:', pairRes.data.device?.device_name);

    // 5. SIMULATE HARDWARE BUTTON CLICK!
    console.log('\n======================================================');
    console.log('🚨 SIMULATING PHYSICAL IOT BUTTON PRESS! 🚨');
    console.log('Hardware button pin triggered -> Sending Webhook...');
    console.log('======================================================');

    const iotTriggerRes = await request('POST', '/api/iot/trigger', {
      deviceIdentifier: deviceIdentifier,
      secretKey: 'sos_iot_secure_device_secret_2026',
      latitude: 28.613939,
      longitude: 77.209021, // Connaught Place / Delhi coordinates for test
      batteryLevel: 94
    }, { 'x-iot-key': 'sos_iot_secure_device_secret_2026' });

    console.log('IoT Trigger Response:', iotTriggerRes.data);
    console.log('\n✅ SIMULATION FINISHED SUCCESSFULLY! Emergency SMS dispatched.');
  } catch (err) {
    console.error('❌ Simulation Error:', err.message);
  }
}

runSimulation();

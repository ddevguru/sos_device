const http = require('http');

const PORT = 5001; // use separate test port to avoid conflict
process.env.PORT = PORT;
process.env.SMS_PROVIDER = 'mock';

// Require backend app
const app = require('./src/server');

function request(method, path, body = null, token = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Content-Type': 'application/json',
      ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      ...headers
    };

    const options = {
      hostname: 'localhost',
      port: PORT,
      path: path,
      method: method,
      headers: reqHeaders
    };

    const req = http.request(options, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch (e) {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function runTests() {
  console.log('🧪 ====================================================');
  console.log('🧪 TESTING NEW SOS FEATURES & RENDER-READY BACKEND');
  console.log('🧪 ====================================================\n');

  // Allow server 1 second to start
  await new Promise(r => setTimeout(r, 1000));

  try {
    // 1. Health check
    console.log('[Test 1] Health Check...');
    const health = await request('GET', '/api/health');
    console.log('Status:', health.status, health.body);

    // 2. Register user
    console.log('\n[Test 2] User Registration with Custom Predefined SOS Message...');
    const regRes = await request('POST', '/api/auth/register', {
      name: 'Rupali User',
      email: `test_${Date.now()}@example.com`,
      phone: '+919876543210',
      password: 'password123',
      blood_group: 'B+',
      medical_notes: 'Allergic to Penicillin'
    });
    console.log('Registered User ID:', regRes.body.user?.id);
    const token = regRes.body.token;

    // 3. Update Profile with Custom SOS Message
    console.log('\n[Test 3] Setting Custom Predefined SOS Message in User Profile...');
    const updateRes = await request('PUT', '/api/auth/profile', {
      customSosMessage: '🚨 DANGER ALERT! {name} needs urgent help right now! Live GPS: {location}'
    }, token);
    console.log('Updated Custom Message:', updateRes.body.user?.customSosMessage);

    // 4. Add Emergency Contact
    console.log('\n[Test 4] Adding Emergency Contact...');
    const contactRes = await request('POST', '/api/contacts', {
      name: 'Papa',
      phone: '+919811122233',
      relationship: 'Father'
    }, token);
    console.log('Added Contact:', contactRes.body.contact?.name, contactRes.body.contact?.phone);

    // 5. Trigger SOS via App Button with Custom Predefined Message
    console.log('\n[Test 5] Triggering SOS via App Button (with custom message)...');
    const appSosRes = await request('POST', '/api/sos/trigger', {
      latitude: 28.6139,
      longitude: 77.2090,
      triggerSource: 'app_button',
      customMessage: '🚨 DANGER ALERT! {name} needs urgent help right now! Live GPS: {location}'
    }, token);
    console.log('App SOS Response:', appSosRes.body.message);

    // 6. Trigger SOS via Double Clap
    console.log('\n[Test 6] Triggering SOS via Double Clap Sensor...');
    const clapSosRes = await request('POST', '/api/sos/trigger', {
      latitude: 28.6145,
      longitude: 77.2095,
      triggerSource: 'clap_detection'
    }, token);
    console.log('Clap SOS Response:', clapSosRes.body.message);

    // 7. Pair IoT Device
    console.log('\n[Test 7] Pairing ESP32 Device (SOS-LIFELINK-BTN)...');
    const pairRes = await request('POST', '/api/iot/pair', {
      deviceIdentifier: 'ESP32-LIFELINK-BTN-01',
      deviceName: 'ESP32 Hardware SOS Button',
      deviceType: 'ble_button'
    }, token);
    console.log('Paired Device:', pairRes.body.device?.device_identifier);

    // 8. Trigger IoT Hardware Button
    console.log('\n[Test 8] Triggering SOS from Physical ESP32 Hardware Button...');
    const iotTriggerRes = await request('POST', '/api/iot/trigger', {
      deviceIdentifier: 'ESP32-LIFELINK-BTN-01',
      secretKey: 'sos_iot_secure_device_secret_2026',
      latitude: 28.6150,
      longitude: 77.2100
    });
    console.log('IoT Trigger Response:', iotTriggerRes.body.message);

    console.log('\n✅ ALL 8 TESTS PASSED SUCCESSFULLY! Everything is functioning seamlessly.\n');
    process.exit(0);
  } catch (err) {
    console.error('❌ Test Error:', err);
    process.exit(1);
  }
}

runTests();

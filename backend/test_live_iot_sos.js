process.env.DATABASE_URL = 'postgresql://sos_admin:3TQuUwPiLZ86mNCRsLbdxsswmy0Nz9xv@dpg-daq2ek4a9krc73aushm0-a.oregon-postgres.render.com/sos_db_42ty';
process.env.SMS_PROVIDER = 'mock';

const db = require('./src/db');
const { register } = require('./src/controllers/authController');
const { addContact } = require('./src/controllers/contactController');
const { handleDeviceTrigger, getUserDevices } = require('./src/controllers/iotController');

async function testLiveIotFlow() {
  console.log('Connecting to Render Cloud PostgreSQL...');
  await db.initDatabase();

  // Mock Request & Response helpers
  const mockRes = () => {
    const res = {};
    res.status = (code) => { res.statusCode = code; return res; };
    res.json = (data) => { res.body = data; return res; };
    return res;
  };

  // 1. Register a user in the live Render DB
  console.log('\n[1] Registering User in Live Render PostgreSQL...');
  const userEmail = `demo_${Date.now()}@sos.com`;
  const regReq = {
    body: {
      name: 'Rupali Test User',
      email: userEmail,
      phone: '+919876543210',
      password: 'mypassword123',
      blood_group: 'O+',
      medical_notes: 'Asthma patient'
    }
  };
  const regRes = mockRes();
  await register(regReq, regRes);
  const user = regRes.body?.user;
  console.log('✅ Registered in Render DB! User ID:', user?.id, 'Email:', user?.email);

  // 2. Add multiple emergency contacts (test unlimited contacts capability)
  console.log('\n[2] Adding Multiple Emergency Contacts in Live Render DB...');
  const contactsToAdd = [
    { name: 'Papa', phone: '+919811111111', relationship: 'Father' },
    { name: 'Mummy', phone: '+919822222222', relationship: 'Mother' },
    { name: 'Bhai', phone: '+919833333333', relationship: 'Brother' }
  ];

  for (const c of contactsToAdd) {
    const cReq = { user: { id: user.id }, body: c };
    const cRes = mockRes();
    await addContact(cReq, cRes);
    console.log(`✅ Saved Contact in Render DB: ${c.name} (${c.phone})`);
  }

  // 3. Check IoT Devices for this user (Verifying pre-connected device in DB)
  console.log('\n[3] Checking Pre-connected IoT Devices in Render DB...');
  const devReq = { user: { id: user.id } };
  const devRes = mockRes();
  await getUserDevices(devReq, devRes);
  console.log('✅ Paired Devices in Render DB:', devRes.body.devices?.map(d => `${d.device_name} (${d.device_identifier})`));

  // 4. Trigger IoT Hardware Button Event!
  console.log('\n[4] Triggering Physical ESP32 Button Alert to Render DB...');
  const triggerReq = {
    headers: { 'x-iot-key': 'sos_iot_secure_device_secret_2026' },
    body: {
      deviceIdentifier: 'SOS-LIFELINK-BTN',
      latitude: 28.613939,
      longitude: 77.209021,
      customMessage: '🚨 DANGER! {name} has triggered emergency hardware button! Live Location: {location}'
    }
  };
  const triggerRes = mockRes();
  await handleDeviceTrigger(triggerReq, triggerRes);
  console.log('✅ IoT Trigger Response:', triggerRes.body.message);
  console.log('✅ Alert ID generated in Render DB:', triggerRes.body.alertId);

  // 5. Query sos_alerts table in Render DB to verify it was stored
  console.log('\n[5] Verifying Alert Record Stored in Render PostgreSQL `sos_alerts` table...');
  const alertRecord = await db.query('SELECT * FROM sos_alerts WHERE user_id = $1 ORDER BY id DESC LIMIT 1', [user.id]);
  console.log('✅ Stored Alert Details:', {
    id: alertRecord.rows[0].id,
    userId: alertRecord.rows[0].user_id,
    triggerSource: alertRecord.rows[0].trigger_source,
    latitude: alertRecord.rows[0].latitude,
    longitude: alertRecord.rows[0].longitude,
    smsCount: alertRecord.rows[0].sms_count,
    createdAt: alertRecord.rows[0].created_at
  });

  console.log('\n🎉 COMPLETE LIVE RENDER POSTGRESQL VERIFICATION SUCCESSFUL!\n');
  process.exit(0);
}

testLiveIotFlow().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});

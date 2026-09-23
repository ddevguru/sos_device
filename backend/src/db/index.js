const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

let pool = null;
let isConnected = false;

// Fallback in-memory store for development/testing when PostgreSQL is offline
const memoryStore = {
  users: [],
  contacts: [],
  iotDevices: [],
  alerts: [],
  nextUserId: 1,
  nextContactId: 1,
  nextDeviceId: 1,
  nextAlertId: 1
};

const initDatabase = async () => {
  const config = {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_NAME || 'sos_db',
    connectionTimeoutMillis: 3000
  };

  if (process.env.DATABASE_URL) {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      connectionTimeoutMillis: 5000,
      ssl: process.env.DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false }
    });
  } else {
    pool = new Pool(config);
  }

  try {
    const client = await pool.connect();
    isConnected = true;
    console.log(`[Database] Successfully connected to PostgreSQL at ${config.host}:${config.port}/${config.database}`);

    // Auto-initialize tables from schema.sql
    try {
      const schemaPath = path.join(__dirname, 'schema.sql');
      const schemaSql = fs.readFileSync(schemaPath, 'utf8');
      await client.query(schemaSql);
      console.log('[Database] Schema verified and tables initialized.');
    } catch (schemaErr) {
      console.warn('[Database] Schema execution warning:', schemaErr.message);
    } finally {
      client.release();
    }
  } catch (err) {
    isConnected = false;
    console.warn(`[Database] PostgreSQL connection failed (${err.message}).`);
    console.warn('[Database] Running in Fallback In-Memory Mode for instant testing without Postgres setup!');
  }
};

let initPromise = initDatabase();

// Database Query Wrapper
const query = async (text, params) => {
  if (initPromise) {
    await initPromise;
  }
  if (isConnected && pool) {
    return pool.query(text, params);
  }

  // Handle fallback in-memory simulation for core queries
  return executeInMemoryQuery(text, params);
};

// Lightweight SQL-like in-memory executor for local testing if Postgres is down
function executeInMemoryQuery(sql, params = []) {
  const trimmed = sql.trim().toLowerCase();

  // 1. User insert
  if (trimmed.startsWith('insert into users')) {
    const [name, email, phone, password_hash, blood_group, medical_notes] = params;
    const user = {
      id: memoryStore.nextUserId++,
      name,
      email,
      phone,
      password_hash,
      blood_group: blood_group || '',
      medical_notes: medical_notes || '',
      custom_sos_message: '',
      sms_sender_number: '',
      created_at: new Date()
    };
    memoryStore.users.push(user);
    return { rows: [user] };
  }

  // 2. User select by email
  if (trimmed.includes('from users where email')) {
    const email = params[0];
    const user = memoryStore.users.find(u => u.email.toLowerCase() === email.toLowerCase());
    return { rows: user ? [user] : [] };
  }

  // 3. User select by id
  if (trimmed.includes('from users where id')) {
    const id = parseInt(params[0], 10);
    const user = memoryStore.users.find(u => u.id === id);
    return { rows: user ? [user] : [] };
  }

  // 4. Update user profile
  if (trimmed.startsWith('update users')) {
    const [name, phone, blood_group, medical_notes, custom_sos_message, sms_sender_number, id] = params;
    const targetId = parseInt(id || params[params.length - 1], 10);
    const user = memoryStore.users.find(u => u.id === targetId);
    if (user) {
      if (name) user.name = name;
      if (phone) user.phone = phone;
      if (blood_group !== undefined) user.blood_group = blood_group;
      if (medical_notes !== undefined) user.medical_notes = medical_notes;
      if (custom_sos_message !== undefined) user.custom_sos_message = custom_sos_message;
      if (sms_sender_number !== undefined) user.sms_sender_number = sms_sender_number;
    }
    return { rows: user ? [user] : [] };
  }

  // 5. Emergency contacts list
  if (trimmed.includes('from emergency_contacts where user_id')) {
    const userId = parseInt(params[0], 10);
    const contacts = memoryStore.contacts.filter(c => c.user_id === userId && c.is_active);
    return { rows: contacts };
  }

  // 6. Insert emergency contact
  if (trimmed.startsWith('insert into emergency_contacts')) {
    const [userId, name, phone, relationship] = params;
    const contact = {
      id: memoryStore.nextContactId++,
      user_id: parseInt(userId, 10),
      name,
      phone,
      relationship: relationship || 'Family',
      is_active: true,
      created_at: new Date()
    };
    memoryStore.contacts.push(contact);
    return { rows: [contact] };
  }

  // 7. Delete emergency contact
  if (trimmed.startsWith('delete from emergency_contacts') || trimmed.startsWith('update emergency_contacts set is_active = false')) {
    const [contactId, userId] = params;
    const idx = memoryStore.contacts.findIndex(c => c.id === parseInt(contactId, 10) && c.user_id === parseInt(userId, 10));
    if (idx !== -1) {
      memoryStore.contacts.splice(idx, 1);
    }
    return { rowCount: 1 };
  }

  // 8. IoT Devices query by identifier
  if (trimmed.includes('from iot_devices where device_identifier')) {
    const deviceId = params[0];
    const device = memoryStore.iotDevices.find(d => d.device_identifier === deviceId);
    return { rows: device ? [device] : [] };
  }

  // 9. Register/pair IoT Device
  if (trimmed.startsWith('insert into iot_devices')) {
    const [userId, deviceName, deviceIdentifier, deviceType] = params;
    let device = memoryStore.iotDevices.find(d => d.device_identifier === deviceIdentifier);
    if (!device) {
      device = {
        id: memoryStore.nextDeviceId++,
        user_id: parseInt(userId, 10),
        device_name: deviceName || 'SOS Button',
        device_identifier: deviceIdentifier,
        device_type: deviceType || 'ble_button',
        is_active: true,
        battery_level: 100,
        last_heartbeat: new Date()
      };
      memoryStore.iotDevices.push(device);
    }
    return { rows: [device] };
  }

  // 10. Record SOS Alert
  if (trimmed.startsWith('insert into sos_alerts')) {
    const [userId, deviceId, lat, lon, address, triggerSource, smsCount, recipients] = params;
    const alert = {
      id: memoryStore.nextAlertId++,
      user_id: parseInt(userId, 10),
      device_id: deviceId ? parseInt(deviceId, 10) : null,
      latitude: lat,
      longitude: lon,
      address,
      trigger_source: triggerSource || 'app_button',
      status: 'triggered',
      sms_count: smsCount || 0,
      sms_recipients: recipients || [],
      created_at: new Date()
    };
    memoryStore.alerts.push(alert);
    return { rows: [alert] };
  }

  // 11. Alerts list
  if (trimmed.startsWith('select * from sos_alerts where user_id')) {
    const userId = parseInt(params[0], 10);
    const userAlerts = memoryStore.alerts.filter(a => a.user_id === userId);
    return { rows: userAlerts.slice(-10).reverse() };
  }

  return { rows: [], rowCount: 0 };
}

module.exports = {
  initDatabase,
  query,
  isPostgresConnected: () => isConnected,
  getMemoryStore: () => memoryStore
};

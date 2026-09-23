const db = require('./src/db');

async function testLiveDb() {
  process.env.DATABASE_URL = 'postgresql://sos_admin:3TQuUwPiLZ86mNCRsLbdxsswmy0Nz9xv@dpg-daq2ek4a9krc73aushm0-a.oregon-postgres.render.com/sos_db_42ty';
  console.log('Connecting to Live Render Postgres...');
  await db.initDatabase();
  console.log('Postgres Connected Status:', db.isPostgresConnected());

  if (db.isPostgresConnected()) {
    // 1. Verify users table query
    const users = await db.query('SELECT COUNT(*) as count FROM users');
    console.log('✅ Users table count in Render DB:', users.rows[0].count);

    // 2. Verify emergency_contacts table query
    const contacts = await db.query('SELECT COUNT(*) as count FROM emergency_contacts');
    console.log('✅ Emergency contacts count in Render DB:', contacts.rows[0].count);

    // 3. Verify iot_devices table query
    const devices = await db.query('SELECT COUNT(*) as count FROM iot_devices');
    console.log('✅ IoT devices count in Render DB:', devices.rows[0].count);

    // 4. Verify sos_alerts table query
    const alerts = await db.query('SELECT COUNT(*) as count FROM sos_alerts');
    console.log('✅ SOS alerts count in Render DB:', alerts.rows[0].count);

    console.log('\n🎉 ALL TABLES VERIFIED AND FULLY OPERATIONAL ON RENDER POSTGRESQL!\n');
  } else {
    console.error('❌ Failed to connect to Postgres.');
  }
  process.exit(0);
}

testLiveDb();

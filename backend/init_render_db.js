const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const connectionString = process.env.DATABASE_URL || 'postgresql://sos_admin:3TQuUwPiLZ86mNCRsLbdxsswmy0Nz9xv@dpg-daq2ek4a9krc73aushm0-a.oregon-postgres.render.com/sos_db_42ty';

async function initRenderDb() {
  console.log('Connecting to Render PostgreSQL Database...');
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    console.log('✅ Connected to database successfully!');

    // Read and execute schema
    const schemaSql = fs.readFileSync(path.join(__dirname, 'src/db/schema.sql'), 'utf8');
    await client.query(schemaSql);

    // Apply migration for existing users table
    await client.query("ALTER TABLE users ADD COLUMN IF NOT EXISTS sms_sender_number VARCHAR(30) DEFAULT ''");
    console.log('✅ Schema tables & sms_sender_number column verified/created.');

    // Query tables
    const res = await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
    console.log('Active DB Tables:', res.rows.map(r => r.table_name));

    await client.end();
  } catch (err) {
    console.error('❌ Database initialization error:', err.message);
    process.exit(1);
  }
}

initRenderDb();

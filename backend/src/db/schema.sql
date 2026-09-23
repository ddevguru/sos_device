-- SOS Emergency Application PostgreSQL Database Schema

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    blood_group VARCHAR(10) DEFAULT '',
    medical_notes TEXT DEFAULT '',
    custom_sos_message TEXT DEFAULT '',
    sms_sender_number VARCHAR(30) DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Emergency Contacts Table
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relationship VARCHAR(50) DEFAULT 'Emergency Contact',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. IoT Devices Table
CREATE TABLE IF NOT EXISTS iot_devices (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_name VARCHAR(100) DEFAULT 'SOS IoT Button',
    device_identifier VARCHAR(100) UNIQUE NOT NULL,
    device_type VARCHAR(50) DEFAULT 'ble_button',
    is_active BOOLEAN DEFAULT TRUE,
    battery_level INTEGER DEFAULT 100,
    last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. SOS Alerts Log Table
CREATE TABLE IF NOT EXISTS sos_alerts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id INTEGER REFERENCES iot_devices(id) ON DELETE SET NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    address TEXT,
    trigger_source VARCHAR(50) NOT NULL DEFAULT 'app_button',
    status VARCHAR(50) DEFAULT 'triggered',
    sms_count INTEGER DEFAULT 0,
    sms_recipients JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexing for high-speed queries during emergencies
CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_iot_device_identifier ON iot_devices(device_identifier);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_user_id ON sos_alerts(user_id);

const db = require('../db');
const { sendEmergencySMS } = require('../services/smsService');
require('dotenv').config();

const IOT_SECRET_KEY = process.env.IOT_SECRET_KEY || 'sos_iot_secure_device_secret_2026';

/**
 * Direct Trigger from IoT Hardware (WiFi / GSM / Webhook)
 */
const handleDeviceTrigger = async (req, res) => {
  try {
    const secret = req.headers['x-iot-key'] || req.body.secretKey;
    const { deviceIdentifier, latitude, longitude, batteryLevel } = req.body;

    if (!deviceIdentifier) {
      return res.status(400).json({
        success: false,
        message: 'deviceIdentifier is required.'
      });
    }

    if (secret && secret !== IOT_SECRET_KEY) {
      return res.status(403).json({
        success: false,
        message: 'Invalid IoT security key.'
      });
    }

    // Find device and its owner
    const deviceRes = await db.query(
      'SELECT id, user_id, device_name, is_active FROM iot_devices WHERE device_identifier = $1',
      [deviceIdentifier]
    );

    let userId = null;
    let deviceId = null;

    if (deviceRes.rows.length > 0) {
      const dev = deviceRes.rows[0];
      userId = dev.user_id;
      deviceId = dev.id;
    } else {
      // If device not yet manually paired, auto-link to specified userId or the latest registered user in the database
      let targetUserId = req.body.userId ? parseInt(req.body.userId, 10) : null;
      if (!targetUserId) {
        const latestUser = await db.query('SELECT id FROM users ORDER BY id DESC LIMIT 1');
        if (latestUser.rows.length > 0) {
          targetUserId = latestUser.rows[0].id;
        }
      }

      if (targetUserId) {
        userId = targetUserId;
        try {
          const autoPairRes = await db.query(
            `INSERT INTO iot_devices (user_id, device_name, device_identifier, device_type)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (device_identifier) DO UPDATE SET user_id = $1
             RETURNING id`,
            [userId, 'ESP32 Smart SOS Button', deviceIdentifier, 'hardware_button']
          );
          deviceId = autoPairRes.rows[0]?.id;
          console.log(`[IoT Controller] Device ${deviceIdentifier} auto-paired to User ID: ${userId}`);
        } catch (e) {
          console.warn('[Auto-Pair Notice]:', e.message);
        }
      } else {
        return res.status(404).json({
          success: false,
          message: `Device with ID ${deviceIdentifier} is not paired to any user and no active users exist.`
        });
      }
    }

    // Fetch user details
    const userRes = await db.query(
      'SELECT id, name, phone, medical_notes, custom_sos_message FROM users WHERE id = $1',
      [userId]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Owner of this IoT device not found.' });
    }
    const user = userRes.rows[0];

    // Fetch user emergency contacts
    const contactsRes = await db.query(
      'SELECT id, name, phone, relationship FROM emergency_contacts WHERE user_id = $1 AND is_active = true',
      [userId]
    );

    const contacts = contactsRes.rows;
    if (contacts.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Device triggered but user has no emergency contacts configured.'
      });
    }

    // Send SMS Broadcast
    const smsResult = await sendEmergencySMS(contacts, {
      userName: user.name,
      userPhone: user.phone,
      latitude: latitude || null,
      longitude: longitude || null,
      medicalNotes: user.medical_notes,
      triggerSource: 'iot_device',
      customMessage: req.body.customMessage || user.custom_sos_message || ''
    });

    // Save SOS Alert
    const alertInsert = await db.query(
      `INSERT INTO sos_alerts (user_id, device_id, latitude, longitude, trigger_source, status, sms_count, sms_recipients)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, created_at`,
      [
        userId,
        deviceId,
        latitude || null,
        longitude || null,
        'iot_device',
        'triggered',
        smsResult.sentCount || 0,
        JSON.stringify(smsResult.recipients || [])
      ]
    );

    console.log(`[IoT Controller] SOS triggered via IoT Device (${deviceIdentifier}) for User: ${user.name}`);

    return res.status(200).json({
      success: true,
      message: `IoT Emergency SOS triggered successfully! SMS dispatched to ${smsResult.sentCount} contact(s).`,
      alertId: alertInsert.rows[0]?.id,
      sentCount: smsResult.sentCount,
      recipients: smsResult.recipients
    });
  } catch (err) {
    console.error('[IoT Device Trigger Error]:', err);
    return res.status(500).json({ success: false, message: 'Server error processing IoT trigger.' });
  }
};

/**
 * Pair a new IoT device to current authenticated user
 */
const pairDevice = async (req, res) => {
  try {
    const userId = req.user.id;
    const { deviceIdentifier, deviceName, deviceType } = req.body;

    if (!deviceIdentifier) {
      return res.status(400).json({
        success: false,
        message: 'deviceIdentifier is required (e.g., BLE MAC address or hardware UUID).'
      });
    }

    const result = await db.query(
      `INSERT INTO iot_devices (user_id, device_name, device_identifier, device_type)
       VALUES ($1, $2, $3, $4)
       RETURNING id, user_id, device_name, device_identifier, device_type, is_active, battery_level, created_at`,
      [userId, deviceName || 'SOS Button', deviceIdentifier.trim(), deviceType || 'ble_button']
    );

    return res.status(201).json({
      success: true,
      message: 'IoT Device paired successfully.',
      device: result.rows[0]
    });
  } catch (err) {
    console.error('[Pair Device Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to pair device.' });
  }
};

/**
 * List paired devices for user
 */
const getUserDevices = async (req, res) => {
  try {
    const userId = req.user.id;
    let result = await db.query(
      'SELECT id, device_name, device_identifier, device_type, is_active, battery_level, last_heartbeat FROM iot_devices WHERE user_id = $1',
      [userId]
    );

    // If user has no device linked yet, pre-link the default ESP32 hardware device
    if (result.rows.length === 0) {
      try {
        const preLinked = await db.query(
          `INSERT INTO iot_devices (user_id, device_name, device_identifier, device_type)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (device_identifier) DO UPDATE SET user_id = $1
           RETURNING id, device_name, device_identifier, device_type, is_active, battery_level, last_heartbeat`,
          [userId, 'ESP32 Smart SOS Button', 'SOS-LIFELINK-BTN', 'ble_gps_button']
        );
        result = preLinked;
      } catch (e) {
        console.warn('[Pre-link Device Warning]:', e.message);
      }
    }

    return res.json({
      success: true,
      devices: result.rows
    });
  } catch (err) {
    console.error('[Get User Devices Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch devices.' });
  }
};

module.exports = {
  handleDeviceTrigger,
  pairDevice,
  getUserDevices
};

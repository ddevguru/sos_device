const db = require('../db');
const { sendEmergencySMS } = require('../services/smsService');

const triggerSOS = async (req, res) => {
  try {
    const userId = req.user.id;
    const { latitude, longitude, address, triggerSource = 'app_button', deviceId, customMessage } = req.body;

    // 1. Fetch User Information
    const userRes = await db.query(
      'SELECT id, name, email, phone, blood_group, medical_notes, custom_sos_message, sms_sender_number FROM users WHERE id = $1',
      [userId]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }
    const user = userRes.rows[0];

    // 2. Fetch Active Emergency Contacts
    const contactsRes = await db.query(
      'SELECT id, name, phone, relationship FROM emergency_contacts WHERE user_id = $1 AND is_active = true',
      [userId]
    );

    const contacts = contactsRes.rows;
    if (contacts.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No emergency contacts found! Please add emergency contacts first.'
      });
    }

    // Determine message to send: passed from request OR user stored profile preference
    const finalCustomMessage = customMessage || user.custom_sos_message || '';

    // 3. Dispatch Emergency SMS
    const smsResult = await sendEmergencySMS(contacts, {
      userName: user.name,
      userPhone: user.phone,
      senderPhone: user.sms_sender_number || user.phone || '',
      latitude: latitude || null,
      longitude: longitude || null,
      address: address || '',
      medicalNotes: user.medical_notes,
      triggerSource: triggerSource,
      customMessage: finalCustomMessage
    });

    // 4. Save Alert Record in DB
    const alertInsert = await db.query(
      `INSERT INTO sos_alerts (user_id, device_id, latitude, longitude, address, trigger_source, status, sms_count, sms_recipients)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, created_at, status`,
      [
        userId,
        deviceId || null,
        latitude || null,
        longitude || null,
        address || null,
        triggerSource,
        'triggered',
        smsResult.sentCount || 0,
        JSON.stringify(smsResult.recipients || [])
      ]
    );

    const alert = alertInsert.rows[0];

    return res.status(200).json({
      success: true,
      message: `Emergency SOS triggered! SMS sent to ${smsResult.sentCount} contact(s).`,
      alertId: alert.id,
      timestamp: alert.created_at,
      sentCount: smsResult.sentCount,
      recipients: smsResult.recipients
    });
  } catch (err) {
    console.error('[Trigger SOS Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to process emergency SOS alert.' });
  }
};

const getAlertHistory = async (req, res) => {
  try {
    const userId = req.user.id;
    const result = await db.query(
      `SELECT id, latitude, longitude, address, trigger_source, status, sms_count, created_at
       FROM sos_alerts
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 20`,
      [userId]
    );

    return res.json({
      success: true,
      alerts: result.rows
    });
  } catch (err) {
    console.error('[Get Alerts History Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch alert history.' });
  }
};

module.exports = {
  triggerSOS,
  getAlertHistory
};

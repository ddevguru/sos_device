require('dotenv').config();

let twilioClient = null;
if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) {
  try {
    const twilio = require('twilio');
    twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
  } catch (e) {
    console.warn('[SMS] Twilio initialization skipped:', e.message);
  }
}

/**
 * Builds the standard emergency message text or formats a user custom template
 */
function buildEmergencyMessage(alertData = {}) {
  const {
    userName,
    userPhone,
    senderPhone,
    latitude,
    longitude,
    address,
    medicalNotes,
    triggerSource,
    customMessage
  } = alertData;

  const timestamp = new Date().toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: true
  });

  const mapsLink = (latitude && longitude)
    ? `https://maps.google.com/?q=${latitude},${longitude}`
    : 'Location not available';

  // If user provided or configured a custom message template
  if (customMessage && customMessage.trim().length > 0) {
    let msg = customMessage.trim();
    // Replace dynamic placeholders
    msg = msg.replace(/{name}/gi, userName || 'User');
    msg = msg.replace(/{phone}/gi, userPhone || '');
    msg = msg.replace(/{time}/gi, timestamp);

    if (msg.includes('{location}')) {
      msg = msg.replace(/{location}/gi, mapsLink);
    } else {
      // Ensure live location link is always attached to emergency messages
      msg += `\n📍 Live Location: ${mapsLink}`;
    }

    if (medicalNotes && !msg.toLowerCase().includes('medical')) {
      msg += `\n💊 Medical: ${medicalNotes}`;
    }
    if (senderPhone && !msg.toLowerCase().includes('sender') && !msg.toLowerCase().includes('callback')) {
      msg += `\n📞 Sender / Callback: ${senderPhone}`;
    }
    return msg;
  }

  // Standard Default Emergency Message
  let msg = `🚨 EMERGENCY SOS ALERT! 🚨\n`;
  msg += `${userName || 'User'} (${userPhone || 'N/A'}) has triggered an emergency alarm!\n`;
  msg += `Trigger Source: ${triggerSource === 'iot_device' ? '🔘 IoT Hardware Button' : (triggerSource === 'clap_detection' ? '👏 Double Clap Detection' : '📱 Mobile App')}\n`;
  msg += `📍 Live Location: ${mapsLink}\n`;
  if (address) {
    msg += `🏠 Nearby: ${address}\n`;
  }
  if (senderPhone) {
    msg += `📞 Dispatcher / Sender Number: ${senderPhone}\n`;
  }
  if (medicalNotes) {
    msg += `💊 Medical Info: ${medicalNotes}\n`;
  }
  msg += `⏰ Time: ${timestamp}\n`;
  msg += `Please contact or reach out immediately!`;

  return msg;
}

/**
 * Dispatches emergency SMS to all given contacts
 * @param {Array} contacts - List of contacts [{ name, phone }]
 * @param {Object} alertData - Details about user and emergency
 */
async function sendEmergencySMS(contacts, alertData) {
  if (!contacts || contacts.length === 0) {
    console.warn('[SMS] No emergency contacts provided to send SMS to.');
    return { success: false, sentCount: 0, recipients: [], error: 'No contacts configured' };
  }

  const messageText = buildEmergencyMessage(alertData);
  const provider = (process.env.SMS_PROVIDER || 'mock').toLowerCase();
  const fromNumber = alertData.senderPhone || process.env.TWILIO_PHONE_NUMBER;
  const results = [];

  console.log('\n======================================================');
  console.log('🚨 DISPATCHING EMERGENCY SOS BROADCAST 🚨');
  console.log(`Recipients Count: ${contacts.length}`);
  console.log(`Sender Phone Number: ${fromNumber || 'Default / Not Set'}`);
  console.log(`Provider: ${provider.toUpperCase()}`);
  console.log('======================================================');

  for (const contact of contacts) {
    const recipientPhone = contact.phone;

    if (provider === 'twilio' && twilioClient && fromNumber) {
      try {
        const res = await twilioClient.messages.create({
          body: messageText,
          from: fromNumber,
          to: recipientPhone
        });
        results.push({
          name: contact.name,
          phone: recipientPhone,
          status: 'sent',
          messageId: res.sid
        });
        console.log(`[Twilio SMS] Sent to ${contact.name} (${recipientPhone}) - SID: ${res.sid}`);
      } catch (err) {
        console.error(`[Twilio SMS Failed] ${recipientPhone}:`, err.message);
        results.push({
          name: contact.name,
          phone: recipientPhone,
          status: 'failed',
          error: err.message
        });
      }
    } else if (provider === 'fast2sms' && process.env.FAST2SMS_API_KEY) {
      try {
        const https = require('https');
        const postData = JSON.stringify({
          route: 'v3',
          sender_id: 'TXTIND',
          message: messageText,
          language: 'english',
          flash: 0,
          numbers: recipientPhone.replace(/\D/g, '').slice(-10)
        });

        // Fast2SMS request execution
        await new Promise((resolve, reject) => {
          const req = https.request({
            hostname: 'www.fast2sms.com',
            path: '/dev/bulkV2',
            method: 'POST',
            headers: {
              authorization: process.env.FAST2SMS_API_KEY,
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(postData)
            }
          }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(data));
          });
          req.on('error', reject);
          req.write(postData);
          req.end();
        });

        results.push({ name: contact.name, phone: recipientPhone, status: 'sent' });
        console.log(`[Fast2SMS] Sent to ${contact.name} (${recipientPhone})`);
      } catch (err) {
        console.error(`[Fast2SMS Failed] ${recipientPhone}:`, err.message);
        results.push({ name: contact.name, phone: recipientPhone, status: 'failed', error: err.message });
      }
    } else {
      // Mock / Development Provider (Default)
      console.log(`\n📨 [SIMULATED SMS SENT TO: ${contact.name} (${recipientPhone})]`);
      console.log('------------------------------------------------------');
      console.log(messageText);
      console.log('------------------------------------------------------\n');

      results.push({
        name: contact.name,
        phone: recipientPhone,
        status: 'simulated_sent',
        timestamp: new Date().toISOString()
      });
    }
  }

  const successCount = results.filter(r => r.status === 'sent' || r.status === 'simulated_sent').length;

  return {
    success: successCount > 0,
    sentCount: successCount,
    totalAttempted: contacts.length,
    messageText,
    recipients: results
  };
}

module.exports = {
  sendEmergencySMS,
  buildEmergencyMessage
};

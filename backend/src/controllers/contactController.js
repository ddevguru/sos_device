const db = require('../db');

const getContacts = async (req, res) => {
  try {
    const userId = req.user.id;
    const result = await db.query(
      `SELECT id, name, phone, relationship, is_active, created_at 
       FROM emergency_contacts 
       WHERE user_id = $1 AND is_active = true 
       ORDER BY id ASC`,
      [userId]
    );

    return res.json({
      success: true,
      contacts: result.rows.map(c => ({
        id: c.id,
        name: c.name,
        phone: c.phone,
        relationship: c.relationship,
        isActive: c.is_active,
        createdAt: c.created_at
      }))
    });
  } catch (err) {
    console.error('[Get Contacts Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch emergency contacts.' });
  }
};

const addContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, phone, relationship } = req.body;

    if (!name || !phone) {
      return res.status(400).json({
        success: false,
        message: 'Contact name and phone number are required.'
      });
    }

    // Clean phone number
    const cleanedPhone = phone.trim();

    const result = await db.query(
      `INSERT INTO emergency_contacts (user_id, name, phone, relationship) 
       VALUES ($1, $2, $3, $4) 
       RETURNING id, name, phone, relationship, is_active, created_at`,
      [userId, name.trim(), cleanedPhone, relationship ? relationship.trim() : 'Family']
    );

    const contact = result.rows[0];
    return res.status(201).json({
      success: true,
      message: 'Emergency contact added successfully.',
      contact: {
        id: contact.id,
        name: contact.name,
        phone: contact.phone,
        relationship: contact.relationship,
        isActive: contact.is_active,
        createdAt: contact.created_at
      }
    });
  } catch (err) {
    console.error('[Add Contact Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to save emergency contact.' });
  }
};

const updateContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const contactId = req.params.id;
    const { name, phone, relationship, isActive } = req.body;

    const result = await db.query(
      `UPDATE emergency_contacts 
       SET name = COALESCE($1, name),
           phone = COALESCE($2, phone),
           relationship = COALESCE($3, relationship),
           is_active = COALESCE($4, is_active)
       WHERE id = $5 AND user_id = $6
       RETURNING id, name, phone, relationship, is_active`,
      [name, phone, relationship, isActive, contactId, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Emergency contact not found.' });
    }

    const updated = result.rows[0];
    return res.json({
      success: true,
      message: 'Emergency contact updated.',
      contact: updated
    });
  } catch (err) {
    console.error('[Update Contact Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to update contact.' });
  }
};

const deleteContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const contactId = req.params.id;

    const result = await db.query(
      'DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2 RETURNING id',
      [contactId, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, message: 'Contact not found or already deleted.' });
    }

    return res.json({
      success: true,
      message: 'Emergency contact removed successfully.'
    });
  } catch (err) {
    console.error('[Delete Contact Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to delete contact.' });
  }
};

module.exports = {
  getContacts,
  addContact,
  updateContact,
  deleteContact
};

const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { JWT_SECRET } = require('../middlewares/authMiddleware');

const register = async (req, res) => {
  try {
    const { name, email, phone, password, blood_group, medical_notes } = req.body;

    if (!name || !email || !phone || !password) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, phone number, and password are required.'
      });
    }

    // Check existing email
    const existing = await db.query('SELECT * FROM users WHERE email = $1', [email.trim().toLowerCase()]);
    if (existing.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'An account with this email address already exists.'
      });
    }

    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    const result = await db.query(
      `INSERT INTO users (name, email, phone, password_hash, blood_group, medical_notes) 
       VALUES ($1, $2, $3, $4, $5, $6) 
       RETURNING id, name, email, phone, blood_group, medical_notes, created_at`,
      [name.trim(), email.trim().toLowerCase(), phone.trim(), password_hash, blood_group || '', medical_notes || '']
    );

    const newUser = result.rows[0];
    const token = jwt.sign(
      { id: newUser.id, email: newUser.email, name: newUser.name },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.status(201).json({
      success: true,
      message: 'Account registered successfully.',
      token,
      user: {
        id: newUser.id,
        name: newUser.name,
        email: newUser.email,
        phone: newUser.phone,
        bloodGroup: newUser.blood_group,
        medicalNotes: newUser.medical_notes
      }
    });
  } catch (err) {
    console.error('[Auth Register Error]:', err);
    return res.status(500).json({ success: false, message: 'Server error during registration.' });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required.'
      });
    }

    const result = await db.query('SELECT * FROM users WHERE email = $1', [email.trim().toLowerCase()]);
    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password credentials.'
      });
    }

    const user = result.rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password credentials.'
      });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      success: true,
      message: 'Login successful.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        bloodGroup: user.blood_group,
        medicalNotes: user.medical_notes
      }
    });
  } catch (err) {
    console.error('[Auth Login Error]:', err);
    return res.status(500).json({ success: false, message: 'Server error during login.' });
  }
};

const getProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const result = await db.query(
      'SELECT id, name, email, phone, blood_group, medical_notes, custom_sos_message, created_at FROM users WHERE id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    const user = result.rows[0];

    // Fetch contact count
    const contactResult = await db.query(
      'SELECT COUNT(*) as count FROM emergency_contacts WHERE user_id = $1 AND is_active = true',
      [userId]
    );

    return res.json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        bloodGroup: user.blood_group,
        medicalNotes: user.medical_notes,
        customSosMessage: user.custom_sos_message || '',
        createdAt: user.created_at,
        contactsCount: parseInt(contactResult.rows[0]?.count || 0, 10)
      }
    });
  } catch (err) {
    console.error('[Get Profile Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to retrieve profile.' });
  }
};

const updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, phone, bloodGroup, medicalNotes, customSosMessage } = req.body;

    const result = await db.query(
      `UPDATE users 
       SET name = COALESCE($1, name),
           phone = COALESCE($2, phone),
           blood_group = COALESCE($3, blood_group),
           medical_notes = COALESCE($4, medical_notes),
           custom_sos_message = COALESCE($5, custom_sos_message),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $6
       RETURNING id, name, email, phone, blood_group, medical_notes, custom_sos_message`,
      [name, phone, bloodGroup, medicalNotes, customSosMessage, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    const updated = result.rows[0];
    return res.json({
      success: true,
      message: 'Profile updated successfully.',
      user: {
        id: updated.id,
        name: updated.name,
        email: updated.email,
        phone: updated.phone,
        bloodGroup: updated.blood_group,
        medicalNotes: updated.medical_notes,
        customSosMessage: updated.custom_sos_message || ''
      }
    });
  } catch (err) {
    console.error('[Update Profile Error]:', err);
    return res.status(500).json({ success: false, message: 'Failed to update profile.' });
  }
};

module.exports = {
  register,
  login,
  getProfile,
  updateProfile
};

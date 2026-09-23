const express = require('express');
const router = express.Router();
const iotController = require('../controllers/iotController');
const { authenticateToken } = require('../middlewares/authMiddleware');

// Hardware trigger endpoint (called by ESP32 / IoT device or webhook)
router.post('/trigger', iotController.handleDeviceTrigger);

// User device management (requires JWT)
router.post('/pair', authenticateToken, iotController.pairDevice);
router.get('/devices', authenticateToken, iotController.getUserDevices);

module.exports = router;

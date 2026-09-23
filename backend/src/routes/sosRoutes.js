const express = require('express');
const router = express.Router();
const sosController = require('../controllers/sosController');
const { authenticateToken } = require('../middlewares/authMiddleware');

router.use(authenticateToken);

router.post('/trigger', sosController.triggerSOS);
router.get('/history', sosController.getAlertHistory);

module.exports = router;

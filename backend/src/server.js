const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { initDatabase, isPostgresConnected } = require('./db');
const authRoutes = require('./routes/authRoutes');
const contactRoutes = require('./routes/contactRoutes');
const sosRoutes = require('./routes/sosRoutes');
const iotRoutes = require('./routes/iotRoutes');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request Logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    timestamp: new Date().toISOString(),
    postgresConnected: isPostgresConnected(),
    smsProvider: process.env.SMS_PROVIDER || 'mock'
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/contacts', contactRoutes);
app.use('/api/sos', sosRoutes);
app.use('/api/iot', iotRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} not found.`
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('[Unhandled Error]:', err.stack);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'production' ? null : err.message
  });
});

// Start Server and Connect DB
async function startServer() {
  await initDatabase();

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n======================================================`);
    console.log(`🚀 SOS Emergency API Server is running on port ${PORT}`);
    console.log(`📡 Local Health Check: http://localhost:${PORT}/api/health`);
    console.log(`🔘 IoT Trigger Webhook: http://localhost:${PORT}/api/iot/trigger`);
    console.log(`📱 Mobile Auth Endpoint: http://localhost:${PORT}/api/auth`);
    console.log(`======================================================\n`);
  });
}

startServer();

module.exports = app;

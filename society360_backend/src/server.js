require('dotenv').config();
const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const logger = require('./config/logger');
const { pool } = require('./config/database');

// Import services
const visitorTimeoutService = require('./services/visitor_timeout_service');

// Import routes
const authRoutes = require('./routes/auth');
const onboardingRoutes = require('./routes/onboarding');
const visitorRoutes = require('./routes/visitors');
const visitRoutes = require('./routes/visits');
const guardRoutes = require('./routes/guards');
const residentRoutes = require('./routes/residents');
const profileRoutes = require('./routes/profile');
const fcmRoutes = require('./routes/fcm');
const emergencyRoutes = require('./routes/emergencies');

// Admin Portal routes
const adminAuthRoutes = require('./routes/adminAuth');
const adminSocietiesRoutes = require('./routes/adminSocieties');
const adminDashboardRoutes = require('./routes/adminDashboard');
const adminEmergenciesRoutes = require('./routes/adminEmergencies');
const adminApprovalsRoutes = require('./routes/adminApprovals');
const noticesRoutes = require('./routes/notices');
const complaintsRoutes = require('./routes/complaints');

// Initialize Express app
const app = express();
const httpServer = createServer(app);

// Initialize Socket.io
const io = new Server(httpServer, {
  cors: {
    origin: process.env.SOCKET_CORS_ORIGIN || '*',
    methods: ['GET', 'POST'],
  },
});

// Make io accessible to routes
app.set('io', io);

// Initialize visitor timeout service with Socket.io instance
visitorTimeoutService.setSocketIO(io);

// Middleware
app.use(helmet()); // Security headers
app.use(cors()); // Enable CORS
app.use(express.json()); // Parse JSON bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
});
app.use('/v1/', limiter);

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.headers['user-agent'],
  });
  next();
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT NOW()');
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
      timeout_service: 'running',
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      database: 'disconnected',
      error: error.message,
    });
  }
});

// API Routes
const API_VERSION = process.env.API_VERSION || 'v1';
app.use(`/${API_VERSION}/auth`, authRoutes);
app.use(`/${API_VERSION}`, onboardingRoutes);
app.use(`/${API_VERSION}/visitors`, visitorRoutes);
app.use(`/${API_VERSION}/visits`, visitRoutes);
app.use(`/${API_VERSION}/guards`, guardRoutes);
app.use(`/${API_VERSION}/resident-requests`, residentRoutes);
app.use(`/${API_VERSION}`, residentRoutes); // Also mount at root for /my-flats endpoint
app.use(`/${API_VERSION}/profile`, profileRoutes);
app.use(`/${API_VERSION}`, fcmRoutes);
app.use(`/${API_VERSION}/emergencies`, emergencyRoutes);

// Admin Portal API Routes
app.use(`/${API_VERSION}/admin/auth`, adminAuthRoutes);
app.use(`/${API_VERSION}/admin/societies`, adminSocietiesRoutes);
app.use(`/${API_VERSION}/admin/dashboard`, adminDashboardRoutes);
app.use(`/${API_VERSION}/admin/emergencies`, adminEmergenciesRoutes);
app.use(`/${API_VERSION}/admin/approvals`, adminApprovalsRoutes);
app.use(`/${API_VERSION}/notices`, noticesRoutes);
app.use(`/${API_VERSION}/complaints`, complaintsRoutes);

// Socket.io connection handling
io.on('connection', (socket) => {
  logger.info(`Socket connected: ${socket.id}`);

  // Join room based on user role and flat/society
  socket.on('join_room', (data) => {
    const { room_type, room_id, user_id } = data;
    const roomName = `${room_type}:${room_id}`;
    socket.join(roomName);
    logger.info(`Socket ${socket.id} joined room: ${roomName}`, { user_id });
  });

  // Leave room
  socket.on('leave_room', (data) => {
    const { room_type, room_id } = data;
    const roomName = `${room_type}:${room_id}`;
    socket.leave(roomName);
    logger.info(`Socket ${socket.id} left room: ${roomName}`);
  });

  // Disconnect
  socket.on('disconnect', () => {
    logger.info(`Socket disconnected: ${socket.id}`);
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error',
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found',
  });
});

// Start server
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  logger.info(`🚀 Society360 Backend running on port ${PORT}`);
  logger.info(`📡 Socket.io server ready`);
  logger.info(`🔗 API Base URL: http://localhost:${PORT}/${API_VERSION}`);

  // Start visitor timeout service
  visitorTimeoutService.start();
  logger.info(`⏱️  Visitor timeout service started (5-minute auto-rejection)`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');

  // Stop timeout service
  visitorTimeoutService.stop();

  httpServer.close(() => {
    logger.info('HTTP server closed');
    pool.end(() => {
      logger.info('Database pool has ended');
      process.exit(0);
    });
  });
});

module.exports = { app, io };

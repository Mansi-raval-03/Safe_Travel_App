#!/usr/bin/env node

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

// Server configuration
const PORT = process.env.PORT || 3000;
const DATA_DIR = path.join(__dirname, 'data');
const DB_PATH = path.join(DATA_DIR, 'sos_alerts.db');

// Initialize Express app and Socket.IO
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // Allow all origins for local network access
    methods: ["GET", "POST"],
    credentials: false
  },
  transports: ['websocket', 'polling'],
  pingInterval: 25000,
  pingTimeout: 60000,
  upgradeTimeout: 30000,
  maxHttpBufferSize: 1e6
});

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Initialize SQLite database
let db;

function initDatabase() {
  return new Promise((resolve, reject) => {
    db = new sqlite3.Database(DB_PATH, (err) => {
      if (err) {
        console.error('Error opening database:', err.message);
        reject(err);
        return;
      }
      
      console.log('Connected to SQLite database');
      
      // Create tables if they don't exist
      const createTables = `
        CREATE TABLE IF NOT EXISTS sos_alerts (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          alert_type TEXT NOT NULL,
          message TEXT,
          user_name TEXT,
          user_phone TEXT,
          user_email TEXT,
          latitude REAL,
          longitude REAL,
          location_accuracy REAL,
          altitude REAL,
          heading REAL,
          speed REAL,
          location_timestamp TEXT,
          device_platform TEXT,
          device_version TEXT,
          additional_data TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS server_stats (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_type TEXT NOT NULL,
          details TEXT,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );
      `;
      
      db.exec(createTables, (err) => {
        if (err) {
          console.error('Error creating tables:', err.message);
          reject(err);
        } else {
          console.log('Database tables initialized');
          resolve();
        }
      });
    });
  });
}

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// CORS middleware for HTTP endpoints
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// HTTP Routes
app.get('/', (req, res) => {
  res.json({
    service: 'Offline SOS Alert Server',
    version: '1.0.0',
    status: 'running',
    connectedClients: io.engine.clientsCount,
    timestamp: new Date().toIso8601String()
  });
});

// Get server statistics
app.get('/stats', async (req, res) => {
  try {
    const stats = await getServerStats();
    res.json({
      success: true,
      stats: stats,
      connectedClients: io.engine.clientsCount
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get all SOS alerts
app.get('/alerts', async (req, res) => {
  try {
    const alerts = await getAllAlerts();
    res.json({
      success: true,
      alerts: alerts,
      count: alerts.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Delete all alerts (for testing)
app.delete('/alerts', async (req, res) => {
  try {
    await clearAllAlerts();
    res.json({
      success: true,
      message: 'All alerts cleared'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);
  logServerEvent('client_connected', { socketId: socket.id });
  
  // Send welcome message
  socket.emit('connected', {
    message: 'Connected to SOS Alert Server',
    serverId: socket.id,
    timestamp: new Date().toIso8601String()
  });

  // Handle SOS alert
  socket.on('sos_alert', async (data, ack) => {
    console.log('SOS Alert received:', JSON.stringify(data, null, 2));
    
    try {
      // Validate required fields
      if (!data.id || !data.alertType || !data.timestamp) {
        const error = 'Missing required fields: id, alertType, timestamp';
        console.error(error);
        if (ack) ack({ success: false, message: error });
        return;
      }

      // Store in database
      await storeSOSAlert(data);
      
      // Broadcast to all connected clients except sender
      socket.broadcast.emit('sos_alert_broadcast', {
        ...data,
        receivedAt: new Date().toIso8601String(),
        fromClient: socket.id
      });

      console.log(`SOS Alert ${data.id} stored and broadcasted to ${io.engine.clientsCount - 1} clients`);
      
      // Send acknowledgment
      if (ack) {
        ack({
          success: true,
          message: 'SOS alert received and broadcasted',
          alertId: data.id,
          clientsNotified: io.engine.clientsCount - 1
        });
      }

      // Log the event
      logServerEvent('sos_alert_received', {
        alertId: data.id,
        alertType: data.alertType,
        clientId: socket.id,
        clientsNotified: io.engine.clientsCount - 1
      });

    } catch (error) {
      console.error('Error handling SOS alert:', error);
      if (ack) {
        ack({
          success: false,
          message: `Server error: ${error.message}`
        });
      }
    }
  });

  // Handle request for stored alerts
  socket.on('get_alerts', async (data, ack) => {
    try {
      const alerts = await getAllAlerts();
      console.log(`Sending ${alerts.length} stored alerts to client ${socket.id}`);
      
      if (ack) {
        ack({
          success: true,
          alerts: alerts,
          count: alerts.length
        });
      }
    } catch (error) {
      console.error('Error getting alerts:', error);
      if (ack) {
        ack({
          success: false,
          message: error.message,
          alerts: []
        });
      }
    }
  });

  // Handle heartbeat
  socket.on('heartbeat', (data) => {
    socket.emit('heartbeat_response', {
      received: data.timestamp,
      serverTime: new Date().toIso8601String()
    });
  });

  // Handle client disconnect
  socket.on('disconnect', (reason) => {
    console.log(`Client disconnected: ${socket.id}, reason: ${reason}`);
    logServerEvent('client_disconnected', { socketId: socket.id, reason: reason });
  });

  // Handle connection errors
  socket.on('error', (error) => {
    console.error(`Socket error from ${socket.id}:`, error);
    logServerEvent('socket_error', { socketId: socket.id, error: error.message });
  });
});

// Database helper functions
function storeSOSAlert(alertData) {
  return new Promise((resolve, reject) => {
    const stmt = db.prepare(`
      INSERT INTO sos_alerts (
        id, timestamp, alert_type, message, user_name, user_phone, user_email,
        latitude, longitude, location_accuracy, altitude, heading, speed, location_timestamp,
        device_platform, device_version, additional_data
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const location = alertData.location || {};
    const user = alertData.user || {};
    const device = alertData.device || {};

    stmt.run([
      alertData.id,
      alertData.timestamp,
      alertData.alertType,
      alertData.message,
      user.name,
      user.phone,
      user.email,
      location.latitude,
      location.longitude,
      location.accuracy,
      location.altitude,
      location.heading,
      location.speed,
      location.timestamp,
      device.platform,
      device.version,
      JSON.stringify(alertData.additionalData || {})
    ], function(err) {
      if (err) {
        reject(err);
      } else {
        resolve(this.lastID);
      }
    });

    stmt.finalize();
  });
}

function getAllAlerts() {
  return new Promise((resolve, reject) => {
    db.all('SELECT * FROM sos_alerts ORDER BY created_at DESC', (err, rows) => {
      if (err) {
        reject(err);
      } else {
        // Convert rows back to original format
        const alerts = rows.map(row => ({
          id: row.id,
          timestamp: row.timestamp,
          alertType: row.alert_type,
          message: row.message,
          user: {
            name: row.user_name,
            phone: row.user_phone,
            email: row.user_email
          },
          location: row.latitude ? {
            latitude: row.latitude,
            longitude: row.longitude,
            accuracy: row.location_accuracy,
            altitude: row.altitude,
            heading: row.heading,
            speed: row.speed,
            timestamp: row.location_timestamp
          } : null,
          device: {
            platform: row.device_platform,
            version: row.device_version
          },
          additionalData: row.additional_data ? JSON.parse(row.additional_data) : {},
          storedAt: row.created_at
        }));
        resolve(alerts);
      }
    });
  });
}

function clearAllAlerts() {
  return new Promise((resolve, reject) => {
    db.run('DELETE FROM sos_alerts', (err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });
}

function logServerEvent(eventType, details) {
  if (db) {
    const stmt = db.prepare('INSERT INTO server_stats (event_type, details) VALUES (?, ?)');
    stmt.run([eventType, JSON.stringify(details)], (err) => {
      if (err) {
        console.error('Error logging event:', err.message);
      }
    });
    stmt.finalize();
  }
}

function getServerStats() {
  return new Promise((resolve, reject) => {
    db.all(`
      SELECT 
        event_type,
        COUNT(*) as count,
        MAX(timestamp) as last_occurrence
      FROM server_stats 
      GROUP BY event_type 
      ORDER BY last_occurrence DESC
    `, (err, rows) => {
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  
  if (db) {
    db.close((err) => {
      if (err) {
        console.error('Error closing database:', err.message);
      } else {
        console.log('Database connection closed');
      }
    });
  }
  
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// Start server
async function startServer() {
  try {
    await initDatabase();
    
    server.listen(PORT, '0.0.0.0', () => {
      console.log('==========================================');
      console.log('🚨 Offline SOS Alert Server Started 🚨');
      console.log('==========================================');
      console.log(`📡 Server running on: http://0.0.0.0:${PORT}`);
      console.log(`📊 Dashboard: http://localhost:${PORT}`);
      console.log(`💾 Database: ${DB_PATH}`);
      console.log(`🌐 Network: Available on local WiFi/hotspot`);
      console.log('==========================================');
      console.log('Ready to receive SOS alerts...\n');
      
      logServerEvent('server_started', { port: PORT, timestamp: new Date().toIso8601String() });
    });

    // Handle server errors
    server.on('error', (error) => {
      if (error.code === 'EADDRINUSE') {
        console.error(`❌ Port ${PORT} is already in use. Try a different port:`);
        console.error(`   PORT=3001 node server.js`);
      } else {
        console.error('Server error:', error);
      }
      process.exit(1);
    });

  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Start the server
startServer();
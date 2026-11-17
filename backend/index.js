const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, ".env") });

const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");
const { connectDB, disconnectDB } = require("./config/database");

// Route imports
const authRoutes = require("./src/routes/authRoutes");
const userRoutes = require("./src/routes/userRoutes");
const medicineRoutes = require("./src/routes/medicineRoutes");
const healthRecordRoutes = require("./src/routes/healthRecordRoutes");
const appointmentRoutes = require("./src/routes/appointmentRoutes");
const emergencyRoutes = require("./src/routes/emergencyRoutes");
const wellnessRoutes = require("./src/routes/wellnessRoutes");
const aiAssistantRoutes = require("./src/routes/aiAssistantRoutes");
const hospitalRoutes = require("./src/routes/hospitalRoutes");

const app = express();
if (process.env.RENDER === 'true') app.set('trust proxy', 1);

// Dynamic CORS configuration supporting Flutter Web, Android Emulators, LAN IPs, and local tools
const allowedOriginPatterns = [
  /^http:\/\/localhost(:\d+)?$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?$/,
  /^http:\/\/10\.0\.2\.2(:\d+)?$/,
  /^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/,
  /^http:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/,
];

const configuredOrigins = new Set((process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean));
const corsOptions = {
  origin: (origin, callback) => {
    const allowed = !origin || configuredOrigins.has(origin) || (process.env.NODE_ENV !== 'production' && allowedOriginPatterns.some((pattern) => pattern.test(origin)));
    callback(null, allowed);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization'],
  optionsSuccessStatus: 204,
};
app.use(cors(corsOptions));
app.disable('x-powered-by');
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  next();
});

// Never cache medical API responses or reveal internal errors in production.
app.use('/api', (req, res, next) => {
  res.setHeader('Cache-Control', 'no-store, private');
  const json = res.json;
  res.json = function(body) {
    if (process.env.NODE_ENV === 'production' && res.statusCode >= 500) {
      body = { success: false, message: 'Service temporarily unavailable. Please retry later.' };
    }
    return json.call(this, body);
  };
  next();
});

// Parse incoming JSON and urlencoded requests
app.use(express.json({ limit: "1mb" }));
app.use(express.urlencoded({ extended: true, limit: "1mb" }));

// Medical documents are available only through authenticated owner-scoped download routes.

// Root Information Endpoint
app.get("/", (req, res) => {
  const isConnected = mongoose.connection.readyState === 1;

  res.json({
    app: "MEDGUARD Backend API",
    status: "running",
    database: isConnected ? "connected" : "disconnected",
    version: "1.0.0",
    revision: (process.env.RENDER_GIT_COMMIT || process.env.APP_REVISION || "local").slice(0, 12),
  });
});

// Health Check Endpoint
app.get("/api/health", (req, res) => {
  const isConnected = mongoose.connection.readyState === 1;

  res.status(isConnected ? 200 : 503).json({
    status: isConnected ? "healthy" : "unhealthy",
    mongodb: isConnected ? "connected" : "disconnected",
  });
});

// Production Readiness Endpoint for Render / Load Balancers
app.get("/api/health/ready", async (req, res) => {
  const isConnected = mongoose.connection.readyState === 1;
  if (!isConnected) {
    return res.status(503).json({
      status: "not_ready",
      database: "connecting_or_disconnected",
      message: "Database is establishing connection to MongoDB Atlas.",
    });
  }

  try {
    await mongoose.connection.db.admin().ping();
    return res.status(200).json({
      status: "ready",
      database: "connected",
      message: "MEDGUARD Backend and MongoDB Atlas are ready to serve requests.",
    });
  } catch (err) {
    return res.status(503).json({
      status: "unhealthy",
      database: "error",
      message: err.message,
    });
  }
});

// Database connection readiness check middleware for /api routes
app.use("/api", async (req, res, next) => {
  if (
    req.path === "/health" ||
    req.path === "/health/ready" ||
    req.path.startsWith("/hospitals")
  ) {
    return next();
  }

  // If connection is in progress, give it up to 4.5 seconds to establish before returning 503
  if (mongoose.connection.readyState !== 1) {
    const startTime = Date.now();
    while (mongoose.connection.readyState !== 1 && (Date.now() - startTime) < 4500) {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }

  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({
      success: false,
      message: "Database is connecting to MongoDB Atlas. Please retry in a few seconds.",
      database: "disconnected",
    });
  }
  next();
});

// Register API Routes
app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/medicines", medicineRoutes);
app.use("/api/health-records", healthRecordRoutes);
app.use("/api/appointments", appointmentRoutes);
app.use("/api/emergency", emergencyRoutes);
app.use("/api/wellness", wellnessRoutes);
app.use("/api/ai", aiAssistantRoutes);
app.use("/api/hospitals", hospitalRoutes);

app.use("/api/launch", require("./src/routes/launchRoutes"));

// Global 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Endpoint not found.",
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error("[API] Request failed:", err.name || "Error");
  res.status(err.status || 500).json({
    success: false,
    message: err.message || "Internal server error.",
  });
});

let serverInstance = null;
let isConnecting = false;

async function attemptDbConnection() {
  if (isConnecting || mongoose.connection.readyState === 1) return;
  isConnecting = true;
  try {
    await connectDB();
    console.log("[SERVER] MongoDB Atlas ready to serve requests.");
  } catch (error) {
    console.error("[SERVER] DB connection attempt failed:", error.message);
    console.log("[SERVER] Scheduling background reconnect in 5 seconds...");
    setTimeout(() => {
      isConnecting = false;
      attemptDbConnection();
    }, 5000);
  } finally {
    isConnecting = false;
  }
}

// Start Server immediately and connect to MongoDB Atlas
async function startServer() {
  require("./src/utils/jwt").getSecret();
  const PORT = process.env.PORT || 5001;

  console.log("[SERVER] Starting MEDGUARD Backend Service...");

  serverInstance = app.listen(PORT, "0.0.0.0", () => {
    console.log(`[SERVER] MEDGUARD Backend running on port ${PORT}`);
    console.log(`[SERVER] Local URL: http://localhost:${PORT}`);
    console.log(`[SERVER] Health check: http://localhost:${PORT}/api/health`);
  });

  serverInstance.on("error", (err) => {
    if (err.code === "EADDRINUSE") {
      console.error(`[SERVER ERROR] Port ${PORT} is already in use by another application.`);
      console.error(`[SERVER TIP] Disable conflicting service or set PORT=5001 in .env.`);
    } else {
      console.error(`[SERVER ERROR] Server error on port ${PORT}:`, err.message);
    }
    process.exit(1);
  });

  attemptDbConnection();
  require('./src/services/deletionService').startDeletionWorker();
}

// Graceful Shutdown Handlers
async function gracefulShutdown(signal) {
  console.log(`\n[SERVER] Received ${signal}. Initiating graceful shutdown...`);

  if (serverInstance) {
    serverInstance.close(() => {
      console.log("[SERVER] HTTP server closed.");
    });
  }

  await disconnectDB().catch(() => {});
  process.exit(0);
}

process.on("SIGINT", () => gracefulShutdown("SIGINT"));
process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));

if (require.main === module) startServer();
module.exports = { app, startServer };

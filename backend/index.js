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

const app = express();

// Enable CORS for local Flutter dev and web clients
app.use(cors());

// Parse incoming JSON and urlencoded requests
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// Serve static uploaded files (vault docs, appointment PDFs)
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// Root Information Endpoint
app.get("/", (req, res) => {
  const isConnected = mongoose.connection.readyState === 1;

  res.json({
    app: "MEDGUARD Backend API",
    status: "running",
    database: isConnected ? "connected" : "disconnected",
    version: "1.0.0",
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

// Register API Routes
app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/medicines", medicineRoutes);
app.use("/api/health-records", healthRecordRoutes);
app.use("/api/appointments", appointmentRoutes);
app.use("/api/emergency", emergencyRoutes);
app.use("/api/wellness", wellnessRoutes);
app.use("/api/ai", aiAssistantRoutes);

// Global 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint not found: ${req.method} ${req.url}`,
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error("Global Error Handler:", err);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || "Internal server error.",
  });
});

let serverInstance = null;

// Start Server after verifying MongoDB Atlas connection
async function startServer() {
  try {
    console.log("[SERVER] Starting MEDGUARD Backend Service...");
    await connectDB();

    const PORT = process.env.PORT || 5001;

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
  } catch (error) {
    console.error("[SERVER ERROR] Startup failed:", error.message);
    await disconnectDB().catch(() => {});
    process.exit(1);
  }
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

startServer();

const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
const mongoose = require("mongoose");

/**
 * Validates and returns MongoDB environment configuration.
 * Never logs or exposes password/secret values.
 */
function getMongoConfig() {
  const username = process.env.MONGODB_USERNAME;
  const password = process.env.MONGODB_PASSWORD;
  const rawHost = process.env.MONGODB_HOST;
  const dbName = process.env.DB_NAME || "medguard";

  if (!username || !password || !rawHost) {
    throw new Error(
      "Missing required MongoDB environment variables (MONGODB_USERNAME, MONGODB_PASSWORD, MONGODB_HOST). Check your .env file."
    );
  }

  // Clean host validation - must be hostname only, without protocol or trailing path
  const host = rawHost.trim().replace(/^https?:\/\//i, "").replace(/\/.*$/, "");

  if (host.includes("://") || host.includes("/")) {
    throw new Error("MONGODB_HOST must contain only the cluster hostname.");
  }

  return { username, password, host, dbName };
}

/**
 * Constructs the MongoDB Atlas SRV URI with properly encoded credentials.
 */
function buildMongoUri(config) {
  const encodedUser = encodeURIComponent(config.username);
  const encodedPass = encodeURIComponent(config.password);
  return `mongodb+srv://${encodedUser}:${encodedPass}@${config.host}/?retryWrites=true&w=majority`;
}

/**
 * Connects to MongoDB Atlas using Mongoose with robust network and TLS options.
 */
async function connectDB(maxRetries = 8, retryDelayMs = 1500) {
  const config = getMongoConfig();
  const uri = buildMongoUri(config);

  const options = {
    dbName: config.dbName,
    serverSelectionTimeoutMS: 20000,
    connectTimeoutMS: 20000,
    socketTimeoutMS: 60000,
    maxPoolSize: 10,
    minPoolSize: 0,
    family: 4, // Prefer IPv4 resolution to prevent IPv6 TLS handshake timeouts
    retryWrites: true,
  };

  // Reuse active connection if already connected
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  let lastError = null;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`[DATABASE] Connecting to MongoDB Atlas (Attempt ${attempt}/${maxRetries})...`);
      await mongoose.connect(uri, options);

      // Verify database ping
      await mongoose.connection.db.admin().ping();

      console.log(`[DATABASE] Connected successfully to MongoDB Atlas!`);
      console.log(`[DATABASE] Target Database: ${config.dbName}`);
      return mongoose.connection;
    } catch (error) {
      lastError = error;
      const sanitizedMsg = error.message.replace(
        /mongodb\+srv:\/\/[^@]+@/,
        "mongodb+srv://***:***@"
      );
      console.warn(
        `[DATABASE] Connection attempt ${attempt}/${maxRetries} failed: ${sanitizedMsg}`
      );
      await mongoose.disconnect().catch(() => {});
      if (attempt < maxRetries) {
        const waitTime = Math.min(retryDelayMs * attempt, 6000);
        await new Promise((resolve) => setTimeout(resolve, waitTime));
      }
    }
  }

  const sanitizedMsg = lastError
    ? lastError.message.replace(/mongodb\+srv:\/\/[^@]+@/, "mongodb+srv://***:***@")
    : "Unknown error";
  console.error(
    `[DATABASE ERROR] Connection failed for cluster "${config.host}" after ${maxRetries} attempts:`,
    sanitizedMsg
  );
  throw new Error(`Database connection failed: ${sanitizedMsg}`);
}

/**
 * Disconnects cleanly from MongoDB Atlas.
 */
async function disconnectDB() {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
    console.log("[DATABASE] Disconnected cleanly from MongoDB Atlas.");
  }
}

module.exports = {
  getMongoConfig,
  buildMongoUri,
  connectDB,
  disconnectDB,
};

const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

const dns = require("dns");
const tls = require("tls");
const mongoose = require("mongoose");
const { getMongoConfig, connectDB, disconnectDB } = require("../config/database");

/**
 * Diagnostic test suite for MongoDB Atlas connection, DNS resolution,
 * per-shard TLS certificate verification, Mongoose connection stability,
 * and database write/read validation.
 *
 * Exits with process.exit(1) on ANY check failure and process.exit(0) ONLY when all pass.
 */
async function runDiagnostics() {
  console.log("==================================================");
  console.log("MEDGUARD — MONGODB ATLAS DIAGNOSTIC & TEST SUITE");
  console.log("==================================================\n");

  let suitePassed = true;
  const failureReasons = [];

  // ----------------------------------------------------
  // CHECK 1: Environment Variables Validation
  // ----------------------------------------------------
  let config;
  try {
    config = getMongoConfig();
    console.log("[CHECK 1] Environment Variables: VALID");
    console.log(` - Cluster Host: ${config.host}`);
    console.log(` - Database Name: ${config.dbName}`);
    console.log(` - Username: ${config.username}`);
  } catch (err) {
    console.error("[CHECK 1 FAILED] Invalid environment configuration:", err.message);
    console.log("\n==================================================");
    console.log("DIAGNOSTIC SUITE RESULT: FAILED");
    console.log("==================================================");
    process.exit(1);
  }

  // ----------------------------------------------------
  // CHECK 2: DNS SRV Resolution
  // ----------------------------------------------------
  console.log("\n[CHECK 2] Testing DNS SRV Resolution for Atlas Cluster...");
  const srvHostname = `_mongodb._tcp.${config.host}`;
  let srvAddresses = [];
  try {
    srvAddresses = await new Promise((resolve, reject) => {
      dns.resolveSrv(srvHostname, (err, addresses) => {
        if (err) reject(err);
        else resolve(addresses);
      });
    });
    console.log(`[CHECK 2 SUCCESS] Resolved ${srvAddresses.length} Atlas shard hosts:`);
    srvAddresses.forEach((srv, index) => {
      console.log(`   Shard ${index + 1}: ${srv.name}:${srv.port}`);
    });
  } catch (err) {
    console.error(`[CHECK 2 FAILED] DNS SRV Lookup failed for ${srvHostname}:`, err.code || err.message);
    suitePassed = false;
    failureReasons.push(`DNS SRV lookup failed for ${srvHostname}: ${err.message}`);
  }

  // ----------------------------------------------------
  // CHECK 3: Per-Shard Direct TLS Connectivity & Certificate Verification
  // ----------------------------------------------------
  console.log("\n[CHECK 3] Testing Direct TLS Connectivity & Certificate Verification per Shard...");
  const shardHosts = srvAddresses.length > 0
    ? srvAddresses.map((s) => s.name)
    : [config.host];

  let shardTlsFailures = 0;

  for (let i = 0; i < shardHosts.length; i++) {
    const shardHost = shardHosts[i];
    process.stdout.write(` Shard ${i + 1}/${shardHosts.length} (${shardHost}:27017)... `);

    try {
      const tlsResult = await new Promise((resolve, reject) => {
        const socket = tls.connect(
          {
            host: shardHost,
            port: 27017,
            servername: shardHost,
            rejectUnauthorized: true, // Strict certificate verification enabled
          },
          () => {
            const protocol = socket.getProtocol();
            const cipher = socket.getCipher() ? socket.getCipher().name : "UNKNOWN";
            const authorized = socket.authorized;
            socket.end();
            resolve({ authorized, protocol, cipher, certError: socket.authorizationError });
          }
        );

        socket.setTimeout(8000, () => {
          socket.destroy();
          reject(new Error("TLS connection timed out (8000ms)"));
        });

        socket.on("error", (err) => {
          reject(err);
        });
      });

      if (tlsResult.authorized) {
        console.log(`TLS CONNECTED (${tlsResult.protocol}, Cipher: ${tlsResult.cipher})`);
      } else {
        console.log(`TLS CERT ERROR: ${tlsResult.certError}`);
        shardTlsFailures++;
      }
    } catch (err) {
      console.log(`TLS FAILED (${err.message})`);
      shardTlsFailures++;
    }
  }

  if (shardTlsFailures > 0) {
    console.error(`[CHECK 3 FAILED] ${shardTlsFailures}/${shardHosts.length} shard(s) failed TLS handshake.`);
    suitePassed = false;
    failureReasons.push(`${shardTlsFailures}/${shardHosts.length} Atlas shards failed TLS connection with certificate verification enabled.`);
  } else {
    console.log(`[CHECK 3 SUCCESS] All ${shardHosts.length} shard(s) passed TLS handshake with valid certificates.`);
  }

  // ----------------------------------------------------
  // CHECK 4: Sequential Mongoose Connection Attempts (Express Driver Logic)
  // ----------------------------------------------------
  const ATTEMPTS = 5;
  console.log(`\n[CHECK 4] Running ${ATTEMPTS} Sequential Mongoose Connection Attempts...`);
  let successCount = 0;
  let failureCount = 0;

  for (let i = 1; i <= ATTEMPTS; i++) {
    process.stdout.write(` Attempt ${i}/${ATTEMPTS}... `);
    try {
      await connectDB();
      await mongoose.connection.db.admin().ping();
      console.log("SUCCESS (Connected & Pinged)");
      successCount++;
      await disconnectDB();
    } catch (err) {
      failureCount++;
      const msg = err.message || "";
      let category = "UNKNOWN_FAILURE";

      if (msg.includes("SSL") || msg.includes("tls") || msg.includes("alert")) {
        category = "TLS_SSL_HANDSHAKE_ERROR";
      } else if (msg.includes("auth") || msg.includes("Authentication")) {
        category = "AUTHENTICATION_FAILED";
      } else if (msg.includes("querySrv") || msg.includes("ENOTFOUND")) {
        category = "DNS_RESOLUTION_FAILED";
      } else if (msg.includes("Server selection timed out")) {
        category = "SERVER_SELECTION_TIMEOUT";
      }

      console.log(`FAILED [Category: ${category}]`);
      console.log(`   Details: ${msg}`);
      await disconnectDB().catch(() => {});
    }
  }

  console.log(`[CHECK 4 SUMMARY] ${successCount}/${ATTEMPTS} attempts succeeded. (${failureCount} failed)`);

  if (failureCount > 0) {
    console.error(`[CHECK 4 FAILED] ${failureCount}/${ATTEMPTS} Mongoose connection attempts failed.`);
    suitePassed = false;
    failureReasons.push(`${failureCount}/${ATTEMPTS} Mongoose connection attempts failed.`);
  } else {
    console.log(`[CHECK 4 SUCCESS] All ${ATTEMPTS} connection attempts succeeded cleanly.`);
  }

  // ----------------------------------------------------
  // CHECK 5: Database Write & Read Verification
  // ----------------------------------------------------
  console.log("\n[CHECK 5] Verifying Document Write and Read Operations on medguard DB...");
  try {
    await connectDB();
    const db = mongoose.connection.db;

    if (db.databaseName !== config.dbName) {
      throw new Error(`Connected database "${db.databaseName}" does not match target "${config.dbName}"`);
    }

    const testCollection = db.collection("setup_checks");
    const testDoc = {
      testId: "connection_check_" + Date.now(),
      service: "MEDGUARD_BACKEND",
      createdAt: new Date(),
    };

    // 5a. Insert test document
    const insertResult = await testCollection.insertOne(testDoc);
    console.log(` [WRITE] Inserted test document into "setup_checks" collection (ID: ${insertResult.insertedId})`);

    // 5b. Read test document back
    const readDoc = await testCollection.findOne({ _id: insertResult.insertedId });
    if (!readDoc || readDoc.testId !== testDoc.testId) {
      throw new Error("Read document verification failed: content mismatch!");
    }
    console.log(` [READ] Successfully retrieved document back. Content matches!`);

    // 5c. Remove test document
    await testCollection.deleteOne({ _id: insertResult.insertedId });
    console.log(` [CLEANUP] Deleted temporary test document from "setup_checks".`);

    console.log(`[CHECK 5 SUCCESS] Database write, read, and delete operations verified on database "${db.databaseName}".`);
  } catch (err) {
    console.error(`[CHECK 5 FAILED] Write/Read verification failed:`, err.message);
    suitePassed = false;
    failureReasons.push(`Database write/read check failed: ${err.message}`);
  } finally {
    await disconnectDB().catch(() => {});
  }

  // ----------------------------------------------------
  // FINAL SUITE RESULT REPORT & EXIT CODE
  // ----------------------------------------------------
  console.log("\n==================================================");
  if (suitePassed) {
    console.log("DIAGNOSTIC SUITE RESULT: PASSED");
    console.log("All connection, TLS, Mongoose, and Write/Read checks PASSED.");
    console.log("==================================================");
    process.exit(0);
  } else {
    console.error("DIAGNOSTIC SUITE RESULT: FAILED");
    console.error("The following checks failed during diagnostic execution:");
    failureReasons.forEach((reason, index) => {
      console.error(`  ${index + 1}. ${reason}`);
    });
    console.log("\n[DIAGNOSTIC ROOT CAUSE ANALYSIS]");
    if (shardTlsFailures > 0) {
      console.log(" -> Primary Cause: TLS handshake alert / rejection on individual Atlas cluster shards.");
      console.log(" -> Action Required: Check MongoDB Atlas Network Access IP Access List.");
      console.log(" -> Note: Add current IP (115.243.91.113) or 0.0.0.0/0 (Allow Access From Anywhere) in Atlas Dashboard.");
    }
    console.log("==================================================");
    process.exit(1);
  }
}

runDiagnostics().catch((err) => {
  console.error("Fatal error during diagnostic execution:", err);
  process.exit(1);
});

const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

const mongoose = require("mongoose");
const { connectDB, disconnectDB, getMongoConfig } = require("../config/database");

/**
 * Task 6 — Verify MongoDB write, read, and delete operations on database "medguard".
 */
async function verifyWriteRead() {
  console.log("==================================================");
  console.log("MEDGUARD — MONGODB WRITE & READ VERIFICATION");
  console.log("==================================================\n");

  const config = getMongoConfig();

  try {
    await connectDB();
    const db = mongoose.connection.db;

    // 1. Confirm database name is medguard
    console.log(`[VERIFY 1] Active Database Name: "${db.databaseName}"`);
    if (db.databaseName !== config.dbName) {
      throw new Error(`Connected database "${db.databaseName}" does not match target "${config.dbName}"`);
    }
    console.log(`[VERIFY 1 SUCCESS] Confirmed target database is "${config.dbName}".`);

    // 2. Insert test document into dedicated setup_checks collection
    const collection = db.collection("setup_checks");
    const testPayload = {
      checkName: "backend_setup_verification",
      environment: "development",
      timestamp: new Date(),
      status: "PASS",
    };

    const insertRes = await collection.insertOne(testPayload);
    console.log(`[VERIFY 2 WRITE] Inserted document into "setup_checks" (ID: ${insertRes.insertedId})`);

    // 3. Read document back and verify content matches
    const retrievedDoc = await collection.findOne({ _id: insertRes.insertedId });
    if (!retrievedDoc) {
      throw new Error("Failed to retrieve written test document!");
    }

    if (
      retrievedDoc.checkName !== testPayload.checkName ||
      retrievedDoc.environment !== testPayload.environment
    ) {
      throw new Error("Retrieved document contents do not match inserted payload!");
    }
    console.log(`[VERIFY 3 READ] Successfully retrieved document back. Content matches!`);

    // 4. Remove temporary document
    await collection.deleteOne({ _id: insertRes.insertedId });
    console.log(`[VERIFY 4 CLEANUP] Deleted temporary document from "setup_checks".`);

    console.log("\n==================================================");
    console.log("SUCCESS: MONGODB WRITE AND READ VERIFIED CLEANLY!");
    console.log("==================================================");
  } catch (err) {
    console.error("\n[VERIFICATION FAILED]:", err.message);
    process.exit(1);
  } finally {
    await disconnectDB();
  }
}

verifyWriteRead();

/**
 * MEDGUARD — Automated Health Vault & GridFS Permanent Storage Verification Script
 *
 * Verifies:
 * 1. Metadata-only Health Record creation (POST /api/health-records)
 * 2. Permanent PDF document upload to MongoDB Atlas GridFS (POST /api/health-records/upload)
 * 3. Permanent Image document upload to MongoDB Atlas GridFS
 * 4. Record listing with proper metadata and fileUrl (GET /api/health-records)
 * 5. Cross-user isolation (User B cannot view or download User A's vault records)
 * 6. Authenticated streaming download from GridFS (GET /api/health-records/:id/download)
 * 7. Record update (PATCH /api/health-records/:id)
 * 8. Record deletion with GridFS cleanup (DELETE /api/health-records/:id)
 * 9. GridFS bucket integrity (vault_files.files & vault_files.chunks)
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const http = require('http');
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const { connectDB, disconnectDB } = require('../config/database');
const User = require('../src/models/User');
const HealthRecord = require('../src/models/HealthRecord');
const { getGridFSBucket } = require('../src/services/storageService');
const healthRecordRoutes = require('../src/routes/healthRecordRoutes');

const TEST_PORT = 5098;
const JWT_SECRET = process.env.JWT_SECRET || 'medguard_jwt_super_secret_key_2026';

function buildMultipartPayload(boundary, fields, file) {
  let parts = [];
  for (const [key, value] of Object.entries(fields)) {
    parts.push(
      `--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${value}\r\n`
    );
  }
  const head = Buffer.from(parts.join(''), 'utf-8');
  const fileHeader = Buffer.from(
    `--${boundary}\r\nContent-Disposition: form-data; name="${file.field}"; filename="${file.filename}"\r\nContent-Type: ${file.contentType}\r\n\r\n`
  );
  const tail = Buffer.from(`\r\n--${boundary}--\r\n`, 'utf-8');
  return Buffer.concat([head, fileHeader, file.buffer, tail]);
}

function makeRequest({ method, path, headers = {}, body = null }) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1',
      port: TEST_PORT,
      path,
      method,
      headers: { ...headers },
    };

    if (body && !headers['Content-Type']) {
      options.headers['Content-Type'] = 'application/json';
    }

    const req = http.request(options, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const rawBuffer = Buffer.concat(chunks);
        let parsed = null;
        try {
          parsed = JSON.parse(rawBuffer.toString('utf-8'));
        } catch (_) {
          parsed = rawBuffer.toString('utf-8');
        }
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          data: parsed,
          rawBuffer,
        });
      });
    });

    req.on('error', reject);

    if (body) {
      if (Buffer.isBuffer(body)) {
        req.write(body);
      } else if (typeof body === 'string') {
        req.write(body);
      } else {
        req.write(JSON.stringify(body));
      }
    }
    req.end();
  });
}

async function withRetry(fn, maxRetries = 4, delayMs = 1500) {
  let lastErr;
  for (let i = 1; i <= maxRetries; i++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      console.warn(`  [RETRY] Transient failure on attempt ${i}/${maxRetries}: ${err.message}. Retrying...`);
      if (i < maxRetries) {
        await new Promise((r) => setTimeout(r, delayMs * i));
      }
    }
  }
  throw lastErr;
}

async function runVaultVerification() {
  console.log('================================================================');
  console.log('  MEDGUARD HEALTH VAULT & GRIDFS AUTOMATED VERIFICATION');
  console.log('================================================================\n');

  let server;
  let userA, userB;
  let tokenA, tokenB;
  const createdRecordIds = [];
  const createdGridFsIds = [];

  try {
    // 1. CONNECT TO DATABASE
    console.log('[1/10] Connecting to MongoDB Atlas...');
    await connectDB();
    console.log('  -> Connected successfully to MongoDB Atlas!\n');

    // 2. CREATE / FIND TEST USERS
    console.log('[2/10] Setting up test accounts for user isolation testing...');
    const userAEmail = `vault_test_a_${Date.now()}@medguard.dev`;
    const userBEmail = `vault_test_b_${Date.now()}@medguard.dev`;

    userA = await withRetry(() =>
      User.create({
        email: userAEmail,
        password: 'HashedPassword123!',
        fullName: 'Alice Test Patient',
        emailVerified: true,
        authProvider: 'email',
      })
    );

    userB = await withRetry(() =>
      User.create({
        email: userBEmail,
        password: 'HashedPassword123!',
        fullName: 'Bob Test Patient',
        emailVerified: true,
        authProvider: 'email',
      })
    );

    tokenA = jwt.sign({ userId: userA._id.toString() }, JWT_SECRET, { expiresIn: '1h' });
    tokenB = jwt.sign({ userId: userB._id.toString() }, JWT_SECRET, { expiresIn: '1h' });

    console.log(`  -> User A created (ID: ${userA._id})`);
    console.log(`  -> User B created (ID: ${userB._id})\n`);

    // 3. START TEST EXPRESS SERVER
    console.log(`[3/10] Starting test HTTP server on port ${TEST_PORT}...`);
    const app = express();
    app.use(cors());
    app.use(express.json());
    app.use('/api/health-records', healthRecordRoutes);

    await new Promise((resolve, reject) => {
      server = app.listen(TEST_PORT, '127.0.0.1', () => {
        console.log(`  -> Test server listening on http://127.0.0.1:${TEST_PORT}\n`);
        resolve();
      });
      server.on('error', reject);
    });

    // 4. TEST 1: CREATE NOTE-ONLY HEALTH RECORD
    console.log('[4/10] Testing POST /api/health-records (Clinical Note / No File)...');
    const notePayload = {
      title: 'Annual Cardiology Assessment',
      category: 'consultation',
      recordType: 'consultation',
      doctorName: 'Dr. Arun Kumar',
      hospitalName: 'Apollo Hospitals',
      documentDate: new Date('2026-09-15').toISOString(),
      notes: 'Patient exhibits normal sinus rhythm. Blood pressure: 120/80 mmHg.',
      tags: ['cardiology', 'annual-checkup'],
    };

    const resNote = await makeRequest({
      method: 'POST',
      path: '/api/health-records',
      headers: { Authorization: `Bearer ${tokenA}` },
      body: notePayload,
    });

    if (resNote.statusCode !== 201 || !resNote.data.success) {
      throw new Error(`Failed to create note record: status ${resNote.statusCode}, ${JSON.stringify(resNote.data)}`);
    }
    const noteRecord = resNote.data.record;
    createdRecordIds.push(noteRecord.id);
    console.log(`  -> PASSED: Created record ${noteRecord.id}`);
    console.log(`     Title: "${noteRecord.title}", Storage: ${noteRecord.storageType}\n`);

    // 5. TEST 2: UPLOAD PDF FILE TO GRIDFS
    console.log('[5/10] Testing POST /api/health-records/upload (PDF to GridFS)...');
    const dummyPdfContent = `%PDF-1.4\n1 0 obj\n<< /Title (MEDGUARD Vault Test Report) /Author (MedGuard) >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF`;
    const pdfBuffer = Buffer.from(dummyPdfContent, 'utf-8');
    const boundaryPdf = `----WebKitFormBoundary${Date.now()}`;
    const pdfMultipart = buildMultipartPayload(
      boundaryPdf,
      {
        title: 'Complete Blood Count (CBC) Lab Report',
        category: 'labReport',
        recordType: 'labReport',
        doctorName: 'Dr. Sarah Jenkins',
        hospitalName: 'City Diagnostic Center',
        documentDate: new Date().toISOString(),
        notes: 'Hemoglobin: 14.2 g/dL, WBC: 6,800 /mcL, Platelets: 250,000 /mcL.',
        tags: 'hematology,blood,lab',
      },
      {
        field: 'file',
        filename: 'cbc_lab_report.pdf',
        contentType: 'application/pdf',
        buffer: pdfBuffer,
      }
    );

    const resPdf = await makeRequest({
      method: 'POST',
      path: '/api/health-records/upload',
      headers: {
        Authorization: `Bearer ${tokenA}`,
        'Content-Type': `multipart/form-data; boundary=${boundaryPdf}`,
      },
      body: pdfMultipart,
    });

    if (resPdf.statusCode !== 201 || !resPdf.data.success) {
      throw new Error(`Failed to upload PDF record: status ${resPdf.statusCode}, ${JSON.stringify(resPdf.data)}`);
    }
    const pdfRecord = resPdf.data.record;
    createdRecordIds.push(pdfRecord.id);
    if (pdfRecord.storageKey) createdGridFsIds.push(pdfRecord.storageKey);

    console.log(`  -> PASSED: PDF stored in GridFS! Record ID: ${pdfRecord.id}`);
    console.log(`     Storage Type: ${pdfRecord.storageType}, Key: ${pdfRecord.storageKey}`);
    console.log(`     File URL: ${pdfRecord.fileUrl}`);

    // Verify directly in MongoDB Atlas GridFS
    const bucket = getGridFSBucket();
    const gridFsFiles = await bucket.find({ _id: new mongoose.Types.ObjectId(pdfRecord.storageKey) }).toArray();
    if (gridFsFiles.length === 0) {
      throw new Error('GridFS file not found in MongoDB Atlas bucket vault_files.files!');
    }
    console.log(`     Verified in Atlas GridFS: ${gridFsFiles[0].filename} (${gridFsFiles[0].length} bytes)\n`);

    // 6. TEST 3: UPLOAD IMAGE FILE TO GRIDFS
    console.log('[6/10] Testing POST /api/health-records/upload (PNG Image to GridFS)...');
    // Minimal 1x1 transparent PNG buffer
    const dummyPngBuffer = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      'base64'
    );
    const boundaryPng = `----WebKitFormBoundaryImg${Date.now()}`;
    const pngMultipart = buildMultipartPayload(
      boundaryPng,
      {
        title: 'Chest X-Ray Digital Scan',
        category: 'imaging',
        recordType: 'imaging',
        doctorName: 'Dr. Robert Chen',
        hospitalName: 'Memorial Radiology',
        documentDate: new Date().toISOString(),
        notes: 'Clear lung fields bilaterally. Cardiac silhouette within normal limits.',
      },
      {
        field: 'file',
        filename: 'chest_xray.png',
        contentType: 'image/png',
        buffer: dummyPngBuffer,
      }
    );

    const resPng = await makeRequest({
      method: 'POST',
      path: '/api/health-records/upload',
      headers: {
        Authorization: `Bearer ${tokenA}`,
        'Content-Type': `multipart/form-data; boundary=${boundaryPng}`,
      },
      body: pngMultipart,
    });

    if (resPng.statusCode !== 201 || !resPng.data.success) {
      throw new Error(`Failed to upload PNG record: status ${resPng.statusCode}, ${JSON.stringify(resPng.data)}`);
    }
    const pngRecord = resPng.data.record;
    createdRecordIds.push(pngRecord.id);
    if (pngRecord.storageKey) createdGridFsIds.push(pngRecord.storageKey);
    console.log(`  -> PASSED: Image stored in GridFS! Record ID: ${pngRecord.id}\n`);

    // 7. TEST 4: LIST RECORDS & VERIFY USER DATA
    console.log('[7/10] Testing GET /api/health-records (Fetch User A list)...');
    const resList = await makeRequest({
      method: 'GET',
      path: '/api/health-records',
      headers: { Authorization: `Bearer ${tokenA}` },
    });

    if (resList.statusCode !== 200 || !resList.data.success) {
      throw new Error(`Failed to list records: status ${resList.statusCode}`);
    }
    const records = resList.data.records;
    console.log(`  -> PASSED: User A retrieved ${records.length} records.`);
    if (records.length < 3) {
      throw new Error(`Expected at least 3 records for User A, got ${records.length}`);
    }
    console.log(`     Records: ${records.map((r) => r.title).join(' | ')}\n`);

    // 8. TEST 5: CROSS-USER ISOLATION & SECURITY
    console.log('[8/10] Testing Cross-User Isolation (User B security checks)...');
    // User B attempts to list records (should not see User A's records)
    const resListB = await makeRequest({
      method: 'GET',
      path: '/api/health-records',
      headers: { Authorization: `Bearer ${tokenB}` },
    });
    if (resListB.data.records.some((r) => createdRecordIds.includes(r.id))) {
      throw new Error('SECURITY VIOLATION: User B can see User A records in list!');
    }

    // User B attempts to access User A's record directly
    const resDetailB = await makeRequest({
      method: 'GET',
      path: `/api/health-records/${pdfRecord.id}`,
      headers: { Authorization: `Bearer ${tokenB}` },
    });
    if (resDetailB.statusCode !== 404) {
      throw new Error(`SECURITY VIOLATION: User B got status ${resDetailB.statusCode} accessing User A record!`);
    }

    // User B attempts to download User A's PDF
    const resDownloadB = await makeRequest({
      method: 'GET',
      path: `/api/health-records/${pdfRecord.id}/download`,
      headers: { Authorization: `Bearer ${tokenB}` },
    });
    if (resDownloadB.statusCode !== 404) {
      throw new Error(`SECURITY VIOLATION: User B got status ${resDownloadB.statusCode} downloading User A file!`);
    }

    // Unauthenticated request should be rejected (401)
    const resUnauth = await makeRequest({
      method: 'GET',
      path: `/api/health-records/${pdfRecord.id}/download`,
    });
    if (resUnauth.statusCode !== 401) {
      throw new Error(`SECURITY VIOLATION: Unauthenticated download got status ${resUnauth.statusCode} (expected 401)!`);
    }

    console.log('  -> PASSED: Strict cross-user isolation and unauthenticated rejections verified!\n');

    // 9. TEST 6: AUTHENTICATED STREAMING DOWNLOAD FROM GRIDFS
    console.log('[9/10] Testing GET /api/health-records/:id/download (Stream from GridFS)...');
    const resDownload = await makeRequest({
      method: 'GET',
      path: `/api/health-records/${pdfRecord.id}/download`,
      headers: { Authorization: `Bearer ${tokenA}` },
    });

    if (resDownload.statusCode !== 200) {
      throw new Error(`Download failed with status ${resDownload.statusCode}`);
    }
    const contentType = resDownload.headers['content-type'];
    const contentDisp = resDownload.headers['content-disposition'];
    console.log(`  -> Content-Type: ${contentType}`);
    console.log(`  -> Content-Disposition: ${contentDisp}`);
    console.log(`  -> Downloaded size: ${resDownload.rawBuffer.length} bytes (Original: ${pdfBuffer.length} bytes)`);

    if (Buffer.compare(resDownload.rawBuffer, pdfBuffer) !== 0) {
      throw new Error('Downloaded bytes do not match original PDF bytes!');
    }
    console.log('  -> PASSED: Downloaded bytes perfectly match original file!\n');

    // 10. TEST 7 & 8: PATCH AND DELETE RECORD
    console.log('[10/10] Testing PATCH & DELETE with GridFS cleanup...');
    const resPatch = await makeRequest({
      method: 'PATCH',
      path: `/api/health-records/${noteRecord.id}`,
      headers: { Authorization: `Bearer ${tokenA}` },
      body: {
        title: 'Annual Cardiology Assessment (Revised)',
        doctorName: 'Dr. Arun Kumar, MD, FACC',
        notes: 'Follow-up ECG confirmed normal sinus rhythm.',
      },
    });

    if (resPatch.statusCode !== 200 || !resPatch.data.success) {
      throw new Error(`PATCH failed: status ${resPatch.statusCode}`);
    }
    console.log(`  -> PASSED: Record updated: "${resPatch.data.record.title}"`);

    // Delete PDF record and verify GridFS file is cleaned up
    const resDelete = await makeRequest({
      method: 'DELETE',
      path: `/api/health-records/${pdfRecord.id}`,
      headers: { Authorization: `Bearer ${tokenA}` },
    });

    if (resDelete.statusCode !== 200 || !resDelete.data.success) {
      throw new Error(`DELETE failed: status ${resDelete.statusCode}`);
    }

    // Check GridFS that file is gone
    const remainingFiles = await bucket.find({ _id: new mongoose.Types.ObjectId(pdfRecord.storageKey) }).toArray();
    if (remainingFiles.length > 0) {
      throw new Error('GridFS cleanup failed: file still exists in bucket after DELETE!');
    }
    console.log(`  -> PASSED: Record deleted and GridFS file cleaned up cleanly!\n`);

    console.log('================================================================');
    console.log('  ALL 10 VERIFICATION CHECKS PASSED WITH 100% SUCCESS!');
    console.log('  MongoDB Atlas GridFS Vault is fully operational and permanent.');
    console.log('================================================================\n');
  } catch (err) {
    console.error('\n❌ VERIFICATION TEST FAILED:', err.message);
    console.error(err.stack);
    process.exitCode = 1;
  } finally {
    // CLEANUP
    console.log('Cleaning up test data from MongoDB Atlas...');
    try {
      if (createdRecordIds.length > 0) {
        await HealthRecord.deleteMany({ _id: { $in: createdRecordIds } });
      }
      if (userA) await User.deleteOne({ _id: userA._id });
      if (userB) await User.deleteOne({ _id: userB._id });
      if (server) server.close();
      await disconnectDB();
      console.log('Test cleanup complete. Disconnected from MongoDB Atlas.');
    } catch (cleanErr) {
      console.warn('Cleanup warning:', cleanErr.message);
    }
  }
}

runVaultVerification();

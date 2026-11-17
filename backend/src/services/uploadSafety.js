const net = require('node:net');
const path = require('node:path');
function failure(message, status = 422) { const error = new Error(message); error.status = status; return error; }
function validateSignature(file) {
  if (!Buffer.isBuffer(file.buffer) || !file.buffer.length || file.buffer.length > 30 * 1024 * 1024) throw failure('File must contain 1 byte–30 MB.');
  const extension = path.extname(file.originalname || '').toLowerCase();
  const b = file.buffer;
  const valid = {
    '.pdf': () => b.subarray(0, 5).toString() === '%PDF-',
    '.png': () => b.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])),
    '.jpg': () => b[0] === 255 && b[1] === 216 && b[2] === 255,
    '.jpeg': () => b[0] === 255 && b[1] === 216 && b[2] === 255,
    '.webp': () => b.subarray(0,4).toString() === 'RIFF' && b.subarray(8,12).toString() === 'WEBP',
    '.gif': () => /^GIF8[79]a$/.test(b.subarray(0,6).toString()),
    '.bmp': () => b.subarray(0,2).toString() === 'BM',
    '.doc': () => b.subarray(0,8).equals(Buffer.from('d0cf11e0a1b11ae1','hex')),
    '.docx': () => b.subarray(0,4).equals(Buffer.from([80,75,3,4])),
    '.txt': () => !b.includes(0), '.csv': () => !b.includes(0),
  };
  if (!valid[extension] || !valid[extension]()) throw failure('File contents do not match a supported file extension.');
}
async function scanBuffer(buffer, options = {}) {
  const host = options.host || process.env.CLAMAV_HOST;
  const required = process.env.NODE_ENV === 'production' || process.env.VAULT_SCAN_REQUIRED === 'true';
  if (!host) {
    if (required) throw failure('File scanner is unavailable. Upload was not stored. Please retry later.', 503);
    return { status: 'unscanned', engine: 'development-only', scannedAt: null };
  }
  if (process.env.NODE_ENV === 'production') await scannerVersion(options);
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port: options.port || Number(process.env.CLAMAV_PORT || 3310) });
    let reply = ''; let settled = false;
    function finish(error, result) { if (settled) return; settled = true; socket.destroy(); if (error) reject(error); else resolve(result); }
    socket.setTimeout(options.timeout || 15000, () => finish(failure('File scanner timed out. Upload was not stored.',503)));
    socket.on('error', () => finish(failure('File scanner is unavailable. Upload was not stored.',503)));
    socket.on('connect', () => {
      socket.write(Buffer.from('zINSTREAM\0'));
      for (let i=0; i<buffer.length; i+=65536) {
        const chunk = buffer.subarray(i,i+65536); const size=Buffer.alloc(4); size.writeUInt32BE(chunk.length); socket.write(size); socket.write(chunk);
      }
      socket.write(Buffer.alloc(4));
    });
    socket.on('data', chunk => {
      reply += chunk.toString('utf8');
      if (reply.length > 4096) return finish(failure('Invalid scanner response.',503));
      if (!reply.includes('\0') && !reply.includes('\n')) return;
      const result=reply.replace(/[\0\r\n]+$/g,'');
      if (result === 'stream: OK') finish(null,{ status:'clean',engine:'clamav',scannedAt:new Date() });
      else if (/ FOUND$/.test(result)) finish(failure('Upload blocked: potentially malicious content detected.'));
      else finish(failure('File could not be scanned. Upload was not stored.',503));
    });
    socket.on('close', () => { if (!settled) finish(failure('Scanner connection closed before a verdict.',503)); });
    socket.on('end', () => { if (!settled) finish(failure('Incomplete scanner response.',503)); });
  });
}
async function inspectUpload(file) { validateSignature(file); return scanBuffer(file.buffer); }
// Refuse scans against stale or unidentifiable signature databases in production.
async function scannerVersion(options = {}) {
  const host = options.host || process.env.CLAMAV_HOST;
  if (!host) throw failure('File scanner is not configured.', 503);
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({host, port: options.port || Number(process.env.CLAMAV_PORT || 3310)});
    let reply = '', settled = false;
    function done(error, value) { if (settled) return; settled = true; socket.destroy(); error ? reject(error) : resolve(value); }
    socket.setTimeout(options.timeout || 5000, () => done(failure('Scanner health check timed out.',503)));
    socket.on('connect', () => socket.write('zVERSION\0'));
    socket.on('error', () => done(failure('Scanner health check unavailable.',503)));
    socket.on('data', data => {
      reply += data.toString('utf8');
      if (reply.length > 4096) return done(failure('Invalid scanner health response.',503));
      if (!/[\0\n]/.test(reply)) return;
      const fields = reply.trim().replace(/\0/g,'').split('/');
      const date = fields.slice(2).join('/');
      const timestamp = Date.parse(date + (/GMT|UTC|[+-]\d{4}/.test(date) ? '' : ' UTC'));
      const maxAgeHours = Number(process.env.CLAMAV_MAX_SIGNATURE_AGE_HOURS || 72);
      if (!fields[0].startsWith('ClamAV ') || !Number.isFinite(timestamp) || !Number.isFinite(maxAgeHours) || maxAgeHours < 1 || maxAgeHours > 168 || Date.now()-timestamp > maxAgeHours*3600000 || timestamp-Date.now() > 3600000) return done(failure('Scanner signatures need updating.',503));
      done(null, {engine:fields[0], signatureVersion:fields[1], signatureUpdatedAt:new Date(timestamp)});
    });
    socket.on('close', () => {if (!settled) done(failure('Incomplete scanner health response.',503));});
  });
}

module.exports = { validateSignature, scanBuffer, inspectUpload, scannerVersion };

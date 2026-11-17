const {test}=require('node:test');const assert=require('node:assert/strict');const net=require('node:net');const {once}=require('node:events');
const {validateSignature,scanBuffer}=require('../src/services/uploadSafety');
test('upload signatures reject renamed executables and malformed types',()=>{
  assert.throws(()=>validateSignature({originalname:'report.pdf',buffer:Buffer.from('MZ executable')}));
  assert.doesNotThrow(()=>validateSignature({originalname:'report.pdf',buffer:Buffer.from('%PDF-1.4\nfixture')}));
});
test('production upload scanning fails closed when no scanner is configured',async()=>{
  const before=process.env.NODE_ENV,host=process.env.CLAMAV_HOST;process.env.NODE_ENV='production';delete process.env.CLAMAV_HOST;
  try{await assert.rejects(scanBuffer(Buffer.from('fixture')),e=>e.status===503);}finally{if(before===undefined)delete process.env.NODE_ENV;else process.env.NODE_ENV=before;if(host)process.env.CLAMAV_HOST=host;}
});
for(const [reply,clean] of [['stream: OK\0',true],['stream: Test.Signature FOUND\0',false],['stream: engine ERROR\0',false]])test('ClamAV protocol handles '+(clean?'clean':reply.includes('FOUND')?'infected':'error')+' verdict',async(t)=>{
  let received=Buffer.alloc(0);const sockets=new Set();
  const server=net.createServer(socket=>{sockets.add(socket);socket.on('close',()=>sockets.delete(socket));socket.on('data',chunk=>{received=Buffer.concat([received,chunk]);if(received.length>=17&&received.subarray(-4).equals(Buffer.alloc(4)))socket.end(reply);});});
  server.listen(0,'127.0.0.1');await once(server,'listening');t.after(async()=>{for(const s of sockets)s.destroy();await new Promise(r=>server.close(r));});
  const task=scanBuffer(Buffer.from('hello'),{host:'127.0.0.1',port:server.address().port,timeout:1000});
  if(clean)assert.equal((await task).status,'clean');else await assert.rejects(task);
  assert.equal(received.subarray(0,10).toString(),'zINSTREAM\0');assert.equal(received.readUInt32BE(10),5);assert.equal(received.subarray(14,19).toString(),'hello');
});

for (const fresh of [true,false]) test('scanner freshness check '+(fresh?'accepts current':'rejects stale')+' signatures',async(t)=>{
  const {scannerVersion}=require('../src/services/uploadSafety');
  const timestamp=new Date(Date.now()-(fresh?3600000:10*86400000)).toUTCString();
  const sockets=new Set();const server=net.createServer(socket=>{sockets.add(socket);socket.on('close',()=>sockets.delete(socket));socket.once('data',data=>{assert.equal(data.toString(),'zVERSION\0');socket.end('ClamAV 1.4.3/12345/'+timestamp+'\0');});});
  server.listen(0,'127.0.0.1');await once(server,'listening');t.after(async()=>{for(const s of sockets)s.destroy();await new Promise(r=>server.close(r));});
  const task=scannerVersion({host:'127.0.0.1',port:server.address().port});
  if(fresh)assert.equal((await task).signatureVersion,'12345');else await assert.rejects(task,e=>e.status===503);
});

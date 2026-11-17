// Encrypted MongoDB (including GridFS) and legacy upload backups. Never restores to Atlas.
const fs=require('node:fs'), fsp=fs.promises, path=require('node:path'), os=require('node:os'), crypto=require('node:crypto');
const {spawn}=require('node:child_process');const {pipeline}=require('node:stream/promises');const net=require('node:net');const {once}=require('node:events');
require('dotenv').config({path:path.join(__dirname,'../.env'),quiet:true});
const {getMongoConfig,buildMongoUri}=require('../config/database');const {MongoClient}=require('mongoose').mongo;
const args=process.argv.slice(2), mode=args.shift();function option(name){const i=args.indexOf(name);return i<0?null:args[i+1];}
let backupStage='initialization';
const magic=Buffer.from('MGBAK001');
async function key() {const filename=option('--key-file');if(!filename)throw Error('Provide --key-file outside the repository.');const k=await fsp.readFile(filename);if(k.length!==32)throw Error('Backup key must be 32 raw random bytes.');if((await fsp.stat(filename)).mode&0o077)throw Error('Backup key must have mode 600.');return k;}
function command(cmd,args,stdio=['ignore','pipe','pipe']) {const child=spawn(cmd,args,{stdio});let toolError='';child.stderr?.on('data',d=>{if(toolError.length<8192)toolError+=d.toString();});const done=new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',code=>code===0?resolve():reject(Object.assign(Error('Backup tool failed.'),{code:'TOOL_EXIT_'+code,safeReason:/TLS|SSL|handshake|connection|server selection|no such host|lookup/i.test(toolError)?'network-or-TLS':/auth|not authorized/i.test(toolError)?'authentication-or-authorization':/config|flag|option|parse|unmarshal/i.test(toolError)?'tool-configuration':'tool-failure'})));});done.catch(()=>{});return {child,done};}
async function encryptCommand(cmd,args,filename,k) {
 const nonce=crypto.randomBytes(12),cipher=crypto.createCipheriv('aes-256-gcm',k,nonce);cipher.setAAD(magic);
 const handle=await fsp.open(filename,'wx',0o600);await handle.write(Buffer.concat([magic,nonce]));await handle.close();
 const {child,done}=command(cmd,args);
 try{await pipeline(child.stdout,cipher,fs.createWriteStream(filename,{flags:'a',mode:0o600}));await done;await fsp.appendFile(filename,cipher.getAuthTag());}catch(e){child.kill();await fsp.rm(filename,{force:true});throw e;}
}
async function decryptTo(filename,k,destination) {
 const stat=await fsp.stat(filename);if(stat.size<36)throw Error('Invalid backup');const h=await fsp.open(filename,'r');const header=Buffer.alloc(20),tag=Buffer.alloc(16);await h.read(header,0,20,0);await h.read(tag,0,16,stat.size-16);await h.close();if(!header.subarray(0,8).equals(magic))throw Error('Unknown backup format');
 const decipher=crypto.createDecipheriv('aes-256-gcm',k,header.subarray(8));decipher.setAAD(magic);decipher.setAuthTag(tag);
 await pipeline(fs.createReadStream(filename,{start:20,end:stat.size-17}),decipher,destination);
}
async function counts(db) {const result={};for(const c of await db.listCollections({}, {nameOnly:true}).toArray())if(!c.name.startsWith('system.'))result[c.name]=await db.collection(c.name).countDocuments();return result;}
async function backup() {
 const k=await key(),directory=option('--out');if(!directory)throw Error('Provide --out outside the repository.');
 const repo=path.resolve(__dirname,'../..');if(path.resolve(directory)===repo||path.resolve(directory).startsWith(repo+path.sep))throw Error('Backups must be outside Git working tree.');await fsp.mkdir(directory,{recursive:true,mode:0o700});
 backupStage='configuration';const config=getMongoConfig(),uri=buildMongoUri(config),stamp=new Date().toISOString().replace(/[:.]/g,'-');
 const prefix=path.join(directory,'medguard-'+stamp),tmp=await fsp.mkdtemp(path.join(os.tmpdir(),'medguard-dump-'));await fsp.chmod(tmp,0o700);
 const client=new MongoClient(uri,{family:4,serverSelectionTimeoutMS:15000});
 try{
  backupStage='atlas-connection';await client.connect();backupStage='collection-counts';const before=await counts(client.db(config.dbName));
  const conf=path.join(tmp,'tools.yml');await fsp.writeFile(conf,'uri: '+JSON.stringify(uri)+'\n',{mode:0o600});
  backupStage='mongodump';await encryptCommand('mongodump',['--config='+conf,'--db='+config.dbName,'--authenticationDatabase=admin','--archive','--gzip'],prefix+'-mongo.mgbackup',k);
  backupStage='legacy-files';await encryptCommand('tar',['-C',path.join(__dirname,'../uploads'),'-czf','-','.'],prefix+'-uploads.mgbackup',k);
  const after=await counts(client.db(config.dbName));
  const hashes={};for(const suffix of ['-mongo.mgbackup','-uploads.mgbackup'])hashes[path.basename(prefix+suffix)]=crypto.createHash('sha256').update(await fsp.readFile(prefix+suffix)).digest('hex');
  const manifest={createdAt:new Date().toISOString(),database:config.dbName,format:'MGBAK001 AES-256-GCM',consistency:'online best-effort; no write freeze or oplog; not certified point-in-time',before,after,hashes};
  await fsp.writeFile(prefix+'-manifest.json',JSON.stringify(manifest,null,2),{mode:0o600});console.log(JSON.stringify({backupPrefix:prefix,status:'encrypted archives created',consistency:manifest.consistency}));
 }finally{await client.close();await fsp.rm(tmp,{recursive:true,force:true});}
}
async function restoreCheck() {
 const k=await key(),filename=option('--archive');if(!filename)throw Error('Provide --archive.');
 if(filename.endsWith('-uploads.mgbackup')) {const {child,done}=command('tar',['-tzf','-'],['pipe','ignore','ignore']);try{await decryptTo(filename,k,child.stdin);await done;console.log('Encrypted legacy upload archive authentication and tar integrity passed.');}catch(e){child.kill();throw e;}return;}
 const manifest=JSON.parse(await fsp.readFile(filename.replace(/-mongo\.mgbackup$/,'-manifest.json'),'utf8'));
 const temp=await fsp.mkdtemp(path.join(os.tmpdir(),'medguard-restore-'));await fsp.chmod(temp,0o700);
 const probe=net.createServer().listen(0,'127.0.0.1');await once(probe,'listening');const port=probe.address().port;await new Promise(r=>probe.close(r));
 const {child:mongo,done:ended}=command('mongod',['--dbpath',temp,'--port',String(port),'--bind_ip','127.0.0.1','--quiet'],['ignore','ignore','ignore']);
 let client;
 try{
  for(let n=0;n<50;n++){try{client=new MongoClient('mongodb://127.0.0.1:'+port,{serverSelectionTimeoutMS:200});await client.connect();break;}catch(e){await client?.close();client=null;await new Promise(r=>setTimeout(r,100));}}
  if(!client)throw Error('Temporary MongoDB could not start.');
  const {child,done}=command('mongorestore',['--uri=mongodb://127.0.0.1:'+port,'--archive','--gzip','--nsFrom='+manifest.database+'.*','--nsTo=medguard_restore_check.*'],['pipe','ignore','ignore']);
  try{await decryptTo(filename,k,child.stdin);await done;}catch(e){child.kill();throw e;}
  const db=client.db('medguard_restore_check'),restored=await counts(db);let filesVerified=0;
  for(const bucket of ['vault_files','avatars'])for await (const file of db.collection(bucket+'.files').find({})){
    let length=0,n=0;for await(const chunk of db.collection(bucket+'.chunks').find({files_id:file._id}).sort({n:1})){if(chunk.n!==n++)throw Error('GridFS chunk gap');length+=chunk.data.value().length;}
    if(length!==file.length||n!==Math.ceil(file.length/file.chunkSize))throw Error('GridFS file length mismatch');filesVerified++;
  }
  const countsMatch=Object.entries(manifest.before).every(([name,count])=>restored[name]===count);
  console.log(JSON.stringify({restoreTarget:'temporary loopback MongoDB only',archiveAuthenticated:true,collectionCount:Object.keys(restored).length,gridFsFilesVerified:filesVerified,countsMatchBefore:countsMatch,pointInTimeCertified:false}));
 }finally{await client?.close();mongo.kill('SIGTERM');await ended.catch(()=>{});await fsp.rm(temp,{recursive:true,force:true});}
}
async function backupFiles() {
 const k=await key(),directory=option('--out');if(!directory)throw Error('Provide --out.');
 const repo=path.resolve(__dirname,'../..');if(path.resolve(directory)===repo||path.resolve(directory).startsWith(repo+path.sep))throw Error('Backup must be outside Git.');await fsp.mkdir(directory,{recursive:true,mode:0o700});
 const filename=path.join(directory,'medguard-'+new Date().toISOString().replace(/[:.]/g,'-')+'-uploads.mgbackup');
 await encryptCommand('tar',['-C',path.join(__dirname,'../uploads'),'-czf','-','.'],filename,k);
 console.log(JSON.stringify({archive:filename,status:'encrypted legacy uploads backup created'}));
}
(mode==='create'?backup():mode==='files-create'?backupFiles():mode==='verify'?restoreCheck():Promise.reject(Error('Use create, files-create or verify.'))).catch(error=>{console.error(JSON.stringify({status:'backup operation failed',stage:backupStage,type:error.name,code:error.code||null,causeCode:error.cause?.code||null,reason:error.safeReason||null}));process.exitCode=1;});

// Read-only configuration and Atlas ping. No credentials or medical records printed.
const path = require('node:path');
require('dotenv').config({path:path.join(__dirname,'../.env'),quiet:true});
const {getMongoConfig,buildMongoUri} = require('../config/database');
const {MongoClient} = require('mongoose').mongo;
async function main() {
  const config = getMongoConfig();
  const result = {checkedAt:new Date().toISOString(), mongoConfiguration:'valid', database:config.dbName, jwtConfigured:!!process.env.JWT_SECRET && process.env.JWT_SECRET.length>=32, scannerConfigured:!!process.env.CLAMAV_HOST, productionMode:process.env.NODE_ENV==='production', corsConfigured:!!process.env.CORS_ORIGINS, backupRetentionConfigured:/^\d+$/.test(process.env.BACKUP_RETENTION_DAYS||'')};
  const client = new MongoClient(buildMongoUri(config),{family:4,serverSelectionTimeoutMS:15000,connectTimeoutMS:15000,appName:'medguard-readonly-verification'});
  try {
    await client.connect(); await client.db(config.dbName).command({ping:1});
    result.mongoPing='passed';
    const names=await client.db(config.dbName).listCollections({}, {nameOnly:true}).toArray();
    result.collectionCount=names.length;
    result.gridFsCollections=names.filter(x=>/^(vault_files|avatars)\.(files|chunks)$/.test(x.name)).map(x=>x.name);
    console.log(JSON.stringify(result,null,2));
  } finally {await client.close();}
}
main().catch(()=>{console.error('Configuration/Atlas verification failed. Check environment, Atlas access list and credentials locally. No secrets logged.');process.exitCode=1;});

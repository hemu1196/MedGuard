const path=require('node:path');require('dotenv').config({path:path.join(__dirname,'../.env'),quiet:true});
const {scanBuffer,scannerVersion}=require('../src/services/uploadSafety');
(async()=>{
  const version=await scannerVersion();
  const clean=await scanBuffer(Buffer.from('MEDGUARD clean scanner health fixture'));
  if(clean.status!=='clean')throw Error('No clean verdict');
  // EICAR standard antivirus test string encoded to avoid accidental source-file detections.
  const fixture=Buffer.from('WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo=','base64');
  let blocked=false;try{await scanBuffer(fixture);}catch(e){blocked=e.status===422;}
  if(!blocked)throw Error('Antivirus fixture not blocked');
  console.log(JSON.stringify({checkedAt:new Date().toISOString(),scanner:version,cleanVerdict:'passed',antivirusTestFixtureBlocked:'passed'}));
})().catch(()=>{console.error('Scanner verification FAILED. Do not enable production uploads until configured and verified.');process.exitCode=1;});

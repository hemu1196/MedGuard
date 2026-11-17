const crypto = require('node:crypto');
const Medicine = require('../models/Medicine');
async function correctDose({userId,medicineId,occurrenceId,expectedStatus,status,reason,operationId}) {
  if(!['taken','skipped','missed'].includes(status)||!['taken','skipped','missed'].includes(expectedStatus)||typeof reason!=='string'||reason.trim().length<3||reason.length>1000||typeof operationId!=='string'||!/^[a-zA-Z0-9_-]{16,100}$/.test(operationId)||typeof occurrenceId!=='string'||!/^[a-f0-9]{64}$/.test(occurrenceId)) return {code:400,message:'Valid status, original status, reason and operation identifier required.'};
  if(status===expectedStatus)return {code:400,message:'Choose a different corrected status.'};
  const medicine=await Medicine.findOne({_id:medicineId,userId});if(!medicine)return {code:404};
  if(medicine.doseCorrections.some(c=>c.operationId===operationId))return {code:200,success:true,duplicate:true};
  const previous=medicine.doseReceipts.find(r=>r.occurrenceId===occurrenceId);
  if(!previous||previous.status!==expectedStatus)return {code:409,message:'Dose changed. Refresh the history before correcting.'};
  const debited=status==='taken'?Math.min(medicine.remainingStock,medicine.dosageQuantity||1):0;
  const refund=previous.status==='taken'?(previous.stockDebited??1):0;
  const delta=refund-debited;
  const correction={operationId,occurrenceId,fromStatus:expectedStatus,toStatus:status,reason:reason.trim(),at:new Date()};
  const update=await Medicine.findOneAndUpdate({_id:medicineId,userId,remainingStock:medicine.remainingStock,doseReceipts:{$elemMatch:{occurrenceId,status:expectedStatus}},'doseCorrections.operationId':{$ne:operationId}},[{$set:{
    remainingStock:{$add:['$remainingStock',delta]},
    doseReceipts:{$map:{input:'$doseReceipts',as:'r',in:{$cond:[{$eq:['$$r.occurrenceId',occurrenceId]},{$mergeObjects:['$$r',{status,stockDebited:debited}]},'$$r']}}},
    doseCorrections:{$concatArrays:[{$ifNull:['$doseCorrections',[]]},[{$literal:correction}]]},
  }}],{new:true});
  if(!update)return {code:409,message:'Dose or stock changed. Refresh and retry.'};
  return {code:200,success:true,remainingStock:update.remainingStock};
}
module.exports={correctDose};

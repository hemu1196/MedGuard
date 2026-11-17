const express = require('express');
const router = express.Router();
const medicineController = require('../controllers/medicineController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.use(authenticateToken);

router.get('/', medicineController.getMedicines);
router.post('/', medicineController.addMedicine);
router.put('/:medicineId', medicineController.updateMedicine);
router.delete('/:medicineId', medicineController.deleteMedicine);
router.post('/log', medicineController.logMedicationAction);
router.get('/logs', medicineController.getMedicationLogs);

router.get('/:medicineId/history', async (req,res,next)=>{try{
  if(!/^[a-f0-9]{24}$/i.test(req.params.medicineId))return res.sendStatus(404);
  const med=await require('../models/Medicine').findOne({_id:req.params.medicineId,userId:req.userId});if(!med)return res.sendStatus(404);
  res.json({success:true,receipts:med.doseReceipts,corrections:med.doseCorrections,remainingStock:med.remainingStock});
}catch(e){next(e);}});
router.post('/:medicineId/corrections',async(req,res,next)=>{try{
  if(!/^[a-f0-9]{24}$/i.test(req.params.medicineId))return res.sendStatus(404);
  const result=await require('../services/doseCorrectionService').correctDose({...req.body,userId:req.userId,medicineId:req.params.medicineId});res.status(result.code).json(result);
}catch(e){next(e);}});
module.exports = router;

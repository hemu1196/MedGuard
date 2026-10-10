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

module.exports = router;

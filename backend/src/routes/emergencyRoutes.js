const express = require('express');
const router = express.Router();
const emergencyController = require('../controllers/emergencyController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.use(authenticateToken);

router.get('/contacts', emergencyController.getEmergencyContacts);
router.post('/contacts', emergencyController.addEmergencyContact);
router.put('/contacts/:contactId', emergencyController.updateEmergencyContact);
router.delete('/contacts/:contactId', emergencyController.deleteEmergencyContact);

router.post('/sos/trigger', emergencyController.triggerSos);
router.get('/sos/history', emergencyController.getSosHistory);

module.exports = router;

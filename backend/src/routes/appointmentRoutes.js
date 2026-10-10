const express = require('express');
const router = express.Router();
const appointmentController = require('../controllers/appointmentController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.use(authenticateToken);

router.get('/', appointmentController.getAppointments);
router.post('/', appointmentController.addAppointment);
router.put('/:appointmentId', appointmentController.updateAppointment);
router.get('/:appointmentId/pdf', appointmentController.downloadAppointmentPdf);
router.delete('/:appointmentId', appointmentController.deleteAppointment);

module.exports = router;

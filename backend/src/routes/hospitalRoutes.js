const express = require('express');
const router = express.Router();
const hospitalController = require('../controllers/hospitalController');

// GET /api/hospitals/nearby - Public discovery endpoint
router.get('/nearby', hospitalController.getNearbyHospitals);

module.exports = router;

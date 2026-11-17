const express = require('express');
const router = express.Router();
const hospitalController = require('../controllers/hospitalController');

// GET /api/hospitals/nearby - Public discovery endpoint
router.use(require('express-rate-limit').rateLimit({windowMs:60000,limit:30,standardHeaders:'draft-8',legacyHeaders:false}));
router.get('/nearby', hospitalController.getNearbyHospitals);

module.exports = router;

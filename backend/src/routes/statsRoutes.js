const express = require('express');
const router = express.Router();
const statsController = require('../controllers/statsController');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.get('/', statsController.getStats); // ?period=month|season|year
router.get('/overall', statsController.getOverallStats);

module.exports = router;

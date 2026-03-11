const express = require("express");
const router = express.Router();
const analyticsController = require("../controllers/analyticsController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/temperature", authMiddleware, analyticsController.getTemperatureAnalytics);
router.get("/inventory", authMiddleware, analyticsController.getInventoryAnalytics);
router.get("/spoilage", authMiddleware, analyticsController.getSpoilageAnalytics);

module.exports = router;

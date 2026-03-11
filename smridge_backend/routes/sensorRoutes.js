const express = require("express");
const router = express.Router();
const sensorController = require("../controllers/sensorController");

// Public route for ESP32 - No authMiddleware
router.post("/data", sensorController.receiveSensorData);

module.exports = router;

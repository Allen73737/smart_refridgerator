const express = require("express");
const router = express.Router();
const sensorController = require("../controllers/sensorController");

// Public route for ESP32
router.post("/data", sensorController.receiveSensorData);

// Route for app to fetch latest device data
router.get("/device/:deviceId", sensorController.getLatestSensorData);

module.exports = router;
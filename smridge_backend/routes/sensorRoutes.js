const express = require("express");
const router = express.Router();
const sensorController = require("../controllers/sensorController");

const auth = require("../middleware/authMiddleware");

// Public route for ESP32
router.post("/data", sensorController.receiveSensorData);

// 🆕 Clean endpoint — no deviceId needed, uses JWT userId internally
// This is the preferred polling route for SensorProvider
router.get("/latest", auth, sensorController.getLatestSensorData);

// Legacy route for app to fetch latest device data (deviceId is ignored; userId from JWT is used)
router.get("/device/:deviceId", auth, sensorController.getLatestSensorData);

module.exports = router;
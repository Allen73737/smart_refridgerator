const express = require("express");
const router = express.Router();
const deviceController = require("../controllers/deviceController");
const auth = require("../middleware/authMiddleware");

// 🟢 Public endpoint for ESP32 to register
router.post("/register", deviceController.registerDevice);

// 🟢 Protected endpoints for App
router.get("/", auth, deviceController.getUserDevices);
router.post("/status", deviceController.updateStatus);

module.exports = router;

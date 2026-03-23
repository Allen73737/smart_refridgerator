const express = require("express");
const router = express.Router();
const activityController = require("../controllers/activityController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/", authMiddleware, activityController.getActivities);
router.post("/log", authMiddleware, activityController.logActivity);
router.get("/stats", authMiddleware, activityController.getActivityStats);

module.exports = router;

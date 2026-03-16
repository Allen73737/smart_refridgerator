const express = require("express");
const router = express.Router();
const notificationController = require("../controllers/notificationController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/", authMiddleware, notificationController.getNotifications);
router.get("/history", authMiddleware, notificationController.getHistory);
router.put("/:id/read", authMiddleware, notificationController.archive);
router.delete("/clear", authMiddleware, notificationController.clearAll);

module.exports = router;

const express = require("express");
const router = express.Router();
const barcodeController = require("../controllers/barcodeController");
const authMiddleware = require("../middleware/authMiddleware");

// Needs auth to align with other routes although public fetch
router.get("/:barcodeNumber", authMiddleware, barcodeController.scanBarcode);

module.exports = router;

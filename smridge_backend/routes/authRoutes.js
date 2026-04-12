const router = require("express").Router();
const { signup, login, googleLogin, forgotPassword, resetPassword, regenerateBackupCodes } = require("../controllers/authController");
const auth = require("../middleware/authMiddleware");

router.post("/signup", signup);
router.post("/login", login);
router.post("/google", googleLogin);

// 🔐 Backup Code Recovery
router.post("/forgot-password", forgotPassword);
router.post("/reset-password", resetPassword);
router.post("/regenerate-codes", auth, regenerateBackupCodes);

module.exports = router;

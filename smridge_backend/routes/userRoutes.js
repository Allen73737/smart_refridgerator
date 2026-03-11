const router = require("express").Router();
const auth = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

const {
  getProfile,
  updateProfile,
  changePassword,
  saveFcmToken,
  uploadProfileImage
} = require("../controllers/userController");

// Profile routes
router.get("/profile", auth, getProfile);
router.put("/profile", auth, updateProfile);
router.put("/profile-image", auth, upload.single("image"), uploadProfileImage);
router.put("/change-password", auth, changePassword);

// 🔔 Save FCM Token
router.post("/save-fcm-token", auth, saveFcmToken);

module.exports = router;

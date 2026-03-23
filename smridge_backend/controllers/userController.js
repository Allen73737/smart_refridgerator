const User = require("../models/User");
const bcrypt = require("bcryptjs");

// 🟢 Get Profile
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("-password");

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// 🟢 Update Profile
exports.updateProfile = async (req, res) => {
  try {
    const { name, email } = req.body;

    const updatedUser = await User.findByIdAndUpdate(
      req.user.id,
      { name, email },
      { new: true }
    ).select("-password");

    res.json(updatedUser);

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// 🟢 Change Password
exports.changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    const user = await User.findById(req.user.id);

    const isMatch = await bcrypt.compare(oldPassword, user.password);

    if (!isMatch) {
      return res.status(400).json({ message: "Old password incorrect" });
    }

    const hashed = await bcrypt.hash(newPassword, 10);
    user.password = hashed;

    await user.save();

    res.json({ message: "Password updated successfully" });

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// 🟢 SAVE FCM TOKEN (FULL IMPLEMENTATION)
exports.saveFcmToken = async (req, res) => {
  try {
    const { token, fcmToken } = req.body;
    const finalToken = token || fcmToken;

    // 1️⃣ Check if token exists in request
    if (!finalToken) {
      return res.status(400).json({ message: "FCM token is required" });
    }

    // 2️⃣ Update user with new token
    const updatedUser = await User.findByIdAndUpdate(
      req.user.id,
      { fcmToken: finalToken },
      { new: true }
    ).select("-password");

    if (!updatedUser) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({
      message: "FCM token saved successfully",
      fcmToken: updatedUser.fcmToken
    });

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// 🟢 Upload Profile Image
exports.uploadProfileImage = async (req, res) => {
  try {
    console.log("--- 👤 Profile Image Upload Request ---");
    console.log("File Status:", req.file ? `Received: ${req.file.originalname}` : "❌ No file in request");
    if (req.file) console.log("Target Cloudinary Path:", req.file.path);

    if (!req.file) {
      return res.status(400).json({ message: "No image provided" });
    }

    let finalImageUrl = req.file.path;
    if (req.file.isLocal) {
      const host = req.get('host');
      const protocol = req.protocol;
      finalImageUrl = `${protocol}://${host}/${req.file.path}`;
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.user.id,
      { profileImage: finalImageUrl },
      { new: true }
    ).select("-password");

    res.json({ message: "Profile image updated", user: updatedUser });

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

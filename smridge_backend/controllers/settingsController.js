const UserSettings = require("../models/UserSettings");

// 🟢 Get User Settings
exports.getUserSettings = async (req, res) => {
  try {
    let settings = await UserSettings.findOne({ userId: req.user.id });
    if (!settings) {
      // Create default settings if not exists
      settings = await UserSettings.create({ userId: req.user.id });
    }
    res.json(settings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// 🟢 Update User Settings
exports.updateUserSettings = async (req, res) => {
  try {
    const settings = await UserSettings.findOneAndUpdate(
      { userId: req.user.id },
      { $set: req.body },
      { new: true, upsert: true }
    );
    res.json(settings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// 🟢 Upload Custom Audio
exports.uploadAudioFile = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "No audio file uploaded" });
    }
    // req.file.path is the Cloudinary URL
    res.json({ url: req.file.path });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

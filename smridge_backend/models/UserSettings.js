const mongoose = require("mongoose");

const userSettingsSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, unique: true },
  
  // Visuals
  fridgeExteriorColor: { type: String, default: "#2B4162" },
  fridgeInteriorColor: { type: String, default: "#FFFFFF" },

  // Sound Indices
  fridgeVibratingSoundIndex: { type: Number, default: 0 },
  fridgeDoorSoundIndex: { type: Number, default: 0 },
  notificationSoundIndex: { type: Number, default: 0 },
  expiryNotificationSoundIndex: { type: Number, default: 0 },
  inventorySaveSoundIndex: { type: Number, default: 0 },

  // Custom Sound URLs (Cloudinary)
  customVibratingSoundUrl: { type: String, default: "" },
  customDoorSoundUrl: { type: String, default: "" },
  customNotificationSoundUrl: { type: String, default: "" },
  customExpiryNotificationSoundUrl: { type: String, default: "" },
  customInventorySaveSoundUrl: { type: String, default: "" },

  // Default sound indices used for "Default" selection
  defaultVibSound: { type: Number, default: 0 },
  defaultDoorSound: { type: Number, default: 0 },
  defaultNotifSound: { type: Number, default: 0 },
  defaultExpirySound: { type: Number, default: 0 },
  defaultSaveSound: { type: Number, default: 0 },

}, { timestamps: true });

module.exports = mongoose.model("UserSettings", userSettingsSchema);

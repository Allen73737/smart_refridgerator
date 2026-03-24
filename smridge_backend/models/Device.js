const mongoose = require("mongoose");

const deviceSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  deviceId: { type: String, unique: true, required: true }, // MAC Address or Unique ID
  name: { type: String, default: "My Smridge" },
  status: { type: String, enum: ['online', 'offline'], default: 'offline' },
  lastSeen: { type: Date, default: Date.now },
  wifiSSID: { type: String, default: "" },
}, { timestamps: true });

module.exports = mongoose.model("Device", deviceSchema);

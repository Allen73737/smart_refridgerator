const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema({
  name:         { type: String, required: true },
  email:        { type: String, unique: true, required: true },
  password:     { type: String, required: function() { return this.authProvider === 'email'; } },
  googleId:     { type: String, default: null },
  avatar:       { type: String, default: "" },
  authProvider: { type: String, enum: ['email', 'google'], default: 'email' },
  profileImage: { type: String, default: "" },
  fcmToken:     { type: String, default: null },
  role:         { type: String, enum: ['user', 'admin'], default: 'user' },
  isBlocked:    { type: Boolean, default: false },
  lastActive:   { type: Date, default: Date.now },
  location:     { type: String, default: "" },
  timezone:     { type: String, default: "UTC" },
  appPin:       { type: String, default: null }, // Hashed PIN
  deviceId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Device', default: null },
  isSimulationEnabled: { type: Boolean, default: false },
}, { timestamps: true });

// Auto-hash password/PIN before saving (SINGLE source of truth)
userSchema.pre('save', async function () {
  if (this.isModified('password') && this.password) {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
  if (this.isModified('appPin') && this.appPin) {
    const salt = await bcrypt.genSalt(10);
    this.appPin = await bcrypt.hash(this.appPin, salt);
  }
});

// Compare plain-text password to hashed DB password
userSchema.methods.matchPassword = async function (enteredPassword) {
  if (!this.password) return false;
  return await bcrypt.compare(enteredPassword, this.password);
};

// Compare plain-text PIN to hashed DB PIN
userSchema.methods.matchPin = async function (enteredPin) {
  if (!this.appPin) return false;
  return await bcrypt.compare(enteredPin, this.appPin);
};

module.exports = mongoose.model("User", userSchema);

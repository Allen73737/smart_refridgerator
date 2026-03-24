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
  deviceId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Device', default: null },
}, { timestamps: true });

// Auto-hash password before saving (SINGLE source of truth — no manual hashing in controllers)
userSchema.pre('save', async function () {
  if (!this.isModified('password')) return;
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Compare plain-text password to hashed DB password
userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model("User", userSchema);

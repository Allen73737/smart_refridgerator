const jwt = require("jsonwebtoken");
const User = require("../models/User");

module.exports = async function (req, res, next) {
  // Allow token to be provided via either header
  const token = req.header("x-auth-token") || req.header("Authorization");

  if (!token) return res.status(401).json({ msg: "No token" });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;

    // 🛡️ Token Version Check: Reject tokens issued before a password reset
    const user = await User.findById(decoded.id).select('tokenVersion lastActive');
    if (!user) return res.status(401).json({ msg: "User not found" });
    
    if (decoded.v !== undefined && user.tokenVersion !== undefined && decoded.v !== user.tokenVersion) {
      return res.status(401).json({ msg: "Session expired. Please login again." });
    }

    // 🕒 Update lastActive (Throttled: 5 mins)
    const now = new Date();
    const fiveMinutes = 5 * 60 * 1000;

    if (!user.lastActive || (now - new Date(user.lastActive)) > fiveMinutes) {
      await User.findByIdAndUpdate(decoded.id, { $set: { lastActive: now } }, { timestamps: false });
    }

    console.log(`🔐 Authenticated User: ${req.user.id}`);
    next();
  } catch (err) {
    res.status(401).json({ msg: "Invalid token" });
  }
};

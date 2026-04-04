const jwt = require("jsonwebtoken");
const User = require("../models/User");

module.exports = async function (req, res, next) {
  // Allow token to be provided via either header
  const token = req.header("x-auth-token") || req.header("Authorization");

  if (!token) return res.status(401).json({ msg: "No token" });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;

    // 🕒 Update lastActive (Throttled: 5 mins)
    const now = new Date();
    const fiveMinutes = 5 * 60 * 1000;

    // Using findOneAndUpdate to optimize (only update if lastActive is > 5 mins old or null)
    await User.findOneAndUpdate(
      { 
        _id: decoded.id, 
        $or: [
          { lastActive: { $lt: new Date(now - fiveMinutes) } },
          { lastActive: { $exists: false } },
          { lastActive: null }
        ]
      },
      { $set: { lastActive: now } },
      { timestamps: false } // Avoid triggering updatedAt for just activity tracking
    );

    console.log(`🔐 Authenticated User: ${req.user.id}`);
    next();
  } catch (err) {
    res.status(401).json({ msg: "Invalid token" });
  }
};

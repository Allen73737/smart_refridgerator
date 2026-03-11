const jwt = require("jsonwebtoken");

module.exports = function (req, res, next) {
  // Allow token to be provided via either header
  const token = req.header("x-auth-token") || req.header("Authorization");

  if (!token) return res.status(401).json({ msg: "No token" });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ msg: "Invalid token" });
  }
};

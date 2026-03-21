const User = require("../models/User");
const jwt = require("jsonwebtoken");
const { OAuth2Client } = require("google-auth-library");
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const logActivity = require("../utils/activityLogger");

exports.signup = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ msg: "User already exists" });

    const user = await User.create({ name, email, password, authProvider: 'email' });

    await logActivity(user._id, 'REGISTER', 'user', `New user registered: ${user.email}`);

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "30d" });
    res.status(201).json({ token, user: { _id: user._id, name: user.name, email: user.email, role: user.role } });
  } catch (error) {
    console.error("Signup Error:", error.message);
    res.status(500).json({ msg: "Registration failed", error: error.message });
  }
};

exports.login = async (req, res) => {
  try {
    let { email, password } = req.body;
    if (email) email = email.trim();
    console.log(`--- [DEBUG] Login Attempt: "${email}" ---`);

    const user = await User.findOne({ email });
    if (!user) {
      console.log(`--- [DEBUG] Login Failed: User not found for ${email} ---`);
      return res.status(400).json({ msg: "Invalid credentials" });
    }
    
    console.log(`--- [DEBUG] User Found: ${user.email}, AuthProvider: ${user.authProvider}, Blocked: ${user.isBlocked} ---`);

    if (user.authProvider !== 'email') {
      console.log(`--- [DEBUG] Login Failed: authProvider is ${user.authProvider}, expected 'email' ---`);
      return res.status(400).json({ msg: "Invalid credentials" });
    }

    const isMatch = await user.matchPassword(password);
    console.log(`--- [DEBUG] Password Match Result: ${isMatch} ---`);
    
    if (!isMatch) {
      console.log(`--- [DEBUG] Login Failed: Password mismatch for ${email} ---`);
      return res.status(400).json({ msg: "Invalid credentials" });
    }

    if (user.isBlocked) {
      console.log(`--- [DEBUG] Login Failed: User ${email} is blocked ---`);
      return res.status(403).json({ msg: "Account is blocked. Contact admin." });
    }

    user.lastActive = Date.now();
    await user.save({ validateBeforeSave: false });

    await logActivity(user._id, 'LOGIN', user.role, `User logged in via email: ${user.email}`);

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "30d" });
    console.log(`--- [DEBUG] Login Successful for ${email} ---`);
    res.json({ token, user: { _id: user._id, name: user.name, email: user.email, role: user.role } });
  } catch (error) {
    console.error("--- [DEBUG] Login Error Exception: ---", error.message);
    res.status(500).json({ msg: "Login failed", error: error.message });
  }
};

exports.googleLogin = async (req, res) => {
  try {
    const { idToken } = req.body;
    const ticket = await client.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const { sub: googleId, email, name, picture: avatar } = payload;

    let user = await User.findOne({ email });

    if (user) {
      if (user.authProvider !== 'google') {
        user.googleId = googleId;
        user.authProvider = 'google';
        user.avatar = avatar;
        await user.save({ validateBeforeSave: false });
      }
    } else {
      user = await User.create({
        name,
        email,
        googleId,
        avatar,
        authProvider: 'google',
        password: Math.random().toString(36).slice(-10), // Dummy password for schema
      });
    }

    if (user.isBlocked) {
      return res.status(403).json({ msg: "Account is blocked." });
    }

    user.lastActive = Date.now();
    await user.save({ validateBeforeSave: false });

    await logActivity(user._id, 'LOGIN', user.role, `User logged in via Google: ${user.email}`);

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "30d" });
    res.json({ token, user: { _id: user._id, name: user.name, email: user.email, role: user.role, avatar: user.avatar } });
  } catch (error) {
    console.error("Google Auth Error:", error.message);
    res.status(400).json({ msg: "Google authentication failed" });
  }
};

/**
 * @file authController.js
 * @description Handles all user authentication flows for Smridge.
 *
 * Supported auth methods:
 *   1. Email/Password (bcrypt hashed, JWT issued on success)
 *   2. Google OAuth 2.0 (ID Token verified via Google Auth Library)
 *
 * All successful logins result in a 30-day JWT token that the Flutter
 * app stores securely and sends in the "x-auth-token" header for every
 * subsequent protected API call.
 */

const User = require("../models/User");
const jwt = require("jsonwebtoken");
const { OAuth2Client } = require("google-auth-library");
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const logActivity = require("../utils/activityLogger");

// ─── EMAIL / PASSWORD AUTH ─────────────────────────────────────────────────────

/**
 * @function signup
 * @route POST /api/auth/signup
 * @description Registers a new user with email and password.
 * - Checks for duplicate email in the database.
 * - Creates the user (password is auto-hashed by the User model's pre-save hook).
 * - Issues a 30-day JWT token to immediately log the user in after registration.
 * - Logs the registration event to the activity log.
 */
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

/**
 * @function login
 * @route POST /api/auth/login
 * @description Authenticates an existing email/password user.
 * - Validates the email exists in DB and the authProvider is 'email'.
 * - Uses `matchPassword` (bcrypt compare) to verify the password hash.
 * - Checks if the user account has been blocked by an admin.
 * - Updates `lastActive` timestamp and issues a fresh JWT.
 */
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

// ─── GOOGLE OAUTH ──────────────────────────────────────────────────────────────

/**
 * @function googleLogin
 * @route POST /api/auth/google
 * @description Authenticates a user via Google Sign-In.
 * - Receives a Google `idToken` from the Flutter Google Sign-In package.
 * - Verifies the token against Google's servers using the OAuth2Client.
 * - If the email already exists in DB (previously email user), migrates them to Google auth.
 * - If the email is new, creates a new user record with a random dummy password (not used).
 * - Checks if the account is blocked, then issues a JWT.
 */
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

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
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const logActivity = require("../utils/activityLogger");

// ─── BACKUP CODE HELPERS ──────────────────────────────────────────────────────

/**
 * Generates N random backup codes in XXXX-XXXX format.
 * Returns { plain: [...], hashed: [...] }
 */
async function generateBackupCodes(count = 10) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // No I/O/0/1 to avoid confusion
  const plain = [];
  const hashed = [];

  for (let i = 0; i < count; i++) {
    let code = "";
    for (let j = 0; j < 8; j++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
      if (j === 3) code += "-"; // Format: XXXX-XXXX
    }
    plain.push(code);
    const salt = await bcrypt.genSalt(10);
    hashed.push(await bcrypt.hash(code, salt));
  }
  return { plain, hashed };
}

// ─── EMAIL / PASSWORD AUTH ─────────────────────────────────────────────────────

/**
 * @function signup
 * @route POST /api/auth/signup
 * @description Registers a new user with email and password.
 * - Creates the user and generates 10 single-use backup codes.
 * - Returns plain backup codes ONE TIME for the user to save.
 */
exports.signup = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    // 🛡️ Password Strength Enforcement
    if (!password || password.length < 8) {
      return res.status(400).json({ msg: "Password must be at least 8 characters" });
    }
    if (!/[A-Z]/.test(password)) {
      return res.status(400).json({ msg: "Password must contain at least one uppercase letter" });
    }
    if (!/[0-9]/.test(password)) {
      return res.status(400).json({ msg: "Password must contain at least one number" });
    }
    if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
      return res.status(400).json({ msg: "Password must contain at least one special character" });
    }

    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ msg: "User already exists" });

    const user = await User.create({ name, email, password, authProvider: 'email' });

    // 🔐 Generate backup codes
    const { plain, hashed } = await generateBackupCodes(10);
    user.backupCodes = hashed;
    user.backupCodesUsed = 0;
    await user.save({ validateBeforeSave: false });

    await logActivity(user._id, 'REGISTER', 'user', `New user registered: ${user.email}`);

    const token = jwt.sign({ id: user._id, v: user.tokenVersion || 0 }, process.env.JWT_SECRET, { expiresIn: "7d" });
    res.status(201).json({
      token,
      user: { _id: user._id, name: user.name, email: user.email, role: user.role },
      backupCodes: plain,
    });
  } catch (error) {
    console.error("Signup Error:", error.message);
    res.status(500).json({ msg: "Registration failed", error: error.message });
  }
};

/**
 * @function login
 * @route POST /api/auth/login
 * @description Authenticates an existing email/password user.
 * - Rate-limited: 5 failed attempts triggers 15-minute lockout.
 * - Issues a 7-day JWT with tokenVersion for session invalidation.
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

    // 🛡️ Login lockout check
    if (user.loginLockUntil && new Date() < new Date(user.loginLockUntil)) {
      const minutesLeft = Math.ceil((new Date(user.loginLockUntil) - new Date()) / 60000);
      console.log(`--- [DEBUG] Login Locked for ${email}: ${minutesLeft}m remaining ---`);
      return res.status(429).json({ msg: `Account temporarily locked. Try again in ${minutesLeft} minutes.` });
    }

    if (user.authProvider !== 'email') {
      console.log(`--- [DEBUG] Login Failed: authProvider is ${user.authProvider}, expected 'email' ---`);
      return res.status(400).json({ msg: "Invalid credentials" });
    }

    const isMatch = await user.matchPassword(password);
    console.log(`--- [DEBUG] Password Match Result: ${isMatch} ---`);
    
    if (!isMatch) {
      // 🛡️ Increment failed login counter
      user.failedLoginAttempts = (user.failedLoginAttempts || 0) + 1;
      console.log(`--- [DEBUG] Login Failed: Password mismatch for ${email} (attempt ${user.failedLoginAttempts}) ---`);
      if (user.failedLoginAttempts >= 5) {
        user.loginLockUntil = new Date(Date.now() + 15 * 60 * 1000); // Lock 15 minutes
        user.failedLoginAttempts = 0;
        console.log(`--- [DEBUG] Login LOCKED for ${email} for 15 minutes ---`);
      }
      await user.save({ validateBeforeSave: false });
      return res.status(400).json({ msg: "Invalid credentials" });
    }

    if (user.isBlocked) {
      console.log(`--- [DEBUG] Login Failed: User ${email} is blocked ---`);
      return res.status(403).json({ msg: "Account is blocked. Contact admin." });
    }

    // ✅ Login successful — reset counters
    user.lastActive = Date.now();
    user.failedLoginAttempts = 0;
    user.loginLockUntil = null;
    await user.save({ validateBeforeSave: false });

    await logActivity(user._id, 'LOGIN', user.role, `User logged in via email: ${user.email}`);

    const token = jwt.sign({ id: user._id, v: user.tokenVersion || 0 }, process.env.JWT_SECRET, { expiresIn: "7d" });
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

// ─── BACKUP CODE RECOVERY ─────────────────────────────────────────────────────

/**
 * @function forgotPassword
 * @route POST /api/auth/forgot-password
 * @description Step 1: Verify the user exists and has remaining backup codes.
 */
exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ msg: "Email is required" });

    const user = await User.findOne({ email: email.trim().toLowerCase() });
    if (!user) return res.status(404).json({ msg: "No account found with this email" });

    if (user.authProvider !== 'email') {
      return res.status(400).json({ msg: "This account uses Google Sign-In. Password recovery is not available." });
    }

    const remaining = 10 - (user.backupCodesUsed || 0);
    if (remaining <= 0) {
      return res.status(403).json({ msg: "All backup codes have been used. Account recovery is no longer possible." });
    }

    if (!user.backupCodes || user.backupCodes.length === 0) {
      return res.status(403).json({ msg: "No backup codes found. Please contact support or regenerate from Settings if logged in." });
    }

    res.json({ found: true, remaining });
  } catch (error) {
    console.error("Forgot Password Error:", error.message);
    res.status(500).json({ msg: "Failed to verify account", error: error.message });
  }
};

/**
 * @function resetPassword
 * @route POST /api/auth/reset-password
 * @description Step 2+3: Verify backup code and reset password.
 * Rate-limited: Max 5 failed attempts per hour.
 */
exports.resetPassword = async (req, res) => {
  try {
    const { email, backupCode, newPassword } = req.body;
    if (!email || !backupCode || !newPassword) {
      return res.status(400).json({ msg: "Email, backup code, and new password are all required" });
    }

    const user = await User.findOne({ email: email.trim().toLowerCase() });
    if (!user) return res.status(404).json({ msg: "No account found with this email" });

    // 🛡️ Rate limiting
    if (user.failedRecoveryLockUntil && new Date() < new Date(user.failedRecoveryLockUntil)) {
      const minutesLeft = Math.ceil((new Date(user.failedRecoveryLockUntil) - new Date()) / 60000);
      return res.status(429).json({ msg: `Too many failed attempts. Try again in ${minutesLeft} minutes.` });
    }

    if (!user.backupCodes || user.backupCodes.length === 0) {
      return res.status(403).json({ msg: "No backup codes available for this account." });
    }

    // 🔐 Compare submitted code against each hashed code
    let matchIndex = -1;
    const normalizedCode = backupCode.trim().toUpperCase();
    for (let i = 0; i < user.backupCodes.length; i++) {
      const isMatch = await bcrypt.compare(normalizedCode, user.backupCodes[i]);
      if (isMatch) {
        matchIndex = i;
        break;
      }
    }

    if (matchIndex === -1) {
      // Increment failure counter
      user.failedRecoveryAttempts = (user.failedRecoveryAttempts || 0) + 1;
      if (user.failedRecoveryAttempts >= 5) {
        user.failedRecoveryLockUntil = new Date(Date.now() + 60 * 60 * 1000); // Lock 1 hour
        user.failedRecoveryAttempts = 0;
      }
      await user.save({ validateBeforeSave: false });
      return res.status(401).json({ msg: "Invalid backup code" });
    }

    // ✅ Code matched — consume it
    user.backupCodes.splice(matchIndex, 1);
    user.backupCodesUsed = (user.backupCodesUsed || 0) + 1;
    user.failedRecoveryAttempts = 0;
    user.failedRecoveryLockUntil = null;

    // Reset password (pre-save hook will hash it)
    user.password = newPassword;
    // 🛡️ Increment tokenVersion to invalidate ALL existing sessions
    user.tokenVersion = (user.tokenVersion || 0) + 1;
    await user.save();

    const remaining = 10 - user.backupCodesUsed;
    console.log(`🔐 Password reset via backup code for: ${email} (${remaining} codes remaining)`);

    await logActivity(user._id, 'PASSWORD_RESET', 'user', `Password reset via backup code. ${remaining} codes remaining.`);

    res.json({ msg: "Password has been reset successfully", remaining });
  } catch (error) {
    console.error("Reset Password Error:", error.message);
    res.status(500).json({ msg: "Failed to reset password", error: error.message });
  }
};

/**
 * @function regenerateBackupCodes
 * @route POST /api/auth/regenerate-codes
 * @description Generates 10 new backup codes. Requires authentication.
 * Old codes are invalidated immediately.
 */
exports.regenerateBackupCodes = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ msg: "User not found" });

    const { plain, hashed } = await generateBackupCodes(10);
    user.backupCodes = hashed;
    user.backupCodesUsed = 0;
    user.failedRecoveryAttempts = 0;
    user.failedRecoveryLockUntil = null;
    await user.save({ validateBeforeSave: false });

    console.log(`🔐 Backup codes regenerated for: ${user.email}`);
    await logActivity(user._id, 'REGENERATE_CODES', 'user', `Backup codes regenerated for: ${user.email}`);

    res.json({ backupCodes: plain, msg: "New backup codes generated. Old codes are now invalid." });
  } catch (error) {
    console.error("Regenerate Codes Error:", error.message);
    res.status(500).json({ msg: "Failed to regenerate backup codes", error: error.message });
  }
};

const admin = require("firebase-admin");
let serviceAccount;

try {
  // 🔹 Try loading from file (Local Development)
  serviceAccount = require("../firebase/serviceAccountKey.json");
} catch (e) {
  // 🔹 Fallback: Load from Environment Variable (Production/Render)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } catch (parseError) {
      console.error("❌ Firebase: Failed to parse FIREBASE_SERVICE_ACCOUNT env var as JSON");
    }
  } else {
    console.warn("⚠️ Firebase: No service account file or environment variable found");
  }
}

if (serviceAccount) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

module.exports = admin;

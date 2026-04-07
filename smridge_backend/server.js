/**
 * @file server.js
 * @description The main entry point for the Smridge backend server.
 * Responsibilities:
 *   1. Loads environment variables from .env
 *   2. Configures Express middleware (CORS, JSON parsing, compression)
 *   3. Connects to the MongoDB database
 *   4. Attaches real-time Socket.io to the HTTP server
 *   5. Mounts all API route groups
 *   6. Registers the global error handler
 *   7. Starts listening for incoming requests on a configured port
 */

require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const http = require("http");
const socketManager = require("./utils/socketManager");
const sensorService = require("./utils/sensorService");
const { calculateOverallFreshness } = require("./utils/freshnessUtils");

const compression = require("compression");
const app = express();

// ─── MIDDLEWARE STACK ────────────────────────────────────────────────────────

// Compress all HTTP responses (gzip) to reduce payload size and improve speed
app.use(compression());

/**
 * CORS Policy: Allows the Flutter mobile app (from any IP) to communicate
 * with this server. In dev, origin is "*" for flexibility with changing device IPs.
 * Allows standard REST verbs and our custom auth header ("x-auth-token").
 */
app.use(cors({
  origin: "*",
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "x-auth-token", "Authorization"],
  exposedHeaders: ["Access-Control-Allow-Private-Network"]
}));

/**
 * Request Logger Middleware
 * Logs every incoming request with timestamp, HTTP method, and URL.
 * Useful for debugging and monitoring traffic in production.
 */
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

/**
 * Chrome Private Network Access Header
 * Required for local ESP32 devices accessed from a web-based dashboard.
 * This header explicitly permits connections from private networks.
 */
app.use((req, res, next) => {
  if (req.headers['access-control-request-private-network']) {
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
  }
  next();
});

// Allow the server to read JSON payloads from request bodies (e.g., item data, sensor pings)
app.use(express.json());

// ─── SERVER & WEBSOCKET SETUP ─────────────────────────────────────────────────

/**
 * We wrap Express in a raw Node.js HTTP server so that Socket.io can be
 * attached to the same port. Both REST requests and WebSocket connections
 * are handled on one unified port (default: 5001).
 */
const server = http.createServer(app);
socketManager.init(server);

// ─── DATABASE CONNECTION ──────────────────────────────────────────────────────

/**
 * Connects to MongoDB using the URI from the .env file.
 * Only AFTER the DB is ready, we load the expiry cron job so it can
 * immediately start querying the Inventory collection.
 */
mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    console.log("MongoDB Connected");
    require("./cron/expiryCron"); // Load cron after DB is ready
  })
  .catch(err => console.error("MongoDB Connection Error:", err));

// ─── API ROUTES ───────────────────────────────────────────────────────────────

// Each route file is loaded lazily here. The string prefix defines the URL path.
app.use("/api/auth", require("./routes/authRoutes"));          // User login & registration
app.use("/api/items", require("./routes/itemRoutes"));          // Fridge inventory CRUD
app.use("/api/user", require("./routes/userRoutes"));           // Profile & account management
app.use("/api/analytics", require("./routes/analyticsRoutes")); // Historical data for charts
app.use("/api/notifications", require("./routes/notificationRoutes")); // Push & in-app alerts
const activityRoutes = require("./routes/activityRoutes");
app.use("/api/activities", activityRoutes);                     // Audit log of user actions
app.use("/api/sensors", require("./routes/sensorRoutes"));      // ESP32 sensor data endpoint
app.use("/api/settings", require("./routes/settingsRoutes"));   // User & admin configuration
app.use("/api/device", require("./routes/deviceRoutes"));       // Physical device pairing
app.use("/api/ai", require("./routes/aiRoutes"));               // Groq LLM AI endpoints
app.use("/api/barcode", require("./routes/barcodeRoutes"));     // OpenFoodFacts barcode scanner
app.use("/uploads", express.static("uploads"));                 // Serve locally stored images

/**
 * Health Check Endpoint
 * Used by deployment platforms (e.g., Render, Railway) to verify the server is alive.
 * Returns a plain 200 "OK" response with no authentication requirements.
 */
app.get("/health", (req, res) => {
  res.status(200).send("OK - Server is responsive");
});

// ─── GLOBAL ERROR HANDLER ─────────────────────────────────────────────────────

/**
 * Catches any errors that escape individual route handlers.
 * Ensures the client always receives a structured JSON error response
 * instead of an empty timeout or an HTML crash page.
 */
app.use((err, req, res, next) => {
  if (err) {
    console.error("--- ❌ Global Error Handler ---");
    console.error(err.message);
    return res.status(500).json({ message: "Internal Error", error: err.message });
  }
  next();
});

// ─── START LISTENING ──────────────────────────────────────────────────────────

const PORT = process.env.PORT || 5001;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT} (reach me at ${process.env.IP_OVERRIDE || '0.0.0.0'})`);
  
  console.log(`Server running on port ${PORT} (reach me at ${process.env.IP_OVERRIDE || '0.0.0.0'})`);
});

// ─── PROCESS SAFETY GUARDS ────────────────────────────────────────────────────

/** Catches unhandled Promise rejections so the server doesn't silently fail. */
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
});

/** Catches synchronous exceptions and forces a clean exit with a log. */
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  process.exit(1);
});

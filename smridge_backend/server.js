require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const http = require("http");
const socketManager = require("./utils/socketManager");
const sensorService = require("./utils/sensorService");
const { getSensorScore } = require("./utils/freshnessUtils");

const compression = require("compression");
const app = express();

app.use(compression());

app.use(cors({
  origin: "*",
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "x-auth-token", "Authorization"],
  exposedHeaders: ["Access-Control-Allow-Private-Network"]
}));

// Request Logger
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Middleware for Chrome Private Network Access
app.use((req, res, next) => {
  if (req.headers['access-control-request-private-network']) {
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
  }
  next();
});

app.use(express.json());

const server = http.createServer(app);
socketManager.init(server);

// 🔹 MongoDB Connection
mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    console.log("MongoDB Connected");
    require("./cron/expiryCron"); // Load cron after DB is ready
  })
  .catch(err => console.error("MongoDB Connection Error:", err));

app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/items", require("./routes/itemRoutes"));
app.use("/api/user", require("./routes/userRoutes"));
app.use("/api/analytics", require("./routes/analyticsRoutes"));
app.use("/api/notifications", require("./routes/notificationRoutes"));
const activityRoutes = require("./routes/activityRoutes");
app.use("/api/activities", activityRoutes);
app.use("/api/sensors", require("./routes/sensorRoutes"));
app.use("/api/settings", require("./routes/settingsRoutes"));
app.use("/api/device", require("./routes/deviceRoutes"));
app.use("/api/ai", require("./routes/aiRoutes"));
app.use("/uploads", express.static("uploads"));

app.get("/health", (req, res) => {
  res.status(200).send("OK - Server is responsive");
});

// Global Error Handler
app.use((err, req, res, next) => {
  if (err) {
    console.error("--- ❌ Global Error Handler ---");
    console.error(err.message);
    return res.status(500).json({ message: "Internal Error", error: err.message });
  }
  next();
});

const PORT = process.env.PORT || 5001;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT} (reach me at ${process.env.IP_OVERRIDE || '0.0.0.0'})`);
  
  console.log(`Server running on port ${PORT} (reach me at ${process.env.IP_OVERRIDE || '0.0.0.0'})`);
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  process.exit(1);
});

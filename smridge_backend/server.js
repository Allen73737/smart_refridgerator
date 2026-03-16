require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config();
require("./cron/expiryCron");

const app = express();

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
const http = require("http");
const socketManager = require("./utils/socketManager");

app.use(express.json());

const server = http.createServer(app);
socketManager.init(server);

mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB Connected"))
  .catch(err => console.log(err));

app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/items", require("./routes/itemRoutes"));
app.use("/api/user", require("./routes/userRoutes"));
app.use("/api/analytics", require("./routes/analyticsRoutes"));
app.use("/api/notifications", require("./routes/notificationRoutes"));
app.use("/api/sensors", require("./routes/sensorRoutes"));
app.use("/api/settings", require("./routes/settingsRoutes"));
app.use("/api/ai", require("./routes/aiRoutes"));
app.use("/uploads", express.static("uploads"));

// Global Error Handler for Multer/Cloudinary
app.use((err, req, res, next) => {
  if (err) {
    console.error("--- ❌ Global Error Handler Caught Error ---");
    console.error("Name:", err.name);
    console.error("Message:", err.message);
    console.error("Stack:", err.stack);
    return res.status(500).json({ 
      message: "Sync Error", 
      error: err.message,
      name: err.name 
    });
  }
  next();
});

server.listen(process.env.PORT, () =>
  console.log(`Server running on port ${process.env.PORT} (with Socket.io support)`)
);

const { Server } = require("socket.io");
const { calculateOverallFreshness } = require("./freshnessUtils");
const User = require("../models/User");
const Threshold = require("../models/Threshold");
const simulationUtils = require("./simulationUtils");

let io;

// Store active intervals and per-user data state
const userIntervals = new Map();
const userRealData = new Map(); // 🔑 userId -> { data, timestamp }
const userSimPaths = new Map(); // 🔑 socketId -> { queue: [], current: {}, lastUpdate: 0 }

module.exports = {
  init: (httpServer) => {
    io = new Server(httpServer, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      },
      pingTimeout: 60000,
      pingInterval: 10000
    });

    io.on("connection", (socket) => {
      console.log(`⚡ Socket connected: ${socket.id}`);

      socket.on("register", (userId) => {
        if (userId) {
          userId = String(userId);
          socket.userId = userId;
          socket.join(`user_${userId}`);
          console.log(`🔑 Socket ${socket.id} registered to room user_${userId}`);
        }
      });

      const startSyncLoop = () => {
        if (userIntervals.has(socket.id)) return;

        const interval = setInterval(async () => {
          const userId = socket.userId;
          if (!userId) return;

          try {
            const sensorService = require('./sensorService');
            // Fetch the last known real data directly from memory or DB
            const latestState = await sensorService.getCurrentSensors(userId);
            
            // Just show the last updated data as requested, ensure it gets pushed to UI
            socket.emit("sensor_data", latestState);
          } catch (err) {
            console.error("Socket emit loop error:", err);
          }
        }, 5000); // 5 sec interval is enough to keep UI in sync

        userIntervals.set(socket.id, interval);
      };

      startSyncLoop();

      socket.on("disconnect", () => {
        console.log(`🔌 Socket disconnected: ${socket.id}`);
        const interval = userIntervals.get(socket.id);
        if (interval) {
          clearInterval(interval);
          userIntervals.delete(socket.id);
        }
      });
    });

    return io;
  },
  getIO: () => {
    if (!io) {
      throw new Error("Socket.io not initialized!");
    }
    return io;
  },
  emitToUser: (userId, event, data) => {
    userId = String(userId);
    if (io) {
      if (event === "sensor_data" && data.isReal) {
        userRealData.set(userId, { data, timestamp: Date.now() });
      }
      io.to(`user_${userId}`).emit(event, data);
    }
  },
  emitEvent: (event, data) => {
    if (io) {
      io.emit(event, data);
    }
  }
};

const { Server } = require("socket.io");

let io;
const { getSensorScore } = require("./freshnessUtils");

// Store active intervals and per-user data state
const userIntervals = new Map();
const userRealData = new Map(); // 🔑 userId -> { data, timestamp }

module.exports = {
  init: (httpServer) => {
    io = new Server(httpServer, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      },
      pingTimeout: 60000,
      pingInterval: 25000
    });

    io.on("connection", (socket) => {
      console.log(`⚡ Socket connected: ${socket.id}`);

      // 🔑 Let client join their personal room for targeted emissions
      socket.on("register", (userId) => {
        if (userId) {
          socket.userId = userId; // 📌 Attach userId to socket for easy lookup
          socket.join(`user_${userId}`);
          console.log(`🔑 Socket ${socket.id} registered to room user_${userId}`);
        }
      });

      // Start per-user simulation if no real data recently
      const startSimulation = () => {
        if (userIntervals.has(socket.id)) return;

        const interval = setInterval(() => {
          const now = Date.now();
          const userId = socket.userId;
          const realSession = userId ? userRealData.get(userId) : null;
          const isRealRecent = realSession && (now - realSession.timestamp) < 10000;

          if (isRealRecent && realSession.data) {
            socket.emit("sensor_data", { ...realSession.data, isReal: true });
          } else {
            // Generate unique simulated data per user
            const seed = socket.id.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
            const driftT = (Math.sin(now / 5000 + seed) * 0.5);
            const driftH = (Math.cos(now / 7000 + seed) * 2.0);

            const simulatedData = {
              temperature: (4.0 + driftT).toFixed(1),
              humidity: (60 + driftH).toFixed(1),
              gasLevel: Math.round(200 + Math.sin(now / 10000 + seed) * 50),
              doorStatus: "closed",
              isReal: false,
              timestamp: now
            };

            const score = getSensorScore(simulatedData);
            const freshness = Math.round((score.total / 60) * 100);

            socket.emit("sensor_data", {
              ...simulatedData,
              calculatedFreshness: freshness,
              status: freshness > 60 ? "Fresh" : (freshness > 30 ? "Caution" : "Spoiled")
            });
          }
        }, 1000);

        userIntervals.set(socket.id, interval);
      };

      startSimulation();

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
  // Helper to emit to a specific user's room and update their real-time state
  emitToUser: (userId, event, data) => {
    if (io) {
      if (event === "sensor_data" && data.isReal) {
        userRealData.set(userId, { data, timestamp: Date.now() });
      }
      io.to(`user_${userId}`).emit(event, data);
    }
  },
  // Legacy broadcast (Use sparingly in multi-user environment)
  emitEvent: (event, data) => {
    if (io) {
      io.emit(event, data);
    }
  }
};

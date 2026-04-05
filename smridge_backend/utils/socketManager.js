const { Server } = require("socket.io");
const { getSensorScore } = require("./freshnessUtils");
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
      pingInterval: 25000
    });

    io.on("connection", (socket) => {
      console.log(`⚡ Socket connected: ${socket.id}`);

      socket.on("register", (userId) => {
        if (userId) {
          socket.userId = userId;
          socket.join(`user_${userId}`);
          console.log(`🔑 Socket ${socket.id} registered to room user_${userId}`);
        }
      });

      const startSimulation = () => {
        if (userIntervals.has(socket.id)) return;

        const interval = setInterval(async () => {
          const now = Date.now();
          const userId = socket.userId;
          if (!userId) return;

          const realSession = userRealData.get(userId);
          const isRealRecent = realSession && (now - realSession.timestamp) < 10000;

          if (isRealRecent && realSession.data) {
            socket.emit("sensor_data", { ...realSession.data, isReal: true });
          } else {
            try {
              // 🛡️ ADMIN PANEL CHECK: Global Simulation Toggle
              const adminConfig = await Threshold.findOne().sort({ createdAt: -1 }).lean();
              const isGlobalEnabled = adminConfig?.isSimulationEnabled ?? false;

              if (isGlobalEnabled) {
                let simState = userSimPaths.get(socket.id);
                if (!simState) {
                  simState = { queue: [], current: null, lastUpdate: 0 };
                  userSimPaths.set(socket.id, simState);
                }

                // 🔄 10-SECOND FLUCTUATION LOGIC
                if (!simState.current || (now - simState.lastUpdate >= 10000)) {
                  // Advance to next point or refill queue
                  if (simState.queue.length === 0) {
                    const baseData = realSession?.data || { temperature: 4.0, humidity: 60, gasLevel: 200 };
                    simState.queue = await simulationUtils.generateAIPath(baseData);
                  }
                  
                  if (simState.queue.length > 0) {
                    simState.current = simState.queue.shift();
                    simState.lastUpdate = now;
                  }
                }

                if (simState.current) {
                  const score = getSensorScore(simState.current);
                  const freshness = Math.round((score.total / 60) * 100);

                  socket.emit("sensor_data", {
                    ...simState.current,
                    calculatedFreshness: freshness,
                    freshnessScore: freshness,
                    status: freshness > 60 ? "Fresh" : (freshness > 30 ? "Caution" : "Spoiled"),
                    isReal: false,
                    timestamp: now
                  });
                }
              }
            } catch (err) {
              console.error("Simulation Logic Error:", err);
            }
          }
        }, 1000); // 1s pulse for connection stability

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
        userSimPaths.delete(socket.id);
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

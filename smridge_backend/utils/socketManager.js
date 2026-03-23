const { Server } = require("socket.io");

let io;

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

      socket.on("disconnect", () => {
        console.log(`🔌 Socket disconnected: ${socket.id}`);
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
  // Helper to emit events easily
  emitEvent: (event, data) => {
    if (io) {
      io.emit(event, data);
      console.log(`📢 Emitted event: ${event}`, data);
    }
  }
};

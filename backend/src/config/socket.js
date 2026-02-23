const { Server } = require('socket.io');
const logger = require('../utils/logger');
const env = require('./env');
const { initSocketHandlers } = require('../services/socketHandler');

let io = null;

const initSocket = (httpServer) => {
  io = new Server(httpServer, {
    cors: {
      origin: env.corsOrigin,
      methods: ['GET', 'POST'],
    },
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Register all socket event handlers
  initSocketHandlers(io);

  logger.info('Socket.io initialized with handlers');
  return io;
};

const getIO = () => {
  if (!io) {
    throw new Error('Socket.io not initialized');
  }
  return io;
};

module.exports = { initSocket, getIO };

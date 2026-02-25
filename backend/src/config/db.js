const mongoose = require('mongoose');
const logger = require('../utils/logger');
const env = require('./env');

const connectDB = async () => {
  try {
    await mongoose.connect(env.mongodbUri, {
      maxPoolSize: 50,          // Max concurrent connections (default: 100, reduce to save memory)
      minPoolSize: 5,           // Keep 5 connections warm
      socketTimeoutMS: 45000,   // Close sockets after 45s of inactivity
      serverSelectionTimeoutMS: 10000, // Fail fast if DB is down
      heartbeatFrequencyMS: 10000,     // Check connection health every 10s
    });
    logger.info('MongoDB connected successfully');
  } catch (error) {
    logger.error('MongoDB connection error:', error.message);
    process.exit(1);
  }

  mongoose.connection.on('error', (err) => {
    logger.error('MongoDB error:', err.message);
  });

  mongoose.connection.on('disconnected', () => {
    logger.warn('MongoDB disconnected');
  });
};

module.exports = connectDB;

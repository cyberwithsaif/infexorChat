const jwt = require('jsonwebtoken');
const env = require('../config/env');

/**
 * Generate access token for a user
 */
function generateAccessToken(userId) {
  return jwt.sign({ userId }, env.jwt.secret, {
    expiresIn: env.jwt.expiresIn,
  });
}

/**
 * Generate refresh token for a user
 */
function generateRefreshToken(userId) {
  return jwt.sign({ userId }, env.jwt.refreshSecret, {
    expiresIn: env.jwt.refreshExpiresIn,
  });
}

/**
 * Verify refresh token
 */
function verifyRefreshToken(token) {
  return jwt.verify(token, env.jwt.refreshSecret);
}

/**
 * Generate admin access token
 */
function generateAdminToken(adminId, role) {
  return jwt.sign({ adminId, role }, env.adminJwt.secret, {
    expiresIn: env.adminJwt.expiresIn,
  });
}

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
  generateAdminToken,
};

const crypto = require('crypto');
const { User, Device } = require('../models');
const otpService = require('../services/otpService');
const tokenService = require('../services/tokenService');
const ApiResponse = require('../utils/apiResponse');
const logger = require('../utils/logger');

/**
 * POST /auth/send-otp
 * Send OTP to phone number via MSG91
 */
exports.sendOtp = async (req, res, next) => {
  try {
    const { phone, countryCode } = req.body;
    // Format phone: remove + if present, ensure country code
    // MSG91 expects number with country code without +
    let fullPhone = `${countryCode}${phone}`.replace(/\+/g, '').replace(/\s/g, '');

    // Check if user is banned
    const existingUser = await User.findOne({ phone: fullPhone });
    if (existingUser && existingUser.status === 'banned') {
      return ApiResponse.forbidden(res, 'This account has been banned');
    }
    if (existingUser && existingUser.status === 'suspended') {
      return ApiResponse.forbidden(res, 'This account has been suspended');
    }

    // Send OTP via MSG91
    const result = await otpService.sendOtp(fullPhone);

    if (!result.success) {
      return ApiResponse.badRequest(res, result.message);
    }

    const isNewUser = !existingUser;

    // Return reqId to client for verification
    return ApiResponse.success(res, {
      reqId: result.reqId,
      isNewUser,
      message: result.message
    }, 'OTP sent successfully');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /auth/verify-otp
 * Verify OTP using MSG91 reqId and login/register user
 */
exports.verifyOtp = async (req, res, next) => {
  try {
    const { phone, countryCode, otp, reqId, deviceId, platform, fcmToken } = req.body;
    let fullPhone = `${countryCode}${phone}`.replace(/\+/g, '').replace(/\s/g, '');

    if (!reqId) {
      return ApiResponse.badRequest(res, 'Request ID (reqId) is required');
    }

    // Verify OTP via MSG91
    const verifyResult = await otpService.verifyOtp(reqId, otp);

    if (!verifyResult.success) {
      return ApiResponse.badRequest(res, verifyResult.message || 'Invalid OTP');
    }

    // Find or create user
    let user = await User.findOne({ phone: fullPhone });
    let isNewUser = false;

    if (!user) {
      isNewUser = true;
      const phoneHash = crypto.createHash('sha256').update(fullPhone).digest('hex');
      user = await User.create({
        phone: fullPhone,
        phoneHash,
      });
    }

    // Generate tokens
    const accessToken = tokenService.generateAccessToken(user._id);
    const refreshToken = tokenService.generateRefreshToken(user._id);

    // Register device
    await Device.findOneAndUpdate(
      { userId: user._id, deviceId: deviceId || 'default' },
      {
        userId: user._id,
        deviceId: deviceId || 'default',
        platform: platform || 'android',
        fcmToken: fcmToken || '',
        refreshToken,
        lastActive: new Date(),
        isActive: true,
      },
      { upsert: true, new: true }
    );

    // Update FCM token on user
    if (fcmToken) {
      await User.findByIdAndUpdate(user._id, {
        fcmToken: fcmToken,
      });
    }

    logger.info(`User authenticated via MSG91: ${fullPhone} (new: ${isNewUser})`);

    return ApiResponse.success(res, {
      accessToken,
      refreshToken,
      isNewUser,
      isProfileComplete: user.isProfileComplete,
      user: {
        _id: user._id,
        phone: user.phone,
        name: user.name,
        about: user.about,
        avatar: user.avatar,
        isProfileComplete: user.isProfileComplete,
      },
    }, 'Login successful');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /auth/refresh-token
 * Refresh access token
 */
exports.refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return ApiResponse.badRequest(res, 'Refresh token required');
    }

    // Verify refresh token
    let decoded;
    try {
      decoded = tokenService.verifyRefreshToken(refreshToken);
    } catch {
      return ApiResponse.unauthorized(res, 'Invalid refresh token');
    }

    // Check if device still has this refresh token
    const device = await Device.findOne({
      userId: decoded.userId,
      refreshToken,
      isActive: true,
    });

    if (!device) {
      return ApiResponse.unauthorized(res, 'Session expired, please login again');
    }

    // Generate new tokens
    const newAccessToken = tokenService.generateAccessToken(decoded.userId);
    const newRefreshToken = tokenService.generateRefreshToken(decoded.userId);

    // Update device refresh token
    device.refreshToken = newRefreshToken;
    device.lastActive = new Date();
    await device.save();

    return ApiResponse.success(res, {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    }, 'Token refreshed');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /auth/logout
 * Logout current device
 */
exports.logout = async (req, res, next) => {
  try {
    const { deviceId } = req.body;
    const userId = req.user.userId;

    await Device.findOneAndUpdate(
      { userId, deviceId: deviceId || 'default' },
      { isActive: false, refreshToken: '', fcmToken: '' }
    );

    return ApiResponse.success(res, null, 'Logged out successfully');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /auth/logout-all
 * Logout from all devices
 */
exports.logoutAll = async (req, res, next) => {
  try {
    const userId = req.user.userId;

    await Device.updateMany(
      { userId },
      { isActive: false, refreshToken: '', fcmToken: '' }
    );

    // Also clear push tokens
    await User.findByIdAndUpdate(userId, { fcmToken: '' });

    return ApiResponse.success(res, null, 'Logged out from all devices');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /auth/retry-otp
 * Retry OTP via MSG91
 */
exports.retryOtp = async (req, res, next) => {
  try {
    const { reqId, retryChannel } = req.body;

    if (!reqId) {
      return ApiResponse.badRequest(res, 'Request ID is required');
    }

    const result = await otpService.retryOtp(reqId, retryChannel);

    if (result.success) {
      return ApiResponse.success(res, null, result.message);
    } else {
      return ApiResponse.badRequest(res, result.message);
    }
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /auth/fcm-token
 * Update FCM token for the device
 */
exports.updateFcmToken = async (req, res, next) => {
  try {
    const { fcmToken, deviceId } = req.body;
    const userId = req.user.userId;

    if (!fcmToken) {
      return ApiResponse.badRequest(res, 'FCM token is required');
    }

    // Update in device
    await Device.findOneAndUpdate(
      { userId, deviceId: deviceId || 'default' },
      { fcmToken }
    );

    // Update in user (single token per user)
    await User.findByIdAndUpdate(userId, { fcmToken });

    return ApiResponse.success(res, null, 'FCM token updated successfully');
  } catch (error) {
    next(error);
  }
};

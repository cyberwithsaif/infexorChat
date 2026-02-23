const { Admin } = require('../models');
const tokenService = require('../services/tokenService');
const ApiResponse = require('../utils/apiResponse');
const logger = require('../utils/logger');

/**
 * POST /admin/auth/login
 */
exports.login = async (req, res, next) => {
  try {
    const { username, password } = req.body;

    const admin = await Admin.findOne({ username, isActive: true });
    if (!admin) {
      return ApiResponse.unauthorized(res, 'Invalid credentials');
    }

    const isMatch = await admin.comparePassword(password);
    if (!isMatch) {
      return ApiResponse.unauthorized(res, 'Invalid credentials');
    }

    const token = tokenService.generateAdminToken(admin._id, admin.role);

    admin.lastLogin = new Date();
    await admin.save();

    logger.info(`Admin login: ${username}`);

    return ApiResponse.success(res, {
      token,
      admin: {
        _id: admin._id,
        username: admin.username,
        name: admin.name,
        role: admin.role,
        permissions: admin.permissions,
      },
    }, 'Login successful');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /admin/auth/create-first
 * One-time setup: create the first superadmin (only if no admins exist)
 */
exports.createFirst = async (req, res, next) => {
  try {
    const count = await Admin.countDocuments();
    if (count > 0) {
      return ApiResponse.forbidden(res, 'Admin already exists. Use admin panel to create more.');
    }

    const { username, password, name } = req.body;

    const admin = await Admin.create({
      username,
      password,
      name: name || 'Super Admin',
      role: 'superadmin',
      permissions: {
        users: true,
        reports: true,
        broadcasts: true,
        monitoring: true,
      },
    });

    logger.info(`First admin created: ${username}`);

    return ApiResponse.created(res, {
      admin: {
        _id: admin._id,
        username: admin.username,
        role: admin.role,
      },
    }, 'Super admin created');
  } catch (error) {
    next(error);
  }
};

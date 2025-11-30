const jwt = require('jsonwebtoken');
const { query } = require('../config/database');
const logger = require('../config/logger');

const JWT_SECRET = process.env.JWT_SECRET || 'society360-admin-secret-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '15m';
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

/**
 * Generate JWT access token
 */
const generateAccessToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
};

/**
 * Generate JWT refresh token
 */
const generateRefreshToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });
};

/**
 * Verify JWT token
 */
const verifyToken = (token) => {
  return jwt.verify(token, JWT_SECRET);
};

/**
 * Middleware to verify admin JWT token
 */
const verifyAdminToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: No token provided',
      });
    }

    const token = authHeader.split('Bearer ')[1];

    // Verify JWT
    const decoded = verifyToken(token);

    // Check if admin user exists and is active
    const adminResult = await query(
      `SELECT au.*, u.name, u.phone, u.avatar_url
       FROM admin_users au
       JOIN users u ON au.user_id = u.id
       WHERE au.id = $1 AND au.is_active = true`,
      [decoded.adminUserId]
    );

    if (adminResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Admin user not found or inactive',
      });
    }

    const adminUser = adminResult.rows[0];

    // Check if account is locked
    if (adminUser.locked_until && new Date(adminUser.locked_until) > new Date()) {
      return res.status(403).json({
        success: false,
        error: 'Account temporarily locked. Try again later.',
      });
    }

    // Fetch roles
    const rolesResult = await query(
      `SELECT role, scope_type, scope_id
       FROM role_assignments
       WHERE user_id = $1 AND revoked = false`,
      [adminUser.user_id]
    );

    // Attach admin user and roles to request
    req.adminUser = {
      id: adminUser.id,
      userId: adminUser.user_id,
      email: adminUser.email,
      name: adminUser.name,
      phone: adminUser.phone,
      avatarUrl: adminUser.avatar_url,
    };
    req.userRoles = rolesResult.rows;
    req.user = { id: adminUser.user_id }; // For compatibility with existing middleware

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Token expired',
        code: 'TOKEN_EXPIRED',
      });
    }

    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: 'Invalid token',
      });
    }

    logger.error('Admin token verification failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
};

/**
 * Middleware to check if admin has specific role(s)
 */
const requireAdminRole = (requiredRoles) => {
  return (req, res, next) => {
    const userRoles = req.userRoles || [];
    const hasRole = userRoles.some(r => requiredRoles.includes(r.role));

    if (!hasRole) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: Insufficient permissions',
      });
    }

    next();
  };
};

/**
 * Middleware to check if admin has access to specific society
 */
const requireSocietyAccess = async (req, res, next) => {
  try {
    const societyId = req.params.societyId || req.body.society_id || req.query.society_id;
    const userRoles = req.userRoles || [];

    // Super admin has access to all societies
    if (userRoles.some(r => r.role === 'super_admin')) {
      return next();
    }

    // Check if user has role scoped to this society
    const hasSocietyAccess = userRoles.some(r =>
      r.scope_type === 'society' && r.scope_id === societyId
    );

    if (!hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: No access to this society',
      });
    }

    next();
  } catch (error) {
    logger.error('Society access check failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
  verifyAdminToken,
  requireAdminRole,
  requireSocietyAccess,
  JWT_SECRET,
  JWT_EXPIRES_IN,
  JWT_REFRESH_EXPIRES_IN,
};

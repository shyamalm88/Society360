const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { query } = require('../config/database');
const logger = require('../config/logger');
const {
  generateAccessToken,
  generateRefreshToken,
  verifyToken,
  verifyAdminToken,
  requireAdminRole,
} = require('../middleware/adminAuth');

const router = express.Router();

/**
 * POST /admin/auth/login
 * Admin login with email/password
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required',
      });
    }

    // Find admin user
    const adminResult = await query(
      `SELECT au.*, u.id as user_id, u.name, u.phone, u.avatar_url
       FROM admin_users au
       JOIN users u ON au.user_id = u.id
       WHERE au.email = $1`,
      [email.toLowerCase()]
    );

    if (adminResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password',
      });
    }

    const adminUser = adminResult.rows[0];

    // Check if account is locked
    if (adminUser.locked_until && new Date(adminUser.locked_until) > new Date()) {
      const remainingMinutes = Math.ceil((new Date(adminUser.locked_until) - new Date()) / 60000);
      return res.status(403).json({
        success: false,
        error: `Account locked. Try again in ${remainingMinutes} minutes.`,
      });
    }

    // Check if account is active
    if (!adminUser.is_active) {
      return res.status(403).json({
        success: false,
        error: 'Account is deactivated. Contact administrator.',
      });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, adminUser.password_hash);

    if (!isValidPassword) {
      // Increment failed login attempts
      const newAttempts = (adminUser.failed_login_attempts || 0) + 1;
      let lockUntil = null;

      // Lock account after 5 failed attempts for 30 minutes
      if (newAttempts >= 5) {
        lockUntil = new Date(Date.now() + 30 * 60 * 1000);
      }

      await query(
        `UPDATE admin_users SET failed_login_attempts = $1, locked_until = $2 WHERE id = $3`,
        [newAttempts, lockUntil, adminUser.id]
      );

      return res.status(401).json({
        success: false,
        error: 'Invalid email or password',
        attemptsRemaining: Math.max(0, 5 - newAttempts),
      });
    }

    // Reset failed login attempts
    await query(
      `UPDATE admin_users SET failed_login_attempts = 0, locked_until = NULL, last_login_at = NOW() WHERE id = $1`,
      [adminUser.id]
    );

    // Fetch roles
    const rolesResult = await query(
      `SELECT role, scope_type, scope_id
       FROM role_assignments
       WHERE user_id = $1 AND revoked = false`,
      [adminUser.user_id]
    );

    // Generate tokens
    const tokenPayload = {
      adminUserId: adminUser.id,
      userId: adminUser.user_id,
      email: adminUser.email,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken({ ...tokenPayload, type: 'refresh' });

    // Store refresh token hash
    const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    await query(
      `INSERT INTO admin_sessions (admin_user_id, refresh_token_hash, device_info, ip_address, user_agent, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        adminUser.id,
        refreshTokenHash,
        JSON.stringify({ platform: req.headers['sec-ch-ua-platform'] }),
        req.ip,
        req.headers['user-agent'],
        expiresAt,
      ]
    );

    // Determine default route based on role
    const roles = rolesResult.rows.map(r => r.role);
    let defaultRoute = '/gate-logs';
    if (roles.includes('super_admin')) {
      defaultRoute = '/saas-dashboard';
    } else if (roles.includes('society_admin')) {
      defaultRoute = '/society-dashboard';
    }

    // Fetch societies for the user
    let societies = [];
    const societyRoles = rolesResult.rows.filter(r => r.scope_type === 'society');

    if (roles.includes('super_admin')) {
      // Super admin gets all societies
      const allSocietiesResult = await query(
        `SELECT id, name, slug, city, logo_url FROM societies ORDER BY name`
      );
      societies = allSocietiesResult.rows;
    } else if (societyRoles.length > 0) {
      // Society admin gets their assigned societies
      const societyIds = societyRoles.map(r => r.scope_id);
      const societiesResult = await query(
        `SELECT id, name, slug, city, logo_url FROM societies WHERE id = ANY($1)`,
        [societyIds]
      );
      societies = societiesResult.rows;
    }

    // Log successful login
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [adminUser.user_id, 'admin_login', 'admin_user', adminUser.id, JSON.stringify({ ip: req.ip })]
    );

    logger.info(`Admin login successful: ${adminUser.email}`);

    res.json({
      success: true,
      data: {
        accessToken,
        refreshToken,
        user: {
          id: adminUser.id,
          userId: adminUser.user_id,
          email: adminUser.email,
          name: adminUser.name,
          phone: adminUser.phone,
          avatarUrl: adminUser.avatar_url,
          roles: rolesResult.rows,
          defaultRoute,
        },
        societies,
      },
    });
  } catch (error) {
    logger.error('Admin login error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /admin/auth/refresh
 * Refresh access token using refresh token
 */
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: 'Refresh token is required',
      });
    }

    // Verify refresh token
    let decoded;
    try {
      decoded = verifyToken(refreshToken);
    } catch (error) {
      return res.status(401).json({
        success: false,
        error: 'Invalid or expired refresh token',
      });
    }

    if (decoded.type !== 'refresh') {
      return res.status(401).json({
        success: false,
        error: 'Invalid token type',
      });
    }

    // Check if refresh token exists in database and is not revoked
    const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const sessionResult = await query(
      `SELECT * FROM admin_sessions
       WHERE refresh_token_hash = $1 AND revoked = false AND expires_at > NOW()`,
      [refreshTokenHash]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Session expired or revoked',
      });
    }

    // Fetch admin user
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
        error: 'Admin user not found or inactive',
      });
    }

    const adminUser = adminResult.rows[0];

    // Generate new access token
    const tokenPayload = {
      adminUserId: adminUser.id,
      userId: adminUser.user_id,
      email: adminUser.email,
    };

    const newAccessToken = generateAccessToken(tokenPayload);

    res.json({
      success: true,
      data: {
        accessToken: newAccessToken,
      },
    });
  } catch (error) {
    logger.error('Token refresh error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /admin/auth/logout
 * Logout and revoke refresh token
 */
router.post('/logout', verifyAdminToken, async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
      await query(
        `UPDATE admin_sessions SET revoked = true, revoked_at = NOW() WHERE refresh_token_hash = $1`,
        [refreshTokenHash]
      );
    }

    // Log logout
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'admin_logout', 'admin_user', req.adminUser.id, JSON.stringify({ ip: req.ip })]
    );

    res.json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    logger.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /admin/auth/me
 * Get current admin user profile
 */
router.get('/me', verifyAdminToken, async (req, res) => {
  try {
    const adminUser = req.adminUser;
    const roles = req.userRoles;

    // Get society info if society_admin
    let societies = [];
    const societyRoles = roles.filter(r => r.scope_type === 'society');

    if (societyRoles.length > 0) {
      const societyIds = societyRoles.map(r => r.scope_id);
      const societiesResult = await query(
        `SELECT id, name, slug, city, logo_url FROM societies WHERE id = ANY($1)`,
        [societyIds]
      );
      societies = societiesResult.rows;
    }

    // Super admin gets all societies
    if (roles.some(r => r.role === 'super_admin')) {
      const allSocietiesResult = await query(
        `SELECT id, name, slug, city, logo_url FROM societies ORDER BY name`
      );
      societies = allSocietiesResult.rows;
    }

    res.json({
      success: true,
      data: {
        user: {
          id: adminUser.id,
          userId: adminUser.userId,
          email: adminUser.email,
          name: adminUser.name,
          phone: adminUser.phone,
          avatarUrl: adminUser.avatarUrl,
        },
        roles,
        societies,
      },
    });
  } catch (error) {
    logger.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /admin/auth/register
 * Register new admin user (Super Admin only)
 */
router.post('/register', verifyAdminToken, requireAdminRole(['super_admin']), async (req, res) => {
  try {
    const { email, password, name, phone, role, societyId } = req.body;

    if (!email || !password || !name || !role) {
      return res.status(400).json({
        success: false,
        error: 'Email, password, name, and role are required',
      });
    }

    // Validate role
    const validRoles = ['super_admin', 'society_admin', 'guard'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid role. Must be one of: ' + validRoles.join(', '),
      });
    }

    // Society admin and guard require societyId
    if ((role === 'society_admin' || role === 'guard') && !societyId) {
      return res.status(400).json({
        success: false,
        error: 'Society ID is required for society_admin and guard roles',
      });
    }

    // Check if email already exists
    const existingResult = await query(
      `SELECT id FROM admin_users WHERE email = $1`,
      [email.toLowerCase()]
    );

    if (existingResult.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Email already registered',
      });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);

    // Create user first
    const userResult = await query(
      `INSERT INTO users (phone, name, email, created_at, updated_at)
       VALUES ($1, $2, $3, NOW(), NOW())
       RETURNING id`,
      [phone || null, name, email.toLowerCase()]
    );
    const userId = userResult.rows[0].id;

    // Create admin user
    const adminResult = await query(
      `INSERT INTO admin_users (user_id, email, password_hash, email_verified)
       VALUES ($1, $2, $3, true)
       RETURNING id`,
      [userId, email.toLowerCase(), passwordHash]
    );
    const adminUserId = adminResult.rows[0].id;

    // Assign role
    const scopeType = role === 'super_admin' ? null : 'society';
    const scopeId = role === 'super_admin' ? null : societyId;

    await query(
      `INSERT INTO role_assignments (user_id, role, scope_type, scope_id, granted_by)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, role, scopeType, scopeId, req.adminUser.userId]
    );

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        req.adminUser.userId,
        'admin_user_created',
        'admin_user',
        adminUserId,
        JSON.stringify({ email, role, societyId }),
      ]
    );

    logger.info(`New admin user created: ${email} with role ${role}`);

    res.status(201).json({
      success: true,
      data: {
        id: adminUserId,
        userId,
        email: email.toLowerCase(),
        name,
        role,
        societyId,
      },
    });
  } catch (error) {
    logger.error('Admin registration error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /admin/auth/change-password
 * Change admin password
 */
router.post('/change-password', verifyAdminToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'Current password and new password are required',
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        error: 'New password must be at least 8 characters',
      });
    }

    // Get current password hash
    const adminResult = await query(
      `SELECT password_hash FROM admin_users WHERE id = $1`,
      [req.adminUser.id]
    );

    const isValidPassword = await bcrypt.compare(currentPassword, adminResult.rows[0].password_hash);

    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        error: 'Current password is incorrect',
      });
    }

    // Update password
    const newPasswordHash = await bcrypt.hash(newPassword, 12);
    await query(
      `UPDATE admin_users SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
      [newPasswordHash, req.adminUser.id]
    );

    // Revoke all existing sessions
    await query(
      `UPDATE admin_sessions SET revoked = true, revoked_at = NOW() WHERE admin_user_id = $1`,
      [req.adminUser.id]
    );

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'password_changed', 'admin_user', req.adminUser.id, JSON.stringify({ ip: req.ip })]
    );

    res.json({
      success: true,
      message: 'Password changed successfully. Please login again.',
    });
  } catch (error) {
    logger.error('Change password error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /admin/auth/exchange-token
 * Exchange Firebase ID token for Admin JWT tokens
 * Used by mobile apps to access admin portal in WebView
 */
router.post('/exchange-token', async (req, res) => {
  try {
    const { firebase_id_token } = req.body;

    if (!firebase_id_token) {
      return res.status(400).json({
        success: false,
        error: 'Firebase ID token is required',
      });
    }

    // Verify Firebase token
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(firebase_id_token);
    } catch (firebaseError) {
      logger.error('Firebase token verification failed:', firebaseError);
      return res.status(401).json({
        success: false,
        error: 'Invalid Firebase token',
      });
    }

    const firebaseUid = decodedToken.uid;

    // Find user by Firebase UID
    const userResult = await query(
      `SELECT id, phone, name, email FROM users WHERE firebase_uid = $1 AND is_deleted = false`,
      [firebaseUid]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
      });
    }

    const user = userResult.rows[0];

    // Check if user is an admin
    const adminCheck = await query(
      `SELECT au.id as admin_user_id, au.email, au.is_active
       FROM admin_users au
       WHERE au.user_id = $1`,
      [user.id]
    );

    if (adminCheck.rows.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'User does not have admin privileges',
      });
    }

    const adminUser = adminCheck.rows[0];

    if (!adminUser.is_active) {
      return res.status(403).json({
        success: false,
        error: 'Admin account is deactivated',
      });
    }

    // Get admin roles
    const rolesResult = await query(
      `SELECT role, scope_type, scope_id
       FROM role_assignments
       WHERE user_id = $1 AND revoked = false
         AND role IN ('super_admin', 'society_admin', 'block_admin', 'guard')`,
      [user.id]
    );

    if (rolesResult.rows.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'No admin roles assigned',
      });
    }

    // Generate JWT tokens
    const tokenPayload = {
      adminUserId: adminUser.admin_user_id,
      userId: user.id,
      email: adminUser.email,
      source: 'firebase_exchange', // Track that this came from token exchange
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken({ ...tokenPayload, type: 'refresh' });

    // Store refresh token hash
    const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    await query(
      `INSERT INTO admin_sessions (admin_user_id, refresh_token_hash, device_info, ip_address, user_agent, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        adminUser.admin_user_id,
        refreshTokenHash,
        JSON.stringify({ platform: 'mobile_webview', source: 'firebase_exchange' }),
        req.ip,
        req.headers['user-agent'],
        expiresAt,
      ]
    );

    // Determine default route
    const roles = rolesResult.rows.map(r => r.role);
    let defaultRoute = '/gate-logs';
    if (roles.includes('super_admin')) {
      defaultRoute = '/saas-dashboard';
    } else if (roles.includes('society_admin')) {
      defaultRoute = '/society-dashboard';
    }

    // Log the token exchange
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [user.id, 'admin_token_exchange', 'admin_user', adminUser.admin_user_id, JSON.stringify({ ip: req.ip, source: 'mobile_app' })]
    );

    logger.info(`Token exchange successful for user: ${user.phone} -> admin: ${adminUser.email}`);

    res.json({
      success: true,
      data: {
        accessToken,
        refreshToken,
        user: {
          id: adminUser.admin_user_id,
          userId: user.id,
          email: adminUser.email,
          name: user.name,
          phone: user.phone,
          roles: rolesResult.rows,
          defaultRoute,
        },
      },
    });
  } catch (error) {
    logger.error('Token exchange error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

module.exports = router;

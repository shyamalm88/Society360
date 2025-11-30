const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { verifyFirebaseToken } = require('../middleware/auth');
const logger = require('../config/logger');

/**
 * GET /profile/me
 * Get current user profile with all associated data
 */
router.get('/me', verifyFirebaseToken, async (req, res) => {
  try {
    const userId = req.user.id;

    // Get user roles
    const rolesResult = await query(
      `SELECT role, scope_type, scope_id
       FROM role_assignments
       WHERE user_id = $1 AND revoked = false`,
      [userId]
    );

    // Get flat information (if resident)
    const flatResult = await query(
      `SELECT
        fo.id as occupancy_id, fo.role as occupancy_role, fo.is_primary, fo.start_date,
        f.id as flat_id, f.flat_number, f.unit_type, f.bhk,
        b.id as block_id, b.name as block_name,
        c.id as complex_id, c.name as complex_name,
        s.id as society_id, s.name as society_name, s.city, s.address
       FROM flat_occupancies fo
       JOIN flats f ON fo.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       JOIN societies s ON c.society_id = s.id
       WHERE fo.user_id = $1 AND fo.end_date IS NULL
       ORDER BY fo.is_primary DESC
       LIMIT 1`,
      [userId]
    );

    // Get guard information (if guard)
    const guardResult = await query(
      `SELECT
        g.id as guard_id, g.active,
        s.id as society_id, s.name as society_name, s.city,
        ga.block_id, b.name as assigned_block_name
       FROM guards g
       LEFT JOIN societies s ON g.society_id = s.id
       LEFT JOIN guard_assignments ga ON g.id = ga.guard_id AND ga.released_at IS NULL
       LEFT JOIN blocks b ON ga.block_id = b.id
       WHERE g.user_id = $1 AND g.active = true`,
      [userId]
    );

    // Get recent notifications (last 10)
    const notificationsResult = await query(
      `SELECT id, channel, payload, status, created_at, delivered_at
       FROM notification_logs
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 10`,
      [userId]
    );

    // Check if user is also an admin (admin portal access)
    let adminInfo = null;
    const adminCheck = await query(
      `SELECT au.id as admin_user_id, au.email as admin_email, au.is_active
       FROM admin_users au
       WHERE au.user_id = $1 AND au.is_active = true`,
      [userId]
    );

    if (adminCheck.rows.length > 0) {
      // User is an admin - get their admin roles
      const adminRolesResult = await query(
        `SELECT ra.role, ra.scope_type, ra.scope_id, s.name as society_name, s.id as society_id
         FROM role_assignments ra
         LEFT JOIN societies s ON ra.scope_type = 'society' AND ra.scope_id = s.id
         WHERE ra.user_id = $1 AND ra.revoked = false
           AND ra.role IN ('super_admin', 'society_admin', 'block_admin')`,
        [userId]
      );

      // Determine admin type and default route
      const adminRoles = adminRolesResult.rows;
      let adminType = null;
      let defaultAdminRoute = null;

      if (adminRoles.some(r => r.role === 'super_admin')) {
        adminType = 'super_admin';
        defaultAdminRoute = '/saas-dashboard';
      } else if (adminRoles.some(r => r.role === 'society_admin')) {
        adminType = 'society_admin';
        defaultAdminRoute = '/society-dashboard';
      } else if (adminRoles.some(r => r.role === 'block_admin')) {
        adminType = 'block_admin';
        defaultAdminRoute = '/society-dashboard';
      }

      // Get societies this admin has access to
      const adminSocieties = adminRoles
        .filter(r => r.society_id)
        .map(r => ({ id: r.society_id, name: r.society_name }));

      adminInfo = {
        is_admin: true,
        admin_user_id: adminCheck.rows[0].admin_user_id,
        admin_email: adminCheck.rows[0].admin_email,
        admin_type: adminType,
        admin_roles: adminRoles,
        admin_societies: adminSocieties,
        default_admin_route: defaultAdminRoute,
        admin_portal_url: process.env.ADMIN_PORTAL_URL || 'http://localhost:5173',
      };
    }

    res.json({
      success: true,
      data: {
        user: {
          id: req.user.id,
          firebase_uid: req.user.firebase_uid,
          phone: req.user.phone,
          email: req.user.email,
          name: req.user.name,
          avatar_url: req.user.avatar_url,
          timezone: req.user.timezone,
          created_at: req.user.created_at,
        },
        roles: rolesResult.rows,
        flat: flatResult.rows[0] || null,
        guard: guardResult.rows[0] || null,
        recent_notifications: notificationsResult.rows,
        admin: adminInfo,
      },
    });
  } catch (error) {
    logger.error('Error fetching profile:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch profile',
    });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const logger = require('../config/logger');
const { verifyAdminToken } = require('../middleware/adminAuth');

/**
 * GET /admin/emergencies
 * Get emergencies for a society (admin)
 */
router.get('/', verifyAdminToken, async (req, res) => {
  try {
    const { society_id, status, limit = 100 } = req.query;

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === society_id);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this society',
      });
    }

    let queryText = `
      SELECT
        e.*,
        f.flat_number,
        b.name as block_name,
        u.name as reported_by_name,
        u.phone as reported_by_phone
      FROM emergencies e
      JOIN flats f ON e.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN complexes c ON b.complex_id = c.id
      JOIN users u ON e.reported_by_user_id = u.id
      WHERE c.society_id = $1
    `;
    const params = [society_id];

    if (status) {
      params.push(status);
      queryText += ` AND e.status = $${params.length}`;
    }

    params.push(parseInt(limit));
    queryText += ` ORDER BY e.created_at DESC LIMIT $${params.length}`;

    const result = await query(queryText, params);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching emergencies:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch emergencies',
    });
  }
});

/**
 * PUT /admin/emergencies/:id/resolve
 * Admin resolves an emergency
 */
router.put('/:id/resolve', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Get emergency first
    const emergencyResult = await query(
      `SELECT e.*, c.society_id
       FROM emergencies e
       JOIN flats f ON e.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE e.id = $1`,
      [id]
    );

    if (emergencyResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Emergency not found',
      });
    }

    const emergency = emergencyResult.rows[0];

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === emergency.society_id);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this emergency',
      });
    }

    // Update emergency
    const updateResult = await query(
      `UPDATE emergencies
       SET resolved_at = NOW(), status = 'resolved'
       WHERE id = $1
       RETURNING *`,
      [id]
    );

    // Emit Socket.io event
    const io = req.app.get('io');
    if (io) {
      io.to(`society:${emergency.society_id}`).emit('emergency_updated', {
        emergency_id: id,
        status: 'resolved',
        resolved_at: updateResult.rows[0].resolved_at,
      });
    }

    logger.info(`Emergency resolved by admin: ${id}`);

    res.json({
      success: true,
      data: updateResult.rows[0],
    });
  } catch (error) {
    logger.error('Error resolving emergency:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to resolve emergency',
    });
  }
});

module.exports = router;

const express = require('express');
const { query } = require('../config/database');
const logger = require('../config/logger');
const { verifyAdminToken, requireSocietyAccess } = require('../middleware/adminAuth');

const router = express.Router();

/**
 * GET /notices
 * List notices for a society
 */
router.get('/', verifyAdminToken, async (req, res) => {
  try {
    const { society_id, priority, published, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    // Build query conditions
    const conditions = [];
    const params = [];
    let paramIndex = 1;

    if (society_id) {
      conditions.push(`n.society_id = $${paramIndex++}`);
      params.push(society_id);
    } else {
      // If no society_id specified, filter by user's accessible societies
      const roles = req.userRoles;
      const isSuperAdmin = roles.some(r => r.role === 'super_admin');

      if (!isSuperAdmin) {
        const societyIds = roles.filter(r => r.scope_type === 'society').map(r => r.scope_id);
        if (societyIds.length === 0) {
          return res.json({ success: true, data: [], pagination: { total: 0 } });
        }
        conditions.push(`n.society_id = ANY($${paramIndex++})`);
        params.push(societyIds);
      }
    }

    if (priority) {
      conditions.push(`n.priority = $${paramIndex++}`);
      params.push(priority);
    }

    if (published !== undefined) {
      conditions.push(`n.published = $${paramIndex++}`);
      params.push(published === 'true');
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const noticesResult = await query(
      `SELECT n.*,
        u.name as created_by_name,
        s.name as society_name,
        (SELECT COUNT(*) FROM notice_reads nr WHERE nr.notice_id = n.id) as read_count
       FROM notices n
       LEFT JOIN users u ON n.created_by = u.id
       LEFT JOIN societies s ON n.society_id = s.id
       ${whereClause}
       ORDER BY n.is_pinned DESC, n.created_at DESC
       LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
      [...params, limit, offset]
    );

    // Get total count
    const countResult = await query(
      `SELECT COUNT(*) FROM notices n ${whereClause}`,
      params
    );

    res.json({
      success: true,
      data: noticesResult.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countResult.rows[0].count),
        totalPages: Math.ceil(countResult.rows[0].count / limit),
      },
    });
  } catch (error) {
    logger.error('List notices error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /notices/:id
 * Get notice details
 */
router.get('/:id', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;

    const noticeResult = await query(
      `SELECT n.*,
        u.name as created_by_name,
        s.name as society_name,
        (SELECT COUNT(*) FROM notice_reads nr WHERE nr.notice_id = n.id) as read_count
       FROM notices n
       LEFT JOIN users u ON n.created_by = u.id
       LEFT JOIN societies s ON n.society_id = s.id
       WHERE n.id = $1`,
      [id]
    );

    if (noticeResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Notice not found',
      });
    }

    // Get read statistics
    const readStatsResult = await query(
      `SELECT
        nr.read_at,
        u.name as user_name,
        f.flat_number,
        b.name as block_name
       FROM notice_reads nr
       JOIN users u ON nr.user_id = u.id
       LEFT JOIN flat_occupancies fo ON fo.user_id = u.id AND fo.end_date IS NULL
       LEFT JOIN flats f ON fo.flat_id = f.id
       LEFT JOIN blocks b ON f.block_id = b.id
       WHERE nr.notice_id = $1
       ORDER BY nr.read_at DESC
       LIMIT 50`,
      [id]
    );

    res.json({
      success: true,
      data: {
        ...noticeResult.rows[0],
        recentReads: readStatsResult.rows,
      },
    });
  } catch (error) {
    logger.error('Get notice error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /notices
 * Create new notice
 */
router.post('/', verifyAdminToken, async (req, res) => {
  try {
    const { society_id, title, body, priority, is_pinned, published, publish_at, expires_at } = req.body;

    if (!society_id || !title) {
      return res.status(400).json({
        success: false,
        error: 'Society ID and title are required',
      });
    }

    // Verify access to society
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === society_id);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this society',
      });
    }

    const result = await query(
      `INSERT INTO notices (society_id, title, body, priority, is_pinned, published, publish_at, expires_at, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        society_id,
        title,
        body,
        priority || 'medium',
        is_pinned || false,
        published !== false,
        publish_at,
        expires_at,
        req.adminUser.userId,
      ]
    );

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'notice_created', 'notice', result.rows[0].id, JSON.stringify({ title, priority })]
    );

    // TODO: Send push notification to society residents
    const io = req.app.get('io');
    io.to(`society:${society_id}`).emit('new_notice', {
      id: result.rows[0].id,
      title,
      priority: priority || 'medium',
    });

    logger.info(`Notice created: ${title} for society ${society_id}`);

    res.status(201).json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error('Create notice error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * PUT /notices/:id
 * Update notice
 */
router.put('/:id', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, body, priority, is_pinned, published, publish_at, expires_at } = req.body;

    // Get existing notice to verify access
    const existingResult = await query(`SELECT society_id FROM notices WHERE id = $1`, [id]);

    if (existingResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Notice not found',
      });
    }

    const societyId = existingResult.rows[0].society_id;

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === societyId);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this notice',
      });
    }

    const result = await query(
      `UPDATE notices
       SET title = COALESCE($1, title),
           body = COALESCE($2, body),
           priority = COALESCE($3, priority),
           is_pinned = COALESCE($4, is_pinned),
           published = COALESCE($5, published),
           publish_at = COALESCE($6, publish_at),
           expires_at = COALESCE($7, expires_at),
           updated_by = $8
       WHERE id = $9
       RETURNING *`,
      [title, body, priority, is_pinned, published, publish_at, expires_at, req.adminUser.userId, id]
    );

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'notice_updated', 'notice', id, JSON.stringify(req.body)]
    );

    res.json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error('Update notice error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * DELETE /notices/:id
 * Delete notice
 */
router.delete('/:id', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Get existing notice to verify access
    const existingResult = await query(`SELECT society_id, title FROM notices WHERE id = $1`, [id]);

    if (existingResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Notice not found',
      });
    }

    const { society_id: societyId, title } = existingResult.rows[0];

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === societyId);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this notice',
      });
    }

    await query(`DELETE FROM notices WHERE id = $1`, [id]);

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'notice_deleted', 'notice', id, JSON.stringify({ title })]
    );

    res.json({
      success: true,
      message: 'Notice deleted successfully',
    });
  } catch (error) {
    logger.error('Delete notice error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

module.exports = router;

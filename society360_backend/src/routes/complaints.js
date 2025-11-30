const express = require('express');
const { query } = require('../config/database');
const logger = require('../config/logger');
const { verifyAdminToken, requireSocietyAccess } = require('../middleware/adminAuth');

const router = express.Router();

/**
 * GET /complaints
 * List complaints for a society
 */
router.get('/', verifyAdminToken, async (req, res) => {
  try {
    const { society_id, status, category, priority, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    // Build query conditions
    const conditions = [];
    const params = [];
    let paramIndex = 1;

    if (society_id) {
      conditions.push(`c.society_id = $${paramIndex++}`);
      params.push(society_id);
    } else {
      // Filter by user's accessible societies
      const roles = req.userRoles;
      const isSuperAdmin = roles.some(r => r.role === 'super_admin');

      if (!isSuperAdmin) {
        const societyIds = roles.filter(r => r.scope_type === 'society').map(r => r.scope_id);
        if (societyIds.length === 0) {
          return res.json({ success: true, data: [], pagination: { total: 0 } });
        }
        conditions.push(`c.society_id = ANY($${paramIndex++})`);
        params.push(societyIds);
      }
    }

    if (status) {
      conditions.push(`c.status = $${paramIndex++}`);
      params.push(status);
    }

    if (category) {
      conditions.push(`c.category = $${paramIndex++}`);
      params.push(category);
    }

    if (priority) {
      conditions.push(`c.priority = $${paramIndex++}`);
      params.push(priority);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const complaintsResult = await query(
      `SELECT c.*,
        u.name as submitted_by_name,
        u.phone as submitted_by_phone,
        f.flat_number,
        b.name as block_name,
        s.name as society_name,
        au.name as assigned_to_name,
        (SELECT COUNT(*) FROM complaint_comments cc WHERE cc.complaint_id = c.id) as comment_count
       FROM complaints c
       LEFT JOIN users u ON c.submitted_by = u.id
       LEFT JOIN flats f ON c.flat_id = f.id
       LEFT JOIN blocks b ON f.block_id = b.id
       LEFT JOIN societies s ON c.society_id = s.id
       LEFT JOIN users au ON c.assigned_to = au.id
       ${whereClause}
       ORDER BY
         CASE c.status
           WHEN 'open' THEN 1
           WHEN 'in_progress' THEN 2
           WHEN 'resolved' THEN 3
           WHEN 'closed' THEN 4
         END,
         CASE c.priority
           WHEN 'critical' THEN 1
           WHEN 'high' THEN 2
           WHEN 'medium' THEN 3
           WHEN 'low' THEN 4
         END,
         c.created_at DESC
       LIMIT $${paramIndex++} OFFSET $${paramIndex++}`,
      [...params, limit, offset]
    );

    // Get total count
    const countResult = await query(
      `SELECT COUNT(*) FROM complaints c ${whereClause}`,
      params
    );

    // Get counts by status for kanban view
    const statusCountsResult = await query(
      `SELECT status, COUNT(*) as count
       FROM complaints c
       ${whereClause}
       GROUP BY status`,
      params
    );

    const statusCounts = {};
    statusCountsResult.rows.forEach(row => {
      statusCounts[row.status] = parseInt(row.count);
    });

    res.json({
      success: true,
      data: complaintsResult.rows,
      statusCounts,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countResult.rows[0].count),
        totalPages: Math.ceil(countResult.rows[0].count / limit),
      },
    });
  } catch (error) {
    logger.error('List complaints error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /complaints/:id
 * Get complaint details with comments
 */
router.get('/:id', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;

    const complaintResult = await query(
      `SELECT c.*,
        u.name as submitted_by_name,
        u.phone as submitted_by_phone,
        u.email as submitted_by_email,
        f.flat_number,
        b.name as block_name,
        cx.name as complex_name,
        s.name as society_name,
        au.name as assigned_to_name,
        ru.name as resolved_by_name
       FROM complaints c
       LEFT JOIN users u ON c.submitted_by = u.id
       LEFT JOIN flats f ON c.flat_id = f.id
       LEFT JOIN blocks b ON f.block_id = b.id
       LEFT JOIN complexes cx ON b.complex_id = cx.id
       LEFT JOIN societies s ON c.society_id = s.id
       LEFT JOIN users au ON c.assigned_to = au.id
       LEFT JOIN users ru ON c.resolved_by = ru.id
       WHERE c.id = $1`,
      [id]
    );

    if (complaintResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Complaint not found',
      });
    }

    // Get comments
    const commentsResult = await query(
      `SELECT cc.*,
        u.name as user_name,
        u.avatar_url as user_avatar
       FROM complaint_comments cc
       LEFT JOIN users u ON cc.user_id = u.id
       WHERE cc.complaint_id = $1
       ORDER BY cc.created_at ASC`,
      [id]
    );

    res.json({
      success: true,
      data: {
        ...complaintResult.rows[0],
        comments: commentsResult.rows,
      },
    });
  } catch (error) {
    logger.error('Get complaint error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /complaints
 * Create new complaint (from admin or resident)
 */
router.post('/', verifyAdminToken, async (req, res) => {
  try {
    const { society_id, flat_id, title, description, category, priority } = req.body;

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
      `INSERT INTO complaints (society_id, flat_id, submitted_by, title, description, category, priority)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        society_id,
        flat_id,
        req.adminUser.userId,
        title,
        description,
        category || 'other',
        priority || 'medium',
      ]
    );

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'complaint_created', 'complaint', result.rows[0].id, JSON.stringify({ title, category })]
    );

    logger.info(`Complaint created: ${title} for society ${society_id}`);

    res.status(201).json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error('Create complaint error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * PUT /complaints/:id
 * Update complaint (status, assignment, etc.)
 */
router.put('/:id', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, category, priority, assigned_to, resolution_note } = req.body;

    // Get existing complaint to verify access
    const existingResult = await query(`SELECT society_id, status as old_status FROM complaints WHERE id = $1`, [id]);

    if (existingResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Complaint not found',
      });
    }

    const { society_id: societyId, old_status: oldStatus } = existingResult.rows[0];

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === societyId);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this complaint',
      });
    }

    // Build update query dynamically
    const updates = [];
    const params = [];
    let paramIndex = 1;

    if (status !== undefined) {
      updates.push(`status = $${paramIndex++}`);
      params.push(status);

      // If marking as resolved
      if (status === 'resolved' && oldStatus !== 'resolved') {
        updates.push(`resolved_at = NOW()`);
        updates.push(`resolved_by = $${paramIndex++}`);
        params.push(req.adminUser.userId);
      }
    }

    if (category !== undefined) {
      updates.push(`category = $${paramIndex++}`);
      params.push(category);
    }

    if (priority !== undefined) {
      updates.push(`priority = $${paramIndex++}`);
      params.push(priority);
    }

    if (assigned_to !== undefined) {
      updates.push(`assigned_to = $${paramIndex++}`);
      params.push(assigned_to);
    }

    if (resolution_note !== undefined) {
      updates.push(`resolution_note = $${paramIndex++}`);
      params.push(resolution_note);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No fields to update',
      });
    }

    params.push(id);
    const result = await query(
      `UPDATE complaints SET ${updates.join(', ')} WHERE id = $${paramIndex} RETURNING *`,
      params
    );

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'complaint_updated', 'complaint', id, JSON.stringify(req.body)]
    );

    // Emit socket event for status change
    if (status && status !== oldStatus) {
      const io = req.app.get('io');
      io.to(`society:${societyId}`).emit('complaint_status_changed', {
        id,
        status,
        oldStatus,
      });
    }

    res.json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error('Update complaint error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /complaints/:id/comments
 * Add comment to complaint
 */
router.post('/:id/comments', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { comment, is_internal } = req.body;

    if (!comment) {
      return res.status(400).json({
        success: false,
        error: 'Comment text is required',
      });
    }

    // Verify complaint exists and user has access
    const complaintResult = await query(`SELECT society_id FROM complaints WHERE id = $1`, [id]);

    if (complaintResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Complaint not found',
      });
    }

    const societyId = complaintResult.rows[0].society_id;

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === societyId);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this complaint',
      });
    }

    const result = await query(
      `INSERT INTO complaint_comments (complaint_id, user_id, comment, is_internal)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [id, req.adminUser.userId, comment, is_internal || false]
    );

    // Get user info for response
    const userResult = await query(
      `SELECT name, avatar_url FROM users WHERE id = $1`,
      [req.adminUser.userId]
    );

    const commentWithUser = {
      ...result.rows[0],
      user_name: userResult.rows[0]?.name,
      user_avatar: userResult.rows[0]?.avatar_url,
    };

    // Emit socket event
    const io = req.app.get('io');
    io.to(`society:${societyId}`).emit('complaint_comment_added', {
      complaintId: id,
      comment: commentWithUser,
    });

    res.status(201).json({
      success: true,
      data: commentWithUser,
    });
  } catch (error) {
    logger.error('Add comment error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * DELETE /complaints/:id
 * Delete complaint
 */
router.delete('/:id', verifyAdminToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Get existing complaint to verify access
    const existingResult = await query(`SELECT society_id, title FROM complaints WHERE id = $1`, [id]);

    if (existingResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Complaint not found',
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
        error: 'No access to this complaint',
      });
    }

    await query(`DELETE FROM complaints WHERE id = $1`, [id]);

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'complaint_deleted', 'complaint', id, JSON.stringify({ title })]
    );

    res.json({
      success: true,
      message: 'Complaint deleted successfully',
    });
  } catch (error) {
    logger.error('Delete complaint error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

module.exports = router;

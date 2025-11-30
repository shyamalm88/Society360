const express = require('express');
const router = express.Router();
const { query, getClient } = require('../config/database');
const logger = require('../config/logger');
const { verifyAdminToken } = require('../middleware/adminAuth');

/**
 * GET /admin/approvals
 * Get pending resident requests for a society (admin)
 */
router.get('/', verifyAdminToken, async (req, res) => {
  try {
    const { society_id, status = 'pending' } = req.query;

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

    const result = await query(
      `SELECT
        rr.*,
        u.name as requesting_user_name,
        u.phone as requesting_user_phone,
        u.email as requesting_user_email,
        f.flat_number,
        b.name as block_name,
        c.name as complex_name
      FROM resident_requests rr
      JOIN users u ON rr.requesting_user_id = u.id
      JOIN flats f ON rr.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN complexes c ON b.complex_id = c.id
      WHERE c.society_id = $1 AND rr.status = $2
      ORDER BY rr.submitted_at DESC`,
      [society_id, status]
    );

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching approvals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch approvals',
    });
  }
});

/**
 * PUT /admin/approvals/:id/approve
 * Approve a resident request (admin)
 */
router.put('/:id/approve', verifyAdminToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const requestId = req.params.id;
    const { note } = req.body;
    const adminUserId = req.adminUser.userId;

    // Get resident request
    const requestResult = await client.query(
      `SELECT rr.*, c.society_id
       FROM resident_requests rr
       JOIN flats f ON rr.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE rr.id = $1`,
      [requestId]
    );

    if (requestResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Resident request not found',
      });
    }

    const request = requestResult.rows[0];

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === request.society_id);

    if (!isSuperAdmin && !hasSocietyAccess) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        error: 'No access to approve this request',
      });
    }

    if (request.status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: `Request already ${request.status}`,
      });
    }

    // Update request status
    await client.query(
      `UPDATE resident_requests
       SET status = 'approved', processed_by = $1, processed_at = now(), processed_note = $2
       WHERE id = $3`,
      [adminUserId, note || 'Approved by admin', requestId]
    );

    // Create flat occupancy
    await client.query(
      `INSERT INTO flat_occupancies (flat_id, user_id, role, start_date, is_primary, source, created_at)
       VALUES ($1, $2, $3, now(), true, 'resident_request', now())
       ON CONFLICT DO NOTHING`,
      [request.flat_id, request.requesting_user_id, request.requested_role]
    );

    // Assign resident role
    await client.query(
      `INSERT INTO role_assignments (user_id, role, scope_type, scope_id, granted_by, granted_at)
       VALUES ($1, 'resident', 'flat', $2, $3, now())
       ON CONFLICT (user_id, role, scope_type, scope_id) DO NOTHING`,
      [request.requesting_user_id, request.flat_id, adminUserId]
    );

    // Log approval
    await client.query(
      `INSERT INTO resident_request_approvals (request_id, approver_user_id, approver_role, decision, note, decided_at)
       VALUES ($1, $2, 'admin', 'approve', $3, now())`,
      [requestId, adminUserId, note || 'Approved']
    );

    await client.query('COMMIT');

    logger.info(`Resident request approved by admin: ${requestId}`);

    res.json({
      success: true,
      message: 'Request approved successfully',
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error approving request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to approve request',
    });
  } finally {
    client.release();
  }
});

/**
 * PUT /admin/approvals/:id/reject
 * Reject a resident request (admin)
 */
router.put('/:id/reject', verifyAdminToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const requestId = req.params.id;
    const { note } = req.body;
    const adminUserId = req.adminUser.userId;

    // Get resident request
    const requestResult = await client.query(
      `SELECT rr.*, c.society_id
       FROM resident_requests rr
       JOIN flats f ON rr.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE rr.id = $1`,
      [requestId]
    );

    if (requestResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Resident request not found',
      });
    }

    const request = requestResult.rows[0];

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === request.society_id);

    if (!isSuperAdmin && !hasSocietyAccess) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        success: false,
        error: 'No access to reject this request',
      });
    }

    if (request.status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: `Request already ${request.status}`,
      });
    }

    // Update request status
    await client.query(
      `UPDATE resident_requests
       SET status = 'rejected', processed_by = $1, processed_at = now(), processed_note = $2
       WHERE id = $3`,
      [adminUserId, note || 'Rejected by admin', requestId]
    );

    // Log rejection
    await client.query(
      `INSERT INTO resident_request_approvals (request_id, approver_user_id, approver_role, decision, note, decided_at)
       VALUES ($1, $2, 'admin', 'reject', $3, now())`,
      [requestId, adminUserId, note || 'Rejected']
    );

    await client.query('COMMIT');

    logger.info(`Resident request rejected by admin: ${requestId}`);

    res.json({
      success: true,
      message: 'Request rejected',
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error rejecting request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to reject request',
    });
  } finally {
    client.release();
  }
});

module.exports = router;

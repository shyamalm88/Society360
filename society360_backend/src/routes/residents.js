const express = require('express');
const router = express.Router();
const { query, getClient } = require('../config/database');
const { verifyFirebaseToken, requireRole } = require('../middleware/auth');
const logger = require('../config/logger');

/**
 * POST /resident-requests
 * Submit a resident request (tenant/owner verification)
 *
 * TODO: This currently auto-approves all requests. When admin module is implemented,
 * this should return to requiring admin approval workflow.
 */
router.post('/', verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const { flat_id, requested_role, docs, note } = req.body;
    const userId = req.user.id;

    if (!flat_id || !requested_role) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'flat_id and requested_role are required',
      });
    }

    if (!['owner', 'tenant', 'other'].includes(requested_role)) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'requested_role must be owner, tenant, or other',
      });
    }

    // Insert resident request with 'approved' status (auto-approve for now)
    const result = await client.query(
      `INSERT INTO resident_requests (
        requesting_user_id, flat_id, requested_role, docs, note, status,
        processed_by, processed_at, processed_note, submitted_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, now(), $8, now())
      RETURNING *`,
      [
        userId,
        flat_id,
        requested_role,
        JSON.stringify(docs || []),
        note || null,
        'approved',
        userId, // Self-approved for now
        'Auto-approved (admin module not yet implemented)'
      ]
    );

    const request = result.rows[0];

    // Create flat occupancy immediately
    await client.query(
      `INSERT INTO flat_occupancies (flat_id, user_id, role, start_date, is_primary, source, created_at)
       VALUES ($1, $2, $3, now(), $4, $5, now())`,
      [flat_id, userId, requested_role, true, 'resident_request']
    );

    // Assign resident role
    await client.query(
      `INSERT INTO role_assignments (user_id, role, scope_type, scope_id, granted_by, granted_at)
       VALUES ($1, $2, $3, $4, $5, now())
       ON CONFLICT (user_id, role, scope_type, scope_id) DO NOTHING`,
      [userId, 'resident', 'flat', flat_id, userId]
    );

    // Log auto-approval
    await client.query(
      `INSERT INTO resident_request_approvals (request_id, approver_user_id, approver_role, decision, note, decided_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [request.id, userId, 'resident', 'approve', 'Auto-approved during onboarding']
    );

    await client.query('COMMIT');

    logger.info(`✅ Resident request auto-approved: ${request.id} for user ${userId} in flat ${flat_id}`);

    res.status(201).json({
      success: true,
      data: request,
      message: 'Resident request approved automatically',
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error creating resident request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create resident request',
    });
  } finally {
    client.release();
  }
});

/**
 * GET /my-flats
 * Get current user's flat assignments
 */
router.get('/my-flats', verifyFirebaseToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await query(
      `SELECT
        fo.id as occupancy_id,
        fo.flat_id,
        fo.role as occupancy_role,
        fo.is_primary,
        fo.start_date,
        f.flat_number,
        f.unit_type,
        f.bhk,
        b.id as block_id,
        b.name as block_name,
        c.id as complex_id,
        c.name as complex_name,
        s.id as society_id,
        s.name as society_name,
        s.city
       FROM flat_occupancies fo
       JOIN flats f ON fo.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       JOIN societies s ON c.society_id = s.id
       WHERE fo.user_id = $1 AND fo.end_date IS NULL
       ORDER BY fo.is_primary DESC, fo.created_at ASC`,
      [userId]
    );

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching user flats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user flats',
    });
  }
});

/**
 * GET /resident-requests
 * Get resident requests (filtered by status)
 */
router.get('/', verifyFirebaseToken, async (req, res) => {
  try {
    const { status } = req.query;

    let queryText = `
      SELECT
        rr.*,
        u.name as requesting_user_name, u.phone as requesting_user_phone,
        f.flat_number, b.name as block_name, c.name as complex_name, s.name as society_name
      FROM resident_requests rr
      JOIN users u ON rr.requesting_user_id = u.id
      JOIN flats f ON rr.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN complexes c ON b.complex_id = c.id
      JOIN societies s ON c.society_id = s.id
      WHERE 1=1
    `;
    const params = [];

    if (status) {
      params.push(status);
      queryText += ` AND rr.status = $${params.length}`;
    }

    queryText += ' ORDER BY rr.submitted_at DESC';

    const result = await query(queryText, params);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching resident requests:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch resident requests',
    });
  }
});

/**
 * POST /resident-requests/:id/approve
 * Approve a resident request (admin only)
 */
router.post('/:id/approve', verifyFirebaseToken, requireRole(['society_admin', 'block_admin', 'super_admin']), async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const requestId = req.params.id;
    const { note } = req.body;

    // Get resident request
    const requestResult = await client.query(
      'SELECT * FROM resident_requests WHERE id = $1',
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

    // Update request status
    await client.query(
      `UPDATE resident_requests
       SET status = $1, processed_by = $2, processed_at = now(), processed_note = $3
       WHERE id = $4`,
      ['approved', req.user.id, note || null, requestId]
    );

    // Create flat occupancy
    await client.query(
      `INSERT INTO flat_occupancies (flat_id, user_id, role, start_date, is_primary, source, created_at)
       VALUES ($1, $2, $3, now(), $4, $5, now())`,
      [request.flat_id, request.requesting_user_id, request.requested_role, true, 'resident_request']
    );

    // Assign resident role
    await client.query(
      `INSERT INTO role_assignments (user_id, role, scope_type, scope_id, granted_by, granted_at)
       VALUES ($1, $2, $3, $4, $5, now())
       ON CONFLICT (user_id, role, scope_type, scope_id) DO NOTHING`,
      [request.requesting_user_id, 'resident', 'flat', request.flat_id, req.user.id]
    );

    // Log approval
    await client.query(
      `INSERT INTO resident_request_approvals (request_id, approver_user_id, approver_role, decision, note, decided_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [requestId, req.user.id, req.userRoles[0]?.role || 'admin', 'approve', note || null]
    );

    await client.query('COMMIT');

    logger.info(`Resident request approved: ${requestId}`);

    res.json({
      success: true,
      message: 'Resident request approved successfully',
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error approving resident request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to approve resident request',
    });
  } finally {
    client.release();
  }
});

/**
 * POST /resident-requests/:id/reject
 * Reject a resident request (admin only)
 */
router.post('/:id/reject', verifyFirebaseToken, requireRole(['society_admin', 'block_admin', 'super_admin']), async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const requestId = req.params.id;
    const { note } = req.body;

    // Get resident request
    const requestResult = await client.query(
      'SELECT * FROM resident_requests WHERE id = $1',
      [requestId]
    );

    if (requestResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Resident request not found',
      });
    }

    // Update request status
    await client.query(
      `UPDATE resident_requests
       SET status = $1, processed_by = $2, processed_at = now(), processed_note = $3
       WHERE id = $4`,
      ['rejected', req.user.id, note || 'Request rejected', requestId]
    );

    // Log rejection
    await client.query(
      `INSERT INTO resident_request_approvals (request_id, approver_user_id, approver_role, decision, note, decided_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [requestId, req.user.id, req.userRoles[0]?.role || 'admin', 'reject', note || null]
    );

    await client.query('COMMIT');

    logger.info(`Resident request rejected: ${requestId}`);

    res.json({
      success: true,
      message: 'Resident request rejected',
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error rejecting resident request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to reject resident request',
    });
  } finally {
    client.release();
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const { query, getClient } = require('../config/database');
const { verifyFirebaseToken, requireRole } = require('../middleware/auth');
const logger = require('../config/logger');
const notificationService = require('../services/notification_service');

/**
 * POST /visits/checkin
 * Guard checks in a visitor
 * Sends notification to resident about check-in
 */
router.post('/checkin', verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const { visitor_id, guard_id, checkin_method, notes } = req.body;

    if (!visitor_id || !guard_id) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'visitor_id and guard_id are required',
      });
    }

    // Verify visitor exists and is accepted
    const visitorResult = await client.query(
      `SELECT v.*, f.id as flat_id, c.society_id
       FROM visitors v
       JOIN flats f ON v.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE v.id = $1`,
      [visitor_id]
    );

    if (visitorResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Visitor not found',
      });
    }

    const visitor = visitorResult.rows[0];

    if (visitor.status !== 'accepted') {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: `Visitor must be accepted before check-in (current status: ${visitor.status})`,
      });
    }

    // Check if already checked in
    const existingVisitResult = await client.query(
      'SELECT * FROM visits WHERE visitor_id = $1 AND checkout_time IS NULL',
      [visitor_id]
    );

    if (existingVisitResult.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'Visitor already checked in',
      });
    }

    // Create visit record
    const visitResult = await client.query(
      `INSERT INTO visits (visitor_id, guard_id, checkin_time, checkin_method, notes, created_at)
       VALUES ($1, $2, now(), $3, $4, now())
       RETURNING *`,
      [visitor_id, guard_id, checkin_method || 'manual', notes || null]
    );

    const visit = visitResult.rows[0];

    // Update visitor status
    await client.query(
      `UPDATE visitors SET status = $1 WHERE id = $2`,
      ['checked_in', visitor_id]
    );

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [req.user.id, 'visitor_checkin', 'visit', visit.id, JSON.stringify({ visitor_id, guard_id })]
    );

    await client.query('COMMIT');

    // Prepare check-in notification data
    const checkinData = {
      visitor_id: visitor_id,
      visitor_name: visitor.visitor_name,
      visit_id: visit.id,
      checkin_time: visit.checkin_time,
    };

    // Emit Socket.io event to flat room (notify residents)
    const io = req.app.get('io');
    const flatRoomName = `flat:${visitor.flat_id}`;
    io.to(flatRoomName).emit('visitor_checkin', checkinData);

    // Also emit to society room (notify guards)
    const societyRoomName = `society:${visitor.society_id}`;
    io.to(societyRoomName).emit('visitor_checkin', checkinData);
    logger.info(`📡 Emitted visitor_checkin to rooms: ${flatRoomName}, ${societyRoomName}`);

    // Send FCM push notification to residents
    notificationService.notifyVisitorCheckedIn(visitor.flat_id, {
      visitor_id: visitor_id,
      visitor_name: visitor.visitor_name,
    }).catch(err => logger.error('Failed to send check-in notification:', err));

    logger.info(`✅ Visitor checked in: visitor_id=${visitor_id}, visit_id=${visit.id}`);

    res.status(201).json({
      success: true,
      data: visit,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error checking in visitor:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check in visitor',
    });
  } finally {
    client.release();
  }
});

/**
 * POST /visits/checkout
 * Guard checks out a visitor
 */
router.post('/checkout', verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const { visit_id, guard_id, notes } = req.body;

    if (!visit_id) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'visit_id is required',
      });
    }

    // Get visit record with visitor, flat, and society details
    const visitResult = await client.query(
      `SELECT v.*, vis.visitor_name, vis.flat_id, c.society_id
       FROM visits v
       JOIN visitors vis ON v.visitor_id = vis.id
       JOIN flats f ON vis.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE v.id = $1`,
      [visit_id]
    );

    if (visitResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Visit not found',
      });
    }

    const visit = visitResult.rows[0];

    if (visit.checkout_time) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'Visitor already checked out',
      });
    }

    // Update visit with checkout time
    const updateResult = await client.query(
      `UPDATE visits
       SET checkout_time = now(), notes = COALESCE(notes || ' | ' || $1, $1)
       WHERE id = $2
       RETURNING *`,
      [notes || 'Checked out', visit_id]
    );

    const updatedVisit = updateResult.rows[0];

    // Update visitor status
    await client.query(
      `UPDATE visitors SET status = $1 WHERE id = $2`,
      ['checked_out', visit.visitor_id]
    );

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [req.user.id, 'visitor_checkout', 'visit', visit_id, JSON.stringify({ visit_id, guard_id })]
    );

    await client.query('COMMIT');

    // Prepare check-out notification data
    const checkoutData = {
      visitor_id: visit.visitor_id,
      visitor_name: visit.visitor_name,
      visit_id: visit_id,
      checkout_time: updatedVisit.checkout_time,
    };

    // Emit Socket.io event to flat room (notify residents)
    const io = req.app.get('io');
    const flatRoomName = `flat:${visit.flat_id}`;
    io.to(flatRoomName).emit('visitor_checkout', checkoutData);

    // Also emit to society room (notify guards)
    const societyRoomName = `society:${visit.society_id}`;
    io.to(societyRoomName).emit('visitor_checkout', checkoutData);
    logger.info(`📡 Emitted visitor_checkout to rooms: ${flatRoomName}, ${societyRoomName}`);

    // Send FCM push notification to residents
    notificationService.notifyVisitorCheckedOut(visit.flat_id, {
      visitor_id: visit.visitor_id,
      visitor_name: visit.visitor_name,
    }).catch(err => logger.error('Failed to send check-out notification:', err));

    logger.info(`✅ Visitor checked out: visit_id=${visit_id}`);

    res.json({
      success: true,
      data: updatedVisit,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error checking out visitor:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to check out visitor',
    });
  } finally {
    client.release();
  }
});

/**
 * GET /visits
 * Get visit history with filters
 */
router.get('/', verifyFirebaseToken, async (req, res) => {
  try {
    const { from, to, flat_id, limit = 100 } = req.query;

    let queryText = `
      SELECT
        v.id, v.visitor_id, v.guard_id, v.checkin_time, v.checkout_time,
        v.checkin_method, v.notes,
        vis.visitor_name, vis.phone, vis.vehicle_no, vis.purpose,
        f.flat_number, b.name as block_name,
        u.name as guard_name
      FROM visits v
      JOIN visitors vis ON v.visitor_id = vis.id
      LEFT JOIN flats f ON vis.flat_id = f.id
      LEFT JOIN blocks b ON f.block_id = b.id
      LEFT JOIN guards g ON v.guard_id = g.id
      LEFT JOIN users u ON g.user_id = u.id
      WHERE 1=1
    `;
    const params = [];

    if (from) {
      params.push(from);
      queryText += ` AND v.checkin_time >= $${params.length}`;
    }

    if (to) {
      params.push(to);
      queryText += ` AND v.checkin_time <= $${params.length}`;
    }

    if (flat_id) {
      params.push(flat_id);
      queryText += ` AND vis.flat_id = $${params.length}`;
    }

    params.push(parseInt(limit));
    queryText += ` ORDER BY v.checkin_time DESC LIMIT $${params.length}`;

    const result = await query(queryText, params);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching visits:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch visits',
    });
  }
});

module.exports = router;

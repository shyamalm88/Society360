const express = require('express');
const router = express.Router();
const { query, getClient } = require('../config/database');
const { verifyFirebaseToken, requireRole } = require('../middleware/auth');
const logger = require('../config/logger');

/**
 * POST /emergencies
 * Resident reports an emergency
 * Sends real-time alert to all guards via Socket.io
 */
router.post('/', verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const { flat_id, description } = req.body;
    const reported_by_user_id = req.user.id;

    if (!flat_id) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: 'flat_id is required',
      });
    }

    // Get flat and society info
    const flatResult = await client.query(
      `SELECT f.*, b.name as block_name, c.society_id
       FROM flats f
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE f.id = $1`,
      [flat_id]
    );

    if (flatResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Flat not found',
      });
    }

    const flat = flatResult.rows[0];

    // Create emergency record
    const emergencyResult = await client.query(
      `INSERT INTO emergencies (flat_id, reported_by_user_id, description, status, created_at)
       VALUES ($1, $2, $3, 'pending', NOW())
       RETURNING *`,
      [flat_id, reported_by_user_id, description || 'Emergency reported']
    );

    const emergency = emergencyResult.rows[0];

    // Get reporter info
    const reporterResult = await client.query(
      'SELECT name, phone FROM users WHERE id = $1',
      [reported_by_user_id]
    );
    const reporter = reporterResult.rows[0];

    await client.query('COMMIT');

    // Prepare emergency alert data
    const emergencyData = {
      emergency_id: emergency.id,
      flat_id: flat_id,
      flat_number: flat.flat_number,
      block_name: flat.block_name,
      description: emergency.description,
      reported_by: reporter.name,
      reported_by_phone: reporter.phone,
      created_at: emergency.created_at,
      status: emergency.status,
    };

    // Emit Socket.io event to society room (all guards)
    const io = req.app.get('io');
    const societyRoomName = `society:${flat.society_id}`;
    io.to(societyRoomName).emit('emergency_alert', emergencyData);
    logger.info(`🚨 Emergency alert emitted to room: ${societyRoomName}, Emergency ID: ${emergency.id}`);

    res.status(201).json({
      success: true,
      data: {
        ...emergency,
        flat_number: flat.flat_number,
        block_name: flat.block_name,
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error creating emergency:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create emergency',
    });
  } finally {
    client.release();
  }
});

/**
 * POST /emergencies/:id/address
 * Guard marks emergency as addressed
 */
router.post('/:id/address', verifyFirebaseToken, requireRole(['guard']), async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const { id } = req.params;
    const guard_id = req.user.guard_id; // Assuming guard_id is attached to user

    // Get emergency
    const emergencyResult = await client.query(
      'SELECT * FROM emergencies WHERE id = $1',
      [id]
    );

    if (emergencyResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Emergency not found',
      });
    }

    const emergency = emergencyResult.rows[0];

    if (emergency.status !== 'pending') {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: `Emergency already ${emergency.status}`,
      });
    }

    // Update emergency
    const updateResult = await client.query(
      `UPDATE emergencies
       SET status = 'addressed', addressed_by_guard_id = $1, addressed_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [guard_id, id]
    );

    await client.query('COMMIT');

    const updated = updateResult.rows[0];

    // Emit Socket.io event for status update
    const io = req.app.get('io');
    const flatResult = await client.query(
      `SELECT f.*, c.society_id
       FROM flats f
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE f.id = $1`,
      [updated.flat_id]
    );

    if (flatResult.rows.length > 0) {
      const flat = flatResult.rows[0];
      io.to(`society:${flat.society_id}`).emit('emergency_updated', {
        emergency_id: id,
        status: 'addressed',
        addressed_at: updated.addressed_at,
      });
    }

    logger.info(`✅ Emergency addressed: ${id}`);

    res.json({
      success: true,
      data: updated,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error addressing emergency:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to address emergency',
    });
  } finally {
    client.release();
  }
});

/**
 * POST /emergencies/:id/resolve
 * Guard marks emergency as resolved
 */
router.post('/:id/resolve', verifyFirebaseToken, requireRole(['guard']), async (req, res) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const { id } = req.params;
    const guard_id = req.user.guard_id;

    // Get emergency
    const emergencyResult = await client.query(
      'SELECT * FROM emergencies WHERE id = $1',
      [id]
    );

    if (emergencyResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Emergency not found',
      });
    }

    const emergency = emergencyResult.rows[0];

    if (emergency.status !== 'addressed') {
      await client.query('ROLLBACK');
      return res.status(400).json({
        success: false,
        error: `Emergency must be addressed before resolving (current status: ${emergency.status})`,
      });
    }

    // Update emergency
    const updateResult = await client.query(
      `UPDATE emergencies
       SET status = 'resolved', resolved_by_guard_id = $1, resolved_at = NOW()
       WHERE id = $2
       RETURNING *`,
      [guard_id, id]
    );

    await client.query('COMMIT');

    const updated = updateResult.rows[0];

    // Emit Socket.io event for status update
    const io = req.app.get('io');
    const flatResult = await client.query(
      `SELECT f.*, c.society_id
       FROM flats f
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE f.id = $1`,
      [updated.flat_id]
    );

    if (flatResult.rows.length > 0) {
      const flat = flatResult.rows[0];
      io.to(`society:${flat.society_id}`).emit('emergency_updated', {
        emergency_id: id,
        status: 'resolved',
        resolved_at: updated.resolved_at,
      });
    }

    logger.info(`✅ Emergency resolved: ${id}`);

    res.json({
      success: true,
      data: updated,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error resolving emergency:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to resolve emergency',
    });
  } finally {
    client.release();
  }
});

/**
 * GET /emergencies
 * Get emergencies with optional filters
 */
router.get('/', verifyFirebaseToken, async (req, res) => {
  try {
    const { status, flat_id, limit = 100 } = req.query;

    let queryText = `
      SELECT
        e.*,
        f.flat_number,
        b.name as block_name,
        u.name as reported_by_name,
        u.phone as reported_by_phone,
        g1.user_id as addressed_by_user_id,
        g2.user_id as resolved_by_user_id
      FROM emergencies e
      JOIN flats f ON e.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN users u ON e.reported_by_user_id = u.id
      LEFT JOIN guards g1 ON e.addressed_by_guard_id = g1.id
      LEFT JOIN guards g2 ON e.resolved_by_guard_id = g2.id
      WHERE 1=1
    `;
    const params = [];

    if (status) {
      params.push(status);
      queryText += ` AND e.status = $${params.length}`;
    }

    if (flat_id) {
      params.push(flat_id);
      queryText += ` AND e.flat_id = $${params.length}`;
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

module.exports = router;

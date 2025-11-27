const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { verifyFirebaseToken } = require('../middleware/auth');
const logger = require('../config/logger');

/**
 * POST /guards/register-device
 * Register guard device for push notifications
 */
router.post('/register-device', verifyFirebaseToken, async (req, res) => {
  try {
    const { device_identifier, fcm_token } = req.body;
    const userId = req.user.id;

    if (!device_identifier) {
      return res.status(400).json({
        success: false,
        error: 'device_identifier is required',
      });
    }

    // Check if device already exists
    const existingDevice = await query(
      'SELECT * FROM devices WHERE user_id = $1 AND device_identifier = $2',
      [userId, device_identifier]
    );

    let device;
    if (existingDevice.rows.length > 0) {
      // Update existing device
      const updateResult = await query(
        `UPDATE devices
         SET fcm_token = $1, last_seen = now()
         WHERE user_id = $2 AND device_identifier = $3
         RETURNING *`,
        [fcm_token || null, userId, device_identifier]
      );
      device = updateResult.rows[0];
    } else {
      // Insert new device
      const insertResult = await query(
        `INSERT INTO devices (user_id, device_identifier, fcm_token, last_seen, created_at)
         VALUES ($1, $2, $3, now(), now())
         RETURNING *`,
        [userId, device_identifier, fcm_token || null]
      );
      device = insertResult.rows[0];
    }

    logger.info(`Device registered for user: ${userId}`);

    res.json({
      success: true,
      data: device,
    });
  } catch (error) {
    logger.error('Error registering device:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to register device',
    });
  }
});

/**
 * GET /society/:societyId/expected-visitors
 * Get expected visitors for a society on a specific date
 */
router.get('/society/:societyId/expected-visitors', verifyFirebaseToken, async (req, res) => {
  try {
    const { societyId } = req.params;
    const { date } = req.query;

    const targetDate = date ? new Date(date) : new Date();
    const startOfDay = new Date(targetDate.setHours(0, 0, 0, 0));
    const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999));

    const result = await query(
      `SELECT
        v.id, v.visitor_name, v.phone, v.vehicle_no, v.purpose,
        v.status, v.expected_start, v.expected_end, v.created_at,
        f.flat_number, b.name as block_name, c.name as complex_name,
        u.name as invited_by_name
       FROM visitors v
       JOIN flats f ON v.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       LEFT JOIN users u ON v.invited_by = u.id
       WHERE c.society_id = $1
         AND v.expected_start >= $2
         AND v.expected_start <= $3
         AND v.status IN ('pending', 'accepted')
       ORDER BY v.expected_start`,
      [societyId, startOfDay, endOfDay]
    );

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length,
      date: targetDate.toISOString().split('T')[0],
    });
  } catch (error) {
    logger.error('Error fetching expected visitors:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch expected visitors',
    });
  }
});

module.exports = router;

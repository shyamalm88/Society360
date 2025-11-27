const express = require('express');
const router = express.Router();
const { query, getClient } = require('../config/database');
const { verifyFirebaseToken } = require('../middleware/auth');
const logger = require('../config/logger');

/**
 * POST /fcm-token
 * Register or update FCM token for the current user
 */
router.post('/fcm-token', verifyFirebaseToken, async (req, res) => {
  try {
    const { token, device_type, device_info } = req.body;
    const userId = req.user.id;

    if (!token) {
      return res.status(400).json({
        success: false,
        error: 'token is required'
      });
    }

    if (device_type && !['ios', 'android', 'web'].includes(device_type)) {
      return res.status(400).json({
        success: false,
        error: 'device_type must be ios, android, or web'
      });
    }

    // Insert or update token
    const result = await query(
      `INSERT INTO fcm_tokens (user_id, token, device_type, device_info, is_active, created_at, updated_at)
       VALUES ($1, $2, $3, $4, true, now(), now())
       ON CONFLICT (token)
       DO UPDATE SET
         user_id = EXCLUDED.user_id,
         device_type = EXCLUDED.device_type,
         device_info = EXCLUDED.device_info,
         is_active = true,
         updated_at = now()
       RETURNING *`,
      [userId, token, device_type || null, device_info ? JSON.stringify(device_info) : null]
    );

    logger.info(`✅ FCM token registered for user ${userId}`, {
      device_type,
      token: token.substring(0, 20) + '...'
    });

    res.json({
      success: true,
      data: result.rows[0],
      message: 'FCM token registered successfully'
    });

  } catch (error) {
    logger.error('Error registering FCM token:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to register FCM token'
    });
  }
});

/**
 * DELETE /fcm-token
 * Delete/deactivate FCM token for the current user
 */
router.delete('/fcm-token', verifyFirebaseToken, async (req, res) => {
  try {
    const { token } = req.body;
    const userId = req.user.id;

    if (!token) {
      return res.status(400).json({
        success: false,
        error: 'token is required'
      });
    }

    const result = await query(
      `UPDATE fcm_tokens
       SET is_active = false, updated_at = now()
       WHERE user_id = $1 AND token = $2
       RETURNING *`,
      [userId, token]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Token not found'
      });
    }

    logger.info(`🗑️  FCM token deactivated for user ${userId}`);

    res.json({
      success: true,
      message: 'FCM token deactivated successfully'
    });

  } catch (error) {
    logger.error('Error deactivating FCM token:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to deactivate FCM token'
    });
  }
});

/**
 * GET /fcm-tokens
 * Get all active FCM tokens for the current user
 */
router.get('/fcm-tokens', verifyFirebaseToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await query(
      `SELECT id, token, device_type, device_info, is_active, created_at, updated_at
       FROM fcm_tokens
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId]
    );

    res.json({
      success: true,
      data: result.rows
    });

  } catch (error) {
    logger.error('Error fetching FCM tokens:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch FCM tokens'
    });
  }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { query } = require('../config/database');
const logger = require('../config/logger');

/**
 * POST /auth/firebase
 * Exchange Firebase ID token for user session
 */
router.post('/firebase', async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({
        success: false,
        error: 'idToken is required',
      });
    }

    // Verify Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const firebaseUid = decodedToken.uid;

    // Check if user exists
    let userResult = await query(
      'SELECT * FROM users WHERE firebase_uid = $1 AND is_deleted = false',
      [firebaseUid]
    );

    let user;
    let isNewUser = false;

    if (userResult.rows.length === 0) {
      // Create new user
      const insertResult = await query(
        `INSERT INTO users (firebase_uid, phone, email, name, phone_normalized, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, now(), now())
         RETURNING *`,
        [
          firebaseUid,
          decodedToken.phone_number || null,
          decodedToken.email || null,
          decodedToken.name || null,
          decodedToken.phone_number ? decodedToken.phone_number.replace(/[^0-9]/g, '') : null,
        ]
      );
      user = insertResult.rows[0];
      isNewUser = true;
      logger.info(`New user registered: ${user.id}`);
    } else {
      user = userResult.rows[0];
    }

    // Get user roles
    const rolesResult = await query(
      `SELECT role, scope_type, scope_id
       FROM role_assignments
       WHERE user_id = $1 AND revoked = false`,
      [user.id]
    );

    // Get user's flat information (if resident)
    const flatResult = await query(
      `SELECT fo.*, f.flat_number, f.block_id, b.name as block_name,
              b.complex_id, c.name as complex_name, c.society_id, s.name as society_name
       FROM flat_occupancies fo
       JOIN flats f ON fo.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       JOIN societies s ON c.society_id = s.id
       WHERE fo.user_id = $1 AND fo.end_date IS NULL
       ORDER BY fo.is_primary DESC
       LIMIT 1`,
      [user.id]
    );

    // Get guard information (if guard)
    const guardResult = await query(
      `SELECT g.*, s.name as society_name
       FROM guards g
       LEFT JOIN societies s ON g.society_id = s.id
       WHERE g.user_id = $1 AND g.active = true`,
      [user.id]
    );

    // Log auth event
    await query(
      `INSERT INTO firebase_auth_audit (user_id, firebase_uid, event, token_issued_at, token_expiry_at, ip, created_at)
       VALUES ($1, $2, $3, to_timestamp($4), to_timestamp($5), $6, now())`,
      [user.id, firebaseUid, 'login', decodedToken.iat, decodedToken.exp, req.ip]
    );

    res.json({
      success: true,
      data: {
        user: {
          id: user.id,
          firebase_uid: user.firebase_uid,
          phone: user.phone,
          email: user.email,
          name: user.name,
          avatar_url: user.avatar_url,
        },
        is_new_user: isNewUser,
        roles: rolesResult.rows,
        flat: flatResult.rows[0] || null,
        guard: guardResult.rows[0] || null,
      },
    });
  } catch (error) {
    logger.error('Auth error:', error);
    res.status(401).json({
      success: false,
      error: error.code === 'auth/id-token-expired' ? 'Token expired' : 'Invalid token',
    });
  }
});

module.exports = router;

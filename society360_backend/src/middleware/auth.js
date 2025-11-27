const admin = require('firebase-admin');
const { query } = require('../config/database');
const logger = require('../config/logger');

// Initialize Firebase Admin SDK
let firebaseApp;
try {
  const serviceAccountPath = process.env.FIREBASE_PRIVATE_KEY_PATH || './firebase-service-account.json';
  const serviceAccount = require(`../../${serviceAccountPath}`);

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID,
  });
  logger.info('✅ Firebase Admin SDK initialized successfully');
} catch (error) {
  logger.error('❌ Firebase Admin SDK initialization failed:', error.message);
  logger.warn('⚠️  Firebase authentication will not work without proper credentials');
}

/**
 * Middleware to verify Firebase ID token and attach user to request
 */
const verifyFirebaseToken = async (req, res, next) => {
  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization;

    // DEVELOPMENT MODE: Allow requests without token for testing
    if (process.env.NODE_ENV === 'development' && (!authHeader || !authHeader.startsWith('Bearer '))) {
      logger.warn('⚠️ Development mode: Bypassing authentication');

      // Use mock guard user from seed data
      const mockUserResult = await query(
        'SELECT * FROM users WHERE phone = $1 LIMIT 1',
        ['+911234567890'] // Guard user from seed data
      );

      if (mockUserResult.rows.length > 0) {
        req.user = mockUserResult.rows[0];
        req.firebaseUser = { uid: 'dev-mode', phone_number: '+911234567890' };
        logger.info(`🔓 Using mock user: ${req.user.id}`);
        return next();
      } else {
        logger.error('Mock user not found. Please run seed script.');
        return res.status(500).json({
          success: false,
          error: 'Development mode: Mock user not found. Run seed script first.',
        });
      }
    }

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: No token provided',
      });
    }

    const idToken = authHeader.split('Bearer ')[1];

    // Verify the ID token
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const firebaseUid = decodedToken.uid;

    // Fetch user from database
    const userResult = await query(
      'SELECT * FROM users WHERE firebase_uid = $1 AND is_deleted = false',
      [firebaseUid]
    );

    let user;
    if (userResult.rows.length === 0) {
      // User doesn't exist - create new user record
      const insertResult = await query(
        `INSERT INTO users (firebase_uid, phone, email, name, created_at, updated_at)
         VALUES ($1, $2, $3, $4, now(), now())
         RETURNING *`,
        [
          firebaseUid,
          decodedToken.phone_number || null,
          decodedToken.email || null,
          decodedToken.name || null,
        ]
      );
      user = insertResult.rows[0];
      logger.info(`New user created: ${user.id} (Firebase UID: ${firebaseUid})`);
    } else {
      user = userResult.rows[0];
    }

    // Log auth audit
    await query(
      `INSERT INTO firebase_auth_audit (user_id, firebase_uid, event, token_issued_at, token_expiry_at, ip, user_agent, created_at)
       VALUES ($1, $2, $3, to_timestamp($4), to_timestamp($5), $6, $7, now())`,
      [
        user.id,
        firebaseUid,
        'token_verified',
        decodedToken.iat,
        decodedToken.exp,
        req.ip,
        req.headers['user-agent'] || null,
      ]
    );

    // Attach user and decoded token to request
    req.user = user;
    req.firebaseUser = decodedToken;

    next();
  } catch (error) {
    logger.error('Firebase token verification failed:', error);

    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        success: false,
        error: 'Token expired',
      });
    }

    return res.status(401).json({
      success: false,
      error: 'Invalid token',
    });
  }
};

/**
 * Middleware to check if user has specific role
 */
const requireRole = (requiredRoles) => {
  return async (req, res, next) => {
    try {
      const userId = req.user.id;

      // Query role assignments
      const roleResult = await query(
        `SELECT role, scope_type, scope_id
         FROM role_assignments
         WHERE user_id = $1 AND revoked = false`,
        [userId]
      );

      const userRoles = roleResult.rows.map(r => r.role);

      // Check if user has any of the required roles
      const hasRole = requiredRoles.some(role => userRoles.includes(role));

      if (!hasRole) {
        return res.status(403).json({
          success: false,
          error: 'Forbidden: Insufficient permissions',
        });
      }

      // Attach roles to request
      req.userRoles = roleResult.rows;
      next();
    } catch (error) {
      logger.error('Role check failed:', error);
      return res.status(500).json({
        success: false,
        error: 'Internal server error',
      });
    }
  };
};

module.exports = {
  verifyFirebaseToken,
  requireRole,
};

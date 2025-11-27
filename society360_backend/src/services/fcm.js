const admin = require('firebase-admin');
const { query } = require('../config/database');
const logger = require('../config/logger');

/**
 * Send FCM push notification to specific users
 * @param {Array<string>} userIds - Array of user IDs to send notification to
 * @param {Object} notification - Notification payload
 * @param {Object} data - Additional data payload
 * @returns {Promise<Object>} - Send results
 */
async function sendNotificationToUsers(userIds, notification, data = {}) {
  try {
    // Fetch active FCM tokens for the users
    const result = await query(
      `SELECT token, user_id, device_type
       FROM fcm_tokens
       WHERE user_id = ANY($1) AND is_active = true`,
      [userIds]
    );

    const tokens = result.rows;

    if (tokens.length === 0) {
      logger.warn(`No active FCM tokens found for users: ${userIds.join(', ')}`);
      return {
        success: false,
        message: 'No active tokens found',
        failedTokens: []
      };
    }

    logger.info(`📤 Sending FCM notification to ${tokens.length} device(s)`, {
      userIds,
      tokenCount: tokens.length,
      notification: notification.title
    });

    // Prepare messages for each token
    const messages = tokens.map(tokenData => ({
      token: tokenData.token,
      notification: {
        title: notification.title,
        body: notification.body,
        ...notification
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1
          }
        }
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          priority: 'high',
          channelId: 'visitor_requests'
        }
      }
    }));

    // Send batch notification
    const batchResponse = await admin.messaging().sendEach(messages);

    logger.info(`✅ FCM batch send complete`, {
      successCount: batchResponse.successCount,
      failureCount: batchResponse.failureCount
    });

    // Handle failed tokens (expired or invalid)
    const failedTokens = [];
    batchResponse.responses.forEach((response, index) => {
      if (!response.success) {
        const error = response.error;
        const tokenData = tokens[index];

        logger.warn(`❌ Failed to send to token (user: ${tokenData.user_id})`, {
          error: error.code,
          message: error.message
        });

        // Mark invalid tokens as inactive
        if (
          error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered'
        ) {
          failedTokens.push(tokenData.token);
        }
      }
    });

    // Deactivate failed tokens
    if (failedTokens.length > 0) {
      await query(
        `UPDATE fcm_tokens
         SET is_active = false, updated_at = now()
         WHERE token = ANY($1)`,
        [failedTokens]
      );
      logger.info(`🗑️  Deactivated ${failedTokens.length} invalid token(s)`);
    }

    return {
      success: batchResponse.successCount > 0,
      successCount: batchResponse.successCount,
      failureCount: batchResponse.failureCount,
      failedTokens
    };

  } catch (error) {
    logger.error('Error sending FCM notification:', error);
    throw error;
  }
}

/**
 * Send visitor request notification to flat residents
 * @param {string} flatId - Flat ID
 * @param {Object} visitorData - Visitor information
 * @returns {Promise<Object>} - Send results
 */
async function sendVisitorRequestNotification(flatId, visitorData) {
  try {
    // Get all residents of the flat
    const residentsResult = await query(
      `SELECT DISTINCT u.id as user_id, u.name
       FROM flat_occupancies fo
       JOIN users u ON fo.user_id = u.id
       WHERE fo.flat_id = $1 AND fo.end_date IS NULL`,
      [flatId]
    );

    if (residentsResult.rows.length === 0) {
      logger.warn(`No residents found for flat: ${flatId}`);
      return {
        success: false,
        message: 'No residents found'
      };
    }

    const userIds = residentsResult.rows.map(r => r.user_id);

    const notification = {
      title: 'Visitor Request',
      body: `${visitorData.visitor_name} wants to visit. Tap to approve or reject.`
    };

    const data = {
      type: 'visitor_request',
      visitor_id: visitorData.id,
      visitor_name: visitorData.visitor_name,
      visitor_phone: visitorData.phone,
      purpose: visitorData.purpose || '',
      flat_id: flatId,
      screen: 'visitor_approvals' // Screen to navigate to
    };

    return await sendNotificationToUsers(userIds, notification, data);

  } catch (error) {
    logger.error('Error sending visitor request notification:', error);
    throw error;
  }
}

module.exports = {
  sendNotificationToUsers,
  sendVisitorRequestNotification
};

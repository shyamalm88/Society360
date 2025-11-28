const admin = require("firebase-admin");
const { query } = require("../config/database");
const logger = require("../config/logger");

/**
 * Notification Service
 * Handles FCM push notifications to mobile devices
 */
class NotificationService {
  /**
   * Send push notification to specific user
   */
  async sendToUser(userId, notification, data = {}) {
    try {
      // Get user's FCM tokens from fcm_tokens table
      const tokensResult = await query(
        "SELECT token FROM fcm_tokens WHERE user_id = $1 AND is_active = true",
        [userId]
      );

      if (tokensResult.rows.length === 0) {
        logger.warn(`No FCM tokens found for user: ${userId}`);
        return { success: false, message: "No devices registered" };
      }

      const tokens = tokensResult.rows.map((row) => row.token);

      // Send multicast message
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          ...data,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      // Log notification
      await query(
        `INSERT INTO notification_logs (user_id, channel, payload, status, created_at, delivered_at)
         VALUES ($1, $2, $3, $4, now(), $5)`,
        [
          userId,
          "push",
          JSON.stringify({ notification, data }),
          response.successCount > 0 ? "delivered" : "failed",
          response.successCount > 0 ? new Date() : null,
        ]
      );

      logger.info(
        `Sent FCM notification to user ${userId}: ${response.successCount}/${tokens.length} devices`
      );

      return {
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
    } catch (error) {
      logger.error("Error sending push notification:", error);
      throw error;
    }
  }

  /**
   * Send visitor request notification to residents of a flat
   */
  async notifyVisitorRequest(flatId, visitorData) {
    try {
      // Get all residents of the flat
      const residentsResult = await query(
        `SELECT DISTINCT u.id as user_id
         FROM flat_occupancies fo
         JOIN users u ON fo.user_id = u.id
         WHERE fo.flat_id = $1 AND fo.end_date IS NULL`,
        [flatId]
      );

      const residents = residentsResult.rows;

      if (residents.length === 0) {
        logger.warn(`No residents found for flat: ${flatId}`);
        return;
      }

      // Send notification to each resident
      const promises = residents.map((resident) =>
        this.sendToUser(
          resident.user_id,
          {
            title: "Visitor Request",
            body: `${visitorData.visitor_name} wants to visit. Tap to approve or reject.`,
          },
          {
            type: "visitor_request",
            visitor_id: visitorData.visitor_id,
            visitor_name: visitorData.visitor_name,
            purpose: visitorData.purpose || "",
            flat_id: flatId,
            screen: "visitor_approvals", // Screen to navigate to
          }
        )
      );

      await Promise.all(promises);
      logger.info(
        `Notified ${residents.length} residents about visitor: ${visitorData.visitor_id}`
      );
    } catch (error) {
      logger.error("Error notifying visitor request:", error);
    }
  }

  /**
   * Send approval/denial notification to guard
   */
  async notifyGuardApproval(societyId, approvalData, options = {}) {
    try {
      // Get all guards of the society
      const guardsResult = await query(
        `SELECT DISTINCT u.id as user_id
         FROM guards g
         JOIN users u ON g.user_id = u.id
         WHERE g.society_id = $1 AND g.active = true`,
        [societyId]
      );

      const guards = guardsResult.rows;

      if (guards.length === 0) {
        logger.warn(`No active guards found for society: ${societyId}`);
        return;
      }

      const decision =
        approvalData.decision === "accept" ? "Approved" : "Rejected";
      const emoji = approvalData.decision === "accept" ? "✅" : "❌";

      // Filter out the user who initiated the action
      const filteredGuards = options.excludeUserId
        ? guards.filter((guard) => guard.user_id !== options.excludeUserId)
        : guards;

      if (filteredGuards.length === 0) return;

      // Send notification to each guard
      const promises = filteredGuards.map((guard) =>
        this.sendToUser(
          guard.user_id,
          {
            title: `${emoji} Visitor ${decision}`,
            body: `${approvalData.visitor_name} ${decision.toLowerCase()} by ${
              approvalData.approver_name
            }`,
          },
          {
            type: "visitor_approval",
            visitor_id: approvalData.visitor_id,
            decision: approvalData.decision,
            status: approvalData.status,
          }
        )
      );

      await Promise.all(promises);
      logger.info(
        `Notified ${filteredGuards.length} guards about approval: ${approvalData.visitor_id}`
      );
    } catch (error) {
      logger.error("Error notifying guard approval:", error);
    }
  }

  /**
   * Send check-in notification to residents
   */
  async notifyVisitorCheckedIn(flatId, visitorData) {
    try {
      // Get all residents of the flat
      const residentsResult = await query(
        `SELECT DISTINCT u.id as user_id
         FROM flat_occupancies fo
         JOIN users u ON fo.user_id = u.id
         WHERE fo.flat_id = $1 AND fo.end_date IS NULL`,
        [flatId]
      );

      const residents = residentsResult.rows;

      if (residents.length === 0) {
        logger.warn(`No residents found for flat: ${flatId}`);
        return;
      }

      // Send notification to each resident
      const promises = residents.map((resident) =>
        this.sendToUser(
          resident.user_id,
          {
            title: "🚪 Visitor Checked In",
            body: `${visitorData.visitor_name} has entered the premises`,
          },
          {
            type: "visitor_checkin",
            visitor_id: visitorData.visitor_id,
            visitor_name: visitorData.visitor_name,
            flat_id: flatId,
          }
        )
      );

      await Promise.all(promises);
      logger.info(
        `Notified ${residents.length} residents about check-in: ${visitorData.visitor_id}`
      );
    } catch (error) {
      logger.error("Error notifying visitor check-in:", error);
    }
  }

  /**
   * Send check-out notification to residents
   */
  async notifyVisitorCheckedOut(flatId, visitorData) {
    try {
      // Get all residents of the flat
      const residentsResult = await query(
        `SELECT DISTINCT u.id as user_id
         FROM flat_occupancies fo
         JOIN users u ON fo.user_id = u.id
         WHERE fo.flat_id = $1 AND fo.end_date IS NULL`,
        [flatId]
      );

      const residents = residentsResult.rows;

      if (residents.length === 0) {
        logger.warn(`No residents found for flat: ${flatId}`);
        return;
      }

      // Send notification to each resident
      const promises = residents.map((resident) =>
        this.sendToUser(
          resident.user_id,
          {
            title: "👋 Visitor Checked Out",
            body: `${visitorData.visitor_name} has left the premises`,
          },
          {
            type: "visitor_checkout",
            visitor_id: visitorData.visitor_id,
            visitor_name: visitorData.visitor_name,
            flat_id: flatId,
          }
        )
      );

      await Promise.all(promises);
      logger.info(
        `Notified ${residents.length} residents about check-out: ${visitorData.visitor_id}`
      );
    } catch (error) {
      logger.error("Error notifying visitor check-out:", error);
    }
  }

  /**
   * Send auto-rejection notification
   */
  async notifyAutoRejection(flatId, societyId, visitorData) {
    try {
      // Notify residents
      const residentsResult = await query(
        `SELECT DISTINCT u.id as user_id
         FROM flat_occupancies fo
         JOIN users u ON fo.user_id = u.id
         WHERE fo.flat_id = $1 AND fo.end_date IS NULL`,
        [flatId]
      );

      const residentPromises = residentsResult.rows.map((resident) =>
        this.sendToUser(
          resident.user_id,
          {
            title: "⏱️ Visitor Request Expired",
            body: `${visitorData.visitor_name} request auto-rejected (no response)`,
          },
          {
            type: "visitor_timeout",
            visitor_id: visitorData.visitor_id,
            visitor_name: visitorData.visitor_name,
          }
        )
      );

      // Notify guards
      const guardsResult = await query(
        `SELECT DISTINCT u.id as user_id
         FROM guards g
         JOIN users u ON g.user_id = u.id
         WHERE g.society_id = $1 AND g.active = true`,
        [societyId]
      );

      const guardPromises = guardsResult.rows.map((guard) =>
        this.sendToUser(
          guard.user_id,
          {
            title: "⏱️ Request Timed Out",
            body: `${visitorData.visitor_name} auto-rejected after 5 minutes`,
          },
          {
            type: "visitor_timeout",
            visitor_id: visitorData.visitor_id,
            visitor_name: visitorData.visitor_name,
          }
        )
      );

      await Promise.all([...residentPromises, ...guardPromises]);
      logger.info(`Notified about auto-rejection: ${visitorData.visitor_id}`);
    } catch (error) {
      logger.error("Error notifying auto-rejection:", error);
    }
  }
}

module.exports = new NotificationService();

const { query, getClient } = require('../config/database');
const logger = require('../config/logger');
const notificationService = require('./notification_service');

/**
 * Visitor Timeout Service
 * Auto-rejects visitor requests that are pending for more than 5 minutes
 */
class VisitorTimeoutService {
  constructor() {
    this.intervalId = null;
    this.CHECK_INTERVAL = 60 * 1000; // Check every 1 minute
    this.TIMEOUT_MINUTES = 5;
  }

  /**
   * Start the timeout checker
   */
  start() {
    if (this.intervalId) {
      logger.warn('Visitor timeout service already running');
      return;
    }

    logger.info('Starting visitor timeout service (5-minute auto-rejection)');

    // Run immediately on start
    this.checkTimedOutVisitors();

    // Then run periodically
    this.intervalId = setInterval(() => {
      this.checkTimedOutVisitors();
    }, this.CHECK_INTERVAL);
  }

  /**
   * Stop the timeout checker
   */
  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
      logger.info('Stopped visitor timeout service');
    }
  }

  /**
   * Check and auto-reject timed out visitors
   */
  async checkTimedOutVisitors() {
    const client = await getClient();

    try {
      await client.query('BEGIN');

      // Find visitors that are pending for more than 5 minutes
      const timeoutThreshold = new Date(Date.now() - this.TIMEOUT_MINUTES * 60 * 1000);

      const timedOutVisitors = await client.query(
        `SELECT v.*,
          f.id as flat_id,
          c.society_id,
          f.flat_number,
          b.name as block_name
         FROM visitors v
         JOIN flats f ON v.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE v.status = 'pending'
           AND v.created_at < $1
           AND (v.approval_deadline IS NULL OR v.approval_deadline < now())`,
        [timeoutThreshold]
      );

      if (timedOutVisitors.rows.length === 0) {
        await client.query('COMMIT');
        return;
      }

      logger.info(`Found ${timedOutVisitors.rows.length} timed-out visitor requests`);

      // Update all timed-out visitors to 'denied'
      for (const visitor of timedOutVisitors.rows) {
        // Update visitor status
        await client.query(
          `UPDATE visitors
           SET status = $1, updated_at = now()
           WHERE id = $2`,
          ['denied', visitor.id]
        );

        // Insert auto-rejection approval record
        await client.query(
          `INSERT INTO visitor_approvals (visitor_id, approver_user_id, approver_role, decision, note, decided_at)
           VALUES ($1, NULL, $2, $3, $4, now())`,
          [
            visitor.id,
            'system',
            'deny',
            'Auto-rejected: No response within 5 minutes',
          ]
        );

        // Log audit
        await client.query(
          `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload, created_at)
           VALUES (NULL, $1, $2, $3, $4, now())`,
          [
            'visitor_auto_rejected',
            'visitor',
            visitor.id,
            JSON.stringify({
              reason: 'timeout',
              timeout_minutes: this.TIMEOUT_MINUTES,
            }),
          ]
        );

        logger.info(`Auto-rejected visitor: ${visitor.id} (${visitor.visitor_name})`);
      }

      await client.query('COMMIT');

      // Send notifications (after commit to ensure data is persisted)
      for (const visitor of timedOutVisitors.rows) {
        // Send FCM push notification
        await notificationService.notifyAutoRejection(
          visitor.flat_id,
          visitor.society_id,
          {
            visitor_id: visitor.id,
            visitor_name: visitor.visitor_name,
          }
        );

        // Emit Socket.io events
        // Note: We need access to io instance, which should be passed during initialization
        if (this.io) {
          // Notify residents
          this.io.to(`flat:${visitor.flat_id}`).emit('visitor_timeout', {
            visitor_id: visitor.id,
            visitor_name: visitor.visitor_name,
            status: 'denied',
            reason: 'timeout',
          });

          // Notify guards
          this.io.to(`society:${visitor.society_id}`).emit('visitor_timeout', {
            visitor_id: visitor.id,
            visitor_name: visitor.visitor_name,
            flat_number: visitor.flat_number,
            block_name: visitor.block_name,
            status: 'denied',
            reason: 'timeout',
          });
        }
      }
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Error checking timed-out visitors:', error);
    } finally {
      client.release();
    }
  }

  /**
   * Set Socket.io instance for real-time notifications
   */
  setSocketIO(io) {
    this.io = io;
  }

  /**
   * Manually reject a specific visitor
   */
  async forceRejectVisitor(visitorId, reason = 'Manual rejection') {
    const client = await getClient();

    try {
      await client.query('BEGIN');

      // Get visitor details
      const visitorResult = await client.query(
        `SELECT v.*, f.id as flat_id, c.society_id
         FROM visitors v
         JOIN flats f ON v.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE v.id = $1`,
        [visitorId]
      );

      if (visitorResult.rows.length === 0) {
        await client.query('ROLLBACK');
        throw new Error('Visitor not found');
      }

      const visitor = visitorResult.rows[0];

      // Update visitor status
      await client.query(
        `UPDATE visitors SET status = $1, updated_at = now() WHERE id = $2`,
        ['denied', visitorId]
      );

      // Insert rejection record
      await client.query(
        `INSERT INTO visitor_approvals (visitor_id, approver_user_id, approver_role, decision, note, decided_at)
         VALUES ($1, NULL, $2, $3, $4, now())`,
        [visitorId, 'system', 'deny', reason]
      );

      await client.query('COMMIT');

      logger.info(`Force rejected visitor: ${visitorId}`);

      return { success: true, visitor };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Error force rejecting visitor:', error);
      throw error;
    } finally {
      client.release();
    }
  }
}

module.exports = new VisitorTimeoutService();

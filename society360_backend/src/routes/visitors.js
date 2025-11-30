const express = require("express");
const router = express.Router();
const { query, getClient } = require("../config/database");
const { verifyFirebaseToken, requireRole } = require("../middleware/auth");
const logger = require("../config/logger");
const notificationService = require("../services/notification_service");

/**
 * Generate a unique 6-digit alphanumeric access code
 */
function generateAccessCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluding ambiguous chars (0, O, I, 1)
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * POST /visitors/guest-pass
 * Create a pre-approved guest pass (by resident)
 * Creates visitor entry with auto_approved=true and QR code
 */
router.post("/guest-pass", verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    logger.info("📥 POST /visitors/guest-pass - Guest pass creation request received", {
      body: req.body,
      user_id: req.user?.id,
      user_phone: req.user?.phone,
      ip: req.ip,
    });

    await client.query("BEGIN");

    const {
      visitor_name,
      phone,
      purpose,
      flat_id,
      expected_start,
      expected_end,
      qr_code,
      number_of_people,
      idempotency_key,
    } = req.body;

    logger.info("📋 Extracted fields", {
      visitor_name,
      phone,
      flat_id,
      purpose,
      qr_code,
      number_of_people,
      has_idempotency_key: !!idempotency_key,
    });

    // Validate required fields
    if (!visitor_name || !phone || !flat_id || !qr_code) {
      logger.warn("❌ Validation failed - missing required fields", {
        has_visitor_name: !!visitor_name,
        has_phone: !!phone,
        has_flat_id: !!flat_id,
        has_qr_code: !!qr_code,
      });
      await client.query("ROLLBACK");
      return res.status(400).json({
        success: false,
        error: "visitor_name, phone, flat_id, and qr_code are required",
      });
    }

    // Check idempotency
    if (idempotency_key) {
      const existingResult = await client.query(
        "SELECT * FROM visitors WHERE idempotency_key = $1",
        [idempotency_key]
      );

      if (existingResult.rows.length > 0) {
        await client.query("COMMIT");
        return res.json({
          success: true,
          data: existingResult.rows[0],
          message: "Guest pass already exists (idempotent)",
        });
      }
    }

    // Check if QR code is unique
    const qrCheck = await client.query(
      "SELECT id FROM visitors WHERE qr_code = $1",
      [qr_code]
    );

    if (qrCheck.rows.length > 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        success: false,
        error: "QR code already exists",
      });
    }

    // Generate unique access code
    let accessCode;
    let isUnique = false;
    while (!isUnique) {
      accessCode = generateAccessCode();
      const codeCheck = await client.query(
        "SELECT id FROM visitors WHERE access_code = $1",
        [accessCode]
      );
      isUnique = codeCheck.rows.length === 0;
    }

    logger.info(`🎫 Generated access code: ${accessCode}`);

    // Insert visitor with pending status (guard must approve after scanning QR/entering access code)
    const visitorResult = await client.query(
      `INSERT INTO visitors (
        visitor_name, phone, purpose, invited_by, flat_id,
        expected_start, expected_end, qr_code, access_code, number_of_people,
        status, auto_approved, idempotency_key, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, now())
      RETURNING *`,
      [
        visitor_name,
        phone,
        purpose || "guest",
        req.user.id,
        flat_id,
        expected_start || new Date(),
        expected_end || null,
        qr_code,
        accessCode,
        number_of_people || 1,
        "pending", // Guest pass requires guard approval at gate
        false, // Not auto-approved - guard must verify
        idempotency_key || null,
      ]
    );

    const visitor = visitorResult.rows[0];

    // Get flat and resident details
    const flatDetailsResult = await client.query(
      `SELECT
        f.id as flat_id, f.flat_number, f.block_id,
        b.name as block_name, b.complex_id,
        c.name as complex_name, c.society_id,
        s.name as society_name,
        u.name as resident_name, u.phone as resident_phone
       FROM flats f
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       JOIN societies s ON c.society_id = s.id
       LEFT JOIN users u ON u.id = $1
       WHERE f.id = $2`,
      [req.user.id, flat_id]
    );

    const flatDetails = flatDetailsResult.rows[0];

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [
        req.user.id,
        "guest_pass_created",
        "visitor",
        visitor.id,
        JSON.stringify({ visitor_name, flat_id, purpose, qr_code, number_of_people }),
      ]
    );

    await client.query("COMMIT");

    logger.info(`✅ Guest pass created: ${visitor.id}, QR: ${qr_code}`);

    res.status(201).json({
      success: true,
      data: {
        visitor,
        flat_details: flatDetails,
      },
    });
  } catch (error) {
    await client.query("ROLLBACK");
    logger.error("Error creating guest pass:", error);

    // Handle unique constraint violations
    if (error.code === '23505' && error.constraint === 'visitors_qr_code_key') {
      return res.status(400).json({
        success: false,
        error: "QR code already exists",
      });
    }

    res.status(500).json({
      success: false,
      error: "Failed to create guest pass",
    });
  } finally {
    client.release();
  }
});

/**
 * GET /visitors/by-qr/:qr_code
 * Get visitor details by QR code (for guard scanning)
 */
router.get("/by-qr/:qr_code", verifyFirebaseToken, async (req, res) => {
  try {
    const { qr_code } = req.params;

    logger.info("🔍 GET /visitors/by-qr - QR code lookup", {
      qr_code,
      user_id: req.user?.id,
    });

    const result = await query(
      `SELECT v.id, v.visitor_name, v.phone, v.vehicle_no, v.purpose,
        v.flat_id, v.status, v.expected_start, v.expected_end, v.number_of_people,
        v.auto_approved, v.created_at, v.invited_by, v.qr_code, v.access_code,
        f.flat_number, b.name as block_name, c.name as complex_name,
        u.name as invited_by_name, u.phone as invited_by_phone,
        vis.id as visit_id, vis.checkin_time, vis.checkout_time
      FROM visitors v
      LEFT JOIN flats f ON v.flat_id = f.id
      LEFT JOIN blocks b ON f.block_id = b.id
      LEFT JOIN complexes c ON b.complex_id = c.id
      LEFT JOIN users u ON v.invited_by = u.id
      LEFT JOIN visits vis ON v.id = vis.visitor_id AND vis.checkout_time IS NULL
      WHERE v.qr_code = $1`,
      [qr_code]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "Guest pass not found",
      });
    }

    const visitor = result.rows[0];

    // Check if guest pass is within valid time window
    if (visitor.expected_start && visitor.expected_end) {
      const now = new Date();
      const startDate = new Date(visitor.expected_start);
      const endDate = new Date(visitor.expected_end);

      if (now < startDate) {
        return res.status(400).json({
          success: false,
          error: "Guest pass is not yet valid. Please use manual visitor entry.",
          error_code: "NOT_YET_VALID",
          data: visitor,
        });
      }

      if (now > endDate) {
        return res.status(400).json({
          success: false,
          error: "Guest pass has expired. Please use manual visitor entry.",
          error_code: "EXPIRED",
          data: visitor,
        });
      }
    }

    res.json({
      success: true,
      data: visitor,
    });
  } catch (error) {
    logger.error("Error fetching visitor by QR code:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch visitor details",
    });
  }
});

/**
 * GET /visitors/by-access-code/:access_code
 * Get visitor details by access code (for manual entry by guard)
 */
router.get("/by-access-code/:access_code", verifyFirebaseToken, async (req, res) => {
  try {
    const { access_code } = req.params;

    logger.info("🔍 GET /visitors/by-access-code - Access code lookup", {
      access_code,
      user_id: req.user?.id,
    });

    const result = await query(
      `SELECT v.id, v.visitor_name, v.phone, v.vehicle_no, v.purpose,
        v.flat_id, v.status, v.expected_start, v.expected_end, v.number_of_people,
        v.auto_approved, v.created_at, v.invited_by, v.qr_code, v.access_code,
        f.flat_number, b.name as block_name, c.name as complex_name,
        u.name as invited_by_name, u.phone as invited_by_phone,
        vis.id as visit_id, vis.checkin_time, vis.checkout_time
      FROM visitors v
      LEFT JOIN flats f ON v.flat_id = f.id
      LEFT JOIN blocks b ON f.block_id = b.id
      LEFT JOIN complexes c ON b.complex_id = c.id
      LEFT JOIN users u ON v.invited_by = u.id
      LEFT JOIN visits vis ON v.id = vis.visitor_id AND vis.checkout_time IS NULL
      WHERE UPPER(v.access_code) = UPPER($1)`,
      [access_code]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "Guest pass not found with this access code",
      });
    }

    const visitor = result.rows[0];

    // Check if guest pass is within valid time window
    if (visitor.expected_start && visitor.expected_end) {
      const now = new Date();
      const startDate = new Date(visitor.expected_start);
      const endDate = new Date(visitor.expected_end);

      if (now < startDate) {
        return res.status(400).json({
          success: false,
          error: "Guest pass is not yet valid. Please use manual visitor entry.",
          error_code: "NOT_YET_VALID",
          data: visitor,
        });
      }

      if (now > endDate) {
        return res.status(400).json({
          success: false,
          error: "Guest pass has expired. Please use manual visitor entry.",
          error_code: "EXPIRED",
          data: visitor,
        });
      }
    }

    res.json({
      success: true,
      data: visitor,
    });
  } catch (error) {
    logger.error("Error fetching visitor by access code:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch visitor details",
    });
  }
});

/**
 * POST /visitors
 * Create a new visitor entry (typically by guard)
 * Emits Socket.io event + sends FCM push notification to residents
 */
router.post("/", verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    logger.info("📥 POST /visitors - Visitor creation request received", {
      body: req.body,
      user_id: req.user?.id,
      user_phone: req.user?.phone,
      ip: req.ip,
    });

    await client.query("BEGIN");

    const {
      visitor_name,
      phone,
      id_type,
      id_number,
      vehicle_no,
      purpose,
      invited_by,
      flat_id,
      expected_start,
      expected_end,
      idempotency_key,
    } = req.body;

    logger.info("📋 Extracted fields", {
      visitor_name,
      phone,
      flat_id,
      purpose,
      invited_by,
      has_idempotency_key: !!idempotency_key,
    });

    // Validate required fields
    if (!visitor_name || !phone || !flat_id) {
      logger.warn("❌ Validation failed - missing required fields", {
        has_visitor_name: !!visitor_name,
        has_phone: !!phone,
        has_flat_id: !!flat_id,
      });
      await client.query("ROLLBACK");
      return res.status(400).json({
        success: false,
        error: "visitor_name, phone, and flat_id are required",
      });
    }

    // Check idempotency
    if (idempotency_key) {
      const existingResult = await client.query(
        "SELECT * FROM visitors WHERE idempotency_key = $1",
        [idempotency_key]
      );

      if (existingResult.rows.length > 0) {
        await client.query("COMMIT");
        return res.json({
          success: true,
          data: existingResult.rows[0],
          message: "Visitor already exists (idempotent)",
        });
      }
    }

    // Set approval deadline to 5 minutes from now
    const approvalDeadline = new Date(Date.now() + 5 * 60 * 1000);

    // Insert visitor
    const visitorResult = await client.query(
      `INSERT INTO visitors (
        visitor_name, phone, id_type, id_number, vehicle_no, purpose,
        invited_by, flat_id, expected_start, expected_end, status,
        approval_deadline, idempotency_key, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, now())
      RETURNING *`,
      [
        visitor_name,
        phone,
        id_type || null,
        id_number || null,
        vehicle_no || null,
        purpose || "guest",
        invited_by || req.user.id,
        flat_id,
        expected_start || new Date(),
        expected_end || null,
        "pending",
        approvalDeadline,
        idempotency_key || null,
      ]
    );

    const visitor = visitorResult.rows[0];

    // Get flat and resident details
    const flatDetailsResult = await client.query(
      `SELECT
        f.id as flat_id, f.flat_number, f.block_id,
        b.name as block_name, b.complex_id,
        c.name as complex_name, c.society_id,
        s.name as society_name,
        fo.user_id as resident_user_id,
        u.name as resident_name, u.phone as resident_phone
       FROM flats f
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       JOIN societies s ON c.society_id = s.id
       LEFT JOIN flat_occupancies fo ON f.id = fo.flat_id AND fo.end_date IS NULL
       LEFT JOIN users u ON fo.user_id = u.id
       WHERE f.id = $1`,
      [flat_id]
    );

    const flatDetails = flatDetailsResult.rows[0];

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [
        req.user.id,
        "visitor_created",
        "visitor",
        visitor.id,
        JSON.stringify({ visitor_name, flat_id, purpose }),
      ]
    );

    await client.query("COMMIT");

    // Prepare notification data
    const visitorNotificationData = {
      visitor_id: visitor.id,
      visitor_name: visitor.visitor_name,
      phone: visitor.phone,
      purpose: visitor.purpose,
      vehicle_no: visitor.vehicle_no,
      flat_number: flatDetails?.flat_number,
      block_name: flatDetails?.block_name,
      society_name: flatDetails?.society_name,
      expected_start: visitor.expected_start,
      created_at: visitor.created_at,
      status: visitor.status,
      approval_deadline: visitor.approval_deadline,
    };

    // Emit Socket.io event to flat room (real-time for active users)
    const io = req.app.get("io");
    const flatRoomName = `flat:${flat_id}`;

    logger.info(`📡 Emitting visitor_request event`, {
      room: flatRoomName,
      visitor_id: visitor.id,
      visitor_name: visitor.visitor_name,
      flat_number: flatDetails?.flat_number,
      connected_sockets: io.sockets.adapter.rooms.get(flatRoomName)?.size || 0,
    });

    io.to(flatRoomName).emit("visitor_request", visitorNotificationData);

    logger.info(`✅ Socket.io event emitted to room: ${flatRoomName}`, {
      data: visitorNotificationData,
    });

    // Send FCM push notification (for users not actively using app)
    notificationService
      .notifyVisitorRequest(flat_id, {
        visitor_id: visitor.id,
        visitor_name: visitor.visitor_name,
        purpose: visitor.purpose,
      })
      .catch((err) => logger.error("Failed to send FCM notification:", err));

    logger.info(`✅ Visitor created: ${visitor.id}, room: ${flatRoomName}`);

    res.status(201).json({
      success: true,
      data: {
        visitor,
        flat_details: flatDetails,
      },
    });
  } catch (error) {
    await client.query("ROLLBACK");
    logger.error("Error creating visitor:", error);
    res.status(500).json({
      success: false,
      error: "Failed to create visitor",
    });
  } finally {
    client.release();
  }
});

/**
 * GET /visitors
 * Get visitors with optional filters
 */
router.get("/", verifyFirebaseToken, async (req, res) => {
  try {
    const { flat_id, status, date_from, date_to } = req.query;

    let queryText = `
      SELECT v.id, v.visitor_name, v.phone, v.vehicle_no, v.purpose,
        v.flat_id, v.status, v.expected_start, v.expected_end,
        v.approval_deadline, v.created_at, v.invited_by,
        f.flat_number, b.name as block_name,
        u.name as invited_by_name,
        vis.id as visit_id
      FROM visitors v
      LEFT JOIN flats f ON v.flat_id = f.id
      LEFT JOIN blocks b ON f.block_id = b.id
      LEFT JOIN users u ON v.invited_by = u.id
      LEFT JOIN visits vis ON v.id = vis.visitor_id AND vis.checkout_time IS NULL
      WHERE 1=1
    `;
    const params = [];

    if (flat_id) {
      params.push(flat_id);
      queryText += ` AND v.flat_id = $${params.length}`;
    }

    if (status) {
      params.push(status);
      queryText += ` AND v.status = $${params.length}`;
    }

    if (date_from) {
      params.push(date_from);
      queryText += ` AND v.created_at >= $${params.length}`;
    }

    if (date_to) {
      params.push(date_to);
      queryText += ` AND v.created_at <= $${params.length}`;
    }

    queryText += " ORDER BY v.created_at DESC LIMIT 100";

    const result = await query(queryText, params);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error("Error fetching visitors:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch visitors",
    });
  }
});

/**
 * GET /visitors/pending-count
 * Get count of pending visitor requests for a specific flat
 */
router.get("/pending-count", verifyFirebaseToken, async (req, res) => {
  try {
    const { flat_id } = req.query;

    if (!flat_id) {
      return res.status(400).json({
        success: false,
        error: "flat_id is required",
      });
    }

    const result = await query(
      `SELECT COUNT(*) as count
       FROM visitors
       WHERE flat_id = $1
         AND status = 'pending'
         AND qr_code IS NULL
         AND access_code IS NULL
         AND (expected_end IS NULL OR expected_end > NOW())`,
      [flat_id]
    );

    res.json({
      success: true,
      data: {
        flat_id,
        pending_count: parseInt(result.rows[0].count),
      },
    });
  } catch (error) {
    logger.error("Error fetching pending count:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch pending count",
    });
  }
});

/**
 * POST /visitors/:id/respond
 * Resident approves or denies visitor request
 * Emits Socket.io event + sends FCM push notification to guards
 */
router.post("/:id/respond", verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query("BEGIN");

    const visitorId = req.params.id;
    const { decision, note } = req.body;

    if (!decision || !["accept", "deny"].includes(decision)) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        success: false,
        error: 'decision must be either "accept" or "deny"',
      });
    }

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
      await client.query("ROLLBACK");
      return res.status(404).json({
        success: false,
        error: "Visitor not found",
      });
    }

    const visitor = visitorResult.rows[0];

    // Check if already responded
    if (visitor.status !== "pending") {
      await client.query("ROLLBACK");
      return res.status(400).json({
        success: false,
        error: `Visitor already ${visitor.status}`,
      });
    }

    // Update visitor status
    const newStatus = decision === "accept" ? "accepted" : "denied";
    await client.query(
      "UPDATE visitors SET status = $1, updated_at = now() WHERE id = $2",
      [newStatus, visitorId]
    );

    // Get user roles
    const rolesResult = await client.query(
      "SELECT role FROM role_assignments WHERE user_id = $1 AND revoked = false",
      [req.user.id]
    );

    const userRole = rolesResult.rows[0]?.role || "resident";

    // Insert approval record
    await client.query(
      `INSERT INTO visitor_approvals (visitor_id, approver_user_id, approver_role, decision, note, decided_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [visitorId, req.user.id, userRole, decision, note || null]
    );

    // Log audit
    await client.query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
      [
        req.user.id,
        "visitor_responded",
        "visitor",
        visitorId,
        JSON.stringify({ decision, note }),
      ]
    );

    await client.query("COMMIT");

    // Prepare approval data
    const approvalData = {
      visitor_id: visitorId,
      visitor_name: visitor.visitor_name,
      decision,
      status: newStatus,
      approver_name: req.user.name,
      note,
      timestamp: new Date(),
    };

    // Emit Socket.io event to guard/society room
    const io = req.app.get("io");
    const guardRoomName = `society:${visitor.society_id}`;
    io.to(guardRoomName).emit("request_approved", approvalData);

    // Send FCM push notification to guards
    notificationService
      .notifyGuardApproval(visitor.society_id, approvalData, {
        excludeUserId: req.user.id,
      }) // Exclude the approver from notification
      .catch((err) => logger.error("Failed to send FCM notification:", err));

    logger.info(`✅ Visitor ${decision}: ${visitorId}, room: ${guardRoomName}`);

    res.json({
      success: true,
      data: {
        visitor_id: visitorId,
        decision,
        status: newStatus,
      },
    });
  } catch (error) {
    await client.query("ROLLBACK");
    logger.error("Error responding to visitor:", error);
    res.status(500).json({
      success: false,
      error: "Failed to respond to visitor request",
    });
  } finally {
    client.release();
  }
});

/**
 * POST /visitors/:id/guard-respond
 * Guard manually approves or denies visitor (after timeout or manual verification)
 */
router.post(
  "/:id/guard-respond",
  verifyFirebaseToken,
  requireRole(["guard", "society_admin"]),
  async (req, res) => {
    const client = await getClient();

    try {
      await client.query("BEGIN");

      const visitorId = req.params.id;
      const { decision, note } = req.body;

      if (!decision || !["accept", "deny"].includes(decision)) {
        await client.query("ROLLBACK");
        return res.status(400).json({
          success: false,
          error: 'decision must be either "accept" or "deny"',
        });
      }

      // Get visitor details
      const visitorResult = await client.query(
        "SELECT * FROM visitors WHERE id = $1",
        [visitorId]
      );

      if (visitorResult.rows.length === 0) {
        await client.query("ROLLBACK");
        return res.status(404).json({
          success: false,
          error: "Visitor not found",
        });
      }

      const visitor = visitorResult.rows[0];

      // Check if guest pass is within valid time window (for accept decision)
      if (decision === "accept" && visitor.expected_start && visitor.expected_end) {
        const now = new Date();
        const startDate = new Date(visitor.expected_start);
        const endDate = new Date(visitor.expected_end);

        if (now < startDate) {
          await client.query("ROLLBACK");
          return res.status(400).json({
            success: false,
            error: "Guest pass is not yet valid. Please use manual visitor entry.",
            error_code: "NOT_YET_VALID",
          });
        }

        if (now > endDate) {
          await client.query("ROLLBACK");
          return res.status(400).json({
            success: false,
            error: "Guest pass has expired. Please use manual visitor entry.",
            error_code: "EXPIRED",
          });
        }
      }

      // Update visitor status
      const newStatus = decision === "accept" ? "accepted" : "denied";
      await client.query(
        "UPDATE visitors SET status = $1, auto_approved = $2, updated_at = now() WHERE id = $3",
        [newStatus, decision === "accept", visitorId]
      );

      // Insert approval record
      await client.query(
        `INSERT INTO visitor_approvals (visitor_id, approver_user_id, approver_role, decision, note, decided_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
        [
          visitorId,
          req.user.id,
          "guard",
          decision,
          note || "Manual guard verification",
        ]
      );

      // Log audit
      await client.query(
        `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5, now())`,
        [
          req.user.id,
          "visitor_guard_override",
          "visitor",
          visitorId,
          JSON.stringify({ decision, note }),
        ]
      );

      await client.query("COMMIT");

      logger.info(
        `✅ Guard ${decision} visitor: ${visitorId} by ${req.user.name}`
      );

      res.json({
        success: true,
        data: {
          visitor_id: visitorId,
          decision,
          status: newStatus,
          manual_approval: true,
        },
      });
    } catch (error) {
      await client.query("ROLLBACK");
      logger.error("Error in guard response:", error);
      res.status(500).json({
        success: false,
        error: "Failed to process guard response",
      });
    } finally {
      client.release();
    }
  }
);

/**
 * POST /visitors/:id/send-invite
 * Send invite notification to visitor (SMS/WhatsApp)
 */
router.post("/:id/send-invite", verifyFirebaseToken, async (req, res) => {
  try {
    const visitorId = req.params.id;

    // Get visitor details
    const visitorResult = await query(
      `SELECT v.*, f.flat_number, b.name as block_name, s.name as society_name
       FROM visitors v
       JOIN flats f ON v.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       JOIN societies s ON c.society_id = s.id
       WHERE v.id = $1`,
      [visitorId]
    );

    if (visitorResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: "Visitor not found",
      });
    }

    const visitor = visitorResult.rows[0];

    // Log notification (actual SMS/WhatsApp integration would go here)
    await query(
      `INSERT INTO notification_logs (user_id, channel, payload, status, created_at)
       VALUES ($1, $2, $3, $4, now())`,
      [
        null,
        "sms",
        JSON.stringify({
          phone: visitor.phone,
          message: `You have been invited to ${visitor.society_name}, ${visitor.block_name} - ${visitor.flat_number}`,
        }),
        "pending",
      ]
    );

    res.json({
      success: true,
      message: "Invite sent successfully",
    });
  } catch (error) {
    logger.error("Error sending invite:", error);
    res.status(500).json({
      success: false,
      error: "Failed to send invite",
    });
  }
});

/**
 * GET /visitors/pending
 * Get pending visitor requests for the current user's flats
 */
router.get("/pending", verifyFirebaseToken, async (req, res) => {
  try {
    const userId = req.user.id;

    // Get pending visitors for user's flats (excluding guest passes)
    // Guest passes are pre-approved by resident and only need guard verification
    const result = await query(
      `SELECT DISTINCT ON (v.id)
        v.id, v.visitor_name, v.phone, v.purpose, v.vehicle_no,
        v.expected_start, v.expected_end, v.status, v.approval_deadline, v.created_at,
        f.id as flat_id, f.flat_number,
        b.name as block_name,
        c.name as complex_name
       FROM visitors v
       JOIN flats f ON v.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       JOIN flat_occupancies fo ON f.id = fo.flat_id
       WHERE fo.user_id = $1
         AND fo.end_date IS NULL
         AND v.status = 'pending'
         AND v.qr_code IS NULL
         AND v.access_code IS NULL
         AND (v.expected_end IS NULL OR v.expected_end > NOW())
       ORDER BY v.id, v.created_at DESC`,
      [userId]
    );

    logger.info(
      `✅ Fetched ${result.rows.length} pending visitor(s) for user ${userId}`
    );

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length,
    });
  } catch (error) {
    logger.error("Error fetching pending visitors:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch pending visitors",
    });
  }
});

/**
 * DELETE /visitors/rejected
 * Delete all rejected visitors for the authenticated user's society
 * Only accessible by guards
 */
router.delete("/rejected", verifyFirebaseToken, async (req, res) => {
  const client = await getClient();

  try {
    await client.query("BEGIN");

    logger.info("🗑️ DELETE /visitors/rejected - Soft deleting rejected visitors", {
      user_id: req.user?.id,
      user_phone: req.user?.phone,
      ip: req.ip,
    });

    // Get the guard's society ID
    const guardResult = await client.query(
      "SELECT society_id FROM guards WHERE user_id = $1",
      [req.user.id]
    );

    if (guardResult.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(403).json({
        success: false,
        error: "Guard not found",
      });
    }

    const societyId = guardResult.rows[0].society_id;

    // Delete rejected visitors
    // Join through flats -> blocks -> complexes to get society_id
    const result = await client.query(
      `DELETE FROM visitors v
       USING flats f, blocks b, complexes c
       WHERE v.flat_id = f.id
       AND f.block_id = b.id
       AND b.complex_id = c.id
       AND v.status = 'denied'
       AND c.society_id = $1
       RETURNING v.id`,
      [societyId]
    );

    await client.query("COMMIT");

    logger.info(`✅ Deleted ${result.rowCount} rejected visitors for society ${societyId}`);

    // Emit Socket.io event to notify guards that rejected visitors were cleared
    const io = req.app.get("io");
    const societyRoomName = `society:${societyId}`;
    io.to(societyRoomName).emit("rejected_visitors_cleared", {
      society_id: societyId,
      deleted_count: result.rowCount,
      cleared_at: new Date().toISOString(),
    });

    logger.info(`📡 Socket.io event 'rejected_visitors_cleared' emitted to room: ${societyRoomName}`, {
      deleted_count: result.rowCount,
    });

    res.json({
      success: true,
      message: `Successfully deleted ${result.rowCount} rejected visitor(s)`,
      deleted_count: result.rowCount,
    });
  } catch (error) {
    await client.query("ROLLBACK");
    logger.error("Error soft deleting rejected visitors:", error);

    // If error is about column not existing, provide helpful message
    if (error.message && error.message.includes("deleted_at")) {
      return res.status(500).json({
        success: false,
        error: "Database schema needs migration. Please add 'deleted_at' column to visitors table.",
      });
    }

    res.status(500).json({
      success: false,
      error: "Failed to delete rejected visitors",
    });
  } finally {
    client.release();
  }
});

module.exports = router;

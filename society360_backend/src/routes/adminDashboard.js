const express = require('express');
const { query } = require('../config/database');
const logger = require('../config/logger');
const { verifyAdminToken, requireAdminRole } = require('../middleware/adminAuth');

const router = express.Router();

/**
 * GET /admin/dashboard/saas
 * Super Admin Dashboard - SaaS Overview
 */
router.get('/saas', verifyAdminToken, requireAdminRole(['super_admin']), async (req, res) => {
  try {
    // Get overall statistics
    const statsResult = await query(`
      SELECT
        (SELECT COUNT(*) FROM societies) as total_societies,
        (SELECT COUNT(*) FROM users WHERE is_deleted = false) as total_users,
        (SELECT COUNT(*) FROM flat_occupancies WHERE end_date IS NULL) as total_residents,
        (SELECT COUNT(*) FROM guards WHERE active = true) as total_guards,
        (SELECT COUNT(*) FROM visitors WHERE created_at >= CURRENT_DATE) as visitors_today,
        (SELECT COUNT(*) FROM emergencies WHERE resolved_at IS NULL) as active_emergencies
    `);

    // Get recent societies
    const recentSocietiesResult = await query(`
      SELECT s.*,
        (SELECT COUNT(*) FROM flat_occupancies fo
         JOIN flats f ON fo.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = s.id AND fo.end_date IS NULL) as resident_count
      FROM societies s
      ORDER BY s.created_at DESC
      LIMIT 5
    `);

    // Get visitor trends (last 7 days)
    const visitorTrendsResult = await query(`
      SELECT
        DATE(created_at) as date,
        COUNT(*) as count,
        COUNT(*) FILTER (WHERE status = 'checked_in' OR status = 'checked_out') as approved
      FROM visitors
      WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
      GROUP BY DATE(created_at)
      ORDER BY date
    `);

    // Get active emergencies
    const emergenciesResult = await query(`
      SELECT e.*,
        u.name as reported_by_name,
        u.phone as reported_by_phone,
        s.name as society_name,
        f.flat_number,
        b.name as block_name
      FROM emergencies e
      LEFT JOIN users u ON e.reported_by_user_id = u.id
      LEFT JOIN flats f ON e.flat_id = f.id
      LEFT JOIN blocks b ON f.block_id = b.id
      LEFT JOIN complexes c ON b.complex_id = c.id
      LEFT JOIN societies s ON c.society_id = s.id
      WHERE e.resolved_at IS NULL
      ORDER BY e.created_at DESC
      LIMIT 10
    `);

    res.json({
      success: true,
      data: {
        stats: statsResult.rows[0],
        recentSocieties: recentSocietiesResult.rows,
        visitorTrends: visitorTrendsResult.rows,
        activeEmergencies: emergenciesResult.rows,
      },
    });
  } catch (error) {
    logger.error('SaaS dashboard error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /admin/dashboard/society/:societyId
 * Society Admin Dashboard
 */
router.get('/society/:societyId', verifyAdminToken, async (req, res) => {
  try {
    const { societyId } = req.params;

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === societyId);

    if (!isSuperAdmin && !hasSocietyAccess) {
      return res.status(403).json({
        success: false,
        error: 'No access to this society',
      });
    }

    // Get society stats
    const statsResult = await query(`
      SELECT
        (SELECT COUNT(*) FROM flat_occupancies fo
         JOIN flats f ON fo.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1 AND fo.end_date IS NULL) as total_residents,
        (SELECT COUNT(*) FROM flats f
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1) as total_flats,
        (SELECT COUNT(*) FROM guards g WHERE g.society_id = $1 AND g.active = true) as total_guards,
        (SELECT COUNT(*) FROM visitors v
         JOIN flats f ON v.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1 AND v.created_at >= CURRENT_DATE) as visitors_today,
        (SELECT COUNT(*) FROM visitors v
         JOIN flats f ON v.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1 AND v.status = 'checked_in') as active_visitors,
        (SELECT COUNT(*) FROM emergencies e
         JOIN flats f ON e.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1 AND e.resolved_at IS NULL) as active_emergencies,
        (SELECT COUNT(*) FROM complaints c WHERE c.society_id = $1 AND c.status IN ('open', 'in_progress')) as open_complaints,
        (SELECT COUNT(*) FROM resident_requests rr
         JOIN flats f ON rr.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1 AND rr.status = 'pending') as pending_approvals
    `, [societyId]);

    // Get live gate feed (currently checked-in visitors)
    const liveGateFeedResult = await query(`
      SELECT v.*,
        f.flat_number,
        b.name as block_name,
        vi.checkin_time
      FROM visitors v
      JOIN flats f ON v.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN complexes c ON b.complex_id = c.id
      LEFT JOIN visits vi ON vi.visitor_id = v.id AND vi.checkout_time IS NULL
      WHERE c.society_id = $1 AND v.status = 'checked_in'
      ORDER BY vi.checkin_time DESC
      LIMIT 20
    `, [societyId]);

    // Get recent notices
    const recentNoticesResult = await query(`
      SELECT n.*, u.name as created_by_name
      FROM notices n
      LEFT JOIN users u ON n.created_by = u.id
      WHERE n.society_id = $1 AND n.published = true
      ORDER BY n.is_pinned DESC, n.created_at DESC
      LIMIT 5
    `, [societyId]);

    // Get complaint summary
    const complaintSummaryResult = await query(`
      SELECT status, COUNT(*) as count
      FROM complaints
      WHERE society_id = $1
      GROUP BY status
    `, [societyId]);

    const complaintSummary = {};
    complaintSummaryResult.rows.forEach(row => {
      complaintSummary[row.status] = parseInt(row.count);
    });

    // Get active emergencies
    const emergenciesResult = await query(`
      SELECT e.*,
        u.name as reported_by_name,
        u.phone as reported_by_phone,
        f.flat_number,
        b.name as block_name
      FROM emergencies e
      LEFT JOIN users u ON e.reported_by_user_id = u.id
      LEFT JOIN flats f ON e.flat_id = f.id
      LEFT JOIN blocks b ON f.block_id = b.id
      LEFT JOIN complexes c ON b.complex_id = c.id
      WHERE c.society_id = $1 AND e.resolved_at IS NULL
      ORDER BY e.created_at DESC
    `, [societyId]);

    // Get visitor trends (last 7 days)
    const visitorTrendsResult = await query(`
      SELECT
        DATE(v.created_at) as date,
        COUNT(*) as count
      FROM visitors v
      JOIN flats f ON v.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN complexes c ON b.complex_id = c.id
      WHERE c.society_id = $1 AND v.created_at >= CURRENT_DATE - INTERVAL '7 days'
      GROUP BY DATE(v.created_at)
      ORDER BY date
    `, [societyId]);

    res.json({
      success: true,
      data: {
        stats: statsResult.rows[0],
        liveGateFeed: liveGateFeedResult.rows,
        recentNotices: recentNoticesResult.rows,
        complaintSummary,
        activeEmergencies: emergenciesResult.rows,
        visitorTrends: visitorTrendsResult.rows,
      },
    });
  } catch (error) {
    logger.error('Society dashboard error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /admin/dashboard/gate-logs/:societyId
 * Gate logs for security supervisor
 */
router.get('/gate-logs/:societyId', verifyAdminToken, async (req, res) => {
  try {
    const { societyId } = req.params;
    const { date, page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    // Verify access
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');
    const hasSocietyAccess = roles.some(r => r.scope_type === 'society' && r.scope_id === societyId);
    const isGuard = roles.some(r => r.role === 'guard');

    if (!isSuperAdmin && !hasSocietyAccess && !isGuard) {
      return res.status(403).json({
        success: false,
        error: 'No access to gate logs',
      });
    }

    const targetDate = date || new Date().toISOString().split('T')[0];

    // Get visitor logs for the day
    const logsResult = await query(`
      SELECT v.*,
        f.flat_number,
        b.name as block_name,
        vi.checkin_time,
        vi.checkout_time,
        g.id as guard_id,
        gu.name as guard_name
      FROM visitors v
      JOIN flats f ON v.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN complexes c ON b.complex_id = c.id
      LEFT JOIN visits vi ON vi.visitor_id = v.id
      LEFT JOIN guards g ON vi.guard_id = g.id
      LEFT JOIN users gu ON g.user_id = gu.id
      WHERE c.society_id = $1
        AND DATE(v.created_at) = $2
      ORDER BY v.created_at DESC
      LIMIT $3 OFFSET $4
    `, [societyId, targetDate, limit, offset]);

    // Get counts
    const countsResult = await query(`
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE v.status = 'checked_in') as checked_in,
        COUNT(*) FILTER (WHERE v.status = 'checked_out') as checked_out,
        COUNT(*) FILTER (WHERE v.status = 'pending') as pending,
        COUNT(*) FILTER (WHERE v.status = 'denied') as denied
      FROM visitors v
      JOIN flats f ON v.flat_id = f.id
      JOIN blocks b ON f.block_id = b.id
      JOIN complexes c ON b.complex_id = c.id
      WHERE c.society_id = $1 AND DATE(v.created_at) = $2
    `, [societyId, targetDate]);

    res.json({
      success: true,
      data: {
        logs: logsResult.rows,
        counts: countsResult.rows[0],
        date: targetDate,
      },
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countsResult.rows[0].total),
      },
    });
  } catch (error) {
    logger.error('Gate logs error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

module.exports = router;

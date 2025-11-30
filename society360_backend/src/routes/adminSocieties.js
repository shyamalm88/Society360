const express = require('express');
const { query } = require('../config/database');
const logger = require('../config/logger');
const { verifyAdminToken, requireAdminRole, requireSocietyAccess } = require('../middleware/adminAuth');

const router = express.Router();

/**
 * GET /admin/societies
 * List all societies (Super Admin) or assigned societies
 */
router.get('/', verifyAdminToken, async (req, res) => {
  try {
    const roles = req.userRoles;
    const isSuperAdmin = roles.some(r => r.role === 'super_admin');

    let societiesQuery;
    let params = [];

    if (isSuperAdmin) {
      societiesQuery = `
        SELECT s.*,
          (SELECT COUNT(*) FROM blocks b JOIN complexes c ON b.complex_id = c.id WHERE c.society_id = s.id) as block_count,
          (SELECT COUNT(*) FROM flats f JOIN blocks b ON f.block_id = b.id JOIN complexes c ON b.complex_id = c.id WHERE c.society_id = s.id) as flat_count,
          (SELECT COUNT(*) FROM flat_occupancies fo
           JOIN flats f ON fo.flat_id = f.id
           JOIN blocks b ON f.block_id = b.id
           JOIN complexes c ON b.complex_id = c.id
           WHERE c.society_id = s.id AND fo.end_date IS NULL) as resident_count
        FROM societies s
        ORDER BY s.created_at DESC
      `;
    } else {
      const societyIds = roles.filter(r => r.scope_type === 'society').map(r => r.scope_id);
      societiesQuery = `
        SELECT s.*,
          (SELECT COUNT(*) FROM blocks b JOIN complexes c ON b.complex_id = c.id WHERE c.society_id = s.id) as block_count,
          (SELECT COUNT(*) FROM flats f JOIN blocks b ON f.block_id = b.id JOIN complexes c ON b.complex_id = c.id WHERE c.society_id = s.id) as flat_count,
          (SELECT COUNT(*) FROM flat_occupancies fo
           JOIN flats f ON fo.flat_id = f.id
           JOIN blocks b ON f.block_id = b.id
           JOIN complexes c ON b.complex_id = c.id
           WHERE c.society_id = s.id AND fo.end_date IS NULL) as resident_count
        FROM societies s
        WHERE s.id = ANY($1)
        ORDER BY s.created_at DESC
      `;
      params = [societyIds];
    }

    const result = await query(societiesQuery, params);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('List societies error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /admin/societies/:id
 * Get society details with structure
 */
router.get('/:societyId', verifyAdminToken, requireSocietyAccess, async (req, res) => {
  try {
    const { societyId } = req.params;

    // Get society details
    const societyResult = await query(
      `SELECT * FROM societies WHERE id = $1`,
      [societyId]
    );

    if (societyResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Society not found',
      });
    }

    // Get complexes with blocks and flats
    const structureResult = await query(
      `SELECT
        c.id as complex_id, c.name as complex_name,
        b.id as block_id, b.name as block_name,
        COUNT(f.id) as flat_count
       FROM complexes c
       LEFT JOIN blocks b ON b.complex_id = c.id
       LEFT JOIN flats f ON f.block_id = b.id
       WHERE c.society_id = $1
       GROUP BY c.id, c.name, b.id, b.name
       ORDER BY c.name, b.name`,
      [societyId]
    );

    // Organize structure
    const complexesMap = new Map();
    structureResult.rows.forEach(row => {
      if (!complexesMap.has(row.complex_id)) {
        complexesMap.set(row.complex_id, {
          id: row.complex_id,
          name: row.complex_name,
          blocks: [],
        });
      }
      if (row.block_id) {
        complexesMap.get(row.complex_id).blocks.push({
          id: row.block_id,
          name: row.block_name,
          flatCount: parseInt(row.flat_count),
        });
      }
    });

    // Get statistics
    const statsResult = await query(
      `SELECT
        (SELECT COUNT(*) FROM flat_occupancies fo
         JOIN flats f ON fo.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1 AND fo.end_date IS NULL) as resident_count,
        (SELECT COUNT(*) FROM guards g WHERE g.society_id = $1 AND g.active = true) as guard_count,
        (SELECT COUNT(*) FROM visitors v
         JOIN flats f ON v.flat_id = f.id
         JOIN blocks b ON f.block_id = b.id
         JOIN complexes c ON b.complex_id = c.id
         WHERE c.society_id = $1 AND v.status = 'checked_in') as active_visitors,
        (SELECT COUNT(*) FROM emergencies e WHERE e.society_id = $1 AND e.resolved_at IS NULL) as active_emergencies`,
      [societyId]
    );

    // Get policies
    const policiesResult = await query(
      `SELECT key, value FROM policies WHERE society_id = $1`,
      [societyId]
    );

    const policies = {};
    policiesResult.rows.forEach(row => {
      policies[row.key] = row.value;
    });

    res.json({
      success: true,
      data: {
        society: societyResult.rows[0],
        structure: Array.from(complexesMap.values()),
        stats: statsResult.rows[0],
        policies,
      },
    });
  } catch (error) {
    logger.error('Get society error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /admin/societies
 * Create new society (Super Admin only)
 */
router.post('/', verifyAdminToken, requireAdminRole(['super_admin']), async (req, res) => {
  try {
    const { name, address, city, timezone, logoUrl, metadata } = req.body;

    if (!name) {
      return res.status(400).json({
        success: false,
        error: 'Society name is required',
      });
    }

    // Generate slug from name
    const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

    // Check if slug exists
    const slugCheck = await query(`SELECT id FROM societies WHERE slug = $1`, [slug]);
    const finalSlug = slugCheck.rows.length > 0 ? `${slug}-${Date.now()}` : slug;

    const result = await query(
      `INSERT INTO societies (name, slug, address, city, timezone, logo_url, metadata, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [name, finalSlug, address, city, timezone || 'Asia/Kolkata', logoUrl, metadata || {}, req.adminUser.userId]
    );

    // Create default complex
    const complexResult = await query(
      `INSERT INTO complexes (society_id, name) VALUES ($1, $2) RETURNING id`,
      [result.rows[0].id, 'Main Complex']
    );

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'society_created', 'society', result.rows[0].id, JSON.stringify({ name })]
    );

    logger.info(`Society created: ${name} (${result.rows[0].id})`);

    res.status(201).json({
      success: true,
      data: {
        ...result.rows[0],
        defaultComplexId: complexResult.rows[0].id,
      },
    });
  } catch (error) {
    logger.error('Create society error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * PUT /admin/societies/:id
 * Update society details
 */
router.put('/:societyId', verifyAdminToken, requireSocietyAccess, async (req, res) => {
  try {
    const { societyId } = req.params;
    const { name, address, city, timezone, logoUrl, metadata } = req.body;

    const result = await query(
      `UPDATE societies
       SET name = COALESCE($1, name),
           address = COALESCE($2, address),
           city = COALESCE($3, city),
           timezone = COALESCE($4, timezone),
           logo_url = COALESCE($5, logo_url),
           metadata = COALESCE($6, metadata)
       WHERE id = $7
       RETURNING *`,
      [name, address, city, timezone, logoUrl, metadata, societyId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Society not found',
      });
    }

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'society_updated', 'society', societyId, JSON.stringify(req.body)]
    );

    res.json({
      success: true,
      data: result.rows[0],
    });
  } catch (error) {
    logger.error('Update society error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * POST /admin/societies/:id/structure
 * Bulk create blocks and flats
 */
router.post('/:societyId/structure', verifyAdminToken, requireSocietyAccess, async (req, res) => {
  try {
    const { societyId } = req.params;
    const { complexId, blocks } = req.body;

    if (!blocks || !Array.isArray(blocks) || blocks.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Blocks array is required',
      });
    }

    // Verify complex belongs to society
    let targetComplexId = complexId;
    if (!targetComplexId) {
      // Get or create default complex
      const complexResult = await query(
        `SELECT id FROM complexes WHERE society_id = $1 ORDER BY created_at LIMIT 1`,
        [societyId]
      );
      if (complexResult.rows.length === 0) {
        const newComplex = await query(
          `INSERT INTO complexes (society_id, name) VALUES ($1, $2) RETURNING id`,
          [societyId, 'Main Complex']
        );
        targetComplexId = newComplex.rows[0].id;
      } else {
        targetComplexId = complexResult.rows[0].id;
      }
    }

    const createdBlocks = [];
    const createdFlats = [];

    for (const block of blocks) {
      // Create block
      const blockResult = await query(
        `INSERT INTO blocks (complex_id, name) VALUES ($1, $2) RETURNING *`,
        [targetComplexId, block.name]
      );
      const newBlock = blockResult.rows[0];
      createdBlocks.push(newBlock);

      // Create flats if specified
      if (block.flats && Array.isArray(block.flats)) {
        for (const flat of block.flats) {
          const flatResult = await query(
            `INSERT INTO flats (block_id, flat_number, unit_type, bhk, square_feet, parking_slots, has_service_quarter, has_covered_parking)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
            [
              newBlock.id,
              flat.flatNumber,
              flat.unitType || 'simplex',
              flat.bhk || '2',
              flat.squareFeet || null,
              flat.parkingSlots || (flat.hasCoveredParking ? 1 : 0),
              flat.hasServiceQuarter || false,
              flat.hasCoveredParking || false,
            ]
          );
          createdFlats.push(flatResult.rows[0]);
        }
      } else if (block.floors && block.unitsPerFloor) {
        // Auto-generate flats based on floors and units
        for (let floor = 1; floor <= block.floors; floor++) {
          for (let unit = 1; unit <= block.unitsPerFloor; unit++) {
            const flatNumber = `${floor}${unit.toString().padStart(2, '0')}`;
            const flatResult = await query(
              `INSERT INTO flats (block_id, flat_number) VALUES ($1, $2) RETURNING *`,
              [newBlock.id, flatNumber]
            );
            createdFlats.push(flatResult.rows[0]);
          }
        }
      }
    }

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        req.adminUser.userId,
        'structure_created',
        'society',
        societyId,
        JSON.stringify({ blocks: createdBlocks.length, flats: createdFlats.length }),
      ]
    );

    logger.info(`Structure created for society ${societyId}: ${createdBlocks.length} blocks, ${createdFlats.length} flats`);

    res.status(201).json({
      success: true,
      data: {
        blocks: createdBlocks,
        flatsCount: createdFlats.length,
      },
    });
  } catch (error) {
    logger.error('Create structure error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * PUT /admin/societies/:id/policies
 * Update society policies (feature toggles)
 */
router.put('/:societyId/policies', verifyAdminToken, requireSocietyAccess, async (req, res) => {
  try {
    const { societyId } = req.params;
    const { policies } = req.body;

    if (!policies || typeof policies !== 'object') {
      return res.status(400).json({
        success: false,
        error: 'Policies object is required',
      });
    }

    // Upsert each policy
    for (const [key, value] of Object.entries(policies)) {
      await query(
        `INSERT INTO policies (society_id, key, value)
         VALUES ($1, $2, $3)
         ON CONFLICT (society_id, key)
         DO UPDATE SET value = $3, effective_from = NOW()`,
        [societyId, key, JSON.stringify(value)]
      );
    }

    // Log action
    await query(
      `INSERT INTO audit_logs (actor_user_id, action, resource_type, resource_id, payload)
       VALUES ($1, $2, $3, $4, $5)`,
      [req.adminUser.userId, 'policies_updated', 'society', societyId, JSON.stringify(policies)]
    );

    res.json({
      success: true,
      message: 'Policies updated successfully',
    });
  } catch (error) {
    logger.error('Update policies error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /admin/societies/:id/residents
 * Get residents list for a society
 */
router.get('/:societyId/residents', verifyAdminToken, requireSocietyAccess, async (req, res) => {
  try {
    const { societyId } = req.params;
    const { status, page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    let whereClause = `c.society_id = $1`;
    const params = [societyId];

    if (status === 'active') {
      whereClause += ` AND fo.end_date IS NULL`;
    } else if (status === 'inactive') {
      whereClause += ` AND fo.end_date IS NOT NULL`;
    }

    const residentsResult = await query(
      `SELECT
        u.id, u.name, u.phone, u.email, u.avatar_url,
        fo.id as occupancy_id, fo.role as occupancy_role, fo.is_primary, fo.start_date, fo.end_date,
        f.id as flat_id, f.flat_number,
        b.id as block_id, b.name as block_name,
        c.id as complex_id, c.name as complex_name
       FROM flat_occupancies fo
       JOIN users u ON fo.user_id = u.id
       JOIN flats f ON fo.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE ${whereClause}
       ORDER BY b.name, f.flat_number, u.name
       LIMIT $2 OFFSET $3`,
      [...params, limit, offset]
    );

    // Get total count
    const countResult = await query(
      `SELECT COUNT(*) FROM flat_occupancies fo
       JOIN flats f ON fo.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE ${whereClause}`,
      params
    );

    res.json({
      success: true,
      data: residentsResult.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countResult.rows[0].count),
        totalPages: Math.ceil(countResult.rows[0].count / limit),
      },
    });
  } catch (error) {
    logger.error('Get residents error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

/**
 * GET /admin/societies/:id/pending-requests
 * Get pending resident approval requests
 */
router.get('/:societyId/pending-requests', verifyAdminToken, requireSocietyAccess, async (req, res) => {
  try {
    const { societyId } = req.params;

    const requestsResult = await query(
      `SELECT
        rr.*,
        u.name as user_name, u.phone as user_phone, u.email as user_email,
        f.flat_number,
        b.name as block_name,
        c.name as complex_name
       FROM resident_requests rr
       JOIN users u ON rr.requesting_user_id = u.id
       JOIN flats f ON rr.flat_id = f.id
       JOIN blocks b ON f.block_id = b.id
       JOIN complexes c ON b.complex_id = c.id
       WHERE c.society_id = $1 AND rr.status = 'pending'
       ORDER BY rr.submitted_at DESC`,
      [societyId]
    );

    res.json({
      success: true,
      data: requestsResult.rows,
    });
  } catch (error) {
    logger.error('Get pending requests error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

module.exports = router;

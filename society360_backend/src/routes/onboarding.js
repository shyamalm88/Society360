const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { verifyFirebaseToken } = require('../middleware/auth');
const logger = require('../config/logger');

/**
 * GET /cities
 * Get list of all cities
 */
router.get('/cities', verifyFirebaseToken, async (req, res) => {
  try {
    const result = await query(
      `SELECT DISTINCT city
       FROM societies
       WHERE city IS NOT NULL
       ORDER BY city`
    );

    res.json({
      success: true,
      data: result.rows.map(row => row.city),
    });
  } catch (error) {
    logger.error('Error fetching cities:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch cities',
    });
  }
});

/**
 * GET /societies
 * Get societies filtered by city
 */
router.get('/societies', verifyFirebaseToken, async (req, res) => {
  try {
    const { city } = req.query;

    let queryText = 'SELECT id, name, slug, city, address FROM societies WHERE 1=1';
    const params = [];

    if (city) {
      params.push(city);
      queryText += ` AND city = $${params.length}`;
    }

    queryText += ' ORDER BY name';

    const result = await query(queryText, params);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching societies:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch societies',
    });
  }
});

/**
 * GET /complexes
 * Get complexes filtered by society_id
 */
router.get('/complexes', verifyFirebaseToken, async (req, res) => {
  try {
    const { society_id } = req.query;

    if (!society_id) {
      return res.status(400).json({
        success: false,
        error: 'society_id is required',
      });
    }

    const result = await query(
      `SELECT id, society_id, name, created_at
       FROM complexes
       WHERE society_id = $1
       ORDER BY name`,
      [society_id]
    );

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching complexes:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch complexes',
    });
  }
});

/**
 * GET /blocks
 * Get blocks filtered by complex_id
 */
router.get('/blocks', verifyFirebaseToken, async (req, res) => {
  try {
    const { complex_id } = req.query;

    if (!complex_id) {
      return res.status(400).json({
        success: false,
        error: 'complex_id is required',
      });
    }

    const result = await query(
      `SELECT id, complex_id, name, created_at
       FROM blocks
       WHERE complex_id = $1
       ORDER BY name`,
      [complex_id]
    );

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching blocks:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch blocks',
    });
  }
});

/**
 * GET /flats
 * Get flats filtered by block_id with occupancy information
 */
router.get('/flats', verifyFirebaseToken, async (req, res) => {
  try {
    const { block_id } = req.query;

    if (!block_id) {
      return res.status(400).json({
        success: false,
        error: 'block_id is required',
      });
    }

    const result = await query(
      `SELECT DISTINCT ON (f.id)
        f.id, f.block_id, f.flat_number, f.unit_type, f.bhk,
        f.square_feet, f.parking_slots, f.is_active,
        CASE WHEN fo.id IS NOT NULL THEN true ELSE false END as is_occupied,
        u.name as resident_name,
        fo.role as occupancy_role
       FROM flats f
       LEFT JOIN flat_occupancies fo ON f.id = fo.flat_id AND fo.end_date IS NULL
       LEFT JOIN users u ON fo.user_id = u.id
       WHERE f.block_id = $1 AND f.is_active = true
       ORDER BY f.id, fo.is_primary DESC, fo.created_at ASC`,
      [block_id]
    );

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('Error fetching flats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch flats',
    });
  }
});

module.exports = router;

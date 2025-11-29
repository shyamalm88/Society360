const { pool } = require('../config/database');
const logger = require('../config/logger');

async function addAccessCodeColumn() {
  const client = await pool.connect();

  try {
    logger.info('Adding access_code column to visitors table...');

    await client.query(`
      ALTER TABLE visitors
      ADD COLUMN IF NOT EXISTS access_code VARCHAR(6) UNIQUE;
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_visitors_access_code
      ON visitors(access_code);
    `);

    logger.info('✅ Successfully added access_code column');

  } catch (error) {
    logger.error('❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run migration
addAccessCodeColumn()
  .then(() => {
    logger.info('Migration completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    logger.error('Migration failed:', error);
    process.exit(1);
  });

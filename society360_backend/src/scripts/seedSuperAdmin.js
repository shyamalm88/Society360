/**
 * Seed Super Admin User
 *
 * Run this script to create the initial super admin user:
 * node src/scripts/seedSuperAdmin.js
 *
 * Or set environment variables:
 * SUPER_ADMIN_EMAIL=admin@society360.com SUPER_ADMIN_PASSWORD=yourpassword node src/scripts/seedSuperAdmin.js
 */

require('dotenv').config();
const bcrypt = require('bcryptjs');
const { query, pool } = require('../config/database');

const SUPER_ADMIN_EMAIL = process.env.SUPER_ADMIN_EMAIL || 'admin@society360.com';
const SUPER_ADMIN_PASSWORD = process.env.SUPER_ADMIN_PASSWORD || 'Admin@123';
const SUPER_ADMIN_NAME = process.env.SUPER_ADMIN_NAME || 'Super Admin';

async function seedSuperAdmin() {
  try {
    console.log('🌱 Starting Super Admin seed...\n');

    // Check if admin already exists
    const existingResult = await query(
      `SELECT au.id FROM admin_users au WHERE au.email = $1`,
      [SUPER_ADMIN_EMAIL.toLowerCase()]
    );

    if (existingResult.rows.length > 0) {
      console.log(`⚠️  Super Admin already exists with email: ${SUPER_ADMIN_EMAIL}`);
      console.log('   Skipping creation.\n');
      process.exit(0);
    }

    // Create user record
    console.log('📝 Creating user record...');
    const userResult = await query(
      `INSERT INTO users (phone, name, email, created_at, updated_at)
       VALUES ($1, $2, $3, NOW(), NOW())
       RETURNING id`,
      ['+910000000000', SUPER_ADMIN_NAME, SUPER_ADMIN_EMAIL.toLowerCase()]
    );
    const userId = userResult.rows[0].id;
    console.log(`   User ID: ${userId}`);

    // Hash password
    console.log('🔐 Hashing password...');
    const passwordHash = await bcrypt.hash(SUPER_ADMIN_PASSWORD, 12);

    // Create admin user
    console.log('👤 Creating admin user...');
    const adminResult = await query(
      `INSERT INTO admin_users (user_id, email, password_hash, email_verified, is_active)
       VALUES ($1, $2, $3, true, true)
       RETURNING id`,
      [userId, SUPER_ADMIN_EMAIL.toLowerCase(), passwordHash]
    );
    const adminUserId = adminResult.rows[0].id;
    console.log(`   Admin User ID: ${adminUserId}`);

    // Assign super_admin role
    console.log('🎭 Assigning super_admin role...');
    await query(
      `INSERT INTO role_assignments (user_id, role, scope_type, scope_id, granted_by)
       VALUES ($1, 'super_admin', NULL, NULL, $1)`,
      [userId]
    );

    console.log('\n✅ Super Admin created successfully!\n');
    console.log('   ┌────────────────────────────────────────┐');
    console.log('   │  Login Credentials                     │');
    console.log('   ├────────────────────────────────────────┤');
    console.log(`   │  Email: ${SUPER_ADMIN_EMAIL.padEnd(28)}│`);
    console.log(`   │  Password: ${SUPER_ADMIN_PASSWORD.padEnd(26)}│`);
    console.log('   └────────────────────────────────────────┘');
    console.log('\n⚠️  IMPORTANT: Change the password after first login!\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding Super Admin:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

seedSuperAdmin();

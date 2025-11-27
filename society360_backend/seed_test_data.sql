-- Seed Test Data for Society360
-- This script creates test data for development/testing

-- Clear existing data (optional - comment out if you want to keep existing data)
TRUNCATE TABLE visits, visitor_approvals, visitors, guards, flat_occupancies, flats, blocks, complexes, societies, users CASCADE;

-- 1. Create a test society
INSERT INTO societies (id, name, slug, city, address, created_at)
VALUES
  (gen_random_uuid(), 'Green Valley Society', 'green-valley', 'Bangalore', '123 MG Road, Bangalore, Karnataka 560001', NOW())
RETURNING id AS society_id \gset

-- Store society_id for later use
\echo 'Created society with ID:' :society_id

-- 2. Create a complex
INSERT INTO complexes (id, society_id, name, created_at)
VALUES
  (gen_random_uuid(), :'society_id', 'Main Complex', NOW())
RETURNING id AS complex_id \gset

-- 3. Create Block A
INSERT INTO blocks (id, complex_id, name, created_at)
VALUES
  (gen_random_uuid(), :'complex_id', 'Block A', NOW())
RETURNING id AS block_id \gset

-- 4. Create flats (including A-303)
INSERT INTO flats (id, block_id, flat_number, unit_type, bhk, square_feet, parking_slots, is_active, created_at)
VALUES
  (gen_random_uuid(), :'block_id', 'A-301', 'apartment', 2, 1200, 1, true, NOW()),
  (gen_random_uuid(), :'block_id', 'A-302', 'apartment', 3, 1500, 1, true, NOW()),
  (gen_random_uuid(), :'block_id', 'A-303', 'apartment', 3, 1600, 2, true, NOW()),
  (gen_random_uuid(), :'block_id', 'A-304', 'apartment', 2, 1200, 1, true, NOW()),
  (gen_random_uuid(), :'block_id', 'A-305', 'apartment', 3, 1500, 1, true, NOW());

-- Get flat_a_303 ID
SELECT id FROM flats WHERE flat_number = 'A-303' \gset flat_a_303_

-- 5. Create test users
-- IMPORTANT: You'll need to update firebase_uid with actual Firebase UIDs from your apps
INSERT INTO users (id, firebase_uid, phone, name, email, created_at, updated_at)
VALUES
  -- Guard user (update firebase_uid with actual guard's Firebase UID)
  (gen_random_uuid(), 'FIREBASE_UID_GUARD_PLACEHOLDER', '+911234567890', 'Rajesh Kumar', 'guard@greenvalley.com', NOW(), NOW()),

  -- Resident users (update firebase_uid with actual residents' Firebase UIDs)
  (gen_random_uuid(), 'FIREBASE_UID_RESIDENT_1_PLACEHOLDER', '+919876543210', 'Amit Sharma', 'resident1@example.com', NOW(), NOW()),
  (gen_random_uuid(), 'FIREBASE_UID_RESIDENT_2_PLACEHOLDER', '+919876543211', 'Priya Singh', 'resident2@example.com', NOW(), NOW());

-- Get user IDs
SELECT id FROM users WHERE phone = '+911234567890' \gset guard_
SELECT id FROM users WHERE phone = '+919876543210' \gset resident1_
SELECT id FROM users WHERE phone = '+919876543211' \gset resident2_

-- 6. Create flat occupancies (link residents to flats)
INSERT INTO flat_occupancies (id, flat_id, user_id, role, start_date, is_primary, created_at)
VALUES
  (gen_random_uuid(), :'flat_a_303_id', :'resident1_id', 'owner', NOW(), true, NOW()),
  (gen_random_uuid(), :'flat_a_303_id', :'resident2_id', 'other', NOW(), false, NOW());

-- 7. Create guard assignment
INSERT INTO guards (id, user_id, society_id, active, created_at)
VALUES
  (gen_random_uuid(), :'guard_id', :'society_id', true, NOW());

-- 8. Refresh the materialized view
REFRESH MATERIALIZED VIEW current_residents;

-- ===== VERIFICATION =====

\echo ''
\echo '===== DATA CREATION SUMMARY ====='
SELECT 'Societies:' as table_name, COUNT(*) as count FROM societies
UNION ALL SELECT 'Complexes:', COUNT(*) FROM complexes
UNION ALL SELECT 'Blocks:', COUNT(*) FROM blocks
UNION ALL SELECT 'Flats:', COUNT(*) FROM flats
UNION ALL SELECT 'Users:', COUNT(*) FROM users
UNION ALL SELECT 'Flat Occupancies:', COUNT(*) FROM flat_occupancies
UNION ALL SELECT 'Guards:', COUNT(*) FROM guards;

\echo ''
\echo '===== FLATS IN BLOCK A ====='
SELECT id, flat_number FROM flats WHERE block_id = :'block_id' ORDER BY flat_number;

\echo ''
\echo '===== RESIDENTS OF A-303 ====='
SELECT u.id, u.name, u.email, u.phone, fo.role
FROM flat_occupancies fo
JOIN users u ON fo.user_id = u.id
WHERE fo.flat_id = :'flat_a_303_id';

\echo ''
\echo '===== GUARDS ====='
SELECT u.id, u.name, u.phone, g.active
FROM guards g
JOIN users u ON g.user_id = u.id;

\echo ''
\echo '===== IMPORTANT: UPDATE FIREBASE UIDs ====='
\echo 'You must update the firebase_uid values in the users table with actual Firebase UIDs from your apps.'
\echo ''
\echo 'Run this after logging in with your apps:'
\echo ''
\echo 'UPDATE users SET firebase_uid = '<actual_guard_firebase_uid>' WHERE phone = '+911234567890';'
\echo 'UPDATE users SET firebase_uid = '<actual_resident_firebase_uid>' WHERE phone = '+919876543210';'
\echo ''
\echo 'Also update your Guard app to use flat_id from this query:'
SELECT 'flat_id for A-303:', id FROM flats WHERE flat_number = 'A-303';

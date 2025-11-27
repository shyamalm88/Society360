-- Schema Verification Script
-- This script verifies that all columns used in the backend code exist in the database

-- Check visitors table has all required columns
SELECT 'visitors table check:' as check_name,
  CASE
    WHEN COUNT(*) = 17 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing columns'
  END as status
FROM information_schema.columns
WHERE table_name = 'visitors'
  AND column_name IN (
    'id', 'visitor_name', 'phone', 'id_type', 'id_number',
    'vehicle_no', 'purpose', 'invited_by', 'flat_id',
    'expected_start', 'expected_end', 'status', 'auto_approved',
    'created_at', 'updated_at', 'approval_deadline', 'idempotency_key'
  );

-- Check visits table has all required columns
SELECT 'visits table check:' as check_name,
  CASE
    WHEN COUNT(*) = 8 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing columns'
  END as status
FROM information_schema.columns
WHERE table_name = 'visits'
  AND column_name IN (
    'id', 'visitor_id', 'guard_id', 'checkin_time',
    'checkout_time', 'checkin_method', 'notes', 'created_at'
  );

-- Check devices table has FCM token column
SELECT 'devices table (FCM) check:' as check_name,
  CASE
    WHEN COUNT(*) = 1 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - fcm_token column missing'
  END as status
FROM information_schema.columns
WHERE table_name = 'devices' AND column_name = 'fcm_token';

-- Check notification_logs table
SELECT 'notification_logs table check:' as check_name,
  CASE
    WHEN COUNT(*) >= 9 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing columns'
  END as status
FROM information_schema.columns
WHERE table_name = 'notification_logs'
  AND column_name IN (
    'id', 'user_id', 'channel', 'payload', 'status',
    'created_at', 'delivered_at', 'correlation_id', 'provider_response'
  );

-- Check visitor_approvals table
SELECT 'visitor_approvals table check:' as check_name,
  CASE
    WHEN COUNT(*) = 7 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing columns'
  END as status
FROM information_schema.columns
WHERE table_name = 'visitor_approvals'
  AND column_name IN (
    'id', 'visitor_id', 'approver_user_id', 'approver_role',
    'decision', 'note', 'decided_at'
  );

-- Check flat_occupancies table
SELECT 'flat_occupancies table check:' as check_name,
  CASE
    WHEN COUNT(*) >= 7 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing columns'
  END as status
FROM information_schema.columns
WHERE table_name = 'flat_occupancies'
  AND column_name IN (
    'id', 'flat_id', 'user_id', 'role', 'start_date',
    'end_date', 'is_primary'
  );

-- Check guards table
SELECT 'guards table check:' as check_name,
  CASE
    WHEN COUNT(*) >= 4 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing columns'
  END as status
FROM information_schema.columns
WHERE table_name = 'guards'
  AND column_name IN ('id', 'user_id', 'society_id', 'active');

-- Check audit_logs table
SELECT 'audit_logs table check:' as check_name,
  CASE
    WHEN COUNT(*) >= 6 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing columns'
  END as status
FROM information_schema.columns
WHERE table_name = 'audit_logs'
  AND column_name IN (
    'id', 'actor_user_id', 'action', 'resource_type',
    'resource_id', 'payload', 'created_at'
  );

-- Check all required tables exist
SELECT 'Required tables check:' as check_name,
  CASE
    WHEN COUNT(*) = 35 THEN 'PASS ✅ - All tables exist'
    ELSE CONCAT('FAIL ❌ - Only ', COUNT(*), ' of 35 tables exist')
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users', 'firebase_auth_audit', 'sessions', 'role_assignments',
    'societies', 'complexes', 'blocks', 'flats', 'flat_occupancies',
    'resident_requests', 'resident_request_approvals', 'guards',
    'guard_assignments', 'devices', 'device_heartbeats',
    'notification_logs', 'otp_sessions', 'visitors', 'visitor_approvals',
    'frequent_visitors', 'frequent_visitor_windows', 'frequent_visitor_usage',
    'visits', 'visits_2025_11', 'visits_2025_12',
    'vehicles', 'parking_allocations', 'attachments', 'csv_imports',
    'policies', 'audit_logs', 'retention_jobs', 'api_rate_limits',
    'idempotency_keys', 'current_residents'
  );

-- Check visitor_status enum has all required values
SELECT 'visitor_status enum check:' as check_name,
  CASE
    WHEN COUNT(*) >= 5 THEN 'PASS ✅'
    ELSE 'FAIL ❌ - Missing enum values'
  END as status
FROM pg_enum
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'visitor_status')
  AND enumlabel IN ('pending', 'accepted', 'denied', 'checked_in', 'checked_out');

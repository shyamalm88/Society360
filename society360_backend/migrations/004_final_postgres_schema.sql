
-- migrations/004_final_postgres_schema.sql
-- Society360: Final PostgreSQL schema (consolidated)
-- Requires: CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- === 1. Core user & auth tables ===

-- users (core identity mapped to Firebase)
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid text UNIQUE,
  phone text NOT NULL,
  phone_normalized text,
  name text,
  email text,
  avatar_url text,
  timezone text DEFAULT 'Asia/Kolkata',
  consent_profile boolean DEFAULT true,
  is_deleted boolean DEFAULT false,
  deleted_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_users_phone_norm ON users(phone_normalized);

-- firebase_auth_audit: track id token verification events (audit)
CREATE TABLE IF NOT EXISTS firebase_auth_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  firebase_uid text,
  event text,
  token_issued_at timestamptz,
  token_expiry_at timestamptz,
  ip inet,
  user_agent text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fba_user ON firebase_auth_audit(user_id);

-- sessions (backend issued JWT sessions if used)
CREATE TABLE IF NOT EXISTS sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  jwt_id text,
  refresh_token_hash text,
  device_id uuid,
  issued_at timestamptz DEFAULT now(),
  expires_at timestamptz,
  revoked boolean DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

-- === 2. Role model: hierarchy, scoped roles ===

CREATE TYPE role_enum AS ENUM (
  'super_admin',
  'society_admin',
  'block_admin',
  'guard',
  'resident'
);

CREATE TABLE IF NOT EXISTS role_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role role_enum NOT NULL,
  scope_type text,
  scope_id uuid,
  granted_by uuid REFERENCES users(id),
  granted_at timestamptz DEFAULT now(),
  revoked boolean DEFAULT false,
  revoked_at timestamptz,
  UNIQUE(user_id, role, scope_type, scope_id)
);
CREATE INDEX IF NOT EXISTS idx_role_user ON role_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_role_scope ON role_assignments(scope_type, scope_id);

-- === 3. Society structure ===

CREATE TABLE IF NOT EXISTS societies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE,
  city text,
  address text,
  timezone text DEFAULT 'Asia/Kolkata',
  metadata jsonb,
  created_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS complexes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES societies(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complex_id uuid REFERENCES complexes(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS flats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid REFERENCES blocks(id) ON DELETE CASCADE,
  flat_number text NOT NULL,
  unit_type text,
  bhk smallint,
  square_feet integer,
  parking_slots integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_flats_block_flat ON flats(block_id, flat_number);

-- === 4. Occupancy and resident lifecycle ===

CREATE TYPE occupancy_role AS ENUM ('owner','tenant','other');

CREATE TABLE IF NOT EXISTS flat_occupancies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flat_id uuid REFERENCES flats(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  role occupancy_role NOT NULL,
  start_date timestamptz DEFAULT now(),
  end_date timestamptz,
  is_primary boolean DEFAULT false,
  source text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_flat_occ_flat ON flat_occupancies(flat_id);
CREATE INDEX IF NOT EXISTS idx_flat_occ_user ON flat_occupancies(user_id);

CREATE TYPE resident_request_status AS ENUM ('pending','approved','rejected','revoked','cancelled');

CREATE TABLE IF NOT EXISTS resident_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requesting_user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  flat_id uuid REFERENCES flats(id),
  requested_role occupancy_role NOT NULL,
  docs jsonb,
  note text,
  status resident_request_status DEFAULT 'pending',
  submitted_at timestamptz DEFAULT now(),
  processed_by uuid REFERENCES users(id),
  processed_at timestamptz,
  processed_note text
);
CREATE INDEX IF NOT EXISTS idx_resreq_flat ON resident_requests(flat_id);
CREATE INDEX IF NOT EXISTS idx_resreq_user ON resident_requests(requesting_user_id);

CREATE TABLE IF NOT EXISTS resident_request_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid REFERENCES resident_requests(id) ON DELETE CASCADE,
  approver_user_id uuid REFERENCES users(id),
  approver_role role_enum,
  decision text,
  note text,
  decided_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_req_approvals_req ON resident_request_approvals(request_id);

-- === 5. Guards, devices, and guard assignment ===

CREATE TABLE IF NOT EXISTS guards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) UNIQUE,
  society_id uuid REFERENCES societies(id),
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS guard_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guard_id uuid REFERENCES guards(id),
  society_id uuid REFERENCES societies(id),
  block_id uuid REFERENCES blocks(id),
  assigned_by uuid REFERENCES users(id),
  assigned_at timestamptz DEFAULT now(),
  released_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_guard_assign_guard ON guard_assignments(guard_id);
CREATE INDEX IF NOT EXISTS idx_guard_assign_society ON guard_assignments(society_id);

CREATE TABLE IF NOT EXISTS devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  device_identifier text,
  platform text,
  fcm_token text,
  last_seen timestamptz,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);

CREATE TABLE IF NOT EXISTS device_heartbeats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id uuid REFERENCES devices(id),
  heartbeat_at timestamptz DEFAULT now(),
  metadata jsonb
);
CREATE INDEX IF NOT EXISTS idx_heartbeat_device ON device_heartbeats(device_id);

-- === 6. Notifications & OTP tracking (detailed logs) ===

CREATE TYPE notif_channel AS ENUM ('push','sms','whatsapp','email');

CREATE TABLE IF NOT EXISTS notification_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  correlation_id text,
  user_id uuid REFERENCES users(id),
  channel notif_channel,
  provider_response jsonb,
  payload jsonb,
  status text,
  retry_count integer DEFAULT 0,
  next_retry_at timestamptz,
  created_at timestamptz DEFAULT now(),
  delivered_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_notif_user ON notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notif_status ON notification_logs(status);

CREATE TABLE IF NOT EXISTS otp_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  phone text,
  provider text,
  provider_token text,
  purpose text,
  status text,
  issued_at timestamptz DEFAULT now(),
  verified_at timestamptz,
  client_ip inet,
  user_agent text
);
CREATE INDEX IF NOT EXISTS idx_otp_user ON otp_sessions(user_id);

-- === 7. Visitors, frequent visitors, approvals ===

CREATE TYPE visitor_status AS ENUM ('pending','accepted','denied','checked_in','checked_out','cancelled');

CREATE TABLE IF NOT EXISTS visitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_name text,
  phone text,
  id_type text,
  id_number text,
  attachment_ids uuid[],
  vehicle_no text,
  purpose text,
  invited_by uuid REFERENCES users(id),
  flat_id uuid REFERENCES flats(id),
  expected_start timestamptz,
  expected_end timestamptz,
  status visitor_status DEFAULT 'pending',
  auto_approved boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  approval_deadline timestamptz,
  idempotency_key text
);
CREATE INDEX IF NOT EXISTS idx_visitors_flat_status ON visitors(flat_id, status);

CREATE TABLE IF NOT EXISTS visitor_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id uuid REFERENCES visitors(id) ON DELETE CASCADE,
  approver_user_id uuid REFERENCES users(id),
  approver_role role_enum,
  decision text,
  note text,
  decided_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_visitor_approvals_vid ON visitor_approvals(visitor_id);

CREATE TABLE IF NOT EXISTS frequent_visitors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flat_id uuid REFERENCES flats(id),
  name text,
  phone text,
  notes text,
  created_by uuid REFERENCES users(id),
  max_visits_per_week smallint DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS frequent_visitor_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  frequent_visitor_id uuid REFERENCES frequent_visitors(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_freq_windows_fvid ON frequent_visitor_windows(frequent_visitor_id);

CREATE TABLE IF NOT EXISTS frequent_visitor_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  frequent_visitor_id uuid REFERENCES frequent_visitors(id),
  week_start date,
  visits_count integer DEFAULT 0,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(frequent_visitor_id, week_start)
);

-- === 8. Visits (audit), partitioning hints ===

CREATE TABLE IF NOT EXISTS visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id uuid REFERENCES visitors(id),
  guard_id uuid REFERENCES guards(id),
  checkin_time timestamptz,
  checkout_time timestamptz,
  checkin_method text,
  notes text,
  created_at timestamptz DEFAULT now()
) PARTITION BY RANGE (created_at);

-- example partition (ops:create monthly)
CREATE TABLE IF NOT EXISTS visits_2025_11 PARTITION OF visits FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE INDEX IF NOT EXISTS idx_visits_checkin ON visits(checkin_time);

-- === 9. Vehicles & parking allocation (detailed) ===

CREATE TABLE IF NOT EXISTS vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  number_plate text,
  model text,
  color text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_vehicles_plate ON vehicles(number_plate);

CREATE TABLE IF NOT EXISTS parking_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flat_id uuid REFERENCES flats(id),
  parking_slot text,
  vehicle_id uuid REFERENCES vehicles(id),
  assigned_at timestamptz DEFAULT now(),
  released_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_parking_flat ON parking_allocations(flat_id);

-- === 10. Attachments & CSV import tracking ===

CREATE TABLE IF NOT EXISTS attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uploaded_by uuid REFERENCES users(id),
  url text,
  mime text,
  size_bytes bigint,
  purpose text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS csv_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uploaded_by uuid REFERENCES users(id),
  filename text,
  rows_total integer,
  rows_success integer,
  rows_failed integer,
  errors jsonb,
  created_at timestamptz DEFAULT now()
);

-- === 11. Policies (per-society configuration) ===

CREATE TABLE IF NOT EXISTS policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES societies(id),
  key text NOT NULL,
  value jsonb,
  effective_from timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_policies_soc ON policies(society_id);

-- === 12. Audit logs & retention ===

CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES users(id),
  action text NOT NULL,
  resource_type text,
  resource_id uuid,
  payload jsonb,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_logs(actor_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_time ON audit_logs(created_at);

CREATE TABLE IF NOT EXISTS retention_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_type text,
  cutoff_date timestamptz,
  action text,
  status text DEFAULT 'pending',
  run_at timestamptz,
  result jsonb
);

-- === 13. Rate limiting, idempotency (simple tables) ===

CREATE TABLE IF NOT EXISTS api_rate_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  key text,
  window_start timestamptz,
  count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, key, window_start)
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE,
  user_id uuid REFERENCES users(id),
  request_method text,
  request_path text,
  request_hash text,
  created_at timestamptz DEFAULT now(),
  response_status integer,
  response_body jsonb
);

-- === 14. Useful views (materialized suggestions) ===

CREATE MATERIALIZED VIEW IF NOT EXISTS current_residents AS
SELECT fo.flat_id, fo.user_id, fo.role, fo.start_date, fo.end_date
FROM flat_occupancies fo
WHERE fo.end_date IS NULL;

-- End of migration

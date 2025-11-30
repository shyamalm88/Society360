-- Migration 008: Notices, Complaints, and Admin Authentication
-- Society360 Admin Portal Support

-- === 1. Admin Authentication Tables ===

-- admin_users: Separate table for admin portal users (email/password auth)
CREATE TABLE IF NOT EXISTS admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  is_active boolean DEFAULT true,
  email_verified boolean DEFAULT false,
  last_login_at timestamptz,
  failed_login_attempts integer DEFAULT 0,
  locked_until timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON admin_users(user_id);

-- admin_sessions: JWT session tracking for admin portal
CREATE TABLE IF NOT EXISTS admin_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid REFERENCES admin_users(id) ON DELETE CASCADE,
  refresh_token_hash text UNIQUE NOT NULL,
  device_info jsonb,
  ip_address inet,
  user_agent text,
  issued_at timestamptz DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked boolean DEFAULT false,
  revoked_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin_user ON admin_sessions(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_refresh_token ON admin_sessions(refresh_token_hash);

-- === 2. Notices Table (Society Announcements) ===

CREATE TYPE notice_priority AS ENUM ('low', 'medium', 'high', 'critical');

CREATE TABLE IF NOT EXISTS notices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES societies(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text,
  priority notice_priority DEFAULT 'medium',
  is_pinned boolean DEFAULT false,
  published boolean DEFAULT true,
  publish_at timestamptz,
  expires_at timestamptz,
  created_by uuid REFERENCES users(id),
  updated_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notices_society ON notices(society_id);
CREATE INDEX IF NOT EXISTS idx_notices_priority ON notices(priority);
CREATE INDEX IF NOT EXISTS idx_notices_published ON notices(published, publish_at);

-- notice_reads: Track which users have read which notices
CREATE TABLE IF NOT EXISTS notice_reads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notice_id uuid REFERENCES notices(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  read_at timestamptz DEFAULT now(),
  UNIQUE(notice_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_notice_reads_notice ON notice_reads(notice_id);
CREATE INDEX IF NOT EXISTS idx_notice_reads_user ON notice_reads(user_id);

-- === 3. Complaints Table (Helpdesk Tickets) ===

CREATE TYPE ticket_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
CREATE TYPE ticket_category AS ENUM ('maintenance', 'security', 'amenities', 'billing', 'noise', 'parking', 'other');

CREATE TABLE IF NOT EXISTS complaints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid REFERENCES societies(id) ON DELETE CASCADE,
  flat_id uuid REFERENCES flats(id),
  submitted_by uuid REFERENCES users(id),
  title text NOT NULL,
  description text,
  category ticket_category DEFAULT 'other',
  status ticket_status DEFAULT 'open',
  priority notice_priority DEFAULT 'medium',
  assigned_to uuid REFERENCES users(id),
  attachment_ids uuid[],
  resolution_note text,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_complaints_society ON complaints(society_id);
CREATE INDEX IF NOT EXISTS idx_complaints_flat ON complaints(flat_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_submitted_by ON complaints(submitted_by);

-- complaint_comments: Thread of comments on a complaint
CREATE TABLE IF NOT EXISTS complaint_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid REFERENCES complaints(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id),
  comment text NOT NULL,
  is_internal boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_complaint_comments_complaint ON complaint_comments(complaint_id);

-- === 4. Add logo_url to societies table ===

ALTER TABLE societies ADD COLUMN IF NOT EXISTS logo_url text;

-- === 5. Create visits partition for December 2025 ===

CREATE TABLE IF NOT EXISTS visits_2025_12 PARTITION OF visits FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

-- === 6. Helper function: Update updated_at timestamp ===

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to tables with updated_at
DROP TRIGGER IF EXISTS update_admin_users_updated_at ON admin_users;
CREATE TRIGGER update_admin_users_updated_at
  BEFORE UPDATE ON admin_users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_notices_updated_at ON notices;
CREATE TRIGGER update_notices_updated_at
  BEFORE UPDATE ON notices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_complaints_updated_at ON complaints;
CREATE TRIGGER update_complaints_updated_at
  BEFORE UPDATE ON complaints
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- End of migration 008

-- Migration 006: Create emergencies table for panic/emergency alerts
CREATE TABLE IF NOT EXISTS emergencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flat_id UUID NOT NULL REFERENCES flats(id) ON DELETE CASCADE,
  reported_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  description TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, addressed, resolved
  addressed_by_guard_id UUID REFERENCES guards(id) ON DELETE SET NULL,
  addressed_at TIMESTAMPTZ,
  resolved_by_guard_id UUID REFERENCES guards(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_emergencies_flat_id ON emergencies(flat_id);
CREATE INDEX IF NOT EXISTS idx_emergencies_status ON emergencies(status);
CREATE INDEX IF NOT EXISTS idx_emergencies_created_at ON emergencies(created_at DESC);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_emergencies_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER emergencies_updated_at_trigger
BEFORE UPDATE ON emergencies
FOR EACH ROW
EXECUTE FUNCTION update_emergencies_updated_at();

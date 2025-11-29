-- Migration 007: Add guest pass fields to visitors table
ALTER TABLE visitors
ADD COLUMN IF NOT EXISTS qr_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS number_of_people INTEGER DEFAULT 1;

-- Create index for faster QR code lookups
CREATE INDEX IF NOT EXISTS idx_visitors_qr_code ON visitors(qr_code) WHERE qr_code IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN visitors.qr_code IS 'Unique QR code identifier for guest pass functionality';
COMMENT ON COLUMN visitors.number_of_people IS 'Approximate number of people for this visit (used in guest passes)';

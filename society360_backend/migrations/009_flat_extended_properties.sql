-- Migration: Add extended flat properties
-- Date: 2025-12-01
-- Description: Add has_service_quarter and has_covered_parking columns to flats table

-- Add service quarter flag
ALTER TABLE flats ADD COLUMN IF NOT EXISTS has_service_quarter boolean DEFAULT false;

-- Add covered parking flag
ALTER TABLE flats ADD COLUMN IF NOT EXISTS has_covered_parking boolean DEFAULT false;

-- Update bhk column to accept text values like '1.5', '2.5', etc.
-- First check if the column type needs to change
DO $$
BEGIN
  -- Only alter if it's smallint
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'flats' AND column_name = 'bhk' AND data_type = 'smallint'
  ) THEN
    ALTER TABLE flats ALTER COLUMN bhk TYPE text USING bhk::text;
  END IF;
END $$;

-- Add index for unit_type queries
CREATE INDEX IF NOT EXISTS idx_flats_unit_type ON flats(unit_type);

-- Migration: Add FCM tokens table for push notifications
-- Created: 2025-11-26

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table to store Firebase Cloud Messaging tokens for push notifications
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  device_type VARCHAR(20) CHECK (device_type IN ('ios', 'android', 'web')),
  device_info JSONB, -- Store additional device metadata
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Index for faster lookups by user
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens(user_id);

-- Index for faster lookups by active tokens
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_active ON fcm_tokens(user_id, is_active) WHERE is_active = true;

-- Unique constraint: one token per device (prevent duplicates)
CREATE UNIQUE INDEX IF NOT EXISTS idx_fcm_tokens_unique_token ON fcm_tokens(token);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_fcm_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER fcm_tokens_updated_at
BEFORE UPDATE ON fcm_tokens
FOR EACH ROW
EXECUTE FUNCTION update_fcm_tokens_updated_at();

COMMENT ON TABLE fcm_tokens IS 'Stores Firebase Cloud Messaging tokens for push notifications';
COMMENT ON COLUMN fcm_tokens.token IS 'FCM device token from Firebase SDK';
COMMENT ON COLUMN fcm_tokens.device_type IS 'Platform: ios, android, or web';
COMMENT ON COLUMN fcm_tokens.device_info IS 'Additional device metadata (model, OS version, etc.)';
COMMENT ON COLUMN fcm_tokens.is_active IS 'Whether this token is still valid and active';

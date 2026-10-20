-- Migration 0016: Add CLOSE_DRAWER to DeviceCommandType enum
-- Supabase PG<15 safe: ALTER TYPE ... ADD VALUE IF NOT EXISTS unsupported,
-- so use DO $$ block with existence check on pg_enum rows.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname = 'DeviceCommandType'
      AND e.enumlabel = 'CLOSE_DRAWER'
  ) THEN
    ALTER TYPE "DeviceCommandType" ADD VALUE 'CLOSE_DRAWER';
  END IF;
END $$;

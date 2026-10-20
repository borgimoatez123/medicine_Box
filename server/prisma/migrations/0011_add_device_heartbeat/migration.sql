-- Migration 0011: Add device connectivity tracking for Raspberry Pi Heartbeat feature
-- Re-adds DeviceStatus enum + MedicineBox.deviceStatus + MedicineBox.lastSeenAt
-- (These columns were previously removed by migration 0010 during the subsystem cleanup.)
-- Idempotent via pg_type catalog check (supports Postgres 12+ — avoids PG15-only CREATE TYPE IF NOT EXISTS).

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'DeviceStatus') THEN
    CREATE TYPE "DeviceStatus" AS ENUM ('ACTIVE', 'OFFLINE');
  END IF;
END$$;

ALTER TABLE "MedicineBox"
  ADD COLUMN IF NOT EXISTS "deviceStatus" "DeviceStatus" NOT NULL DEFAULT 'OFFLINE';

ALTER TABLE "MedicineBox"
  ADD COLUMN IF NOT EXISTS "lastSeenAt" TIMESTAMP(3);

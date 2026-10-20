-- Migration 0015: Add DeviceCommand for drawer unlock / open command workflow (Mobile → Backend → RPi)
-- Supabase pooler / PG <15 safe. All statements idempotent.
-- Introduces two new enums and one table with two FKs + two indexes.
-- NOTE: All String @id fields in Prisma map to TEXT PG type; FK columns MUST be TEXT to type-match.
--       MedicineBox.deviceId is TEXT @unique (correct target FK). Drawer.id TEXT @id (correct target FK).
-- PG <15 does NOT support ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS → FK addition wrapped in
-- a DO $$ pg_constraint catalog-existence guard, identical to migration 0014 pattern.
-- Enum creation also idempotent via DO $$ check pg_type.

-- 1. Create enum "DeviceCommandType" if not already present (OPEN_DRAWER only today)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'DeviceCommandType' AND typtype = 'e') THEN
    CREATE TYPE "DeviceCommandType" AS ENUM ('OPEN_DRAWER');
  END IF;
END $$;

-- 2. Create enum "DeviceCommandStatus" if not already present (PENDING/SENT/EXECUTED/FAILED/EXPIRED)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'DeviceCommandStatus' AND typtype = 'e') THEN
    CREATE TYPE "DeviceCommandStatus" AS ENUM ('PENDING','SENT','EXECUTED','FAILED','EXPIRED');
  END IF;
END $$;

-- 3. Create DeviceCommand table idempotently
CREATE TABLE IF NOT EXISTS "DeviceCommand" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "deviceId" TEXT NOT NULL,
  "drawerId" TEXT,
  "type" "DeviceCommandType" NOT NULL,
  "status" "DeviceCommandStatus" NOT NULL DEFAULT 'PENDING'::"DeviceCommandStatus",
  "reason" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "sentAt" TIMESTAMP(3),
  "executedAt" TIMESTAMP(3),
  "error" TEXT
);

-- 4. Create two indexes idempotently (matches schema.prisma @@index)
CREATE INDEX IF NOT EXISTS "_DeviceCommandDeviceIdStatus_idx"
  ON "DeviceCommand"("deviceId", "status");

CREATE INDEX IF NOT EXISTS "_DeviceCommandDrawerIdCreatedAt_idx"
  ON "DeviceCommand"("drawerId", "createdAt");

-- 5. FK 1: deviceId → MedicineBox.deviceId, onDelete CASCADE (matches Prisma schema onDelete: Cascade)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'DeviceCommand_deviceId_fkey'
  ) THEN
    ALTER TABLE "DeviceCommand"
      ADD CONSTRAINT "DeviceCommand_deviceId_fkey"
      FOREIGN KEY ("deviceId") REFERENCES "MedicineBox"("deviceId")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- 6. FK 2: drawerId → Drawer.id, onDelete SetNull (matches Prisma schema onDelete: SetNull)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'DeviceCommand_drawerId_fkey'
  ) THEN
    ALTER TABLE "DeviceCommand"
      ADD CONSTRAINT "DeviceCommand_drawerId_fkey"
      FOREIGN KEY ("drawerId") REFERENCES "Drawer"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

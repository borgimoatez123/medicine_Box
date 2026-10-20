-- Migration 0014: Add DrawerSensorState table for per-drawer DHT11 + fire sensor current state
-- Supabase pooler / PG <15 safe. All statements idempotent.
-- No new enums introduced.
-- NOTE: Drawer.id is TEXT on Postgres (Prisma String @default(uuid()) -> TEXT PG type),
-- so drawerId FK MUST be TEXT to type-match. Do NOT use UUID type.
-- PG <15 does NOT support `ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS` (SQLSTATE 42601).
-- FK constraint addition is wrapped in a DO $$ catalog-existence guard.

CREATE TABLE IF NOT EXISTS "DrawerSensorState" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "drawerId" TEXT NOT NULL,
  "temperature" DOUBLE PRECISION,
  "humidity" DOUBLE PRECISION,
  "fireDetected" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "DrawerSensorState_drawerId_key"
  ON "DrawerSensorState"("drawerId");

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'DrawerSensorState_drawerId_fkey'
  ) THEN
    ALTER TABLE "DrawerSensorState"
      ADD CONSTRAINT "DrawerSensorState_drawerId_fkey"
      FOREIGN KEY ("drawerId") REFERENCES "Drawer"("id")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

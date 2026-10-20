-- Migration 0013: Add MISSED MedicationSessionResult + MedicationSession occurrence unique key
-- Supabase pooler / PG <15 safe. All statements idempotent.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname = 'MedicationSessionResult'
      AND e.enumlabel = 'MISSED'
  ) THEN
    ALTER TYPE "MedicationSessionResult" ADD VALUE 'MISSED';
  END IF;
END $$;

ALTER TABLE "MedicationSession"
  ADD COLUMN IF NOT EXISTS "occurrenceDate" TIMESTAMPTZ;

ALTER TABLE "MedicationSession"
  ADD COLUMN IF NOT EXISTS "occurrenceTime" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "MedicationSession_schedule_occurrence_unique"
  ON "MedicationSession" ("scheduleId", "occurrenceDate", "occurrenceTime")
  WHERE "occurrenceDate" IS NOT NULL AND "occurrenceTime" IS NOT NULL;

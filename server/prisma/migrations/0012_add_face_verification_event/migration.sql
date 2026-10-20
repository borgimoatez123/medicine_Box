-- Migration 0012: Add FaceVerificationEvent table for Raspberry Pi face verification audit
-- Idempotent: CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS
-- No new enums; uses plain boolean verified + optional DOUBLE PRECISION similarity.
-- NOTE: Patient.id / MedicineBox.deviceId are both stored as TEXT on Postgres
-- (Prisma @default(uuid()) with String column maps to TEXT on PG), so our FK
-- columns MUST be TEXT to be type-compatible. UUID type on our side would fail.

CREATE TABLE IF NOT EXISTS "FaceVerificationEvent" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "deviceId" TEXT,
  "patientId" TEXT NOT NULL,
  "verified" BOOLEAN NOT NULL,
  "similarity" DOUBLE PRECISION,
  "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "FaceVerificationEvent_deviceId_fkey" FOREIGN KEY ("deviceId")
    REFERENCES "MedicineBox"("deviceId") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "FaceVerificationEvent_patientId_fkey" FOREIGN KEY ("patientId")
    REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "FaceVerificationEvent_deviceId_timestamp_idx"
  ON "FaceVerificationEvent"("deviceId" ASC, "timestamp" DESC);

CREATE INDEX IF NOT EXISTS "FaceVerificationEvent_patientId_timestamp_idx"
  ON "FaceVerificationEvent"("patientId" ASC, "timestamp" DESC);

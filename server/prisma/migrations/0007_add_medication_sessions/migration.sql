CREATE TYPE "MedicationSessionResult" AS ENUM (
  'PATIENT_TAKEN',
  'PATIENT_SKIPPED',
  'FACE_RECOGNITION_FAILED',
  'DISPENSING_FAILED',
  'DEVICE_FAILURE'
);

CREATE TABLE "MedicationSession" (
  "id" TEXT NOT NULL,
  "scheduleId" TEXT NOT NULL,
  "patientId" TEXT NOT NULL,
  "medicationId" TEXT NOT NULL,
  "drawerId" TEXT NOT NULL,
  "scheduledAt" TIMESTAMP(3) NOT NULL,
  "startedAt" TIMESTAMP(3),
  "completedAt" TIMESTAMP(3),
  "quantityBefore" INTEGER NOT NULL,
  "quantityAfter" INTEGER,
  "result" "MedicationSessionResult",
  CONSTRAINT "MedicationSession_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "MedicationSession" ADD CONSTRAINT "MedicationSession_scheduleId_fkey" FOREIGN KEY ("scheduleId") REFERENCES "Schedule"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MedicationSession" ADD CONSTRAINT "MedicationSession_patientId_fkey" FOREIGN KEY ("patientId") REFERENCES "Patient"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MedicationSession" ADD CONSTRAINT "MedicationSession_medicationId_fkey" FOREIGN KEY ("medicationId") REFERENCES "Medication"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MedicationSession" ADD CONSTRAINT "MedicationSession_drawerId_fkey" FOREIGN KEY ("drawerId") REFERENCES "Drawer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "MedicationSession_scheduleId_idx" ON "MedicationSession"("scheduleId");
CREATE INDEX "MedicationSession_patientId_idx" ON "MedicationSession"("patientId");
CREATE INDEX "MedicationSession_medicationId_idx" ON "MedicationSession"("medicationId");
CREATE INDEX "MedicationSession_drawerId_idx" ON "MedicationSession"("drawerId");
CREATE INDEX "MedicationSession_scheduleId_scheduledAt_idx" ON "MedicationSession"("scheduleId", "scheduledAt");
CREATE INDEX "MedicationSession_drawerId_completedAt_idx" ON "MedicationSession"("drawerId", "completedAt");

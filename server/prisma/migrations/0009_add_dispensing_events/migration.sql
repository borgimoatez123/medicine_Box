CREATE TYPE "PhysicalDeviceEvent" AS ENUM ('DISPENSING_STARTED', 'DISPENSING_SUCCESS', 'DISPENSING_FAILED', 'DRAWER_OPENED', 'DRAWER_CLOSED', 'QUANTITY_CHANGED');

CREATE TABLE "DispensingEvent" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "medicineBoxId" TEXT NOT NULL,
    "drawerId" TEXT NOT NULL,
    "event" "PhysicalDeviceEvent" NOT NULL,
    "quantityBefore" INTEGER,
    "quantityAfter" INTEGER,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DispensingEvent_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DispensingEvent_eventId_key" ON "DispensingEvent"("eventId");

CREATE INDEX "DispensingEvent_medicineBoxId_idx" ON "DispensingEvent"("medicineBoxId");

CREATE INDEX "DispensingEvent_drawerId_idx" ON "DispensingEvent"("drawerId");

CREATE INDEX "DispensingEvent_eventId_idx" ON "DispensingEvent"("eventId");

CREATE INDEX "DispensingEvent_drawerId_recordedAt_idx" ON "DispensingEvent"("drawerId", "recordedAt");

ALTER TABLE "DispensingEvent" ADD CONSTRAINT "DispensingEvent_medicineBoxId_fkey" FOREIGN KEY ("medicineBoxId") REFERENCES "MedicineBox"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "DispensingEvent" ADD CONSTRAINT "DispensingEvent_drawerId_fkey" FOREIGN KEY ("drawerId") REFERENCES "Drawer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

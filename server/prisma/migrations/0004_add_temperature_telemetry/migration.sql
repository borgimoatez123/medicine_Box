ALTER TABLE "Drawer" ADD COLUMN "temperature" DOUBLE PRECISION;

CREATE TABLE "TemperatureReading" (
    "id" TEXT NOT NULL,
    "drawerId" TEXT NOT NULL,
    "temperature" DOUBLE PRECISION NOT NULL,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TemperatureReading_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "TemperatureReading"
    ADD CONSTRAINT "TemperatureReading_drawerId_fkey"
    FOREIGN KEY ("drawerId") REFERENCES "Drawer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "TemperatureReading_drawerId_idx" ON "TemperatureReading"("drawerId");
CREATE INDEX "TemperatureReading_drawerId_recordedAt_idx" ON "TemperatureReading"("drawerId", "recordedAt");

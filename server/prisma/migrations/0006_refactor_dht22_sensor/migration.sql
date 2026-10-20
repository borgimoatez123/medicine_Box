ALTER TABLE "TemperatureReading" RENAME TO "DHT22Reading";

ALTER TABLE "DHT22Reading" ADD COLUMN "humidity" DOUBLE PRECISION;
UPDATE "DHT22Reading" SET "humidity" = 0 WHERE "humidity" IS NULL;
ALTER TABLE "DHT22Reading" ALTER COLUMN "humidity" SET NOT NULL;

ALTER TABLE IF EXISTS "TemperatureReading_drawerId_idx" RENAME TO "DHT22Reading_drawerId_idx";
ALTER TABLE IF EXISTS "TemperatureReading_drawerId_recordedAt_idx" RENAME TO "DHT22Reading_drawerId_recordedAt_idx";

ALTER TABLE "Drawer" ADD COLUMN "humidity" DOUBLE PRECISION;

-- Migration 0010: Remove Raspberry Pi / physical-device subsystem
-- Reverses 0002, 0003, 0004, 0005, 0006, 0009
-- Safe, incremental, non-destructive (uses IF EXISTS / DROP CASCADE)

-- 1. Drop device-only tables (target of back-refs first, cascade FKs)
DROP TABLE IF EXISTS "DispensingEvent" CASCADE;
DROP TABLE IF EXISTS "QuantityReading" CASCADE;
DROP TABLE IF EXISTS "DHT22Reading" CASCADE;

-- 2. Drop device-only fields from MedicineBox
ALTER TABLE "MedicineBox" DROP COLUMN IF EXISTS "deviceStatus";
ALTER TABLE "MedicineBox" DROP COLUMN IF EXISTS "lastSeenAt";

-- 3. Drop device-only fields from Drawer
ALTER TABLE "Drawer" DROP COLUMN IF EXISTS "temperature";
ALTER TABLE "Drawer" DROP COLUMN IF EXISTS "humidity";

-- 4. Drop device-only enums
DROP TYPE IF EXISTS "PhysicalDeviceEvent" CASCADE;
DROP TYPE IF EXISTS "DeviceStatus" CASCADE;

-- Safe add missingQuantity column to DrawerMedication
-- Intentionally nullable to preserve existing rows without backfill
ALTER TABLE "DrawerMedication" ADD COLUMN "missingQuantity" INTEGER;

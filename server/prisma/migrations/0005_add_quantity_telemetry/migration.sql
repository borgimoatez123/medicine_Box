ALTER TABLE "DrawerMedication" ADD COLUMN "quantity" INTEGER;

CREATE TABLE "QuantityReading" (
    "id" TEXT NOT NULL,
    "drawerId" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "QuantityReading_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "QuantityReading" ADD CONSTRAINT "QuantityReading_drawerId_fkey" FOREIGN KEY ("drawerId") REFERENCES "Drawer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "QuantityReading_drawerId_idx" ON "QuantityReading"("drawerId");
CREATE INDEX "QuantityReading_drawerId_recordedAt_idx" ON "QuantityReading"("drawerId", "recordedAt");

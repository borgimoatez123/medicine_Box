-- ================================================================
-- 0002_add_device_status_and_enums
--
-- Splits the overloaded single-status MedicineBoxStatus into two
-- concepts and adds MedicineBox.deviceStatus.
--
-- NOTE: Postgres (all versions through 17+) does NOT support
--       `ALTER TYPE ... DROP VALUE 'xyz'` for enums.  Therefore
--       we use the standard "swap enum" pattern:
--         1. Create a new enum type with corrected values
--         2. Drop column default
--         3. ALTER COLUMN ... TYPE new_enum USING ...::text::new_enum
--         4. Re-add column default
--         5. Drop old enum and rename new -> original.
--
-- All operations are idempotent / existence-guarded so this script
-- can be run against a database that is already partially-converted
-- without error (e.g. DeviceStatus already created).
-- ================================================================

BEGIN;

-- ----------------------------------------------------------------
-- 1. Create DeviceStatus enum (ACTIVE | OFFLINE) if missing.
-- ----------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_type t
      JOIN pg_namespace n ON n.oid = t.typnamespace
     WHERE n.nspname = 'public'
       AND t.typname = 'DeviceStatus'
       AND t.typtype = 'e'
  ) THEN
    CREATE TYPE "DeviceStatus" AS ENUM ('ACTIVE', 'OFFLINE');
  END IF;
END $$;

-- ----------------------------------------------------------------
-- 2. REGISTERED -> READY rename in the legacy MedicineBoxStatus
--    enum, but ONLY if REGISTERED is still present and READY is
--    not.  If REGISTERED was already renamed in a prior partial
--    execution the DO block simply no-ops.
-- ----------------------------------------------------------------
DO $$ DECLARE
  has_registered boolean;
  has_ready      boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
      FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
      JOIN pg_namespace n ON n.oid = t.typnamespace
     WHERE n.nspname='public'
       AND t.typname='MedicineBoxStatus'
       AND e.enumlabel='REGISTERED'
  ) INTO has_registered;

  SELECT EXISTS (
    SELECT 1
      FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
      JOIN pg_namespace n ON n.oid = t.typnamespace
     WHERE n.nspname='public'
       AND t.typname='MedicineBoxStatus'
       AND e.enumlabel='READY'
  ) INTO has_ready;

  IF has_registered AND NOT has_ready THEN
    ALTER TYPE "MedicineBoxStatus" RENAME VALUE 'REGISTERED' TO 'READY';
  END IF;
END $$;

-- ----------------------------------------------------------------
-- 3. Migrate any rows that still carry the legacy OFFLINE *lifecycle*
--    value to a proper lifecycle value based on userId presence.
--    OFFLINE leaves the enum entirely after this migration; it now
--    belongs exclusively to DeviceStatus.
-- ----------------------------------------------------------------
UPDATE "MedicineBox"
   SET "status" = CASE
                    WHEN "userId" IS NULL THEN 'READY'::text::"MedicineBoxStatus"
                    ELSE                     'ACTIVE'::text::"MedicineBoxStatus"
                  END
 WHERE EXISTS (
         SELECT 1
           FROM pg_type t
           JOIN pg_enum e ON e.enumtypid = t.oid
           JOIN pg_namespace n ON n.oid = t.typnamespace
          WHERE n.nspname='public'
            AND t.typname='MedicineBoxStatus'
            AND e.enumlabel='OFFLINE'
       )
   AND "status"::text = 'OFFLINE';

-- ----------------------------------------------------------------
-- 4. Correct the ambiguous transitional state:
--      status = ACTIVE   AND   userId IS NULL
--    ACTIVE means "user-owned" in the new model, so without an
--    owner this row actually means "provisioned / available" and
--    must be READY.
-- ----------------------------------------------------------------
UPDATE "MedicineBox"
   SET "status" = 'READY'::"MedicineBoxStatus"
 WHERE "status" = 'ACTIVE'::"MedicineBoxStatus"
   AND "userId" IS NULL;

-- ----------------------------------------------------------------
-- 5. Replace the MedicineBoxStatus enum so the OFFLINE value no
--    longer exists inside it.  Postgres does not support DROP VALUE.
-- ----------------------------------------------------------------
DO $$ DECLARE
  offline_still_present boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
      FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
      JOIN pg_namespace n ON n.oid = t.typnamespace
     WHERE n.nspname='public'
       AND t.typname='MedicineBoxStatus'
       AND e.enumlabel='OFFLINE'
  ) INTO offline_still_present;

  IF offline_still_present THEN
    -- 5a. build the replacement enum
    DROP TYPE IF EXISTS "MedicineBoxStatus_new";
    CREATE TYPE "MedicineBoxStatus_new" AS ENUM ('READY', 'ACTIVE', 'MAINTENANCE');

    -- 5b. drop the status column's DEFAULT so Postgres can cast the
    --     column type between enums.
    ALTER TABLE "MedicineBox" ALTER COLUMN "status" DROP DEFAULT;

    -- 5c. cast column type to replacement enum (text cast is safe
    --     because we already ensured every row carries READY, ACTIVE,
    --     or MAINTENANCE from steps 3 + 4).
    ALTER TABLE "MedicineBox"
      ALTER COLUMN "status" TYPE "MedicineBoxStatus_new"
      USING "status"::text::"MedicineBoxStatus_new";

    -- 5d. restore the Prisma-schema default for the new enum.
    ALTER TABLE "MedicineBox"
      ALTER COLUMN "status" SET DEFAULT 'READY'::"MedicineBoxStatus_new";

    -- 5e. swap names: old out, new in.
    DROP TYPE "MedicineBoxStatus";
    ALTER TYPE "MedicineBoxStatus_new" RENAME TO "MedicineBoxStatus";
  END IF;
END $$;

-- ----------------------------------------------------------------
-- 6. Add MedicineBox.deviceStatus column if missing.
--    Non-nullable with default OFFLINE (conservative; backend must
--    never claim a device is online without a real heartbeat).
-- ----------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name   = 'MedicineBox'
       AND column_name  = 'deviceStatus'
  ) THEN
    ALTER TABLE "MedicineBox"
      ADD COLUMN "deviceStatus" "DeviceStatus" NOT NULL DEFAULT 'OFFLINE';
  END IF;
END $$;

-- ----------------------------------------------------------------
-- 7. Guarantee MedicineBox.status default = 'READY' to match
--    Prisma schema @default(READY).  If steps 2 or 5 ran they
--    already set this, but repeating the ALTER ... SET DEFAULT is
--    a cheap no-op and keeps the "partially-converted DB"
--    idempotency story clean.
-- ----------------------------------------------------------------
ALTER TABLE "MedicineBox"
  ALTER COLUMN "status" SET DEFAULT 'READY'::"MedicineBoxStatus";

COMMIT;

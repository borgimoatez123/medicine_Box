# Tasks: Remove Raspberry Pi / Device Subsystem

Parent spec: `.trae/specs/remove-raspberry-pi-device-subsystem/spec.md`

---

## Task 1: DELETE files belonging purely to the device subsystem
**Priority:** high
**Status:** pending
**Dependencies:** none

### Scope
Delete (do not edit to empty):
- `src/presentation/middlewares/deviceAuthMiddleware.ts`
- `src/presentation/controllers/DevicesController.ts`
- `src/presentation/routes/devices.routes.ts`
- `src/presentation/validators/deviceTelemetry.validator.ts`
- `src/domain/entities/DispensingEvent.ts`
- `src/domain/repositories/IDispensingEventRepository.ts`
- `src/infrastructure/database/prisma/repositories/PrismaDispensingEventRepository.ts`
- `src/application/use-cases/medicine-box/DeviceHeartbeat.ts`
- `src/application/use-cases/medicine-box/ReportDrawerDHT22.ts`
- `src/application/use-cases/medicine-box/ReportDrawerQuantity.ts`
- `src/application/use-cases/medicine-box/ReportPhysicalDispensingEvent.ts`
- `src/application/utils/assertUsableForPhysicalOps.ts`
- `tests/device-heartbeat.spec.ts`
- `tests/device-telemetry-dht22.spec.ts`
- `tests/device-telemetry-quantity.spec.ts`
- `tests/step4a-dispensing-events.spec.ts`
- `RASPBERRY-PI-POSTMAN-TESTS.txt`
- `TEST-ENDPOINTS.txt` (device endpoints only, but entire file is device/pi test oriented → delete whole file; if user later complains we can regenerate without device section, but current file 100% device smoke steps)
- `_smoke_output.txt` (previous device smoke test output)

**Rule TR 1.1:** After deletion, `git status` (or dir listing) must show all these filenames no longer exist. Evidence: `npx tsc --strict --noEmit` passes only after remaining references are also cleaned up in Tasks 2–5; but verify files don't exist via LS first.

**Rule TR 1.2:** Router import removed from `app.ts` → compile errors about missing import not present (resolves itself after Task 3).

---

## Task 2: Clean remaining references from app.ts + routes mount
**Priority:** high
**Status:** pending
**Dependencies:** Task 1

**Rule TR 2.1:** `src/app.ts` no longer imports `devicesRouter`, no longer mounts `app.use('/api/devices', devicesRouter)`.
**Rule TR 2.2:** AllowedHeaders in CORS config still doesn't mention X-Device-* (it doesn't currently). No change needed.

---

## Task 3: Domain layer — remove device-only entities/interfaces
**Priority:** high
**Status:** pending
**Dependencies:** Task 1

### Scope
1. **MedicineBox entity**
   Remove fields: `DeviceStatus` type, `deviceStatus`, `lastSeenAt`.
   Keep: `deviceId`, `deviceToken`, `status`, `userId`, `numberOfDrawers`, `drawerCapacity`, timestamps.

2. **Drawer entity**
   Remove: `temperature`, `humidity` fields + entire `DHT22Reading` interface.

3. **DrawerMedication entity**
   Remove: entire `QuantityReading` interface.

4. **IMedicineBoxRepository interface**
   Remove: `verifyDeviceCredentials`, `markDeviceSeen`, `touchLastSeenAndSetActiveByDeviceId`, type aliases `DeviceHeartbeatResult`, `MarkDeviceSeenResult`, remove `deviceStatus`/`lastSeenAt` fields from `CreateMedicineBoxData`/`UpdateMedicineBoxData`/`AdminUpdateMedicineBoxData`.
   Keep: `findByDeviceId`, `existsByDeviceId`, `findById`, `findAll`, `create`, `update`, `adminUpdate`, `activateAtomic`, `releaseOwnership`, `findAllByUserId`, `findByIdAndUserId`.

5. **IDrawerRepository interface**
   Remove: `ReportDHT22Result`, `reportDHT22`, `listDHT22Readings`.
   Remove `temperature` / `humidity` from `CreateDrawerData` / `UpdateDrawerData` (they become empty optional → keep types trimmed, remove these 2 fields).

6. **IDrawerMedicationRepository interface**
   Remove: `ReportCurrentQuantityResult`, `ReportPhysicalDispensingResult`, `reportCurrentQuantity`, `listQuantityReadings`, `reportPhysicalDispensing`.
   Also remove `QuantityReading` import (it was removed in 3.3).

7. Keep: `IMedicationSessionRepository`, `IMedicineBoxRepository` methods still used.

**Rule TR 3.1:** tsc strict noEmit no type errors in domain folder after all edits.

---

## Task 4: Infrastructure Prisma repos — align to interfaces
**Priority:** high
**Status:** pending
**Dependencies:** Task 3

### Scope
1. **PrismaMedicineBoxRepository**
   Remove methods: `verifyDeviceCredentials`, `markDeviceSeen`, `touchLastSeenAndSetActiveByDeviceId`.
   Remove `deviceStatus`/`lastSeenAt` writes from `create()` and `adminUpdate()`.
   `toDomain()` no longer copies `deviceStatus`/`lastSeenAt`.
   Keep `findByDeviceId`/`existsByDeviceId` + Activate flow.
   `toPublicMedicineBox` still omits `deviceToken`. Keep it because deviceToken field still on the domain entity as activation key.

2. **PrismaDrawerRepository**
   Remove methods: `reportDHT22`, `listDHT22Readings`.
   Remove `temperature`/`humidity` from `create()`, `update()`, `toDomain()`, from `CreateDrawerData`-like usage.
   Remove back-ref to dispensingEvents/dht22Readings when schema changes later in Task 5.

3. **PrismaDrawerMedicationRepository**
   Remove methods: `reportCurrentQuantity`, `listQuantityReadings`, `reportPhysicalDispensing` (incl `ReportPhysicalDispensingResult` import).
   Keep all other methods (find, crud, upsert, findByDrawerId etc).

4. No edits to `PrismaMedicationSessionRepository`, `PrismaUserRepository`, etc — unless tsc reports unused imports.

**Rule TR 4.1:** tsc strict 0 errors in infrastructure after Task 5 prisma schema applied.

---

## Task 5: Prisma schema edits + migration 0010
**Priority:** high
**Status:** pending
**Dependencies:** Task 3 + 4 (interface clean first so models match)

### Scope
Edit `prisma/schema.prisma`:
1. DELETE enum `DeviceStatus`.
2. DELETE enum `PhysicalDeviceEvent`.
3. DELETE entire model `DispensingEvent`.
4. DELETE entire model `Dht22Reading`.
5. DELETE entire model `QuantityReading`.
6. `MedicineBox` model — REMOVE fields `deviceId? no — KEEP deviceId`, keep `deviceToken`. REMOVE only `deviceStatus DeviceStatus @default(OFFLINE)`, `lastSeenAt DateTime?`. Also REMOVE `dispensingEvents DispensingEvent[]` back-ref.
7. `Drawer` model — REMOVE `temperature Float?`, `humidity Float?`. REMOVE back-ref fields `dht22Readings Dht22Reading[]`, `quantityReadings QuantityReading[]`, `dispensingEvents DispensingEvent[]`.

### Migration
Create `prisma/migrations/0010_remove_device_subsystem/migration.sql` with safe SQL:
```sql
ALTER TABLE "Drawer"     DROP COLUMN IF EXISTS "temperature";
ALTER TABLE "Drawer"     DROP COLUMN IF EXISTS "humidity";

ALTER TABLE "MedicineBox" DROP COLUMN IF EXISTS "deviceStatus";
ALTER TABLE "MedicineBox" DROP COLUMN IF EXISTS "lastSeenAt";

DROP TABLE IF EXISTS "DispensingEvent"  CASCADE;
DROP TABLE IF EXISTS "DHT22Reading"    CASCADE;
DROP TABLE IF EXISTS "QuantityReading" CASCADE;

DROP TYPE IF EXISTS "PhysicalDeviceEvent";
DROP TYPE IF EXISTS "DeviceStatus";
```
Then `npx prisma migrate deploy` and then `prisma generate` + `prisma validate`.

**Rule TR 5.1:** `npx prisma validate` passes exit 0.
**Rule TR 5.2:** `npx prisma migrate status` — 10 migrations found, DB up to date.
**Rule TR 5.3:** No leftover references to removed models in schema (back-ref arrays removed from MedicineBox/Drawer).

---

## Task 6: Presentation validators + controller cleanup
**Priority:** high
**Status:** pending
**Dependencies:** Task 3, 5

### Scope
1. `medicineBox.validator.ts`:
   - Remove `DeviceStatus` import, remove `validDeviceStatuses` array, remove `deviceStatus` field from `adminUpdateMedicineBoxSchema` object.
   - Keep `addMedicineBoxSchema` (deviceId, deviceToken still required for admin provisioning).
   - Keep `activateMedicineBoxSchema` (deviceId, deviceToken still credentials for Flutter activation).
   - Keep `userUpdateMedicineBoxSchema` as-is.

2. No `DevicesController` anymore (deleted → no edits needed).

3. MedicineBoxController.ts still only uses valid schemas.

**Rule TR 6.1:** tsc strict noEmit clean presentation layer.

---

## Task 7: Update tests / mock types in remaining suites
**Priority:** high
**Status:** pending
**Dependencies:** Tasks 3,4,5,6

### Scope
1. `tests/drawer-medication-api.spec.ts`: remove `reportPhysicalDispensing` field from `MockDrawerMedRepo` type and factory `mockDm()`.
2. Check other files — use global grep for:
   - `reportCurrentQuantity`
   - `listQuantityReadings`
   - `reportPhysicalDispensing`
   - `markDeviceSeen`
   - `verifyDeviceCredentials`
   - `deviceStatus` / `lastSeenAt` references in remaining test files
3. In tests that build medicine boxes (e.g. `auth-rbac-ownership.spec.ts`, `medicine-box-api.spec.ts`, etc.) — they may set `deviceStatus:'OFFLINE'`, `lastSeenAt: null`, and `deviceToken`. Remove the first two fields from fixture builder calls; keep deviceToken/deviceId because those still in domain.
4. Remove any assert about `deviceStatus = ACTIVE` after `markDeviceSeen` in non-device tests.

**Rule TR 7.1:** `npx jest --forceExit` 0 failures.

---

## Task 8: Env vars, README, package deps
**Priority:** low
**Status:** pending
**Dependencies:** All prior

**Scope:**
1. Inspect `.env` and `.env.example` for Raspberry Pi–specific vars (e.g. `DEVICE_*`, `RASPBERRY_*`). If none exist → skip delete. Do not touch DATABASE_URL/JWT/SUPABASE.
2. Scan `README.md` for any mention of: heartbeat, /api/devices, DispensingEvent, X-Device-Id, X-Device-Token, Raspberry Pi, `PI-DEV-001`, `PI-SECRET-T0K3N`. Delete/rewrite only those sentences/lines containing device refs. Keep rest.

**Rule TR 8.1:** Keep env vars file still present, not corrupted.

---

## Task 9: Pipeline verification + global grep sweep
**Priority:** high
**Status:** pending
**Dependencies:** Tasks 1–8

### Scope
Run in order, fail-fast on errors:
1. `npx prisma validate`
2. `npx prisma migrate status` (10 migrations, DB schema up to date)
3. `npx prisma generate`
4. `npx tsc --strict --noEmit`
5. `npx jest --forceExit` (all tests pass)
6. `npm run build` (if script present in package.json)
7. Global grep sweep for the list in spec AC-10. Produce an explicit list of any remaining matches with the exact file:line and the EXPLANATION why it was INTENTIONALLY kept (e.g. `deviceId` field kept because ActivateMedicineBox uses it as provisioning identifier). Clean up any that are actually leftover/commented dead Raspberry Pi references.

**Rule TR 9.1:** All pipeline steps exit 0.
**Rule TR 9.2:** AC-10 final grep produces only explicitly justified remaining identifiers (deviceId / deviceToken kept as activation keys, not Raspberry Pi runtime code).

---

## Task 10: Write final report
**Priority:** medium
**Status:** pending
**Dependencies:** Task 9 green

**Scope**
Return final concise report to the user matching requested sections:
- Removed
- Database changes (removed models / fields / enums / indexes; preserved models)
- Preserved
- Verification (results)
- Remaining references with exact file:line + intentional keep rationale

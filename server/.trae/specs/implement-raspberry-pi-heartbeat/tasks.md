# TASKS: Implement Raspberry Pi Heartbeat Feature

Dependency order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

Global success criterion: every rule AC, every rubric meets threshold; pipeline green.

---

## Task 1: Prisma Schema + Migration 0011

**Parent ACs**: AC-1, AC-2, FR-8

**Description: 
1. Edit `prisma/schema.prisma`: re-add:
   - `enum DeviceStatus { ACTIVE OFFLINE }` after MedicineBoxStatus enum.
   - Add `deviceStatus DeviceStatus @default(OFFLINE)` field on MedicineBox model.
   - Add `lastSeenAt DateTime?` field on MedicineBox model.
2. Create `prisma/migrations/0011_add_device_heartbeat/migration.sql` with safe SQL:
   ```sql
   CREATE TYPE IF NOT EXISTS "DeviceStatus" AS ENUM ('ACTIVE', 'OFFLINE');
   ALTER TABLE "MedicineBox" ADD COLUMN IF NOT EXISTS "deviceStatus" "DeviceStatus" NOT NULL DEFAULT 'OFFLINE';
   ALTER TABLE "MedicineBox" ADD COLUMN IF NOT EXISTS "lastSeenAt" TIMESTAMP(3);
   ```
3. Run `npx prisma format && npx prisma validate && npx prisma migrate deploy && npx prisma generate`.

**Test Requirements** (TRs):
- TR-1 [rule] `npx prisma validate` exits with exit code 0.
- TR-2 [rule] `npx prisma migrate status` reports 11 migrations found, all applied.
- TR-3 [rule] `grep schema.prisma for `PhysicalDeviceEvent | DispensingEvent | Dht22Reading | QuantityReading returns empty (0 matches).

**Status**: pending
**Blocked By**: none
**Completion Evidence**: (to be filled)

---

## Task 2: Domain Entity + Repository Interface

**Parent ACs**: AC-1, NFR-1, FR-9

Description:
1. `src/domain/entities/MedicineBox.ts`:
   - Add `export type DeviceStatus = 'ACTIVE' | 'OFFLINE';`
   - Add to MedicineBox interface: `deviceStatus: DeviceStatus;` `lastSeenAt: Date | null;`
2. `src/domain/repositories/IMedicineBoxRepository.ts`:
   - Add two methods to interface:
     - `markDeviceSeen(deviceId: string): Promise<MedicineBox | null>;`
     - `markStaleDevicesOffline(thresholdMs: number): Promise<number>;`

**TRs**:
- TR-1 [rule] `npx tsc --strict --noEmit 2>&1 | Select-Object -First 40 shows 0 new errors (ignore Prisma type mismatch in `tsc` after Task 4 complete)
- TR-2 [rule] grep IMedicineBoxRepository.ts interface has exactly 2 new method signatures added; every existing method untouched.

**Status**: pending
**Blocked By**: Task 1 (need Prisma generate before TS types)
**Completion Evidence**: (to be filled)

---

## Task 3: Prisma Repository Implementation

**Parent ACs**: FR-9, NFR-1

Description: Update `PrismaMedicineBoxRepository.ts`:
1. `toDomain()`: map deviceStatus (`'ACTIVE'|'OFFLINE'` from Prisma enum → domain `toDate | null);
2. Implement `markDeviceSeen(deviceId)`:
   ```ts
   async markDeviceSeen(deviceId: string): Promise<MedicineBox | null> {
     try {
       const box = await prisma.medicineBox.update({
         where: { deviceId },
         data: { deviceStatus: 'ACTIVE', lastSeenAt: new Date() },
       });
       return this.toDomain(box);
     } catch (e) {
       // Prisma P2025 = not found
       return null;
     }
   }
   ```
3. Implement `markStaleDevicesOffline(thresholdMs: number):
   ```ts
   const thresholdDate = new Date(Date.now() - thresholdMs);
   const res = await prisma.medicineBox.updateMany({ where: { deviceStatus: 'ACTIVE', lastSeenAt: { lt: thresholdDate } }, data: { deviceStatus: 'OFFLINE' } });
   return res.count;
   ```

**TRs**:
- TR-1 [rule] Concrete repo class has both new methods; tsc strict passes.
- TR-2 [rule] No existing method (create/update/adminUpdate/activateAtomic/releaseOwnership methods untouched (file diff against baseline) — no method body changed.

**Status**: pending
**Blocked By**: Task 1, Task 2
**Completion Evidence**: (to be filled)

---

## Task 4: DeviceHeartbeat Use Case + DeviceOfflineMonitor Module

**Parent ACs**: FR-10, FR-6, NFR-1

Description:
1. `src/application/use-cases/device/DeviceHeartbeat.ts` new folder and file. Constructor takes `IMedicineBoxRepository`. `execute(id) double-checks non-empty, calls `findByDeviceId` (NotFoundError if null), calls `markDeviceSeen`, returns `{ deviceId, status: 'ACTIVE', lastSeen: updated.lastSeenAt }`.
2. `src/application/services/DeviceOfflineMonitor.ts` new module:
   ```ts
   let interval: NodeJS.Timeout | null = null;
   const DEFAULT_THRESHOLD_MS = 5000;
   const DEFAULT_INTERVAL_MS = 1000;
   export function getOfflineThresholdMs(): number { return Number(process.env.DEVICE_OFFLINE_THRESHOLD_MS ?? DEFAULT_THRESHOLD_MS);
   export async function runOfflineDetectionNow(): Promise<number> { const repo = new PrismaMedicineBoxRepository(); return repo.markStaleDevicesOffline(getOfflineThresholdMs()); }
   export function startOfflineMonitor(): void { if (interval) return; interval = setInterval(async () => { try { await runOfflineDetectionNow(); } catch (e) { console.error('[offline-monitor]', e); } }, Number(process.env.DEVICE_MONITOR_INTERVAL_MS ?? DEFAULT_INTERVAL_MS)); }
   export function stopOfflineMonitor(): void { if (interval) clearInterval(interval); interval = null; }
   ```

**TRs**:
- TR-1 [rule] DeviceHeartbeat execute throws NotFoundError for unknown deviceId after findByDeviceId returns null.
- TR-2 [rule] `stopOfflineMonitor` is exported and clears the interval; no open-handle warning after calling stop.

**Status**: pending
**Blocked By**: Task 2
**Completion Evidence**: (to be filled)

---

## Task 5: Validator + DevicesController + devices.routes.ts + mount in app.ts

**Parent ACs**: AC-3, AC-9, FR-1, FR-2, FR-7, NFR-1

Description:
1. `src/presentation/validators/devices.validator.ts`:
   ```ts
   import { z } from 'zod';
   export const heartbeatSchema = z.object({ deviceId: z.string().trim().min(1, 'deviceId is required') }).strict();
   // FUTURE DEVICE AUTH EXTENSION:
   // export const deviceHeadersSchema = z.object({ 'x-device-id': z.string().min(1), 'x-device-token': z.string().min(1) }).strip();
   ```
2. `src/presentation/controllers/DevicesController.ts` - pattern match MedicineBoxController style with static object of async functions (req, res, next), zod safeParse, BadRequestError formatZodErrors, repo instantiate `new PrismaMedicineBoxRepository(); `new DeviceHeartbeat(`, call, existing `status: success, statusCode, data: { deviceId, status, lastSeen: .toISOString()}
3. `src/presentation/routes/devices.routes.ts` Router(); heartbeatController.heartbeat
4. `app.ts` import devicesRouter + `app.use('/api/devices', devicesRouter);` insert between drawerMedicationRouter and errorMiddleware.
5. Add single limitation comment at controller top:
   ```ts
   // SECURITY LIMITATION (intentional this iteration): device auth (X-Device-Id / X-Device-Token headers) is NOT enforced here. See spec.md OQ-1. Callers with a known deviceId can submit heartbeats today. Extend with devices.validator.ts deviceHeadersSchema when enforcing.
   ```

**TRs**:
- TR-1 [rule] Posting `{ deviceId: ' ' }` (whitespace) → 400 Bad Request.
- TR-2 [rule] device.routes.ts mounts DevicesController.heartbeat at POST /.
- TR-3 [rule] App.ts has devicesRouter import + app.use line present. tsc --strict passes.
- TR-4 [rule] devices.validator.ts line `deviceHeadersSchema stub is commented out as an explicit comment (stub present.

**Status**: pending
**Blocked By**: Task 4

---

## Task 6: Hook Offline Monitor Start in server.ts

**Parent ACs**: AC-4, FR-6

Description: `src/server.ts start() function. After logDatabaseStatus() and before app.listen, call `startOfflineMonitor();`. Additionally, inside the shutdown() function after server.close and before process.exit(0), call `stopOfflineMonitor()`. Add `.env.example`: insert `DEVICE_OFFLINE_THRESHOLD_MS=5000` and `#DEVICE_MONITOR_INTERVAL_MS=1000` commented interval override line).

**TRs**:
- TR-1 [rule] server shutdown calls stopOfflineMonitor and no open handles during graceful shutdown.
- TR-2 [rule] .env.example has DEVICE_OFFLINE_THRESHOLD_MS=5000 present.

**Status**: pending
**Blocked By**: Task 5
**Completion Evidence**: (to be filled)

---

## Task 7: Jest Test Suite (5 tests required per user spec section 13)

**Parent ACs**: AC-3, AC-4, AC-7

Description: `tests/device-heartbeat.spec.ts`. 5 sequential tests. Use pattern (Mock IMedicineBoxRepository + runOfflineDetectionNow in-memory jest.fn() mocks).

### Test 1 (Valid heartbeat):
mockRepo.findByDeviceId → returns buildBox(deviceId:'PI-DEV-001', status:'ACTIVE')
mockRepo.markDeviceSeen → returns updated with lastSeen = now().
DeviceHeartbeat UC returns data.deviceId = 'PI-DEV-001', status 'ACTIVE', lastSeen within 3000 ms of Date.now().

### Test 2 (Missing deviceId, controller zod validation):
Pass {} body → zod fail (400). Controller/zod BadRequest with message === 'deviceId is required'.

### Test 3 (Unknown deviceId):
UC calls markDeviceSeen → null → throw NotFoundError 'Device not found'.

### Test 4 (Previously OFFLINE → ACTIVE after heartbeat):
mock markDeviceSeen returns box previously OFFLINE; heartbeat → deviceStatus: 'ACTIVE', lastSeenAt: Date.

### Test 5 (Offline detection flips stale ACTIVE→OFFLINE fresh remains):
Build two rows: [boxA(lastSeen = now - 10_000 ms status ACTIVE), boxB(lastSeen=now-1000 ACTIVE). Inject mock Prisma markStaleDevicesOffline thresholdMs =5000 → markStaleDevicesOffline updateMany called with threshold Date.now -5000 date-ish. return 1 (boxA flipped).

**TRs**:
- TR-1 [rule] 5 tests exist and `npx jest tests/device-heartbeat.spec.ts --forceExit  exits 0 0 failures.
- TR-2 [rule] All 5 tests tagged with descriptions matching Section 13 1–5 as named.

**Status**: pending
**Blocked By**: Task 4, Task 5

---

## Task 8: Postman Text Guide

**Parent ACs**: FR-11

Description: Create project root file `RASPBERRY-PI-HEARTBEAT-POSTMAN.txt` containing:
- POST endpoint http://localhost:3000/api/devices/heartbeat
- Headers: Content-Type: application/json
- Body { "deviceId": "PI-DEV-001" }
- Expected 200 JSON envelope example
- Expected 400 {} example
- Expected 404 unknown example
- Short "Offline Detection Explainer (5 s default threshold env-var configurable)

**TRs**:
- TR-1 [rule] File exists at correct path; non-empty; contains the exact endpoint and PI-DEV-001 example text.
- TR-2 [rule] No mention of DISPENSING, DHT22, QUANTITY endpoint URLs; scope-restricted to heartbeat only.

**Status**: pending
**Blocked By**: None (can run after task 1-5 for file written)

---

## Task 9: Full Verification Pipeline (Prisma / tsc / jest / build / global grep)

**Parent ACs**: AC-2, AC-6, AC-7, AC-8

**Execute strictly in order**. If any step non-zero exit → fix → rerun until green.

1. `npx prisma validate`.
2. `npx tsc --strict --noEmit`.
3. `npx jest --forceExit`.
4. `npm run build`.
5. Global search in src/ tests/ (excluding migrations 0001-0010) for keywords `DispensingEvent|PhysicalDeviceEvent|Dht22Reading|QuantityReading|reportDHT22|reportCurrentQuantity → 0 matches.

**TRs**:
- TR-1 [rule] All 5 pipeline steps pass (exit 0).
- TR-2 [rule] global grep in src/ tests/ returns 0 matches for deleted scope keywords.

**Status**: pending
**Blocked By**: Tasks 1–8 all complete
**Completion Evidence**: (to be filled)

---

## Task 10: Final Report to User (exact structure from user Section 16)

**Parent ACs**: All AC summary report written after Task 9 green:

Sections (per user Section 16 exactly):
1. Exact modified files list (paths with clickable format file:///…).
2. Prisma schema changes delta (added DeviceStatus enum, two fields, no new models).
3. Migration 0011 required SQL.
4. Final endpoint (verb + URL).
5. Request/Response format JSON examples.
6. Offline detection explanation (threshold env var, interval setInterval 1s, markStaleDevicesOffline).
7. Postman test instructions (copy of Task 8 file summary).
8. Existing tests run command + result (exit 0, counts).
9. Statement: "No unrelated functionality was modified" + list of preserved routes/features.
10. Evidence files/tests confirm feature works (Task 9 TR-1 passing).

**Status**: pending
**Blocked By**: Task 9 pipeline green
**Completion Evidence**: (delivered verbally to user chat)

# SPEC: Implement Raspberry Pi Heartbeat Feature

## Problem
Smart Medicine Box backend currently lacks any mechanism to track whether a physical Raspberry Pi device is alive and connected. The Flutter-facing MedicineBox provisioning model still stores `deviceId` + `deviceToken` (activation key pair), but no runtime connectivity tracking (last-seen timestamp, offline/active state) exists after the prior subsystem cleanup removed these fields.

## Users
- **Raspberry Pi client firmware**: calls the endpoint every ~0.5 s to signal liveness.
- **Backend operators / admin Flutter UI**: relies on status to display "Online/Offline" device state.
- **Future device features**: downstream endpoints that require an "is device connected?" check can read the stored fields.

## Goals
1. Expose **POST /api/devices/heartbeat** which validates the request, finds the MedicineBox row by `deviceId`, and updates two columns (`lastSeenAt`, `deviceStatus`) only.
2. Maintain an offline-detection job that flips any stale `deviceStatus=ACTIVE` row back to `deviceStatus=OFFLINE` when `now() - lastSeenAt` exceeds a configurable threshold.
3. Stay strictly within the heartbeat scope. Do NOT re-introduce dispensing, DHT22, quantity, device-token header auth middleware, or any other deleted Pi feature.

## Non-Goals (explicitly out of scope)
- ❌ Face Recognition, Camera APIs
- ❌ Schedule synchronization
- ❌ Medication sessions / dispensing events
- ❌ Drawer APIs (provision/load/refill)
- ❌ Sensor (temperature/humidity) telemetry
- ❌ Device authentication enforcement via `X-Device-Id` / `X-Device-Token` headers this iteration (extensibility hooks only)
- ❌ MQTT / WebSockets / external queues / Bull / Redis
- ❌ Heartbeat-history table (no rows inserted per heartbeat)
- ❌ Notifications

---

## Functional Requirements (FRs)

### FR-1 Endpoint
- `POST /api/devices/heartbeat` is mounted at the Express app via `app.use('/api/devices', devicesRouter)` (new route file, consistent with the existing 8 route files pattern).
- Request body shape: `{ deviceId: string }`.
- Response envelope follows the existing project format exactly: `{ status: 'success', statusCode: 200, data: HeartbeatResp }` where `HeartbeatResp = { deviceId: string, status: 'ACTIVE', lastSeen: string }` and `lastSeen` is an ISO-8601 UTC string.
- Request validates via zod validator in `validators/` folder consistent with `medicineBox.validator.ts` style.

### FR-2 Validation (Step 1)
- `deviceId` missing, empty string, non-string, or `" "` (whitespace-only) → `400 Bad Request` via `BadRequestError` class, message = exactly `"deviceId is required"`.
- Route controller catches, calls `next(error)`, existing `errorMiddleware` formats it.

### FR-3 Lookup (Step 2)
- Repository layer `findByDeviceId(deviceId)` already exists on `IMedicineBoxRepository`; reused as-is.
- Row not found → `404 Not Found` via `NotFoundError` class, message = exactly `"Device not found"`.
- Never auto-create a device row from a heartbeat (per requirement).

### FR-4 Update (Step 3)
- On success, repository method `markDeviceSeen(deviceId)` (new method added to interface + concrete Prisma impl):
  - Sets `lastSeenAt = now()` server-side (**backend clock only**; never accept client-supplied timestamp).
  - Sets `deviceStatus = ACTIVE`.
  - Uses a single `UPDATE` (atomic) and returns the updated MedicineBox domain entity.
- 480 heartbeats/min per device = ~8 Hz peak. The single-row in-place UPDATE is correct per the "no new row per heartbeat" rule.

### FR-5 Offline Detection (Rule-based)
- `DEVICE_OFFLINE_THRESHOLD_MS` configurable via `.env`. Default fallback = `5000` (5 seconds).
- Rule: For any row where `deviceStatus === ACTIVE` AND `now() - lastSeenAt > threshold` → set `deviceStatus = OFFLINE`.
- The check is deterministic and idempotent; re-running does not change already-OFFLINE rows.

### FR-6 Offline Detection (Runtime)
- Mechanism: minimal `setInterval` started inside `server.ts` start() after DB healthcheck, scheduled **every 1000 ms** (1 second, safely below the 5 s threshold, ~0.25x oversample so worst-case detection lag ~6 s).
- Export: `runOfflineDetectionNow(): Promise<number>` (returns rows flipped) so tests can run the logic without `jest.useFakeTimers()` complexity.
- Teardown: export `stopOfflineMonitor(): void` that `clearInterval`s so Jest tests don't leak open handles.
- No external packages added. No `node-cron`/`node-schedule`/Bull.
- Failure safety: if the background interval throws once (e.g., transient DB issue), it logs the error and MUST NOT rethrow or crash the interval. `try/catch` with `console.error` inside the interval tick body.

### FR-7 Device Authentication Compatibility
- The heartbeat route does NOT enforce `X-Device-Id` / `X-Device-Token` headers this iteration (the full middleware chain was removed in cleanup migration 0010).
- Compatibility hooks:
  1. The validator file is named `devices.validator.ts` and exports both `heartbeatSchema` (used now) and a reserved, commented-out stub of `deviceHeadersSchema` for future `X-Device-*` auth.
  2. Controller accepts but ignores headers; a single-line comment at the controller top clearly documents the limitation: "Device auth enforcement (X-Device-Id/X-Device-Token headers) is deferred. Any caller with a known deviceId can currently submit a heartbeat."
- No credentials invented; no hardcoded secrets.

### FR-8 Prisma Schema (Delta on top of migration 0010)
Because migration 0010 removed them:
1. **Re-add `DeviceStatus` enum**: `ACTIVE | OFFLINE`.
2. **Re-add `MedicineBox.deviceStatus DeviceStatus @default(OFFLINE)`**.
3. **Re-add `MedicineBox.lastSeenAt DateTime?`** (nullable because a freshly provisioned box has never heartbeaten).
4. **Do NOT re-add**: `DispensingEvent`, `PhysicalDeviceEvent`, `Dht22Reading`, `QuantityReading`, Drawer.temperature/humidity, back-ref arrays. These remain dropped forever for heartbeat-only scope.

### FR-9 Domain Layer Updates (Aligned with Clean Arch)
- `MedicineBox.ts` entity:
  - Add `export type DeviceStatus = 'ACTIVE' | 'OFFLINE'` mirroring the Prisma enum.
  - Add `deviceStatus: DeviceStatus; lastSeenAt: Date | null;` to the `MedicineBox` interface.
- `IMedicineBoxRepository.ts`:
  - Add `markDeviceSeen(deviceId: string): Promise<MedicineBox | null>`.
  - Add `markStaleDevicesOffline(thresholdMs: number): Promise<number>`.
  - Keep every existing method unchanged; do not break any Flutter-facing use cases.
- `PrismaMedicineBoxRepository.ts`:
  - `toDomain()` maps `deviceStatus` + `lastSeenAt` after prisma generate exposes the new fields.
  - `markDeviceSeen`: one `prisma.medicineBox.update(where: { deviceId }, data: { deviceStatus: 'ACTIVE', lastSeenAt: new Date() })` + return null if P2025 (not found).
  - `markStaleDevicesOffline`: one `prisma.medicineBox.updateMany({ where: { deviceStatus: 'ACTIVE', lastSeenAt: { lt: thresholdDate } }, data: { deviceStatus: 'OFFLINE' } })` → return `count`.

### FR-10 Use Case
- Single use case file `src/application/use-cases/device/DeviceHeartbeat.ts` (folder: device, matches naming of `medicine-box/`).
- Constructor signature: `constructor(private readonly medicineBoxRepo: IMedicineBoxRepository)`.
- `execute(deviceId: string): Promise<HeartbeatResult>` where `HeartbeatResult = { deviceId: string, status: 'ACTIVE', lastSeen: Date }`.
- Throws NotFoundError (missing device) and BadRequestError (empty/whitespace id) — validated beforehand by the zod schema so the UC can assert non-empty, but double checks defensively to avoid bypass routes.

### FR-11 Postman Guide Document
Create `RASPBERRY-PI-HEARTBEAT-POSTMAN.txt` at project root with:
- Endpoint `POST http://localhost:3000/api/devices/heartbeat`.
- Headers `Content-Type: application/json`.
- Body JSON example with `PI-DEV-001`.
- Expected 200 response (envelope format).
- 400 / 404 examples.
- A short "Offline Detection" note explaining the 5-second threshold.
This is the only documentation artifact created (no README updates, no spec changes outside the scope doc).

### FR-12 Error Handling Summary
| Scenario | Class | HTTP | Message |
|---|---|---|---|
| deviceId missing or empty string | BadRequestError | 400 | "deviceId is required" |
| Unknown deviceId | NotFoundError | 404 | "Device not found" |
| Prisma / DB thrown | errorMiddleware normalizes | 500 | "Something went wrong" (prod) / actual message (dev) |

All error paths route through existing global errorMiddleware; **zero duplicated error handling**.

---

## Non-Functional Requirements

### NFR-1 Clean Architecture Fidelity
- Layer boundaries preserved:
  - Presentation: `devices.routes.ts` + `DevicesController.ts` + `devices.validator.ts`.
  - Application: `DeviceHeartbeat` use case + `DeviceOfflineMonitor` module (start/stop/runNow).
  - Domain: `MedicineBox.ts` entity add DeviceStatus + fields + interface methods added.
  - Infrastructure: `PrismaMedicineBoxRepository` implement 2 new methods.
- Path-aliases (`@presentation`, `@application` etc.) used in every new import. No relative `../../../../` imports.

### NFR-2 No Dead Imports / Empty Files
- After implementation, `npx tsc --strict --noEmit` = exit 0.
- No unused import lines left behind.
- All new files referenced (imported) from exactly one top-level entry: routes from app.ts, controller referenced by routes, UC referenced by controller, offline monitor imported in server.ts.

### NFR-3 Idempotency
- Submitting the same `deviceId` heartbeat N times consecutively is safe: lastSeenAt advances, status stays ACTIVE, no error.
- Running offline detection N times is safe: already-OFFLINE rows unchanged, count reflects only newly flipped rows.

### NFR-4 Backward Compatibility
- All 8 existing route files and all existing Flutter endpoints remain 100% unchanged in behavior.
- `AddMedicineBox.execute` continues to write only its existing columns; the new columns default correctly (`deviceStatus OFFLINE`, `lastSeenAt NULL`) so no UC code change required there.

---

## Constraints
- **Migration safety**: New file `prisma/migrations/0011_add_device_heartbeat/migration.sql` only. Never edit migration files 0001-0010. Use `prisma migrate deploy` against `DIRECT_URL`/`DATABASE_URL`.
- **No duplicate models**: Reuse `MedicineBox`; never create a `Device` model (violates the "inspect-existing" rule in user Section 2 item 7).
- **Zod validation library only** (already project dep). No yup/joi.
- **No scheduler deps added**. setInterval only.
- **No new heartbeat history table** (one-row update per Section 9).
- **Minimal code**: heartbeat only — never bring back any deleted dispensing/DHT22/quantity telemetry files or tests or models or enums (PhysicalDeviceEvent/DispensingEvent/Dht22Reading/QuantityReading stay removed).

## Dependencies
- Prisma client v5.22 (already installed).
- Zod v4 (already installed).
- Express v5 (already installed).
- No new npm dependencies.

## Assumptions
1. The existing columns `MedicineBox.deviceId` + `MedicineBox.deviceToken` remain (provisioning identity; heartbeat only reads deviceId to match).
2. MedicineBox table has real rows to test against (admin can `AddMedicineBox` first; Postman guide references `PI-DEV-001` as a placeholder sample value, which is expected to be provisioned manually before testing).
3. `app.listen` server startup in `server.ts` is a safe place to attach the offline interval (Section 7 says "implement the smallest clean mechanism").
4. The project has a `.env` file with `DATABASE_URL` already set (confirmed during cleanup).

## Open Questions (resolved during spec)
- **OQ-1 Full device auth now or later?** Resolved: LATER with compatibility hooks documented. The explicit mandate in user Section 8 ("If not yet implemented… compatible… clearly document limitation") takes priority over inventing middleware this iteration.
- **OQ-2 Response envelope: user example JSON vs project existing envelope?** Resolved: Follow the EXISTING envelope format (`{ status, statusCode, data }`) used by all 8 existing controllers per user Section 5 Step 4 "Follow the existing API response format if the project already has one." The `data` object contains exactly `deviceId / status / lastSeen` keys.

---

## Acceptance Criteria (exhaustive, typed rule/rubric)

### AC-1 [rule] Prisma schema contains DeviceStatus enum + MedicineBox.deviceStatus + MedicineBox.lastSeenAt ONLY (no other device models added).
Evidence: `cat prisma/schema.prisma | grep -n "enum DeviceStatus\|model DispensingEvent\|model Dht22Reading\|model QuantityReading\|PhysicalDeviceEvent"` returns exactly 3 hits (enum + 2 fields in MedicineBox model), 0 hits for deleted models.

### AC-2 [rule] Migration 0011_add_device_heartbeat applied via prisma migrate deploy.
Evidence: `npx prisma migrate status` returns "11 migrations found, applied, database up-to-date"; migration folder exists with a non-empty `migration.sql` that uses `CREATE TYPE IF NOT EXISTS … / ALTER TABLE … ADD COLUMN IF NOT EXISTS`.

### AC-3 [rule] POST /api/devices/heartbeat responds correctly for all 4 base test scenarios.
Evidence (Jest):
- Valid PI-DEV-001 → 200 + `data.deviceStatus === ACTIVE` + `lastSeen` recent (< 3 s old).
- `{}` → 400 + message = "deviceId is required".
- Unknown → 404 + message = "Device not found".
- Previously OFFLINE → after heartbeat, repository returns deviceStatus ACTIVE and lastSeenAt !== null.

### AC-4 [rule] Offline detection flips ACTIVE+stale → OFFLINE without touching ACTIVE+fresh.
Evidence (Jest):
- 2 mock rows: (A: ACTIVE, lastSeenAt = now - 10s) + (B: ACTIVE, lastSeenAt = now - 1s) → after `runOfflineDetectionNow(5000)`: A becomes OFFLINE, B remains ACTIVE.

### AC-5 [rule] No new dependency lines added to package.json dependencies/devDependencies.
Evidence: `git diff package.json` (or file compare) shows dep lines identical to baseline cleanup version.

### AC-6 [rule] tsc --strict --noEmit = 0 errors; npm run build = 0 errors.
Evidence: exit code 0 for both commands in terminal.

### AC-7 [rule] jest --forceExit passes existing + new tests (0 failures, 0 open handle warnings if stopOfflineMonitor called).
Evidence: exit code 0; output shows "Tests: XX passed, XX total".

### AC-8 [rule] Global search for deleted-scoped features returns 0 in new source added by this task:
Grep strings: `dispensingEvent | PhysicalDeviceEvent | Dht22Reading | QuantityReading | temperature Float | humidity Float | reportDHT22 | reportCurrentQuantity | X-Device-Id middleware`.
Evidence: 0 matches in any non-migration, non-spec file.

### AC-9 [rubric] Architecture consistency (0–2; threshold 2)
- 2 pts: Route/Controller/Validator/UseCase/Entity/Repository layers match naming conventions of the 8 existing peer route files. Path aliases used everywhere, no relative imports. No duplicate constructs.
- 1 pt: One layer missing (e.g., validator file absent, or route/controller combined).
- 0 pts: Code crammed into server.ts or endpoints.ts with no layering.

### AC-10 [rubric] Device auth extensibility documentation clarity (0–2; threshold ≥1)
- 2 pts: devices.validator.ts exports commented-out deviceHeadersSchema stub; controller single-line comment documents the explicit limitation; spec open-question OQ-1 cross-referenced.
- 1 pt: Single comment in controller only.
- 0 pts: No documentation at all; or new auth middleware silently invented with spec violation.

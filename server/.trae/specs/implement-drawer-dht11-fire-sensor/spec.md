# SPEC: Drawer-Level DHT11 Temperature/Humidity + Fire Sensor Backend Integration

Last updated: 2026-09-23

## 1. Problem

The Smart Medicine Box backend currently has domain models for MedicineBox, Drawer, DrawerMedication, Medication, Patient, Schedule, MedicationSession, and FaceVerificationEvent. No model or API exists for per-drawer environmental safety sensor data (DHT11 temperature/humidity per drawer + per-drawer boolean fire/smoke detection).

The Raspberry Pi connected to each medicine box reads per-drawer sensors and must report them to the backend via HTTP POST (never direct PostgreSQL access — the backend alone is the source of truth). The Flutter mobile application requires authenticated GET endpoints to retrieve the latest sensor reading per drawer for display and stale-detection (via updatedAt).

Per user §9 MVP rule, only the CURRENT state per drawer is stored — ONE row per drawer — using an upsert strategy on a unique drawerId key. No historical time-series or analytics tables are created today. Per user §5 strict security rule, the backend must verify the full device → MedicineBox → Drawer association chain before accepting any sensor write, returning 403 if a device attempts to submit data for a drawer belonging to another box. Per user §6, fireDetected state is persisted only; no new notification architecture is implemented this task.

User §16 explicitly forbids implementing: Heartbeat, Face Recognition, Schedule Synchronization, Medication Taken logic, Medication Refill logic, Motor control, Drawer opening, MQTT, WebSockets, new notification architecture, historical sensor analytics, AI, Computer Vision, new authentication system, new user roles, or unrelated database refactoring. All forbidden scope is enforced by end-of-pipeline scope grep.

## 2. Users / Actors

1. **Raspberry Pi (device identified by MedicineBox.deviceId)** — reads per-drawer DHT11 + fire sensors and makes HTTP POST to report one reading per drawer per call. Has NO direct PostgreSQL/Supabase access. Architecture per user §1 architecture diagram: Sensors → Pi → POST Backend → Express → Postgres.
2. **Node.js / Express Backend + PostgreSQL/Supabase** — single source of truth. Validates every relationship, applies sensor range and strict type checks, upserts the single per-drawer current state row, and serves authenticated GET responses to Flutter.
3. **Flutter Mobile Application (user-authenticated via existing JWT requireAuth)** — makes GET calls to retrieve latest per-drawer sensor state for display and stale-detection via updatedAt. User must own the MedicineBox (medicineBox.userId === req.user.userId) to access.

## 3. Goals (in scope)

G1. Add new Prisma model `DrawerSensorState` with unique `drawerId` FK → one current sensor state row per drawer. Migration 0014 deployed to Supabase pooler-safe idempotent SQL.
G2. Implement device-facing endpoint `POST /api/devices/sensor-readings` inside existing `devicesRouter` (no new router file).
G3. Strict Zod validation: deviceId, drawerId (non-empty strings required). temperature (valid finite number, not NaN/Infinity/null/invalid-string). humidity (valid finite number AND 0 ≤ value ≤ 100, reject impossible values per user §4). fireDetected (strict boolean, no silent string conversion). All extra fields rejected (strict schema).
G4. Device → Box → Drawer security chain: G4a. deviceId exists → find box by deviceId. If device not found → 404. G4b. find drawer by drawerId. If drawer not found → 404. G4c. Verify drawer.medicineBoxId === box.id. If mismatch → **403 Forbidden "Drawer does not belong to this device's medicine box"** per user §5 rule.
G5. After all validation gates, UPSERT DrawerSensorState by unique drawerId. For a drawer that has never had readings (no row yet): INSERT with the three sensor values. For a drawer that has an existing row: UPDATE temperature, humidity, fireDetected, and updatedAt (automatic via Prisma @updatedAt). createdAt preserved on initial insert.
G6. Implement Flutter-facing endpoint `GET /api/medicine-boxes/:medicineBoxId/sensors` inside existing medicineBoxRouter. Requires existing JWT requireAuth (already applied to entire medicineBoxRouter via `.use(requireAuth)`). G6a. Caller ownership: `medicineBox.userId === req.user!.userId`. If box not found → 404. If userId mismatch → 403 Forbidden per user §7.
G7. GET sensors response: Return envelope with `data.medicineBoxId` and `data.drawers[]` array. For EVERY drawer belonging to that medicine box (user §10 multi-drawer rule — each drawer has its own sensors), include an entry {drawerId, temperature, humidity, fireDetected, updatedAt}. If a drawer has never had a sensor reading (no DrawerSensorState row), output the drawer entry with temperature=null, humidity=null, fireDetected=false, updatedAt=null. Never omit drawers from the array.
G8. Optional single-drawer GET `GET /api/drawers/:drawerId/sensors` inside existing drawerRouter — because the pattern exists (DrawerController.getById already does `findByIdAndUserId(userId, id)` ownership). Authenticated via existing drawerRouter `requireAuth`. Validates drawer.userId chain through medicineBox → user. Returns envelope with single drawer sensor object. Returns 404 if drawer not found, 403 if not owner. Same null-field semantics as G7 for missing sensor row.
G9. Response envelope format: identical to ALL existing controllers — `{ status: 'success', statusCode: <int>, data: <obj> }`. Overrides user's illustrative `success:true` payload examples per project convention confirmed in heartbeat/face/schedule/medication-events endpoints.
G10. Device controller pattern: Append 6th method to existing DevicesController export object. Apply the exact same top-of-file `SECURITY LIMITATION` comment block used in today's medication-events controller. Reuse the exact `resolveRequestingDeviceId(req)` helper function unchanged — preference order trusted `req.deviceId` → query → body. Overwrite payload deviceId if trusted middleware is present. Do not invent new device middleware.
G11. Jest test suite: tests/drawer-sensor.spec.ts, 9+ it() blocks covering user §15 Postman scenarios T1–T7 plus 2 bonus (invalid temperature not finite / fireDetected string). All tests use jest.fn() mock repos; NO real prisma.
G12. Pipeline green 5-step exit 0: prisma validate → tsc strict → full jest suite (≥519 green) → npm run build → forbidden-scope grep 0 matches for tokens listed in user §16.
G13. Postman guide SENSOR-DRAWER-POSTMAN.txt at project root covering T1–T7 user §15 scenarios with full HTTP method, URL, headers, body, and expected status + shape.
G14. Clean architecture strict layers: domain interfaces first → prisma impls in infra → use-case classes in application → zod validators + controllers + routes in presentation. Business logic never in routes.

## 4. Non-goals (forbidden per user §16 + project rules, NO EXCEPTIONS)

NG1. No Heartbeat / Face Recognition / Schedule sync / Medication taken / Medication refill / Motor control / Drawer open / Drawer close logic — existing implementations are STATIC today and must not be modified by this task.
NG2. No MQTT, no WebSockets. Only plain REST endpoints (POST device, GET mobile).
NG3. No new notification / alert / push / OS-level notification architecture. Fire sensor state is persisted and exposed via GET only (exactly user §6 rule — no extra notification infrastructure).
NG4. No historical time-series sensor storage; no sensor event history table; no analytics; no AI; no computer vision.
NG5. No new authentication system, no new user roles, no new device middleware. Reuse existing requireAuth and resolveRequestingDeviceId exactly.
NG6. Do not store sensor data at MedicineBox level. Each drawer has its own sensors (user §10).
NG7. Do not create a new DrawerSensorState database row per reading (user §9 explicit MVP: only the latest state, single row per drawer via upsert unique).
NG8. No unrelated database refactoring. Touch only: add DrawerSensorState prisma model + migration 0014. No changes to MedicineBox/Drawer/DrawerMedication/MedicationSession/FaceVerificationEvent models.
NG9. No Pi direct DB access. No Supabase client in device controller. Access exclusively through Prisma repository layer as in §14 controller → usecase → repo → prisma → postgres.

## 5. Functional Requirements (FR)

### FR-1. Prisma model DrawerSensorState (append after FaceVerificationEvent in schema.prisma)

```prisma
model DrawerSensorState {
  id           String   @id @default(uuid())
  drawerId     String   @unique
  temperature  Float?
  humidity     Float?
  fireDetected Boolean  @default(false)
  updatedAt    DateTime @updatedAt
  createdAt    DateTime @default(now())

  drawer Drawer @relation(fields: [drawerId], references: [id], onDelete: Cascade)
}
```

Semantic rules:
- `drawerId` is UNIQUE → enforces "one current state per drawer" MVP policy.
- `onDelete: Cascade` on drawer relation → deleting a drawer auto-cleans its sensor row.
- `temperature`/`humidity` nullable Float because a Pi might send only fire status in some edge reads (defensive); validator still requires finite numbers for the POST fields they ARE present on (non-nullable in request schema unless user relaxes — per user §3 example request all 5 fields are sent, so request schema makes all 3 sensor fields required/non-nullable at API boundary. Nullable in DB only for future-proofing if a partial upsert is added later.)
- `fireDetected Boolean @default(false)` — explicit default for new rows.
- `updatedAt` used by Flutter for stale-data detection per user §11.

### FR-2. Migration 0014 SQL idempotent pooler-safe

Create folder prisma/migrations/20260923130000_add_drawer_sensor_state/migration.sql with:
1. `CREATE TABLE IF NOT EXISTS "DrawerSensorState" (...)` with PK uuid, drawerId TEXT UNIQUE NOT NULL, temperature DOUBLE PRECISION, humidity DOUBLE PRECISION, fireDetected BOOLEAN NOT NULL DEFAULT false, createdAt TIMESTAMPTZ NOT NULL DEFAULT now(), updatedAt TIMESTAMPTZ NOT NULL DEFAULT now().
2. `ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS ... FOREIGN KEY (drawerId) REFERENCES "Drawer"(id) ON DELETE CASCADE`.
3. `CREATE UNIQUE INDEX IF NOT EXISTS "DrawerSensorState_drawerId_key" ON "DrawerSensorState"(drawerId)`; or rely on UNIQUE column constraint.
4. Supabase pooler-safe: No `CREATE TYPE IF NOT EXISTS` for enums (no new enums this migration). All statements idempotent.

Deploy via `prisma migrate deploy` using Direct_URL session mode. Exit 0 required.

### FR-3. Domain repository interface IDrawerSensorStateRepository

New file `src/domain/repositories/IDrawerSensorStateRepository.ts`:
```
interface IDrawerSensorStateRepository {
  upsert(data: {
    drawerId: string;
    temperature: number;
    humidity: number;
    fireDetected: boolean;
  }): Promise<DrawerSensorStateEntity>;

  findByDrawerId(drawerId: string): Promise<DrawerSensorStateEntity | null>;

  findManyByDrawerIds(drawerIds: string[]): Promise<DrawerSensorStateEntity[]>;
}
```
Also create domain entity class `DrawerSensorState` in `src/domain/entities/DrawerSensorState.ts` with same fields as model (typed).

### FR-4. Prisma repository implementation + wiring

New file `src/infrastructure/database/prisma/repositories/PrismaDrawerSensorStateRepository.ts` implementing IDrawerSensorStateRepository:
- `upsert()` → calls `prisma.drawerSensorState.upsert({ where: {drawerId}, create: {...}, update: {...} })` — Prisma's native UPSERT handles insert-or-update in single atomic statement; `@updatedAt` auto-updated.
- `findByDrawerId()` → findUnique({where:{drawerId}}).
- `findManyByDrawerIds(ids)` → findMany({where:{drawerId:{in: ids}}}).
- Return domain entities, not raw prisma rows (consistent with other prisma repo impls).
- If a shared repositories index / barrel file exists, wire the new repo export. If none, leave imported as needed per existing DI pattern (manual constructor injection in controllers).

### FR-5. Device use-case: RecordDrawerSensorReading

New file `src/application/use-cases/device/RecordDrawerSensorReading.ts`. Class constructor takes: (medicineBoxRepo, drawerRepo, drawerSensorStateRepo). Execute method takes typed payload `{deviceId, drawerId, temperature, humidity, fireDetected}` and returns `{drawerId, temperature, humidity, fireDetected, updatedAt: Date}`.

Validation/security gates in ORDER (fail-fast inside usecase, throwing shared AppErrors):
1. `box = medicineBoxRepo.findByDeviceId(deviceId)` → if null throw **NotFoundError "Device not found" (404)** per user §15 T4.
2. `drawer = drawerRepo.findById(drawerId)` → if null throw NotFoundError "Drawer not found" (404).
3. `drawer.medicineBoxId !== box.id` → throw **ForbiddenError "Drawer does not belong to this device's medicine box" (403)** per user §5 / §15 T5.
4. After gates pass, call `sensorRepo.upsert(payload)` → return the upserted entity's 5 fields for response.

No transaction required for single upsert (Prisma UPSERT is atomic by itself for a single-row write).

### FR-6. Mobile use-case: GetMedicineBoxSensorReadings

New file `src/application/use-cases/medicine-box/GetMedicineBoxSensorReadings.ts`. Constructor takes: (medicineBoxRepo, drawerRepo, drawerSensorStateRepo). Execute takes `(userId: string, medicineBoxId: string)`.

Gates:
1. `box = medicineBoxRepo.findByIdAndUserId(medicineBoxId, userId)` → if null → if box not found at all NotFoundError 404, else if found but userId mismatch → ForbiddenError 403. (Existing findByIdAndUserId returns null when either — simplify to NotFound if null, as existing MedicineBoxController.getById does; ownership is enforced because findByIdAndUserId joins on userId.)
2. `drawers = drawerRepo.findAllByMedicineBoxId(medicineBoxId)` → ALL drawers in the box.
3. `sensorRows = sensorRepo.findManyByDrawerIds(drawers.map(d=>d.id))` → LEFT-JOIN-style in memory from the list.
4. Build result shape: `{medicineBoxId, drawers: Array<{drawerId, temperature: number|null, humidity: number|null, fireDetected: boolean, updatedAt: Date|null}>}`. For every drawer in drawers, if matching sensorRow found use its values; else `{temperature:null, humidity:null, fireDetected:false, updatedAt:null}`. Per user §10 rule: all N drawers included, never omitted.

### FR-7. Optional use-case: GetDrawerSensorReading (for §8 optional single drawer GET)

New file `src/application/use-cases/drawers/GetDrawerSensorReading.ts`. Constructor: (drawerRepo, drawerSensorStateRepo). Execute takes `(userId, drawerId)`.

Gates:
1. `drawer = drawerRepo.findByIdAndUserId(drawerId, userId)` → null means not found or not owner → NotFound 404 (the standard pattern in DrawerController.getById today; the findByIdAndUserId method internally walks drawer→medicineBox→user.userId).
2. `sensor = sensorRepo.findByDrawerId(drawerId)`.
3. Return: `{drawerId, temperature: sensor?.temperature ?? null, humidity: sensor?.humidity ?? null, fireDetected: sensor?.fireDetected ?? false, updatedAt: sensor?.updatedAt ?? null}`.

This use-case is optional; implemented ONLY if the existing drawer pattern naturally accommodates it (it does — drawerRouter already exists with GET /:id).

### FR-8. Validator schema append to devices.validator.ts

Append to existing `src/presentation/validators/devices.validator.ts` new export:

```typescript
export const drawerSensorReadingSchema = z
  .object({
    deviceId: z.string().trim().min(1, 'deviceId is required (non-empty string)'),
    drawerId: z.string().trim().min(1, 'drawerId is required (non-empty string)'),
    temperature: z.number(),
    humidity: z.number(),
    fireDetected: z.boolean(),
  })
  .strict()
  .superRefine((v, ctx) => {
    if (!Number.isFinite(v.temperature)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['temperature'],
        message: 'temperature must be a valid finite number (not NaN/Infinity)' });
    }
    if (!Number.isFinite(v.humidity)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['humidity'],
        message: 'humidity must be a valid finite number (not NaN/Infinity)' });
    } else if (v.humidity < 0 || v.humidity > 100) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['humidity'],
        message: 'humidity must be within 0..100 % (impossible value rejected)' });
    }
  });
```

Rules checked:
- Strict schema: extra fields rejected (HTTP 400).
- deviceId/drawerId: trimmed, min length 1.
- temperature/humidity typed as `z.number()` rejects null/string/NaN-string inputs at the type step already. `Number.isFinite()` in superRefine additionally blocks Infinity/-Infinity which pass z.number() technically.
- humidity additionally clamped to physical 0..100 % per user §4 (T3 test case 150 rejected 400).
- fireDetected as `z.boolean()` accepts ONLY true/false native booleans. Rejects `"true"`, `1`, any other silent coercion — exactly user §4 requirement.

### FR-9. DevicesController.recordSensorReading method (append to existing export)

Append 6th method to DevicesController export object in `src/presentation/controllers/DevicesController.ts`:

Pattern match the exact style of medication-event method today:
1. Keep the existing `SECURITY LIMITATION` comment block at top-of-file unchanged; add a one-line SECURITY LIMITATION comment inside the method identical to `recordMedicationEvent` method comment lines 235–236.
2. `const bodyParsed = drawerSensorReadingSchema.safeParse(req.body ?? {})` → if fail → throw BadRequestError with formatZodErrors extended case for this schema.
3. `trustedDeviceId = resolveRequestingDeviceId(req as DeviceRequest)`. Overwrite `payload.deviceId = trustedDeviceId` if present.
4. Manual DI: instantiate `new PrismaMedicineBoxRepository()`, `new PrismaDrawerRepository()`, `new PrismaDrawerSensorStateRepository()`.
5. Construct `new RecordDrawerSensorReading(medicineBoxRepo, drawerRepo, sensorRepo)`. Call `await uc.execute(payload)`.
6. Return envelope 200 OK with data shape: `{drawerId, temperature, humidity, fireDetected, updatedAt: result.updatedAt.toISOString()}` — ISO string dates in JSON as other endpoints do.

### FR-10. Route append: POST /api/devices/sensor-readings

Inside existing `src/presentation/routes/devices.routes.ts`, append as line 14 (after medication-events route line 13, before export):
```typescript
devicesRouter.post('/sensor-readings', DevicesController.recordSensorReading);
```
No new middleware, no auth. Keep the devicesRouter no-auth style per existing 5 routes (all unauthenticated today; SECURITY LIMITATION documented; future trusted-device middleware extension hook ready via resolveRequestingDeviceId).

### FR-11. MedicineBoxController.getSensors method + route append

Append new method to `MedicineBoxController` export object in `src/presentation/controllers/MedicineBoxController.ts`. Style matches `getById` method lines 79–90 exactly:
1. `userId = req.user!.userId`.
2. `medicineBoxId` = `req.params.id` (router uses `:id` param; same pattern as getById/unassign/update — though user spec example uses `:medicineBoxId`, stick with existing medicineBoxRouter's `:id` for consistency because existing routes use `/medicineBoxes/:id/*`; the method will be mounted at `GET /:id/sensors` BEFORE line 39 `GET /:id` so param routing works correctly).
3. Instantiate PrismaMedicineBoxRepository, PrismaDrawerRepository, PrismaDrawerSensorStateRepository.
4. `const uc = new GetMedicineBoxSensorReadings(medicineBoxRepo, drawerRepo, sensorRepo)`.
5. `const result = await uc.execute(userId, id)`.
6. Map ISO strings: for each drawer entry convert updatedAt → `.toISOString()` if not null.
7. Envelope okPublic(res, 200, { medicineBoxId, drawers: mappedDrawers }) — shape per user §7 example with data.medicineBoxId + data.drawers[] inside envelope.

Append route to `src/presentation/routes/medicineBox.routes.ts` at LINE 38.5 (between `POST /:id/unassign` line 38 and `GET /:id` line 39):
```typescript
medicineBoxRouter.get('/:id/sensors', MedicineBoxController.getSensors);
```
Crucially: must be BEFORE the generic `GET /:id` route so "sensors" is matched literally before falling through to `:id` parameter. Whole router already has `requireAuth` applied.

### FR-12. Optional: DrawerController.getSensors method + route (§8 optional GET drawer/:id/sensors)

If implemented: append method to DrawerController similar to getById. Route append to drawer.routes.ts:
```typescript
drawerRouter.get('/:id/sensors', DrawerController.getSensors);
```
inserted BEFORE `GET /:id` line 25 so sensors literal matches first.
Response envelope shape: `{ status: 'success', statusCode: 200, data: {drawerId, temperature, humidity, fireDetected, updatedAt: ISO|null} }`.
This is marked OPTIONAL in user spec; implemented to match existing drawer controller pattern.

### FR-13. Error handling consistency

All validation / auth errors thrown as existing AppError subclasses:
- BadRequestError (HTTP 400) — zod validation failures (e.g., humidity=150 → 400, T3).
- UnauthorizedError (401) — triggered by existing requireAuth when JWT missing/invalid (no new code).
- ForbiddenError (403) — user §5 T5: drawer belongs to other device. Also §7 T7: another user accessing a box.
- NotFoundError (404) — deviceId not found T4, drawerId not found, medicineBoxId not found.
- Existing global error middleware catches AppError subclasses and translates to the correct HTTP status codes per project convention.
- NEVER expose raw Prisma / Postgres error text to client.

### FR-14. Drawer count / multi-drawer correctness (user §10)

For GET medicine-box sensors response: the `drawers[]` array length MUST EQUAL the box's total number of drawers (from `drawerRepo.findAllByMedicineBoxId`). If some drawers have never received sensor readings, they appear with null fields. No drawer silently dropped.

### FR-15. updatedAt stale-detection support (user §11)

updatedAt timestamp ALWAYS included in: POST response's data.updatedAt, every drawer[] entry's updatedAt (even if null). Flutter app can compute staleness locally. No extra "sensorStatus" invented.

### FR-16. Error text for formatZodErrors helper extension

Extend the existing `formatZodErrors` switch in DevicesController.ts to accept a new literal case `'sensor-reading'` and return a concise sensor-specific invalid hint string, same style as other schemas (heartbeat/face-reference/etc.). Import line must append `drawerSensorReadingSchema` to the existing import.

## 6. Non-functional Requirements

NR1. Clean Architecture 4 layers strictly separated. Route handlers contain NO business logic (only DI, validation, response shaping). All business validation gates live in application use-case classes.
NR2. TypeScript strict: no implicit any, no unused variables (TS6133), no loose non-null assertions without guards.
NR3. Prisma schema validates with `prisma validate` exit 0.
NR4. Jest tests: no real prisma client, no real database, all repos mocked with jest.fn() returning shaped entities consistent with domain.
NR5. Response envelope: all new endpoints return `{status:'success', statusCode:<int>, data:<obj>}` — never deviate.
NR6. Existing implementations (heartbeat, face reference, face verification, schedule sync, medication events) are STATIC: source code of their controllers / validators / routes / usecases / prisma impls / tests NOT modified by this task (only append operations to shared files — devices validator export adds one schema, DevicesController export adds one method, devices.routes adds one line append, medicineBox routes adds one line append, drawer routes adds one optional line, medicineBox controller adds one method export, drawer controller adds one optional method export). Append-only pattern to shared files; no deletion of existing code.
NR7. Migration idempotent: running twice produces identical state. Pooler-safe (ALTER/DROP/CREATE TABLE IF NOT EXISTS style).
NR8. Scope-forbidden grep: src + tests files search for forbidden tokens from user §16 (Heartbeat|Face Recognition|Schedule Sync|Medication taken|Medication refill|motor|open drawer|close drawer|MQTT|WebSocket|AI|Computer Vision|notification architecture). NEW code introduced by this task must have 0 matches. Existing code is allowed to keep previous feature tokens (they are shipped separate features).

## 7. Constraints / Dependencies / Assumptions

C1. Prisma Postgres on Supabase (project kyxmkhdrnijymlotjynr). Migration uses prisma migrate deploy with DIRECT_URL. Pooler version < PG 15 — no `CREATE TYPE IF NOT EXISTS` syntax. No new enums this migration so DO $$ block isn't required; idempotent CREATE TABLE/INDEX IF NOT EXISTS is enough.
C2. Device identity extension hook: existing SECURITY LIMITATION documentation remains truthful; no device auth enforcement this iteration; future middleware sets req.deviceId and resolveRequestingDeviceId already prefers it.
C3. Drawer uniqueness per box: Drawer model already has @@unique([medicineBoxId, drawerNumber]); findById returns one row always.
C4. Ownership gate for mobile GET: medicineBox.userId single scalar check — the existing findByIdAndUserId already returns only when (id, userId) match, which is the exact shared userId pattern used by all prior tasks (face/schedule/med events).
C5. Sensor values: temperature has NO aggressive business range clamp (user §4 instruction: "do not invent aggressive business limits that could reject legitimate sensor readings"). Only finite check applied; no min/max on temperature.
C6. fireDetected strict boolean: no string truthy coercion. If Pi sends `"fireDetected":"1"` → zod rejects with 400 (fireDetected: Expected boolean, received string). Correct per user §4.
C7. findAllByMedicineBoxId + findManyByDrawerIds = 2 prisma queries for the GET box sensors endpoint. Read performance is acceptable for MVP (a medicine box has ≤ ~20 drawers max). No N+1.
C8. Prisma native upsert for single drawer state: one SQL statement (INSERT ON CONFLICT DO UPDATE). No read-then-write race; no transaction needed. Atomic.

## 8. Open Questions resolved by default (documented explicitly by Spec)

OQ-1. Temperature range: apply only finite validity check, no absolute min/max per user §4 lenient constraint.
OQ-2. Naming: DrawerSensorState (user's conceptual was DrawerSensorData; choose State to emphasize it is single current-state snapshot; acceptable by user's "do not copy blindly, adapt to naming conventions" rule §2).
OQ-3. Drawer entries with no sensor row: return with null temperature/humidity and fireDetected=false, updatedAt=null. Project convention: include all drawers per user §10 not just those with readings.
OQ-4. Optional drawer/:id/sensors endpoint: implement because drawerRouter/DrawerController.getById pattern exists perfectly; trivial 1-file 1-route append; provides mobile flexibility.
OQ-5. Route param name for medicine-box GET sensors: existing medicineBoxRouter uses `:id` everywhere (not `:medicineBoxId`). Follow existing convention for consistency; the logical resource semantics are identical.
OQ-6. fireDetected DB default: false (per user conceptual schema example @default(false)).
OQ-7. Prisma impl upsert vs update-then-insert: use prisma native upsert; most efficient and race-free.

## 9. Acceptance Criteria (AC type: rule OR rubric)

AC-01 [rule] — Prisma schema: model `DrawerSensorState` appended after FaceVerificationEvent with fields: id(uuid PK), drawerId(unique FK), temperature(Float?), humidity(Float?), fireDetected(Boolean default false), updatedAt, createdAt. Relation Drawer onDelete Cascade. prisma validate passes exit 0.
AC-02 [rule] — Migration 0014 SQL created, idempotent CREATE TABLE IF NOT EXISTS + UNIQUE drawerId + FK cascade. prisma migrate deploy Supabase exit 0.
AC-03 [rule] — POST /api/devices/sensor-readings route appended to existing devices.routes.ts devicesRouter; correct HTTP method, path matches user §3.
AC-04 [rule] — POST schema validator drawerSensorReadingSchema: deviceId/drawerId non-empty strings required; temperature finite number; humidity finite AND 0..100; fireDetected strict boolean; strict extra fields rejected. humidity=150 → 400 BadRequest (T3).
AC-05 [rule] — POST validation: unknown deviceId → 404 (T4). Cross-device drawer (drawer belongs to other box) → 403 Forbidden (T5).
AC-06 [rule] — POST valid reading (T1, T2 fire true): upsert DrawerSensorState row by drawerId unique → one row per drawer (no duplicates). repeated calls with same drawerId → same row updated, row count stays 1. updatedAt changes on each upsert. Database fireDetected=true after T2.
AC-07 [rule] — POST response envelope `{status:'success', statusCode:200, data:{drawerId,temperature,humidity,fireDetected,updatedAt:ISO}}`.
AC-08 [rule] — GET /api/medicine-boxes/:id/sensors route appended BEFORE generic GET /:id in medicineBox.routes.ts; whole router protected by existing requireAuth.
AC-09 [rule] — GET ownership: calling user's req.user.userId !== medicineBox.userId → 403 (T7 unauthorized mobile access). Non-existent medicineBoxId → 404.
AC-10 [rule] — GET response: envelope data.medicineBoxId and data.drawers[] with length equal to total drawers in that box (every drawer in findAllByMedicineBoxId present). Each entry {drawerId, temperature, humidity, fireDetected, updatedAt}. Drawers without sensor row have null temp/humidity, fireDetected=false, updatedAt=null (T6 mobile GET).
AC-11 [rule] — updatedAt timestamps in all responses as ISO strings for stale detection (user §11).
AC-12 [rule] — Optional GET /api/drawers/:id/sensors (if implemented): route appended BEFORE generic drawer GET /:id; ownership via findByIdAndUserId; same field shape as single drawer entry; 404/403 gates consistent.
AC-13 [rule] — Clean architecture: domain IDrawerSensorStateRepository interface, domain entity DrawerSensorState, Prisma impl in infrastructure, use-case classes in application (device folder + medicine-box folder + optional drawers folder), zod validator append, controller methods append, routes append. Business logic 100% outside route definitions.
AC-14 [rule] — DevicesController.recordSensorReading includes SECURITY LIMITATION comment identical to existing recordMedicationEvent. Uses resolveRequestingDeviceId extension hook; overwrites deviceId if trusted req.deviceId is set. No new device middleware.
AC-15 [rule] — Idempotent per-drawer storage: 5 consecutive POSTs of the same drawerId reading → 1 total row in DB; 5th response updatedAt newer than 1st; temperature/humidity/fireDetected reflect latest values. No time-series rows (user §9 MVP).
AC-16 [rule] — Jest tests/drawer-sensor.spec.ts 9+ it() blocks passing covering T1 valid, T2 fire true, T3 invalid humidity 150, T4 invalid device, T5 drawer other device 403, T6 mobile GET, T7 unauthorized mobile access 403, plus T-invalid-temperature-Infinity, T-fireDetected-string-coercion. All repo mocks jest.fn(); NOT real prisma.
AC-17 [rule] — SENSOR-DRAWER-POSTMAN.txt file present at project root with T1–T7 examples per user §15.
AC-18 [rule] — Pipeline: prisma validate exit 0. tsc --strict exit 0. full jest suite 519+ tests green pass. npm run build exit 0. forbidden grep in new files 0 matches.
AC-19 [rubric 0–2, pass ≥1] — Existing device features untouched: heartbeat route / face / schedule / medication-events source files unchanged (only append lines to shared devices.validator / DevicesController / devices.routes export objects). No regression.
AC-20 [rubric 0–2, pass ≥1] — Project response envelope consistent across all 3 new endpoints (POST device, GET box, GET drawer optional). Standard shared AppErrors used.
AC-21 [rule] — No MQTT, no WebSocket, no new notification architecture, no historical tables, no motor/drawer-open logic anywhere in new/modified files (scope).
AC-22 [rule] — Pi never accesses DB directly; sensor writes only via POST endpoint; backend is sole source of truth.

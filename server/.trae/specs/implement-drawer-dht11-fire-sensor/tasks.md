# Tasks: Implement Drawer-Level DHT11 Temperature/Humidity + Fire Sensor Backend Integration

Work directory: `c:\Users\borgi\Desktop\app\server`

Pipeline required at end (Task 10): prisma validate → tsc strict → jest full suite → npm run build → forbidden-token grep. ALL must exit 0.
Coverage requirement: every AC in spec.md (22 total) maps to at least one task-local Test Requirement (rule or rubric).

## Checklist 1 → 12 (plus optional Task 8b)

### Task 1 — Prisma schema DrawerSensorState model append + prisma validate/generate
- **Status**: pending
- **Maps AC**: AC-01
- **Edit prisma/schema.prisma (APPEND-ONLY after FaceVerificationEvent model, no edits to existing models)**:
  - Insert new model `DrawerSensorState` with:
    - `id String @id @default(uuid())`
    - `drawerId String @unique`
    - `temperature Float?`
    - `humidity Float?`
    - `fireDetected Boolean @default(false)`
    - `updatedAt DateTime @updatedAt`
    - `createdAt DateTime @default(now())`
    - Relation: `drawer Drawer @relation(fields: [drawerId], references: [id], onDelete: Cascade)`
  - Do NOT modify MedicineBox / Drawer / DrawerMedication / MedicationSession / FaceVerificationEvent models.
  - Do NOT remove any existing @@index / @@unique lines.
- **Run**: `npx prisma validate` → must pass exit 0.
- **Run**: `npx prisma generate` → client types updated (DrawerSensorState type accessible).
- **Test Requirements**:
  - TR-1.1 [rule] `npx prisma validate` prints "The provided schema is valid" exit 0.
  - TR-1.2 [rule] Prisma client `DrawerSensorStateWhereUniqueInput` contains `drawerId` as unique selector (confirms @unique applied).
  - TR-1.3 [rule] Grep prisma/schema.prisma for `"DrawerSensorState"` → exactly 1 model definition block found; MedicineBox/Drawer model line counts unchanged.

---

### Task 2 — Migration 0014 (Supabase pooler-safe idempotent SQL) + deploy exit 0
- **Status**: pending
- **Maps AC**: AC-02
- **Create folder**: `prisma/migrations/20260923130000_add_drawer_sensor_state/`
- **Create file**: `migration.sql` with all statements idempotent IF NOT EXISTS:
  1. `CREATE TABLE IF NOT EXISTS "DrawerSensorState" (...)` — all columns match the Prisma model types:
     - `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` (or uuid() equivalent — use uuid extension if needed, or accept TEXT Prisma default; match existing pattern used by Drawer table id)
     - `"drawerId" TEXT NOT NULL UNIQUE`
     - `temperature DOUBLE PRECISION`
     - `humidity DOUBLE PRECISION`
     - `"fireDetected" BOOLEAN NOT NULL DEFAULT false`
     - `"createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP`
     - `"updatedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP`
  2. `ALTER TABLE "DrawerSensorState" ADD CONSTRAINT IF NOT EXISTS "DrawerSensorState_drawerId_fkey" FOREIGN KEY ("drawerId") REFERENCES "Drawer"(id) ON DELETE CASCADE;`
  3. `CREATE UNIQUE INDEX IF NOT EXISTS "DrawerSensorState_drawerId_key" ON "DrawerSensorState"("drawerId");` (may be redundant with UNIQUE constraint; keep both idempotent-safe)
- **Deploy**: `npx prisma migrate deploy --schema prisma/schema.prisma` using Direct_URL (session mode against Supabase kyxmkhdrnijymlotjynr). If transient P1001 pooler: Start-Sleep 3, retry once. Require exit 0.
- **Test Requirements**:
  - TR-2.1 [rule] `npx prisma migrate deploy` exits 0; stdout shows "1 migration found" or "All migrations applied" or "Already in sync".
  - TR-2.2 [rule] Running migration.sql a 2nd time manually via `npx prisma db execute --stdin --schema prisma/schema.prisma` exits 0 (idempotent, no errors from duplicate objects).
  - TR-2.3 [rule] Supabase table exists: describe via prisma introspect or pg equivalent → DrawerSensorState with unique drawerId + cascade FK to Drawer.id confirmed.

---

### Task 3 — Domain layer: DrawerSensorState entity + IDrawerSensorStateRepository interface
- **Status**: pending
- **Maps AC**: AC-03, AC-13
- **Create NEW file `src/domain/entities/DrawerSensorState.ts`**:
  - Export class/interface `DrawerSensorState` with typed fields: id(string), drawerId(string), temperature(number|null), humidity(number|null), fireDetected(boolean), updatedAt(Date), createdAt(Date). Match style of existing Drawer entity or MedicationSession entity in same folder.
- **Create NEW file `src/domain/repositories/IDrawerSensorStateRepository.ts`**:
  - Export 3 method signatures:
    1. `upsert(data: { drawerId: string; temperature: number; humidity: number; fireDetected: boolean; }): Promise<DrawerSensorState>;`
    2. `findByDrawerId(drawerId: string): Promise<DrawerSensorState | null>;`
    3. `findManyByDrawerIds(drawerIds: string[]): Promise<DrawerSensorState[]>;`
  - Style match sibling repo interfaces (IMedicineBoxRepository / IDrawerRepository) — same import style, same exported type pattern.
- **Test Requirements**:
  - TR-3.1 [rule] tsc --noEmit succeeds (interfaces parse; no missing type imports).
  - TR-3.2 [rule] IDrawerSensorStateRepository exports exactly 3 methods; method return types use domain entity DrawerSensorState, NOT raw prisma types.
  - TR-3.3 [rule] Domain entity DrawerSensorState has temperature/humidity nullable number type to match model.

---

### Task 4 — Infrastructure layer: PrismaDrawerSensorStateRepository impl
- **Status**: pending
- **Maps AC**: AC-01, AC-06, AC-13, AC-15
- **Create NEW file `src/infrastructure/database/prisma/repositories/PrismaDrawerSensorStateRepository.ts`**:
  - Class `implements IDrawerSensorStateRepository`.
  - Imports existing prisma singleton (matching style of PrismaDrawerRepository / PrismaMedicineBoxRepository in same folder).
  - `upsert()`: calls `prisma.drawerSensorState.upsert({ where: { drawerId }, create: { drawerId, temperature, humidity, fireDetected }, update: { temperature, humidity, fireDetected } })`. Returns domain entity via `toDomainDrawerSensorState(row)` helper function defined in the same file (pattern matches toPublicMedicineBox / domain mapper helpers in sibling repos).
  - `findByDrawerId(drawerId)` → prisma.findUnique where {drawerId} → toDomain or null.
  - `findManyByDrawerIds(ids)` → prisma.findMany where drawerId in ids → map to domain array.
  - Export `toDomainDrawerSensorState` helper as named export so tests can construct domain-shaped mocks.
- **Optional**: if a shared repositories barrel/index file exists in prisma/repositories/, add export line for new PrismaDrawerSensorStateRepository. If no barrel exists, skip (existing controllers import concrete repo classes directly by absolute file path — DI pattern already works that way).
- **Test Requirements**:
  - TR-4.1 [rule] tsc --noEmit exit 0 (repository class compiles, implements interface correctly).
  - TR-4.2 [rule] upsert implementation calls prisma `upsert()` (NOT create-then-update or find-then-save). Atomic per-drawer unique-key policy.
  - TR-4.3 [rubric 0-2, pass ≥1] Domain mapper helper converts prisma row fields correctly (Date objects for updatedAt/createdAt, null for nullable temperature/humidity). Pattern consistent with sibling Prisma*Repository mappers.

---

### Task 5 — Application layer use-cases (3 files)
- **Status**: pending
- **Maps AC**: AC-05, AC-06, AC-09, AC-10, AC-14, AC-15, AC-20
- **Files created**:
  1. `src/application/use-cases/device/RecordDrawerSensorReading.ts` — device POST usecase.
  2. `src/application/use-cases/medicine-box/GetMedicineBoxSensorReadings.ts` — Flutter GET medicine-box usecase.
  3. (Optional) `src/application/use-cases/drawers/GetDrawerSensorReading.ts` — single-drawer GET usecase (implements FR-7; if skipped, set cancelled with user-approved "Optional §8 not implemented" justification). IMPLEMENTED BY DEFAULT because drawer controller pattern exists.
- **File 1 — RecordDrawerSensorReading constructor params**: `(IMedicineBoxRepository, IDrawerRepository, IDrawerSensorStateRepository)`. Execute payload typed: `{deviceId, drawerId, temperature, humidity, fireDetected}`.
  - Gates (strict order, throw typed AppErrors from @shared/errors):
    1. `box = findByDeviceId(deviceId)` → null → NotFoundError 404.
    2. `drawer = findById(drawerId)` → null → NotFoundError 404.
    3. `drawer.medicineBoxId !== box.id` → ForbiddenError 403.
    4. Pass gates: `sensorRepo.upsert(payload)` → return shaped result `{drawerId, temperature, humidity, fireDetected, updatedAt}` from upserted entity.
- **File 2 — GetMedicineBoxSensorReadings constructor**: `(IMedicineBoxRepository, IDrawerRepository, IDrawerSensorStateRepository)`. Execute `(userId, medicineBoxId)`.
  - Gates:
    1. `box = medicineBoxRepo.findByIdAndUserId(medicineBoxId, userId)` → null → NotFoundError 404 (covers both "box not exists" and "not owner" because the join on userId filters both; consistent with existing GetMedicineBoxById usecase).
  - Logic:
    2. `drawers = drawerRepo.findAllByMedicineBoxId(medicineBoxId)` → all N drawers.
    3. `sensors = sensorRepo.findManyByDrawerIds(drawers.map(d=>d.id))` → joinable list.
    4. For each drawer: if sensor row found → use its values; else `{temperature:null, humidity:null, fireDetected:false, updatedAt:null}`. fireDetected always boolean, never undefined.
  - Return: `{medicineBoxId, drawers: Array<{drawerId, temperature, humidity, fireDetected, updatedAt:Date|null}>}` (updatedAt is Date domain object; controller stringifies).
- **File 3 optional — GetDrawerSensorReading constructor**: `(IDrawerRepository, IDrawerSensorStateRepository)`. Execute `(userId, drawerId)`.
  - Gate 1: `drawer = drawerRepo.findByIdAndUserId(drawerId, userId)` → null → NotFound 404.
  - Gate 2: `sensor = sensorRepo.findByDrawerId(drawerId)` → may be null.
  - Return same per-drawer shape as array entries from File 2.
- **All 3 files**: No prisma imports in use-cases (clean arch — depends only on domain interfaces).
- **Test Requirements**:
  - TR-5.1 [rule] Device usecase: device not found → throws NotFoundError. Drawer not found → throws NotFoundError. Drawer belongs to other box → throws ForbiddenError. Valid → calls sensorRepo.upsert once with correct 4 fields.
  - TR-5.2 [rule] MedicineBox usecase: box not owned → throws NotFound via findByIdAndUserId. 3 drawers, 2 sensor rows → result.drawers.length===3; 1 drawer has null temperature/humidity, fireDetected=false.
  - TR-5.3 [rule] Upsert called inside device usecase returns the upserted domain entity; no stale reads.
  - TR-5.4 [rubric 0-2, pass ≥1] Clean arch: grep application use-case files for `from '@prisma'` or `from '@infrastructure'` → 0 matches for prisma/infra concrete class names (depends only on domain interfaces imported from @domain/*).

---

### Task 6 — Presentation layer: Validator schema append to devices.validator.ts + formatZodErrors extended
- **Status**: pending
- **Maps AC**: AC-04, AC-13
- **Edit `src/presentation/validators/devices.validator.ts` APPEND-ONLY at bottom (above the FUTURE DEVICE AUTH EXTENSION comment block, if exists — otherwise after medicationEventSchema export)**:
  - Append export `drawerSensorReadingSchema` per spec FR-8 exactly:
    - z.object strict: deviceId (string.trim.min1), drawerId (string.trim.min1), temperature (z.number), humidity (z.number), fireDetected (z.boolean).
    - superRefine: temperature finite → else custom issue. humidity finite AND 0..100 → else custom issue per range.
  - Keep all existing exports (heartbeat, face, schedule, medicationEvent) untouched. Verify by file diff: only additions, no deletions/edits to existing schemas.
- **Test Requirements**:
  - TR-6.1 [rule] humidity=150 parse → safeParse success=false, issues[0].path=['humidity'] → T3 400 scenario covered.
  - TR-6.2 [rule] temperature=Infinity parse → safeParse success=false (finite check). fireDetected="true" (string) → success=false (strict boolean). Extra field `"foo":"bar"` → success=false (strict).
  - TR-6.3 [rule] Existing heartbeat/face-verification/medication-event schemas in the same file still export identically; no line edits outside the new schema block.
  - TR-6.4 [rule] All 4 fields valid: deviceId="PI-DEV-001" drawerId="d-1" temp=27.4 humidity=58.2 fire=false → safeParse success=true.

---

### Task 7 — Presentation layer: Controllers + Routes (3 endpoints total; 2 mandatory + 1 optional)
- **Status**: pending
- **Maps AC**: AC-03, AC-07, AC-08, AC-11, AC-12, AC-14, AC-20
- **Part 7A — DevicesController + devices.routes.ts (MANDATORY POST /sensor-readings)**:
  - Edit `src/presentation/controllers/DevicesController.ts`:
    - Top-of-file import: append `drawerSensorReadingSchema` to the validator import. Append `RecordDrawerSensorReading` usecase import. Append PrismaDrawerSensorStateRepository import.
    - Extend `formatZodErrors` switch: add case `'sensor-reading'` returning concise human-readable invalid-message (consistent style with other cases; extend the schema parameter literal union type accordingly).
    - Append new method `async recordSensorReading(req, res, next)` BEFORE the closing `};` of DevicesController export object.
    - Inside method: SECURITY LIMITATION one-line comment (exactly matching recordMedicationEvent's inner SECURITY LIMITATION style, lines 235-236 pattern).
    - Parse: `bodyParsed = drawerSensorReadingSchema.safeParse(req.body ?? {})` → fail → BadRequestError(formatZodErrors(error, 'sensor-reading')).
    - Resolve trusted: `trustedDeviceId = resolveRequestingDeviceId(req as DeviceRequest)`; overwrite payload.deviceId if present.
    - DI: instantiate `new PrismaMedicineBoxRepository()`, `new PrismaDrawerRepository()`, `new PrismaDrawerSensorStateRepository()`.
    - Construct usecase → execute(payload).
    - Envelope response 200: `{status:'success', statusCode:200, data:{drawerId, temperature, humidity, fireDetected, updatedAt: result.updatedAt.toISOString()}}`. Use existing `okPublic()` helper.
    - catch (error) → next(error).
  - Verify: top-of-file `SECURITY LIMITATION` comment block (lines 1–6) unchanged. `resolveRequestingDeviceId` function untouched (no edits — only used).
  - Edit `src/presentation/routes/devices.routes.ts` APPEND line between medication-events route (L13) and export (L15): `devicesRouter.post('/sensor-readings', DevicesController.recordSensorReading);` → keep existing 5 routes untouched.
- **Part 7B — MedicineBoxController + medicineBox.routes.ts (MANDATORY GET /:id/sensors)**:
  - Edit `src/presentation/controllers/MedicineBoxController.ts`:
    - Import lines: append `GetMedicineBoxSensorReadings` usecase. Append `PrismaDrawerRepository` + `PrismaDrawerSensorStateRepository` (import paths match existing style in DrawerController).
    - Append method `async getSensors(req, res, next)` BEFORE closing `};`.
    - Pattern: userId = req.user!.userId; id = req.params.id as string; DI 3 repos → usecase → execute(userId, id) → map drawers array updatedAt fields to ISO strings if non-null → okPublic(res, 200, { medicineBoxId, drawers: mappedDrawers }).
  - Edit `src/presentation/routes/medicineBox.routes.ts`: Insert route AFTER POST /:id/unassign (L38) but BEFORE generic GET /:id (L39): `medicineBoxRouter.get('/:id/sensors', MedicineBoxController.getSensors);` → CRITICAL order. Because whole router already `.use(requireAuth)`, route is protected automatically by existing middleware.
- **Part 7C — DrawerController + drawer.routes.ts (OPTIONAL §8 GET /:id/sensors, IMPLEMENTED)**:
  - Edit `src/presentation/controllers/DrawerController.ts`: append optional `async getSensors(req, res, next)` method. userId extraction, DI (PrismaDrawerRepository + PrismaDrawerSensorStateRepository), instantiate GetDrawerSensorReading usecase, result ISO-map, ok envelope.
  - Edit `src/presentation/routes/drawer.routes.ts`: insert BEFORE generic GET /:id (L25): `drawerRouter.get('/:id/sensors', DrawerController.getSensors);` → correct order.
- **Test Requirements**:
  - TR-7.1 [rule] devices.routes.ts grep for `'/sensor-readings'` → exactly 1 match, method POST, correct controller reference.
  - TR-7.2 [rule] medicineBox.routes.ts grep shows `/sensors` route declared BEFORE `'/:id'` literal in file-order (no routing collision with generic id param).
  - TR-7.3 [rule] DevicesController recordSensorReading method body contains SECURITY LIMITATION comment and calls resolveRequestingDeviceId.
  - TR-7.4 [rule] Response envelopes all 3 endpoints: status === 'success', has statusCode number, has data object.
  - TR-7.5 [rule] Existing 5 device routes + their controller methods source code unchanged (grep their method names heartbeat/getFaceReference/recordFaceVerification/getDeviceSchedule/recordMedicationEvent in DevicesController post-edit; their source body start/end line diffs show zero content changes, only new import lines + new method append).

---

### Task 8 — Jest tests drawer-sensor.spec.ts (9+ scenarios, T1–T7 + 2 bonus)
- **Status**: pending
- **Maps AC**: AC-16
- **Create NEW file `tests/drawer-sensor.spec.ts`**.
- Style: jest.fn() mock repositories + mock usecase returns. NO real prisma, NO real DB. Pattern match tests/device-medication-events.spec.ts existing style (read it first).
- **Mandatory it() blocks (user §15)**:
  1. **T1 Valid sensor reading** — POST happy path. Construct valid payload (deviceId exists, drawer belongs to box). Mocks: medicineBoxRepo.findByDeviceId → valid box; drawerRepo.findById → drawer with drawer.medicineBoxId === box.id; sensorRepo.upsert → returns domain entity with all 5 fields set. Expect call count upsert === 1. Expect return data shape correct.
  2. **T2 Fire detected true** — Same device setup, payload fireDetected=true. Mocks: sensorRepo upsert called with fireDetected=true. Result returns fireDetected=true.
  3. **T3 Invalid humidity 150** — zod schema validation at controller layer. Expect BadRequestError (400 status) before any repo method called. (Test can be direct zod schema parse test without wiring full controller.)
  4. **T4 Invalid device (deviceId not exists)** — usecase test. medicineBoxRepo.findByDeviceId("PI-NOT-EXIST") → null. Execute → throws NotFoundError (maps to 404).
  5. **T5 Drawer belongs to another device/box** — usecase test. box-A exists, drawer-B's medicineBoxId === box-B.id not box-A.id. Execute → throws ForbiddenError (maps to 403).
  6. **T6 Mobile GET medicine-box sensors** — usecase + controller test. userId owns the box. medicineBoxRepo.findByIdAndUserId(boxId, userId) → valid box. drawerRepo.findAllByMedicineBoxId → [drawer1, drawer2, drawer3]. sensorRepo.findManyByDrawerIds → [row1, row3 only, no row2 for drawer2]. Expect result drawers length 3; drawer2 entry has temperature=null, humidity=null, fireDetected=false, updatedAt=null.
  7. **T7 Unauthorized mobile access (other user)** — usecase test. userId=user-A, box.userId=user-B. medicineBoxRepo.findByIdAndUserId(boxId, user-A) → returns null because join userId filters. Execute throws NotFoundError (controller renders as 404 consistent with existing getById pattern; spec AC-09 accepts 404 for "not found OR not owned" as findByIdAndUserId collapses both cases).
- **Bonus 2 scenarios ≥2 tests**:
  8. **T-invalid-temperature-Infinity** — zod schema direct parse: temperature=Infinity → fails superRefine finite check.
  9. **T-fireDetected-string-coercion** — zod schema direct parse: fireDetected="false" (string) → fails z.boolean() check; correct HTTP 400.
  10. (Optional bonus beyond 9): T-idempotent-upsert: 2 calls same drawerId → mock sensorRepo.upsert called 2x with same drawerId; tests that call count === 2 (the test verifies the controller/usecase DOES call upsert — the actual single-row guarantee is provided by Prisma UPSERT + @unique drawerId, which Task 4's prisma impl handles).
- **Run**: `npx jest tests/drawer-sensor.spec.ts --runInBand` → must pass ALL tests (at least 9 green).
- **After**: Run full `npx jest` → entire test suite ≥519 tests green. No regressions.
- **Test Requirements**:
  - TR-8.1 [rule] Jest count: ≥9 it() blocks. `npx jest tests/drawer-sensor.spec.ts` passes with 0 failures.
  - TR-8.2 [rule] Full jest suite after new file added: exit 0, ≥519 tests pass.
  - TR-8.3 [rule] Grep test file for `new PrismaClient` / `from '@prisma/client'` → 0 matches (tests use pure jest.fn() mocks; not real DB).
  - TR-8.4 [rubric 0-2, pass ≥1] Test names clearly reference T1–T7 user §15 scenarios. Error expectations map to status codes.

---

### Task 9 — SENSOR-DRAWER-POSTMAN.txt project-root guide
- **Status**: pending
- **Maps AC**: AC-17
- **Create NEW file `SENSOR-DRAWER-POSTMAN.txt`** at project root `c:\Users\borgi\Desktop\app\server\SENSOR-DRAWER-POSTMAN.txt`.
- **Document user §15 T1–T7 tests verbatim as Postman collection guidance**:
  1. T1 Valid POST /api/devices/sensor-readings — Method, URL, Headers (Content-Type: application/json), Body JSON example, Expected 200 → response example.
  2. T2 Fire detected POST — fireDetected=true body, Expected 200, DB fireDetected=true note.
  3. T3 Invalid humidity POST — humidity=150 body, Expected 400 Bad Request.
  4. T4 Invalid device not found POST — bad deviceId, Expected 404.
  5. T5 Drawer belongs to another device POST — deviceId box-A + drawerId from box-B, Expected 403 Forbidden.
  6. T6 Mobile GET /api/medicine-boxes/{medicineBoxId}/sensors — Method, URL, Required Authorization: Bearer {jwt} for owning user, Expected 200 → response shape example with drawers[] array.
  7. T7 Unauthorized mobile GET — another user's Bearer token for same box URL, Expected 401 or 403 (per existing error middleware).
- File style: match existing PATIENT-TAKES-MEDICATION-POSTMAN.txt layout and verbosity.
- **Test Requirements**:
  - TR-9.1 [rule] File exists at correct path, contains 7 section headers T1–T7.
  - TR-9.2 [rule] T1–T5 endpoint method POST `/api/devices/sensor-readings` present verbatim. T6–T7 endpoint method GET `/api/medicine-boxes/{medicineBoxId}/sensors` present verbatim.

---

### Task 10 — Pipeline 5-step sequential exit 0
- **Status**: pending
- **Maps AC**: AC-01, AC-02, AC-18, AC-19, AC-21
- Run sequentially, EVERY step exit code 0 required. If any step fails, fix and restart from step 1.
  1. **Step 1 prisma validate**: `npx prisma validate` → exit 0.
  2. **Step 2 tsc strict**: `npx tsc --noEmit --project tsconfig.json` → exit 0. No TS6133 unused vars. No implicit any.
  3. **Step 3 jest full**: `npx jest` → exit 0. Entire suite ≥519 tests green. No `.only` tests left.
  4. **Step 4 npm build**: Read package.json scripts, find correct build command. Likely `npm run build` → exit 0.
  5. **Step 5 forbidden-scope grep**: PowerShell search in `src/`, `tests/`, NEW files created this task only (exclude existing shipped feature files). Tokens case-insensitive match: `Heartbeat.*UseCase|RecordFace|Face[Rr]ecognition|Schedule.*[Ss]ync|ProcessPatientMedicationEvent|drawer open|drawer close|Motor|MQTT|WebSocket|notification architecture|Computer Vision|AI model`. NEW code (Task files 1-9 created/edited by this spec) must produce 0 matches. Existing legacy code in other modules (heartbeat/face/schedule/med-events) allowed to keep their tokens — exclude them via specific file list.
- **Test Requirements**:
  - TR-10.1 [rule] Steps 1→4 each individually exit 0. Record stdout/stderr if failure.
  - TR-10.2 [rule] Step 5 grep NEW/modified files only: match count = 0.
  - TR-10.3 [rubric 0-2, pass ≥1] Pipeline was run at least once start-to-finish sequential, not just individual steps cherry-picked. Documented by stdout capture from each step.

---

### Task 11 — Final 11-point §17 deliverable printed verbatim
- **Status**: pending
- **Maps AC**: AC-01 through AC-22 comprehensively
- After Task 10 passes, produce the user §17 requested final deliverable as the final assistant message of this task (printed in natural language response, not a file). Structure must include ALL 11 sections EXACTLY as user §17 numbered:
  1. Prisma schema changes (list added model)
  2. Migration (0014 folder, SQL statements used, deploy status exit 0)
  3. Controller (list 2–3 controller methods added, file paths, line counts appended)
  4. Service/Usecase (list 3 usecase classes file paths + responsibilities)
  5. Routes (3 endpoints: POST device, GET box sensors, optional GET drawer sensors)
  6. Validation (drawerSensorReadingSchema rules, test cases passed T3/humidity150/invalid-temp/invalid-fire-boolean)
  7. Authentication/authorization integration (requireAuth reuse for mobile endpoints, device identity via resolveRequestingDeviceId, cross-device drawer 403 enforcement, mobile ownership 404/403)
  8. API request/response examples (2+ example request bodies and envelope response JSON bodies)
  9. Postman test cases (T1–T7 documented in txt, paths/urls/methods)
  10. List of files changed/created (CREATE/MODIFY per file, absolute paths or project-root relative)
  11. Confirmation statement: "Existing features (heartbeat, face recognition, schedule sync, medication events, drawer medication assignments) were NOT modified beyond necessary append-only additions to shared devices.validator / DevicesController / devices.routes export objects. No unrelated database refactoring performed. Forbidden implementations list (user §16) has zero code introduced."
- **Test Requirements**:
  - TR-11.1 [rule] All 11 numbered §17 sections present in final response in order 1..11.
  - TR-11.2 [rubric 0-2, pass ≥1] Each §17 section references actual file paths and concrete values from the implementation (not hypothetical). File list (section 10) matches git diff / actual created/modified files on disk.

---

### Optional Task 8b — (Not a separate task number; incorporated into Task 8 test file count)
If any AC uncovered during testing: add extra it() blocks to Task 8 test file to close rubric AC gaps. Maximum 4 bonus tests; AC coverage must remain intact.

## Dependencies between Tasks (run order MUST be preserved)
- Task 1 → Task 2 (schema first, then migration generated/applied against it)
- Task 3 → Task 4 (domain interface before impl)
- Tasks 1+3+4 → Task 5 (use-cases require all repos ready)
- Task 5 → Tasks 6+7 (presentation depends on use-cases)
- Task 7 → Task 8 (tests import controller methods and validator schemas)
- All 1–9 → Task 10 (pipeline after everything wired)
- Task 10 green → Task 11 (final report)

**Status**: All tasks pending. User approval required before implementation starts per SP-4.

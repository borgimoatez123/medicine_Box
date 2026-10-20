# SPEC: Raspberry Pi Schedule Synchronization Backend

Last updated: 2026-09-23

## 1. Problem

The Smart Medicine Box Raspberry Pi devices (one per Medicine Box, identified by `MedicineBox.deviceId`) need a local copy of the patient's current medication schedule so they can independently detect when a medication action is due (timer loop runs on the Pi, not the backend — per user §2/§24). The backend remains the single source of truth for patient schedules, medications, drawer assignments and dosages; it must expose a single REST endpoint to deliver the current, correct, filtered schedule to the Pi.

Existing code already has an authenticated user-facing schedule CRUD API (`SchedulesController`, `PrismaScheduleRepository.findAllByUserId`) but **no device-facing schedule endpoint**. The existing repository does not: (a) filter by deviceId → MedicineBox → Patient association chain, (b) include drawer medication data needed to produce `drawerId` + `quantity`, (c) enforce the device authorization boundary required by user §18 (prevent PI-DEV-001 pulling Patient-999 schedules).

This spec closes that gap.

## 2. Users / Actors

* **Raspberry Pi device (MedicineBox.deviceId)** — calls a new GET `/api/devices/:deviceId/schedule`. Actor is the box identified by `deviceId` (same `deviceId` column used by heartbeat and face endpoints on the `MedicineBox` table; NO separate `Device` model per the verified constraint from the prior device-subsystem cleanup).
* **Backend** — validates the device exists, resolves MedicineBox → shared-userId patient(s), fetches active schedules + medications + drawer-medications, shapes to the lean Pi payload, orders deterministically, returns through the project-standard response envelope. Backend NEVER runs any scheduling timer loop.
* **Existing user/admin schedule-writers** — unmodified; they continue writing schedules through the existing authenticated user routes. The device endpoint is read-only and has no side-effects on schedule rows, drawer quantities, medication state, or any other write.

## 3. Goals (in-scope, feature)

G1. Implement one new route: `GET /api/devices/:deviceId/schedule` mounted inside the existing `devicesRouter` (prefix `/api/devices`). No new top-level router file; append only.
G2. Validate the full device → MedicineBox → patient chain exactly per user §6 Step 1–4, with distinct 404 messages for each missing stage, plus 400 for invalid deviceId.
G3. For the resolved patient, produce a flat array of **per-schedule, per-time-entry rows** (i.e., a single Schedule with `times:["08:00","20:00"]` produces two rows in the payload) because the §8 minimum schema requires a singular `time: "HH:mm"` field, and the §1 example diagram uses per-time rows.
G4. Every row must include §8 minimum fields: `scheduleId, medicationId, medicationName, drawerId, dosage, time`. In addition, per §12, include an optional `quantity` number field sourced from the matching active `DrawerMedication.quantity` when one exists.
G5. Include per-schedule administration metadata required for correct local Pi execution: `daysOfWeek: number[] | null` (integers 1..7), `startDate: ISO-8601 date`, `endDate: ISO-8601 date | null`, `status: "ACTIVE"` (filtered so only ACTIVE appears), `isActive: true` (filtered). These fields let the Pi skip due times outside the date range / weekday window.
G6. Filter schedules per §14: include only rows where `schedule.status === 'ACTIVE'` AND `schedule.isActive === true` AND `drawerMedication.isActive === true` when a drawer assignment is present.
G7. Order deterministically §10: first by `time` HH:mm string ascending, then by `scheduleId` string stable, then by drawerId.
G8. Empty schedule (patient exists, 0 matching rows) must return 200 OK with `schedules: []` — per §15, not a server error.
G9. Strict READ ONLY: no row writes, no drawer open/close, no quantity +/- , no mark taken/missed, no notifications. Forbidden per §23/§24.
G10. Reuse existing Clean Architecture layers (domain → application → infrastructure → presentation), existing repositories where possible, existing shared `{status, statusCode, data}` response envelope, existing shared error classes + middleware.
G11. Jest coverage for the 7 scenarios user §21 lists (T1 valid, T2 no device, T3 no box for device, T4 no patient for box, T5 empty schedules, T6 multiple schedules with times expanded, T7 inactive excluded).
G12. Documented Postman collection GET example in a project-root `SCHEDULE-SYNC-POSTMAN.txt` mirroring the style of FACE-RECOGNITION-POSTMAN.txt.

## 4. Non-Goals (explicitly out of scope)

NG1. Do NOT create a separate `Device` model. All device identity continues to live on `MedicineBox.deviceId`.
NG2. Do NOT modify the `Schedule` / `DrawerMedication` / `Drawer` / `Medication` / `Patient` Prisma schemas. This endpoint is read-only shape-only; no columns added, no migrations.
NG3. Do NOT add WebSocket / MQTT / push sync channels. First implementation is REST pull only per §17.
NG4. Do NOT implement any timer, scheduler, drawer open, motor command, sensor read, notification, or quantity write on the backend (forbidden §23, §24).
NG5. Do NOT create a new schedule storage model or new event/logging tables. This feature has NO state mutation.
NG6. Do NOT convert timezone away from stored form. User §11 Tunisia local schedule times: no UTC conversion. Document assumption: Schedule.times HH:mm are stored as local Tunisia wall-clock strings (no TZ). `startDate` / `endDate` are YYYY-MM-DD or ISO dates as already stored; no date shifting.
NG7. Do NOT implement device-token enforcement middleware this iteration. Follow the same documented-extension-hook pattern as the existing heart-beat/face endpoints: prefer future `req.deviceId` from middleware; route param `:deviceId` is the current source. Add SECURITY LIMITATION comment at controller top mirroring the one already in DevicesController.
NG8. Do NOT return unnecessary patient PII beyond patientId. No avatar, no notes, no name in the schedule payload.

## 5. Functional Requirements (FR)

### FR-1. New route signature
- Verb + path: `GET /api/devices/:deviceId/schedule`
- Mounted under: existing [devices.routes.ts](file:///C:/Users/borgi/Desktop/app/server/src/presentation/routes/devices.routes.ts) (appended line, same router alongside heartbeat / face-reference / face-verification).
- Auth pattern: same as other `/api/devices/*` endpoints today — unauthenticated on the wire, but **authorization boundary enforced inside use-case** (the device → box → patient chain; extension hook for future `req.deviceId` override documented).

### FR-2. Validation chain (user §6 Step 1–4, in strict order)
Every step short-circuits on failure with the exact specified HTTP + message:
1. **deviceId format** (`:deviceId` param). Must be string, trimmed, length ≥ 1. If missing / empty → 400 `BadRequestError("deviceId is required")`.
2. **Device (MedicineBox) exists**. Query `MedicineBoxRepository.findByDeviceId(deviceId)`. If result `null` → 404 `NotFoundError("Device not found")`.
3. **MedicineBox exists / is well-formed**. We already re-used MedicineBox as device carrier so a result here IS the box. However, explicitly: if returned MedicineBox has `deviceId !== null` — box exists. Document that Step 3 is satisfied by Step 2 in this implementation, but keep the distinct 404 message if we ever split the model. Never the less, NO second 404. Step 3 output is implicitly the box returned.
   * Note from inspecting schema: MedicineBox has the deviceId, so step 2 returns the box. User §6 step 3 text "Medicine box associated with the device" is here: the MedicineBox itself. We satisfy it by design. The 404 distinct message would be triggered only if in the future a PhysicalDevice FK is re-added; today the same 404 "Device not found" covers step 2+3 because MedicineBox IS the device container. However, user §6 Step 4 explicitly calls out "No patient assigned → distinct 404 message", so we implement Step 4 with its unique message.
4. **Patient assigned to this box's owner**. Association rule (re-uses the face-recognition endpoint approved rule — no direct MedicineBox↔Patient FK): the authoritative authorization boundary is **shared userId ownership**, same as the face endpoints / admin activate box flow:
   - From `box` → `box.userId`
   - From `Patient` collection → find first / primary patient whose `patient.userId === box.userId`.
   - If `box.userId` is **null** OR there is **no patient row with matching userId** → 404 `NotFoundError("No patient assigned to this medicine box")`.

### FR-3. Efficient relation-loaded schedule retrieval (§7, §19 — no N+1)
Implement a new repository method on `IScheduleRepository` (and on the existing `PrismaScheduleRepository` impl) called:
```ts
findAllActiveByPatientIdForDeviceSync(patientId: string): Promise<Array<{
  schedule: Schedule;
  medication: { id:string; name:string };
  drawerMedication: { id:string; drawerId:string; quantity:number; isActive:boolean } | null;
}>>
```
Implementation must make **ONE prisma call** using Prisma nested `include: { medication: true, medication: { drawerMedications: { where: { isActive: true }, include: { drawer: true } } } }` style — no per-schedule medication lookup.

Filter inside the prisma `where` clause:
- `medication: { patientId: <patientId> }` (equivalent to current user-auth filter without userId),
- `status: 'ACTIVE'`,
- `isActive: true`.

Post-prisma shape: for each resulting (schedule, medication) pair, locate the active drawerMedication entry for that (medicationId, boxId? — actually medication drawer assignments are global per medicine-box owner; inspecting existing schema: `DrawerMedication.drawerId` references Drawer which references `MedicineBox` via `medicineBoxId`. Filter drawer medications to the requesting box by joining `Drawer.medicineBoxId === box.id`. That is the correct drawer link per user §1 (Patient ↓ Schedule ↓ Medication ↓ DrawerMedication ↓ Drawer).

### FR-4. Per-time row expansion (G3 / §8 singular time field)
Each Prisma `Schedule.times` value is typed `unknown | null` (domain entity) / `Json` prisma. In practice the existing validator enforces `(HH:mm)[]` per tests schedule-api.spec.ts lines 59-63. So normalization rules:
- If times is an array of non-empty strings → use each entry as the `time` for a row. Validate regex HH:mm when expanding for safety; skip silently any non-HH:mm entry.
- If times is empty array / null AND timesPerDay ≥ 1 → return 1 row with the special sentinel time `"00:00"` (so Pi can at least see the schedule exists) PLUS include in the payload the `timesPerDay` number so downstream code can interpret. Always include `timesPerDay` in the row for completeness.
- Else → drop the schedule (no times at all → no row).
Dedupe identical time strings per schedule. Keep row order of time strings as they appear in the array; then overall stable sort per G7.

### FR-5. Per-row payload (§8 + §12 extras)
Every element in `schedules[]` must have EXACTLY these keys (no extras, no omission):
```ts
{
  scheduleId: string;
  medicationId: string;
  medicationName: string;
  drawerId: string | null;       // null if no active DrawerMedication assigned for that drawer/med for that box
  dosage: string;                // the stored dosage string unchanged ("1 tablet", "2", etc.)
  time: string;                  // HH:mm per expansion rule FR-4
  quantity: number | null;       // drawerMedication.quantity when drawerId non-null; else null
  daysOfWeek: number[] | null;   // 1..7, exactly as stored on Schedule (Json → array / null)
  startDate: string;             // ISO date or datetime; `.toISOString().slice(0,10)` date-only form to avoid timezone drift; per NG6 no shift
  endDate: string | null;
  timesPerDay: number | null;
  status: "ACTIVE";              // guaranteed by filter
  isActive: true;                // guaranteed by filter
}
```
No field names from §8 example are aliased. `medicationName` is the `Medication.name` column per existing schema; inspect to confirm.

### FR-6. Empty payload (§15)
When the resolved patient has 0 rows after all filters / expansion → HTTP 200 with:
```
status: 'success', statusCode: 200, data: { patientId: <id>, schedules: [] }
```
No 404.

### FR-7. Ordering (§10)
The final `schedules[]` array is ordered (stable sort):
1. Primary: `time` ascending (lex on HH:mm strings; this works because 08:00 < 14:00). `null` / `"00:00"` sentinel rows sort FIRST.
2. Secondary: `startDate` ascending (ISO string lex).
3. Tertiary: `scheduleId` ascending (UUID lex = stable).

### FR-8. Read-only enforcement
Controller method handles the GET; use-case method name is `GetDeviceSchedule.execute(deviceId: string)` → returns shaped `{ patientId, schedules[] }`. No repository `update/create/delete` calls anywhere in the call chain.

### FR-9. Security & auth hook (§18)
- Same as existing DevicesController extension pattern: inside the controller, before invoking the use-case, run:
  ```
  const effectiveDeviceId = resolveRequestingDeviceId(req) ?? req.params.deviceId
  ```
  Preference order for `resolveRequestingDeviceId`: (1) `req.deviceId` trusted property if set by future middleware, (2) `req.headers['x-device-id']` string if present, (3) fallback to route param.
- If `effectiveDeviceId` after resolution is not equal to the route param `req.params.deviceId` AND both are non-empty → treat middleware value as authoritative (overwrite), use the effective one. This prevents cross-device spoofing once middleware is on.
- Add SECURITY LIMITATION comment block at the top of DevicesController's new `getDeviceSchedule` method (or the controller class header comment block if already shared) stating the exact current limitation: route param is used today; x-device-id header is read but NOT cryptographically verified until middleware ships.

### FR-10. Response envelope (§9 + project convention)
Use the project-wide envelope pattern `{status, statusCode, data}` same as the existing `MedicineBoxController.ok()` helper style and the existing `DevicesController` pattern for heartbeat. `data` shape:
```ts
{
  patientId: string;
  schedules: Array<{ FR-5 payload }>;
}
```

### FR-11. Error handling (§20)
Use the existing shared error classes imported from `@shared/errors` (the same pattern in use-cases like GetPatientFaceReference). Reuse the existing centralized error middleware; no inline try/catch swallowing. Error map:
| Case | HTTP | Class | Exact message |
|---|---|---|---|
| deviceId empty string | 400 | BadRequestError | `"deviceId is required"` |
| findByDeviceId → null | 404 | NotFoundError | `"Device not found"` |
| box.userId null OR 0 patients match box.userId | 404 | NotFoundError | `"No patient assigned to this medicine box"` |
| prisma / DB error thrown | 500 | (next(err)) | Handled by middleware, no custom message |

Note: Step 3 of §6 (MedicineBox not found for device) = same 404 as device not found in this architecture (no separate Device table). If/when a future iteration splits Device → MedicineBox FK, the distinct 404 "Medicine box not found for this device" message can be added without route shape change. This is documented in the Assumptions section.

## 6. Non-functional Requirements (NR)

NR-1. **Performance (§19)**: one prisma query only, no N+1. Use nested `include` to load medication + drawer medications + drawer.
NR-2. **Prisma query readability**: prefer one level nesting; post-process the drawer link in TypeScript (drawerMedication → drawer.medicineBoxId matches current box) since Prisma filtered nested includes on grand-children can be fragile. Max two helper functions in the repository method: one prisma call, one TS filter step linking drawerMedication to the specific `box.id`.
NR-3. **Test isolation**: Jest tests use jest.fn() mocks on the repository interface (same pattern as device-face-recognition.spec.ts). No real DB hit, no supertest app bootstrap required.
NR-4. **Clean Architecture layers**:
  * New repository method on `IScheduleRepository` (domain interface)
  * New use case class `GetDeviceSchedule` → `src/application/use-cases/device/GetDeviceSchedule.ts` alongside existing heartbeat/face use-cases.
  * New method on `DevicesController` → `getDeviceSchedule`, imported schemas / use case in constructor.
  * New zod validator schema → `getDeviceScheduleSchema` appended to [devices.validator.ts](file:///C:/Users/borgi/Desktop/app/server/src/presentation/validators/devices.validator.ts).
  * New route line appended to [devices.routes.ts](file:///C:/Users/borgi/Desktop/app/server/src/presentation/routes/devices.routes.ts).
NR-5. **No schema changes, no migration**: endpoint is read-only; no new columns / tables. `npx prisma validate` and `npx prisma migrate deploy` are unchanged idempotent steps.
NR-6. **TS strict**: `npx tsc --strict --noEmit` passes with 0 errors after changes.
NR-7. **Build**: `npm run build` passes after changes.
NR-8. **All existing tests remain green**: `npx jest --forceExit` must still report 0 failures after new test file added.
NR-9. **Scope exclusion audit (post-hook)**: After implementation, grep `src` and `tests` for any occurrence of identifiers from user §23/§24 forbidden list (`Open.*drawer|closeDrawer|markMedication|updateQuantity|sendNotif|setTimeout.*schedule|cron|schedule.*timer|DispensingEvent|triggerMotor|sensor|heartbeat|face.*verification`) EXCLUDING the previously-shipped heartbeat + face endpoint files. Verify 0 forbidden calls.

## 7. Constraints / Dependencies / Assumptions

### C1 Constraints (hard, non-negotiable)
* C1.1. No schedule mutation on this endpoint.
* C1.2. No drawer / motor / sensor / notification logic.
* C1.3. No Prisma schema changes.
* C1.4. No new router file → one line append inside existing devices.routes.ts mount.
* C1.5. Strict §10 ordering, §15 empty 200.
* C1.6. No timezone shift.
* C1.7. Repository method must be added on existing interface + Prisma impl; no ad-hoc prisma call in the controller / use case body directly.
* C1.8. Association gate = shared userId only (no drawer-medications-must-exist check; a patient assigned to a box gets empty schedules if nothing's filled yet, per §15 empty return).

### C2 Dependencies
* Existing `MedicineBoxRepository.findByDeviceId(deviceId)` — re-used.
* Existing `PatientRepository` — we may or may not need a new small method `findFirstByUserId(userId)`; if it doesn't exist add it on `IPatientRepository` + Prisma impl (one-liner prisma.findFirst where userId = X, then orderBy createdAt ASC to get deterministic first patient). This is the ONLY new non-schedule repository method needed, and only if missing.
* Existing `PrismaScheduleRepository.findAllByUserId` — left untouched for user routes. The new method is additive.
* Existing `DevicesController` / `devices.validator.ts` / `devices.routes.ts` — append only.

### C3 Assumptions (document, DO NOT silently change behavior)
* **A3.1 Association rule no direct FK**: MedicineBox ↔ Patient has no direct FK. Approved rule = shared userId ownership, approved earlier. For users with multiple patients under one account, we return schedules for the FIRST patient matching that userId (deterministic: earliest `createdAt` Patient row). Document this in `GetDeviceSchedule` JSDoc / controller SECURITY comment and in the Limitations section of the final report. If/when the project adds a direct `MedicineBox.primaryPatientId FK → Patient.id` later, we can swap the association step to that FK with zero route shape change.
* **A3.2 Medication ↔ Drawer linking**: A Medication can be assigned to N Drawers across N MedicineBoxes via the existing DrawerMedication join → Drawer.medicineBoxId. We select the drawerMedication for the requesting box specifically. If a medication has zero active drawerMedication rows for this specific box: `drawerId = null, quantity = null` in the row. Pi must handle null drawerId gracefully (doc assumption).
* **A3.3 Timezone**: All `times[]` HH:mm values are stored as Tunisia local wall-clock (UTC+1 standard, UTC+2 DST). Backend never shifts. The Pi MUST apply its own configured TZ when comparing to RTC. Documented in Postman txt and final §14 report.
* **A3.4 Status / isActive filter**. We exclude PAUSED/COMPLETED/ARCHIVED schedules. This aligns with §14 "return only active schedules". If client ever needs to sync paused schedules a query parameter `?include=paused` can be added later; today no query params are accepted except the implicit route `:deviceId`.
* **A3.5 dosages are strings**. §8 shows `dosage: 2` as integer example but existing domain entity has `dosage: string`. We RETURN string unchanged per stored schema; doc note that if integer is needed Pi parses numeric prefixes.
* **A3.6 No device credential enforcement today**. Documented SECURITY LIMITATION comment; route param is the source until middleware ships.
* **A3.7 Patient for userId tie-break**. Users with multiple patients currently take first-by-createdAt. Documented assumption; not changed now.
* **A3.8 Step 3 404 sharing**. User §6 Step 3 ("Medicine box not found for this device") message is NOT produced because the MedicineBox IS the device container (no separate Device entity). Only step 2 `"Device not found"` 404 and step 4 `"No patient assigned to this medicine box"` 404 are emitted. If/when schema separates Device → MedicineBox FK, implement the distinct Step 3 404 message with no route change. Documented.

## 8. Open Questions (resolved with assumptions above; documented for approval)

**OQ-1 Association gate for multi-patient user accounts**: A userId may own N patients (e.g., parent manages children). Today: pick earliest createdAt patient. Alternative: introduce `MedicineBox.primaryPatientId FK`. Decision: **use earliest createdAt patient now, documented as assumption, no schema change this iteration** (consistent with C1.3 No Schema Changes).

**OQ-2 Medication → Drawer link: include rows with null drawerId?** Alternative: filter out schedules where `drawerId == null`. Decision: **keep them in the payload with drawerId:null, quantity:null** so the Pi logs a "not yet assigned" message locally instead of silently missing schedules (more debuggable).

**OQ-3 Inactive DrawerMedication.filter**: When drawerMedication.isActive=false but schedule status=ACTIVE: keep row with drawerId=null (treat same as not assigned) OR keep row showing inactive drawerId? Decision: **set drawerId=null, quantity=null for inactive drawer meds** (so Pi won't try to open an inactive drawer slot). Same behavior as no assignment.

All three OQs are implemented as stated unless user explicitly overrides.

## 9. Acceptance Criteria (exhaustive, rule | rubric)

### AC Coverage Legend:
`[rule]` = binary pass/fail, verifiable by pipeline / test / assert.
`[rubric]` = evaluative, 0-2 scale, threshold ≥ 1 for pass.

### Core endpoint
* **AC-1 [rule]** — Route `GET /api/devices/:deviceId/schedule` exists and is mounted under `/api/devices` inside devices.routes.ts.
* **AC-2 [rule]** — Empty deviceId route param ("/schedule" with empty or whitespace) → 400 BadRequest with message `"deviceId is required"`.
* **AC-3 [rule]** — Valid deviceId not present in MedicineBox table → 404 NotFound with message `"Device not found"`.
* **AC-4 [rule]** — Valid deviceId, box exists, box.userId=null → 404 `"No patient assigned to this medicine box"`. Same 404 message if box.userId is non-null but no Patient row exists with matching userId.
* **AC-5 [rule]** — Happy path: device with box + box.userId + 1 patient + 1 schedule with times["08:00"] + 1 drawerMed active → 200, schedules[0] has all FR-5 keys, time="08:00", drawerId & quantity populated.
* **AC-6 [rule]** — Patient exists but has zero schedules → 200 schedules: [] (empty array).
* **AC-7 [rule]** — One Schedule entity times["08:00","14:00"] → produces 2 rows in the payload with same scheduleId, same medicationId, different time strings.
* **AC-8 [rule]** — Inactive schedules excluded: (status=PAUSED OR status=COMPLETED OR status=ARCHIVED OR isActive=false) → 0 rows for those entries even when times populated.
* **AC-9 [rule]** — Inactive drawerMedication (isActive=false) → drawerId=null, quantity=null on that row (still included in schedules array, not dropped entirely).
* **AC-10 [rule]** — Deterministic ordering: times lex ascending, then startDate, then scheduleId.

### Response / envelope
* **AC-11 [rule]** — Response wraps in project standard `{ status, statusCode, data }` envelope, data shape has top-level keys `patientId` (string) and `schedules` (array).

### Scope / safety
* **AC-12 [rule]** — No writes to prisma on this endpoint (Jest can verify by having mock repos with only find* methods; never a create/update/delete called).
* **AC-13 [rule]** — Grep `src/` (except prior heartbeat / face files which are unrelated) for identifiers: `openDrawer|closeDrawer|updateQuantity|markMed|notification|sensor|setTimeout.*schedule|cron` → 0 matches.
* **AC-14 [rule]** — No new Prisma schema changes; `npx prisma validate` output unchanged from baseline.

### Code quality
* **AC-15 [rubric 0-2, ≥1]** — Clean Architecture layers respected: (domain interface method + prisma impl + device use-case + controller method + route append + validator schema). Score 2 = all layers separated, no prisma code anywhere outside infrastructure; 1 = one leak; 0 = two+ leaks.
* **AC-16 [rubric 0-2, ≥1]** — Extension hooks and SECURITY LIMITATION comment mirroring existing face / heartbeat device endpoint pattern present in DevicesController. 2 = identical pattern, helper reused; 1 = present but duplicated; 0 = missing.

### Pipeline green
* **AC-17 [rule]** — `npx tsc --strict --noEmit` exit 0.
* **AC-18 [rule]** — `npm run build` exit 0.
* **AC-19 [rule]** — `npx jest tests/device-schedule-sync.spec.ts` 0 failures (7+ test cases: T1-T7).
* **AC-20 [rule]** — `npx jest --forceExit` total 0 failures.

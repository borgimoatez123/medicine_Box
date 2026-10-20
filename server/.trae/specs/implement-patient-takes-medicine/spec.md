# SPEC: Patient Takes Medicine Backend Integration

Last updated: 2026-09-23

## 1. Problem

The existing Smart Medicine Box backend has all the ingredient tables (Patient, Schedule, Medication, MedicineBox, Drawer, DrawerMedication) and an existing session history model `MedicationSession` with a five-value `MedicationSessionResult` enum (PATIENT_TAKEN / PATIENT_SKIPPED / FACE_RECOGNITION_FAILED / DISPENSING_FAILED / DEVICE_FAILURE). The user now needs a new device-facing endpoint `POST /api/devices/medication-events` which the Raspberry Pi calls after the complete physical workflow: scheduled time arrives → Pi runs face recognition → opens drawer → reads sensors → decides TAKEN or MISSED → sends report to backend.

The backend must be the database single source of truth: it validates every part of the relationship chain, decrements DrawerMedication.quantity inside a transaction, detects empty drawers (quantity=0), calculates persisted missingQuantity via the existing drawer capacity, records history, and critically must be IDEMPOTENT against HTTP retries / duplicate sensor events so the same dose is never subtracted twice. Database consistency is required; no partial writes.

The existing MedicationSession model does not yet support a MISSED distinct token, and the current unique indexes on MedicationSession are (scheduleId), (patientId), (medicationId), (drawerId) single-column plus compound (scheduleId, scheduledAt). These are insufficient for the idempotency-key required per user spec §21-§22. Hence an incremental prisma schema delta is needed (migration 0013): one enum token addition, one new optional column with compound unique index.

User forbids implementing: Heartbeat, Face Recognition, Schedule Synchronization, Drawer Refill Commands, Camera logic, Sensor hardware, Motor control. All forbidden scope is enforced via end-of-pipeline scope grep.

## 2. Users / Actors

1. **Raspberry Pi (device identified by MedicineBox.deviceId)** — makes exactly one HTTP call: POST the medication event result (TAKEN or MISSED). Has no direct DB access.
2. **Backend API / Database** — the source of truth for validation, transactional quantity, session history, refill state.
3. **Existing refill / user admin APIs (out of scope today)** — will consume DrawerMedication.quantity, DrawerMedication.missingQuantity and Drawer.status fields updated today, but we do not call them.

## 3. Goals (in scope)

G1. Implement device route `POST /api/devices/medication-events` inside existing devicesRouter.
G2. Strict request validation for the 6 required fields (deviceId, patientId, scheduleId, drawerId, status, quantityTaken) plus optional idempotencyKey via §21 server-occurrence auto-derivation.
G3. Validate full device → box → patient authorization boundary: shared userId ownership rule. 403 on mismatch.
G4. Validate schedule → medication → drawerMedication → drawer ownership chain, strictly. 409 on drawer mismatch / schedule-drawer mismatch / wrong medication.
G5. Validate expected quantity match: schedule.dosage (string) → leading integer must equal quantityTaken (partial doses rejected per spec §10).
G6. TAKEN workflow inside a prisma $transaction:
   - Read DrawerMedication record with row-lock-style pessimistic concurrency (selectForUpdate if available, fallback to WHERE quantity >= qty in UPDATE statement).
   - Assert current quantity >= quantityTaken → 409 `"Insufficient medication quantity"` if not.
   - Compute newQuantity = currentQuantity - quantityTaken.
   - Write ONE MedicationSession row (the event history) with scheduledAt = current server-occurrence derived timestamp, quantityBefore, quantityAfter after. Result enum = PATIENT_TAKEN.
   - UPDATE DrawerMedication.quantity = newQuantity.
   - UPDATE DrawerMedication.missingQuantity = max(0, drawerCapacity - newQuantity) using the existing DrawerMedication.missingQuantity Int column.
   - Update Drawer.status derived state per existing `drawerStatusPatch` semantics when newQuantity === 0 → EMPTY if operational. Drawer status transition is NOT a new status enum; reuse existing DrawerStatus.EMPTY/LOADED.
G7. MISSED workflow: create one MedicationSession row, result = MISSED (new enum token added today). quantityBefore = current, quantityAfter = current (unchanged), NO DrawerMedication update, NO drawer state change.
G8. Empty drawer detection per spec §18/§20: after TAKEN, if newQuantity === 0, set response refillRequired=true; if the drawer status can sync to EMPTY (per shouldSyncStatus helper in existing PrismaDrawerMedicationRepository) → drawer EMPTY.
G9. Duplicate protection / idempotency: every incoming TAKEN or MISSED event derives a server-side occurrence identifier composed of `(scheduleId + Africa/Tunis local calendar date YYYY-MM-DD + the nearest matching HH:mm time slot from Schedule.times)`. Add unique index MedicationSession(scheduleId, occurrenceDate, occurrenceTime) — if duplicate unique key violation inside transaction: catch, read the existing session row, return 200 envelope with duplicate:true + original response fields, NO quantity subtraction again.
G10. Existing shared error middleware + shared response envelope `{status, statusCode, data}` consistent with heartbeat / face / schedule endpoints.
G11. Jest coverage for user T1–T8 exactly: success taken, zero-quantity taken, missed medication, insufficient quantity, wrong patient 403, wrong drawer 409, wrong dosage reject, duplicate idempotent.
G12. Pipeline green: prisma validate, tsc strict, jest full suite 0 failures, build, forbidden-token grep (all required).
G13. Postman guide PATIENT-TAKES-MEDICATION-POSTMAN.txt at project root.

## 4. Non-goals (forbidden by user spec §32, no exceptions)

NG1. No new Face Recognition / Camera / Sensor / Motor / Drawer Open / Drawer Close logic anywhere in backend.
NG2. No new notification system / MQTT / WebSockets. Drawer refill command is out of scope; we only write the DrawerMedication.missingQuantity field and Drawer.status EMPTY (fields consumer can poll or use later).
NG3. No heartbeat / schedule-sync / face-verification modifications — today touches only medication-event logic.
NG4. Do not accept Raspberry Pi timestamps as database truth; scheduledAt / startedAt / completedAt on MedicationSession are all server-clock.
NG5. Do not modify existing MedicationSession primary key or any existing FK / indexes beyond adding occurrence fields + one compound unique index + MISSED enum.
NG6. Do not convert Tunisia schedule times to UTC — times are stored HH:mm strings Africa/Tunis (local wall-clock) unchanged; we use them only to find the occurrence slot for idempotency.
NG7. Do not change the schema for DrawerMedication.quantity — single source of truth. Do not add Medication.quantity decrements (Medication.quantity is the global patient medication cabinet stock; today's feature only touches per-drawer DrawerMedication.quantity per spec §11-§14).

## 5. Functional Requirements (FR)

### FR-1. New route signature
`POST /api/devices/medication-events` appended inside existing devicesRouter mounted at `/api/devices`.
No new router file.

### FR-2. Body shape strict zod schema (user §3/§4) + optional idempotencyKey fallback column
```
{
  deviceId:        string, trim, min 1, required
  patientId:       string, trim, min 1, required
  scheduleId:      string, trim, min 1, required
  drawerId:        string, trim, min 1, required
  status:          enum ('TAKEN' | 'MISSED'), required
  quantityTaken:   integer, > 0 when status=TAKEN, === 0 when MISSED
}
```
- For `MISSED`: validator rejects quantityTaken > 0. For `TAKEN`: rejects quantityTaken <= 0. Strict schema, extra fields 400.

### FR-3. Device + box + patient authorization chain (strict order)
1. Trim all string fields. If any empty → BadRequest.
2. Resolve effectiveDeviceId preference order same style as existing endpoints: trusted req.deviceId (future middleware) → body.deviceId. Overwrite body.deviceId if middleware set.
3. box = boxRepo.findByDeviceId(effectiveDeviceId). If null → 404 `"Device not found"`.
4. patient = patientRepo.findById(body.patientId). If null → 404 `"Patient not found"`.
5. If box.userId == null OR patient.userId !== box.userId → **403 `"Patient is not associated with this device"`**.

### FR-4. Schedule + medication + drawer chain
1. scheduleRepo.findById(scheduleId) → 404 `"Schedule not found"`.
2. Because there is no direct schedule.patientId FK in current schema, validate schedule belongs to patient through medication: load schedule medication via medication.patientId === patientId. If schedule.medication → medication.patientId !== patientId → 403 `"Schedule does not belong to this patient"`.
3. drawerRepo.findById(drawerId) → 404 `"Drawer not found"`.
4. Drawer must belong to THIS specific box: drawer.medicineBoxId === box.id → if fails 409 `"Drawer does not belong to this device's medicine box"` (or 403; per spec §26 Schedule/drawer mismatch is listed 409 so we use 409 for drawer/med/schedule graph, 403 for identity/patient ownership). The distinction aligns exactly with user §26 table.
5. DrawerMedication dm = dmRepo.findByDrawerId(drawerId). If not found or dm.medicationId !== schedule.medicationId → 409 `"Schedule medication does not match drawer medication"` (spec §9 critical check: cannot say drawer-2-taken when schedule → drawer-1).

### FR-5. Dosage match rule (§10 rejection)
- Extract integer `expectedDosage = parseInt(schedule.dosage, 10)`, require non-NaN integer > 0. If parse fails → 400 BadRequest `"Schedule dosage format not supported"` or similar.
- Required: expectedDosage === quantityTaken for status=TAKEN. If mismatch → 409 Conflict `"Quantity taken does not match scheduled dosage"` per §10 explicit rule. No partial accepts.

### FR-6. Quantity available check (§12)
- Current `quantity = dm.quantity ?? 0`.
- If status=TAKEN AND current < quantityTaken → 409 Conflict `"Insufficient medication quantity"`. No update, no event created.

### FR-7. Idempotency occurrence identifier (§21/§22)
Server computes. No client idempotencyKey required. Steps:
1. Server now in Africa/Tunis timezone = convert `new Date()` to Africa/Tunis wall-clock. Use Intl if platform; fallback: derive by UTC offset for Tunisia (fixed +1h standard +2h DST — docs assumption explicit A4).
2. Find `slotTime: string HH:mm` = the HH:mm entry in Schedule.times array that is CLOSEST to current wall-clock time (within ±6 hours). If no Schedule.times entry matches within 6h window → use the FIRST entry HH:mm. If Schedule.times empty/null → use "00:00" sentinel (same as timesPerDay fallback in schedule-sync).
3. `occurrenceDate: YYYY-MM-DD` in Tunis local calendar.
4. occurrenceDate + occurrenceTime(slot) + scheduleId uniquely identify one scheduled-dose event. Back this with a Prisma compound @@unique on MedicationSession (see FR-10 schema delta section).

### FR-8. Transaction body (§13 atomic)
Wrap everything after the pre-validation chain in one single `prisma.$transaction(async (tx) => { ... })` with isolation level as default (Serializable if available via Prisma options). Inside:

For status === 'TAKEN':
1. Pessimistic read of DM row via tx.drawerMedication.findUnique with dm id; if stale check quantity >= quantityTaken.
2. Build newQuantity = quantity - quantityTaken. Compute drawerCapacity from box.drawerCapacity; compute missingQuantity = Math.max(0, drawerCapacity - newQuantity).
3. Try create MedicationSession row with: scheduleId, patientId, medicationId = dm.medicationId, drawerId, scheduledAt = server-date + slotTime combined (ISO timestamp), startedAt = server now, completedAt = server now, quantityBefore = quantity, quantityAfter = newQuantity, result = 'PATIENT_TAKEN'. Populate the new columns occurrenceDate + occurrenceTime.
   - If duplicate @@unique violation throw → catch at controller/use-case and enter idempotent-duplicate path.
4. UPDATE drawerMedication SET quantity = newQuantity, missingQuantity = missingQuantity WHERE id = dm.id AND quantity == quantity (optimistic concurrency check inside UPDATE where-clause; if rows affected 0 rollback transaction → throw Conflict "concurrent update" or retry once).
5. If newQuantity === 0 → sync Drawer.status to EMPTY inside the same tx via existing drawerStatusPatch/shouldSyncStatus helper if drawer is operational status (LOADED). Do not touch ERROR/LOCKED.

For status === 'MISSED':
1. Create one MedicationSession identical fields except result = 'MISSED', quantityBefore = currentQuantity, quantityAfter = currentQuantity, startedAt = null? or startedAt = now completedAt = now consistent with existing.
2. 0 DrawerMedication updates. 0 Drawer.status updates. DrawerMedication.missingQuantity unchanged.

On unique constraint violation during session create → return `{ duplicate: true, existingSession }` from tx, shape 200 OK response with duplicate flag set and no quantity re-subtracted.

### FR-9. Response shape (§23/§24/§25) + envelope
Inside standard envelope:
```
data: {
  status: 'TAKEN' | 'MISSED',
  patientId: string,
  scheduleId: string,
  drawerId: string,
  quantityTaken: number,
  remainingQuantity: number,      // for TAKEN newQuantity; for MISSED original quantity
  refillRequired: boolean,        // TAKEN ? newQuantity===0 : false
  missingQuantity?: number,       // only when refillRequired=true, or always for TAKEN (spec §24 example shows it when empty — we output always if status TAKEN for convenience, else null for MISSED)
  duplicate?: boolean,            // present and true on idempotent retry.
  message?: 'Medication event already processed' when duplicate
}
```
For MISSED, response simplified to §25 example minus refill fields.

### FR-10. Prisma schema changes (1 enum token + 2 columns + 1 unique index, migration 0013)
In prisma/schema.prisma, edit only:

1. `enum MedicationSessionResult` append new entry `MISSED`:
```
enum MedicationSessionResult {
  PATIENT_TAKEN
  PATIENT_SKIPPED
  FACE_RECOGNITION_FAILED
  DISPENSING_FAILED
  DEVICE_FAILURE
  MISSED
}
```

2. `model MedicationSession` add two columns:
```
  occurrenceDate        DateTime?  // date-only; set to Africa/Tunis day at midnight.
  occurrenceTime        String?    // HH:mm (exact slot used)
```
and add compound unique index:
```
  @@unique([scheduleId, occurrenceDate, occurrenceTime], map: "MedicationSession_schedule_occurrence_unique")
```
Do not remove existing indexes. Keep model's existing @@index lines untouched.

Existing FK columns unchanged. All default nullable; existing rows null (no idempotency enforcement retroactively).

### FR-11. Repository method additions (domain interfaces + prisma impl)
- IMedicationSessionRepository: add method `createInsideTransaction(tx: PrismaTransactionLike, data: CreateMedicationSessionData & {occurrenceDate?: Date, occurrenceTime?: string})` or equivalent; if too invasive, instead implement the entire tx body at application use-case `ProcessPatientMedicationEvent` with direct prisma client import (allowed since it's a transaction boundary — but prefer keeping transaction logic in use-case, with per-operation find/create helpers using `tx` closures). Actually cleaner implementation: implement the entire prisma.$transaction() inside a new Prisma repo method `processDeviceMedicationEventTransaction(...)` that the use-case calls with validated data; use-case keeps business-rule throws and input validation only. This keeps prisma imports inside infrastructure layer only (clean arch NR-4).
- IDrawerMedicationRepository: if not available add `findByDrawerId(id)` → returns existing impl already has it. Add `findById(id)` if missing today; we'll use it.
- IDrawerRepository: add `findByIdAndMedicineBoxId(drawerId, boxId)` OR reuse existing findById and then check in use-case — choose simplest.
- IScheduleRepository: existing findById already returns Schedule. To validate the schedule's medication's patient we need ONE prisma query `schedule with include: { medication: true }` → add `findByIdWithMedication(id)` domain method or simply use existing schedule.medicationId → medicationRepo.findById to validate. Medication.findById existing; then compare medication.patientId against patientId. 2 queries total, acceptable for a POST endpoint.

## 6. Non-functional Requirements

NR1. Clean architecture layers: domain interface methods defined in domain, Prisma impls in infrastructure, use case in application (device folder), validator/presentation/routes in presentation.
NR2. prisma.$transaction single place; no multiple BEGIN/COMMIT.
NR3. TS strict mode 0 errors.
NR4. prisma validate 0 errors.
NR5. Tests jest.fn mocks only; NOT real prisma. Mock transaction call with jest.fn() returning shaped session + quantities.
NR6. Forbidden-scope grep must produce 0 matches in src/tests excluding existing files.
NR7. Build success.
NR8. Pipeline (§Task 9) serially: prisma → tsc → new-test → all-jest → build → grep.

## 7. Constraints / Dependencies / Assumptions

C1. Prisma Postgres Supabase pooler compatible. Migration uses idempotent SQL.
C2. No device auth enforcement this iteration; documented extension hook; pattern identical to heartbeat/face/schedule.
C3. Drawer capacity integer sourced from `MedicineBox.drawerCapacity` (already existing).
C4. Timezone handling for Tunisia: assume server `Intl.DateTimeFormat('en-US', {timeZone:'Africa/Tunis'})` available (Node 14+). OccurrenceDate calculated from Africa/Tunis local calendar; NOT system local calendar of host machine. A3 doc explicitly.
C5. Drawer status only transitions EMPTY/LOADED when drawer in operational set. Reuse existing `shouldSyncStatus(currentStatus)` + `drawerStatusPatch` helper functions from PrismaDrawerMedicationRepository.ts; export if private today.
C6. Existing MedicationSessionResult enum rule: token `MISSED` added; no removal.
C7. Schedule.dosage parse rule parseInt leading-integer only, or if dosage is pure integer string, direct equality — same for both.
C8. Duplicate detection uses unique index inside transaction; guarantees correctness even for concurrent retries.

## 8. Open Questions resolved by default (documented explicitly by Spec):

OQ-1. Event model: Existing MedicationSession + add MISSED token to enum. Approved minimal change per C6.
OQ-2. missingQuantity formula: max(0, MedicineBox.drawerCapacity - DrawerMedication.newQuantity) persisted, matches AssignMedicationToDrawer semantics.
OQ-3. Idempotency: server-side scheduleId + occurrenceDate(Africa/Tunis YYYY-MM-DD) + occurrenceTime(HH:mm slot) + compound unique index. Retry-safe. Unique index.
OQ-4. Dosage match: parseInt(schedule.dosage) leading integer must === quantityTaken strict; if dosage cannot parse, BadRequest. No partials accepted per §10.

## 9. Acceptance Criteria

AC-1 [rule] — Route POST /api/devices/medication-events present in devices.routes.ts.
AC-2 [rule] — Validator schema: required 6 fields, status enum TAKEN/MISSED, qty TAKEN positive int, MISSED zero, strict extras 400.
AC-3 [rule] — Device → box → patient ownership rule: box/patient userId match, else 403.
AC-4 [rule] — Schedule/drawer/medication chain validation, mismatch drawer vs schedule → 409.
AC-5 [rule] — Status=TAKEN, qty OK → creates MedicationSession PATIENT_TAKEN, decrements quantity, correct remainingQuantity.
AC-6 [rule] — Quantity becomes 0 → refillRequired true, missingQuantity = drawerCapacity - 0, Drawer EMPTY if operational.
AC-7 [rule] — Status MISSED: session row created with result MISSED, NO drawer quantity update, NO drawer state change.
AC-8 [rule] — Insufficient qty → 409, zero writes.
AC-9 [rule] — Wrong patient → 403, no writes. Wrong drawer → 409, no writes. Wrong dosage mismatch → 409, no writes.
AC-10 [rule] — Duplicate within same occurrence: second request returns duplicate:true, quantity unchanged.
AC-11 [rule] — Schema delta: MedicationSessionResult.MISSED token added, occurrenceDate/occurrenceTime columns + unique index present.
AC-12 [rule] — Prisma migration 0013 deploys on Supabase pooler (idempotent SQL, DO $$ for enum), prisma generate + validate green.
AC-13 [rule] — Envelope standard.
AC-14 [rubric 0-2, pass ≥1] Clean architecture layers respected.
AC-15 [rubric 0-2, pass ≥1] Transaction atomicity with idempotent duplicate path.
AC-16 [rule] — Scope-grep forbidden tokens 0 matches.
AC-17 [rule] — TS strict, build, prisma, jest all exit 0.
AC-18 [rule] — Postman txt document provided at root.

# SPEC: Raspberry Pi Face Recognition Backend Integration

Last updated: 2026-09-23

## 1. Problem

The Smart Medicine Box hardware already contains a Raspberry Pi with USB camera and runs a local face recognition model (camera capture, face detection, embedding comparison, MATCH / NO MATCH decision). That comparison requires a reference patient image, and once it produces a verified true / verified false boolean, the backend must:
  * serve the reference image for the correct patient / device pair,
  * refuse images to devices that are not associated with that patient,
  * record the verification outcome (success or failure) for auditability,
  * allow downstream medication workflows to continue on `verified=true` without this backend opening any drawer or touching quantities.

Existing code has no device-facing reference-face endpoint or verification-event table yet, and the only existing "FACE_RECOGNITION_FAILED" token lives inside `MedicationSessionResult` enum attached to a full session (scheduleId / medicationId / drawerId) — a scope too heavy for a standalone verification record outside an active session window.

## 2. Users / Actors

* **Raspberry Pi device** — calls two new `/api/devices/*` endpoints over HTTPS.
  Actor identity: a box identified by `deviceId` (same field as heartbeat `MedicineBox.deviceId`).
* **Backend** — responds, validates device↔patient association, logs events. Never does any face comparison locally.
* **Downstream medication workflow features** — consumers of the latest verification state. They consult recorded events / session state; this backend does not directly open drawers or decrement pills.

## 3. Goals (Feature scope)

In scope for this SPEC (and nothing more):

G1. Provide device-facing endpoint to fetch a patient's existing reference face image (avatarUrl) only after:
  — patient exists,
  — patient actually has a reference avatarUrl,
  — patient belongs to the same user that owns the requesting MedicineBox device.
G2. Provide device-facing endpoint to record the Pi's verification verdict with minimal structured metadata: deviceId, patientId, verified bool, optional similarity, server-generated timestamp.
G3. Persist both verification events durably in a new smallest-possible table, with no reliance on an active MedicationSession.
G4. Implement strict error handling for 400/403/404 and DB failures, reusing existing error middleware.
G5. Implement jest coverage for each of the 6 user-listed scenarios (§Tests T1-T6).
G6. Respect the existing Clean Architecture layer boundaries + response envelope `{status, statusCode, data}` that all other controllers already produce.
G7. Keep strict separation — no Pi camera control / no InsightFace / no drawer open inside backend.

## 4. Non-Goals (Explicitly out of scope, even if adjacent)

NG1. Heartbeat endpoint, offline monitor, schedule sync, drawer control, refill, sensor APIs, notifications — all forbidden.
NG2. Any face recognition or face embedding computation on the backend.
NG3. Any avatar upload/delete/encoding logic change. The existing UploadPatientAvatar / Supabase storage `patient-avatars` bucket stays untouched beyond reading the URL.
NG4. Any drawer open, drawer close, medication quantity update, medication mark-as-taken, schedule update, new schedule creation, notification send.
NG5. Any new storage provider. Avatar URL is reused verbatim from `Patient.avatarUrl` already stored on the DB row.
NG6. Device authentication enforcement via new middleware at this iteration. Per user §18, implement documented compatibility hooks only, do not invent credentials or hardcode secrets.

## 5. Functional Requirements (FR)

### FR-1. Endpoint A — GET patient face reference
Route: `GET /api/devices/patients/:patientId/face-reference`

Processing order in the use-case / controller:
  a) Parse and validate `patientId` route param: required, string, trimmed, min length 1. Fail with 400 `BadRequestError`.
  b) Resolve requesting device identity. Current architecture has no device-header middleware, so as a documented placeholder the controller / use-case MUST accept an optional `deviceId` passed in body / query / header-compatible location.
     * For consistency with heartbeat (which already uses POST body deviceId), GET accepts deviceId via query param `?deviceId=PI-DEV-001`; this is named `requestingDeviceId` internally.
     * If / when middleware adds a trusted `request.deviceId`, the use-case MUST prefer that and ignore any user-supplied deviceId.
  c) Load `Patient` by `patientId`. If null → 404 `NotFoundError` message `"Patient not found"`.
  d) Load `MedicineBox` by `requestingDeviceId` via `findByDeviceId`. If null → 404 `NotFoundError` message `"Device not found"`.
  e) Enforce `device ↔ patient` relationship. Since there is NO direct foreign key between `MedicineBox` and `Patient`, the shared `userId` ownership is the authoritative association (same as admin ActivateMedicineBox's pattern): `patient.userId === medicineBox.userId`, and `medicineBox.userId` may NOT be null (unassigned boxes are not allowed to pull face images). If not equal → 403 `ForbiddenError` message `"Patient is not associated with this device"`.
  f) If `patient.avatarUrl` is null / empty string → 404 `NotFoundError` message `"Patient face reference not found"`. This is explicitly the user's §20 case.
  g) Return payload `{ patientId, faceReference: { url: <avatarUrl>, updatedAt: patient.updatedAt } }`. Use existing avatar URL exactly as stored; do not transform to base64.

### FR-2. Endpoint B — POST receive face verification result
Route: `POST /api/devices/face-verification`

Body shape (strict zod):
```
  deviceId   string required trimmed min 1
  patientId  string required trimmed min 1
  verified   boolean required
  similarity number? optional (if present 0.0 ≤ value ≤ 1.0; optional field only stored, never used for recognition logic)
```

Processing order:
  a) zod safeParse → 400 `BadRequestError` on any invalid shape, message through existing `formatZodErrors` pattern.
  b) Resolve verified device identity same rules as FR-1: prefer future `request.deviceId` from middleware when present, and otherwise fall back to body `deviceId` with a documented extension hook.
  c) Load box by deviceId → 404 `"Device not found"`.
  d) Load patient by patientId → 404 `"Patient not found"`.
  e) Relationship check identical to FR-1 step e: `patient.userId === box.userId` AND `box.userId` is non-null. If fail → 403 `"Patient is not associated with this device"`.
  f) Persist ONE row of verification event into the new minimal schema addition (§Constraints C1 event table). Populate: `deviceId`, `patientId`, `verified: boolean`, `similarity: number | null` (rounded / stored as DB float, if provided), `timestamp: new Date()` backend-clock-only.
  g) Response: 200 OK envelope containing `{ deviceId, patientId, verified, similarity? , message }`. Messages:
     * verified=true → `"Patient verified successfully"`
     * verified=false → `"Face verification failed"`
  h) verified=false is NOT a server error. Status code 200, never 500, never 400.

### FR-3. Medication Session bridge state (non-regression, defensive)
The existing enum `MedicationSessionResult` already contains `FACE_RECOGNITION_FAILED`. This SPEC does NOT modify that enum, does NOT delete it, does NOT add new cases to it. That enum stays untouched. The downstream medication workflow may at a later task consume FaceVerificationEvent records; this SPEC only guarantees the events exist and are searchable by deviceId+patientId+time. No writes to MedicationSession, no writes to Drawer, no writes to DrawerMedication, no writes to Schedule, no writes to Medication quantity.

## 6. Non-Functional Requirements (NFR)

NFR1. Strict separation — Backend MUST NOT import / depend on `insightface`, `face-engine`, `opencv`, `@vladmandic/face-api` or any ML / CV package. If any were accidentally in package.json this iteration would remove them before ship. Confirmation: package.json inspected; no such packages, this iteration adds 0 new dependencies.
NFR2. No schema regressions — Prisma validate passes, Postgres migration idempotent using `DO $$` pattern for enum creation + `ADD COLUMN IF NOT EXISTS` / `CREATE TABLE IF NOT EXISTS` style. Existing migrations 0001–0011 must never be rewritten. New migration number: 0012.
NFR3. TypeScript strict — `npx tsc --strict --noEmit` exit 0.
NFR4. Jest green — `npx jest --forceExit` exit 0; new tests total exactly 6 matching user §21 T1–T6; no existing 489 tests may regress.
NFR5. Idempotency — repeated POST face-verification with the same payload correctly writes a NEW event row each time (not an upsert). Each Pi decision is a distinct auditable event.
NFR6. Security — documented current auth limitation per §18; the 2 endpoints have a clear extension hook pattern so a future middleware can bind `request.deviceId` without modifying controllers; controller-level comment block and a commented validator stub. Never invent API keys / shared secrets / hardcoded tokens.
NFR7. Build — `npm run build` (tsc compile) exit 0.
NFR8. Scope grep — src + tests directory grep `DispensingEvent|reportDHT22|Drawer.*(open|close)|QuantityReading|heartbeat` → no new introductions of forbidden code paths outside their existing files (heartbeat existing files stay untouched; heartbeat routes remain unchanged).

## 7. Constraints & Dependencies

C1. Existing schema state inspected: Patient uses `avatarUrl String?` backed by Supabase Storage bucket `patient-avatars` (public bucket, exact name preserved from prior tasks). This SPEC reuses it verbatim. New storage architecture = forbidden.
C2. Existing direct box↔patient relationship: none on schema. Relationship is inferred transitively through User (`MedicineBox.userId === Patient.userId`, both User FKs non-null where applicable). This is the authoritative association rule, per ActivateMedicineBox's existing convention. Document that as an explicit assumption.
C3. Event / log models — No dedicated "event" or "audit" model exists in current Prisma schema. The only event-adjacent entity is MedicationSession but it requires scheduleId + drawerId + medicationId and is scoped to an active medication taking moment; unsuitable for standalone verification logging. Therefore a single minimal new table `FaceVerificationEvent` is the smallest schema addition. Columns: id (uuid PK), deviceId String FK → MedicineBox.deviceId? (deviceId indexed, no FK cascade set ON DELETE SET NULL to allow box deletion without log loss), patientId String FK → Patient.id ON DELETE CASCADE, verified Boolean NOT NULL, similarity Decimal? (or Float?), timestamp DateTime @default(now()). Indexes: [deviceId, timestamp desc], [patientId, timestamp desc].
C4. Device authentication — current backend does not enforce a header chain; documented only. Controller top-of-file comment: "SECURITY LIMITATION: At this iteration, identity of the requesting Raspberry Pi is established from the payload deviceId. Do not rely on this for production multi-tenant security. Enable the future device middleware and source trusted deviceId from middleware locals; this controller is already coded to prefer that path via a single accessor."
C5. Prisma `MedicationSessionResult` enum with `FACE_RECOGNITION_FAILED` token — read-only. Keep; never edit.
C6. Response envelope — reuse existing format: `{ status: 'success'|'fail'|'error', statusCode: <number>, data: { ... } }` consistent with MedicineBoxController and DevicesController.heartbeat pattern. (This follows user's §6 clause: follow existing format if one exists.)
C7. New routes: mounted alongside `/api/devices/heartbeat` on the existing `devicesRouter` — do NOT create a second top-level app.use for a new device prefix; keep three device endpoints together for consistency.

## 8. Assumptions

A1. Patient reference face image == Patient.avatarUrl. The existing UploadPatientAvatar already writes a public Supabase URL there; no additional column like `faceReferenceUrl` is introduced or needed. This avoids data duplication.
A2. The user-facing 404 distinction between "patient missing entirely" and "patient present but no avatar" is a concrete acceptance item (user §20 explicitly lists it), so avatarUrl=null case returns its own 404 message different from patient missing.
A3. The existing `deviceId` from the body / query on device routes is trusted for now with documented limitation. This mirrors the heartbeat endpoint's posture (approved in prior spec).
A4. No similarity threshold is enforced on the backend per §8. Similarity is nullable in storage, optional in requests, never used to override the Pi's explicit `verified` boolean.
A5. User expects both GET face-reference and POST face-verification to coexist with the heartbeat endpoint on `/api/devices/*` — this is correct and routes are combined.

## 9. Open Questions (OQ) — Explicit decisions needed before implementation

Each OQ proposes a recommended answer (R) aligned with existing patterns; if user silent on approve, R becomes plan of record.

  OQ-1. Where does the GET face-reference endpoint read the requesting deviceId?
        Options: (A) `?deviceId=PI-DEV-001` query param on the GET; (B) only from body (unusual for GET); (C) forced from headers `X-Device-Id` now.
        R: A — matches the POST body pattern, no middleware invention this iteration, and the code path single-sources `requestingDeviceId` accessor so middleware can override later seamlessly. User §18 explicitly says document limitation if auth not present → query-param + documented single source accessor.

  OQ-2. The association rule `patient.userId === medicineBox.userId` and box must be assigned (userId non-null). Is that the only association, or do we also / instead check that the patient has at least one Medication stored in drawers of that box?
        Options: (A) shared userId only (consistent with ActivateMedicineBox), (B) also require the patient to have a Medication that links through DrawerMedication → Drawer → this MedicineBox.
        R: A only because many admins upload the avatar before drawers are configured. Adding B would cause valid test cases where face-reference wrongly 403s because drawer layout is TBD. Keep strict shared-userid rule + box assigned.

  OQ-3. Similarity storage type in Postgres/Prisma: Decimal or Float?
        Options: (A) `similarity Float?` (simple, matches "0.82" example), (B) `similarity Decimal(5,4)?` (precision-preserving).
        R: A Float? because similarity is audit metadata and 0.01 precision is amply sufficient; example in request is 0.82 decimal representation.

  OQ-4. FaceVerificationEvent.deviceId foreign key: OnDelete CASCADE, SET NULL, or NO FK? 
        Options: (A) NO FK (just indexed plain string for logs), (B) FK + SET NULL, (C) FK + CASCADE deletion.
        R: B FK MedicineBox(deviceId) ON DELETE SET NULL + Patient.id FK ON DELETE CASCADE. Preserves audit if a box is ever decommissioned; deletes logs if patient is GDPR-removed.

  OQ-5. Should route file keep the name devices.routes.ts and append 2 new routes inside (or rename)?
        R: Keep existing devices.routes.ts / DevicesController.ts and append. One controller for all device-facing endpoints matches architecture. Heartbeat routes untouched (only added alongside).

## 10. Acceptance Criteria (AC)

Every AC below is typed explicitly: `rule` means an objectively verifiable binary condition. `rubric` means evaluative 0-2 scale with threshold 2.

### rule AC-1 (Route A exists)
Route mount chain exists: `GET /api/devices/patients/:patientId/face-reference` inside existing devicesRouter. Evidence: route file contents + app.ts mount (unchanged /api/devices prefix).

### rule AC-2 (Route A patientId invalid → 400)
`GET /api/devices/patients/%20%20/face-reference?deviceId=PI-DEV-001` and `GET /api/devices/patients//face-reference?deviceId=PI-DEV-001` produce 400 response. Evidence: jest Test T6-adjacent and controller validator.

### rule AC-3 (Route A patient missing → 404 "Patient not found")
404 + message exact string. Evidence: jest Test 2 passes.

### rule AC-4 (Route A device missing → 404 "Device not found")
404 + exact message. Evidence: jest Test 2 variant covers this.

### rule AC-5 (Route A box unassigned (userId=null) → 403 relationship invalid)
Not just userId mismatch; unassigned boxes are 403 too. Evidence: jest Test 3 covers 403 path.

### rule AC-6 (Route A patient.userId ≠ box.userId → 403 "Patient is not associated with this device")
Exact 403 message. Evidence: jest Test 3 passes.

### rule AC-7 (Route A avatarUrl null → 404 "Patient face reference not found")
Exact 404 message distinct from "Patient not found". Evidence: test helper scenario in T2 suite.

### rule AC-8 (Route A happy path → 200 with url + updatedAt)
avatarUrl from patient row returned verbatim as faceReference.url. Evidence: jest Test 1 passes.

### rule AC-9 (Route B exists with 4 schema fields)
`POST /api/devices/face-verification` accepts body schema `{deviceId,patientId,verified, similarity?}`. zod strict; extra fields → 400. Evidence: validator + Test 6.

### rule AC-10 (Route B unknown deviceId → 404 "Device not found")
Evidence: test scenario within suite.

### rule AC-11 (Route B unknown patientId → 404 "Patient not found")
Evidence: test scenario within suite.

### rule AC-12 (Route B relationship invalid → 403)
Shared userId rule, box assigned. Evidence: covered by tests.

### rule AC-13 (Route B verified=true → 200 success message; new event row written with verified TRUE)
Exact 200 message. Event store count increments. Evidence: jest Test 4.

### rule AC-14 (Route B verified=false → 200 "Face verification failed"; new event row written with verified FALSE)
StatusCode remains 200, never 400/500. Event count increments. Evidence: jest Test 5.

### rule AC-15 (Similarity nullable; never overrides verified)
If provided, stored. If not provided, the recorded event.similarity == null. If similarity=0.05 but verified=true, outcome is STILL success. The backend never compares. Evidence: two scenarios in jest.

### rule AC-16 (Schema + 0012 migration green)
Prisma validate exit 0. `prisma migrate deploy` exit 0 against Supabase pooler (or idempotent if already run). Prisma Client regenerated. Only 1 new table `FaceVerificationEvent` and no other model/field changes.

### rule AC-17 (Pipeline)
  (a) `npx prisma validate` exit 0
  (b) `npx tsc --strict --noEmit` exit 0
  (c) `npx jest --forceExit` exit 0 — 12+ suites, 495+ tests (489 base + 6 new)
  (d) `npm run build` exit 0
  (e) `src`+`tests` global regex of scope-forbidden identifiers → 0 new matches.

### rule AC-18 (Response envelope consistency)
All success/error bodies from both new endpoints use the same 3-key shape as heartbeat: `{status, statusCode, data}`. Evidence: controller matches DevicesController.heartbeat.

### rubric AC-19 (Architecture fidelity — 0-2, threshold ≥ 2)
- 2: Strictly layered — new entity in domain, new repository interface methods in IPatientRepository/IMedicineBoxRepository + new FaceVerification repo, Prisma implementations, use-cases under application/use-cases/device/, validators + controller + routes unchanged file hierarchy; 0 new architectural abstractions.
- 1: Works but leaks DB concerns across a layer boundary or file placed in wrong folder.
- 0: Everything dumped in routes / ad-hoc Prisma calls in controller.

### rubric AC-20 (Security posture documentation — 0-2, threshold ≥ 2)
- 2: Controller SECURITY LIMITATION comment block verbatim, validator file contains commented future `deviceHeadersSchema` stub for X-Device-Id / X-Device-Token, use-case has single source `resolveRequestingDeviceId()` helper instead of sprinkling req.body / req.query reads directly.
- 1: Only 1/3 of these documented extensibility hooks present.
- 0: No documented hooks and deviceId assumed safe.

## 11. Final Integrity checks (Post-Implement Review gate)
The independent review pass will verify each AC using the Evidence sources above, and separately re-run pipeline items AC-17 a–e to ensure environment-agnostic green. Any deviation from §23 forbidden list is a FAIL Review result. Any new direct schema mutation beyond 0012 or modifying migrations 0001–0011 = FAIL Review. Any test regression relative to baseline 489 = FAIL Review.

# TASKS: Raspberry Pi Face Recognition Backend Integration

Plan state 5 phases: Specify ✔ → Plan █ → Approve → Implement → Review.
Mapped 1:1 from spec.md Acceptance Criteria. Parenthesis references.
Each task is atomic; only one in_progress at a time.

---

## Task 1: Prisma Schema addition — FaceVerificationEvent model + migration 0012

**Objective**: Implement schema delta + deploy migration.
**Status**: pending
**Priority**: high
**Maps to AC**: rule AC-16
**Dependencies**: none

### Work Items
1. Edit prisma/schema.prisma:
   - After MedicationSessionResult enum — NO EDIT (per C5) — STAYS UNTOUCHED.
   - Add enum `FaceVerificationResult { SUCCESS FAILED }` (if needed for readable event results? NO — actually use boolean `verified`. Keep no enum; we already have MedicationSessionResult untouched. Just minimal model only add model block below.
     Actually Plan: add only model FaceVerificationEvent:
   ```prisma
   model FaceVerificationEvent {
     id         String   @id @default(uuid())
     deviceId   String?
     patientId  String
     verified Boolean
     similarity Float?
     timestamp DateTime @default(now())
     medicineBox MedicineBox? @relation(fields: [deviceId], references: [deviceId], onDelete: SetNull, map: "FK_face_verif_device")
     patient    Patient       @relation(fields: [patientId], references: [id], onDelete: Cascade)
     @@index([deviceId, timestamp(sort: Desc)])
     @@index([patientId, timestamp(sort: Desc)])
     @@map("FaceVerificationEvent")
   }
   ```
   (Note: Relation fields deviceId indexed, timestamp desc sort order syntax prisma 5 supports `@@index([deviceId, timestamp(sort: Desc)`. Add both indexes.
2. `npx prisma format` → exit 0.
3. `npx prisma validate` → exit 0.
4. Create migration `prisma/migrations/0012_add_face_verification_event/migration.sql using DO $$ enum-less idempotent:
   a) CREATE TABLE IF NOT EXISTS, with FKs manually in SQL with ON DELETE SET NULL for deviceId FK and ON DELETE CASCADE patientId FK; indexes. Actually:
   b) In SQL: deviceId FK references MedicineBox(deviceId) DEFERRABLE INITIALLY DEFERRED if possible; patientId FK references Patient(id) ON DELETE CASCADE. If postgres friendly.
   c) Idempotent CREATE INDEX IF NOT EXISTS idx_...deviceId_timestamp desc.
5. `npx prisma migrate deploy` exit 0 (with Supabase pooler compatible; retry once P1001).
6. `npx prisma generate`.

### Local Test Requirements
| ID  | Type | Statement |
|---|---|---|
| T1-1 | rule | `npx prisma validate` exit 0 |
| T1-2 | rule | Migration 0012 deploys exit 0 |
| T1-3 | rule | Prisma Client generates; type `Prisma.FaceVerificationEventCreateInput` exists (compile later ts strict) |

### Completion Evidence
(none until done)

---

## Task 2: Domain Layer — FaceVerificationEvent entity + repository interfaces

**Objective**: Add entity, add IFaceVerificationEvent + extend IPatientRepo if needed or MedicineBox helper method.
**Status**: pending
**Priority**: high
**Maps to AC**: AC-19 (architecture fidelity)
**Depends on**: Task 1

### Work Items
1. New src/domain/entities/FaceVerificationEvent.ts
   ```
   export interface FaceVerificationEvent {
     id: string;
     deviceId: string | null;
     patientId: string;
     verified: boolean;
     similarity: number | null;
     timestamp: Date;
   }
   ```
2. New src/domain/repositories/IFaceVerificationEventRepository.ts interface:
   ```
   export type CreateFaceVerificationEventData = Omit<FaceVerificationEvent, 'id' | 'timestamp'> & { timestamp?: Date };
   export interface IFaceVerificationEventRepository {
     create(data: CreateFaceVerificationEventData): Promise<FaceVerificationEvent>;
     countByPatientId(patientId: string): Promise<number>;
   }
   ```
   (count used for tests asserts; also list methods unnecessary per scope).

### Test Requirements
| ID  | Type | Statement |
|---|---|---|
| T2-1 | rule | TS strict: entities interfaces satisfy, no new compilation errors (pipeline later) |

### Completion Evidence
(none until done)

---

## Task 3: Infrastructure Layer — Prisma FaceVerificationEventRepository impl + Prisma MedicineBox:: toDomain untouched
**Status**: pending
**Priority**: high
**Depends on**: Task 2
**Maps**: AC-19 architecture 2/2 rubric evidence.

Work items:
1. New src/infrastructure/database/prisma/repositories/PrismaFaceVerificationEventRepository.ts implementing IFaceVerificationEventRepository. Contains create and countByPatientId (count({where: {patientId}}).
2. Edit PrismaMedicineBoxRepository. No edit! MedicineBox is untouched. Need add methods are in Task 4 use-cases.
Actually: NO edit PrismaMedicineBox / IPatientRepo interfaces needed. FindById in existing:
Wait — FR-1 needs find patient avatarUrl + findByDeviceId medicineBox (already exist).
— FR-1: Use-case new methods exist findById (IPatientRepo.findById + IMedicineBoxRepo.findByDeviceId) — yes already exist. So Task 3 work is only new PrismaFaceVerificationEventRepository.

### Test Requirements
| ID  | Type | Statement |
|---|---|---|
| T3-1 | rule | Repository exports Prisma create with prisma.faceVerificationEvent.create + count. |

### Completion Evidence

---

## Task 4: Application Layer — two new use cases + resolveRequestingDeviceId helper
**Status**: pending
**Priority**: high
**Depends on**: Task 3
**Maps to AC**: AC-1 through AC-15, AC-20 (single source accessor)

### Work Items:
1. Application use case 1: src/application/use-cases/device/GetPatientFaceReference.ts — class GetPatientFaceReference
   Constructor args: (patientRepo: IPatientRepository, medicineBoxRepo: IMedicineBoxRepository).
   Method `execute(patientId: string, requestingDeviceId: string)` — return object:
   Step A: patientId validation trim!== '' else BadRequestError 'patientId is required'
   Step B: requestingDeviceId validation trim!== '' else BadRequestError 'deviceId is required' (per AC-2)
   Step C: patient = patientRepo.findById(patientId). null → NotFound 'Patient not found'
   Step D: box = medicineBoxRepo.findByDeviceId(requestingDeviceId). null → NotFound 'Device not found'
   Step E: if box.userId == null OR patient.userId !== box.userId → ForbiddenError 'Patient is not associated with this device'
   Step F: if !patient.avatarUrl → NotFound 'Patient face reference not found'.
   Step G: return { patientId, faceReference: { url: patient.avatarUrl, updatedAt: patient.updatedAt } }.

2. Application use case 2: src/application/use-cases/device/RecordFaceVerification.ts.
   Constructor args (patientRepo, medicineBoxRepo, faceVerificationRepo: IFaceVerificationEventRepository).
   Method `execute({ deviceId, patientId, verified, similarity? }).
   Step A: Validate non-empty strings + bool checked at controller.
   Step B: Find device = medicineBoxRepo.findByDeviceId(deviceId) → null NotFound 'Device not found'.
   Step C: Find patient = patientRepo.findById(patientId) → null NotFound 'Patient not found'.
   Step D: box.userId non-null AND patient.userId equals box.userId. If not → Forbidden.
   Step E: record event. similarity if provided (0.0 <= value ?. Actually optional. Backend NEVER overrides; boolean verified only stores the Pi verdict.
   Step F: Return the persisted FaceVerificationEvent.

3. Shared helper `resolveRequestingDeviceId(req: Request)` — single source accessor in controllers later. File src/presentation/controllers/DevicesController.ts. Actually put helper in use-case helper. Put resolveRequestingDeviceId(req) prefers req['deviceId'] (future locals) else fallback query ? deviceId else body deviceId. Returns null if none. This aligns extensibility. Actually location inside controller.

### Test Requirements (use cases only)
| ID  | Type | Statement |
|---|---|---|
| T4-1 | rule | GetPatientFaceReference.execute validates patientId + deviceId |
| T4-2 | rule | RecordFaceVerification.execute enforces relationship. |

### Completion Evidence
None.

---

## Task 5: Presentation Layer — validator updates, DevicesController 2 new methods, devices routes append
**Status**: pending
**Priority**: high
**Depends on**: Task 4.
**Maps to**: AC-1 through AC-9, AC-18, AC-20

### Work Items:
1. Edit src/presentation/validators/devices.validator.ts — ADD two new schemas:
   ```ts
   // new (keep heartbeatSchema as-is)
   export const getFaceReferenceSchema = z.object({
     patientId: z.string().trim().min(1),
     deviceId: z.string().trim().min(1),
   }).strict(); // combined from route param + query

   export const faceVerificationSchema = z.object({
     deviceId: z.string().trim().min(1),
     patientId: z.string().trim().min(1),
     verified: z.boolean(),
     similarity: z.number().gte(0).lte(1).optional(),
   }).strict();
   ```
   Keep future deviceHeadersSchema stub commented AC-20 evidence.

2. Edit DevicesController — NEW private helper `resolveRequestingDeviceId(req): string | null` (prefer future req['deviceId'] from middleware; then GET req.query.deviceId; then fallback req.body.deviceId). Return trimmed string or null.
3. DevicesController.heartbeat untouched.
4. ADD DevicesController.getFaceReference.
5. ADD DevicesController.recordFaceVerification.
6. formatZodErrors reuse same style. For verified always reuse.

7. Edit devices.routes.ts — ADD two routes (do not modify heartbeat):
   ```
   devicesRouter.get('/patients/:patientId/face-reference', DevicesController.getFaceReference);
   devicesRouter.post('/face-verification', DevicesController.recordFaceVerification);
   ```
8. app.ts — unchanged route mount /api/devices already present; no edit needed (devicesRouter already mounted.

### Test Requirements
| ID  | Type | Statement |
|---|---|---|
| T5-1 | rule | GET + POST two new tests later. Routes wired. |

### Completion Evidence
None until.

---

## Task 6: server.ts NO OP. No edits.
Wait actually is need to hook. Nope. Skip.
Depends none.
Work items none.

---

## Task 7: Jest tests — 6 new tests match user §21 T1–T6.
**Status**: pending
**Priority**: high
**Depends on**: Task 5.

### Jest tests T1–T6 file: tests/device-face-recognition.spec.ts

Scenario list 6 tests:

T1. Get reference → 200 valid (valid url + updatedAt
T2. Patient not exists → 404 "Patient not found"
T3. Patient not associated / unassigned box → 403
T4. Post verification verified true → 200 + FaceVerificationEvent SUCCESS created with verified=true recorded +message Patient verified successfully
T5. Post verified false → 200 message "Face verification failed" + event verified=false recorded, similarity=0.12 stored
T6. Post invalid (empty) → 400 BadRequest ({} deviceId required.

Use jest.fn mocks. Use repository mocks not real DB.

### Test Requirements
| ID  | Type | Statement |
|---|---|---|
| T7-1 | rule | Jest 6 tests all pass. |
| T7-2 | rule | Existing 489 tests never lose. |

### Completion Evidence

---

## Task 8: Postman guide text file
**Objective**: Write FACE-RECOGNITION-POSTMAN.txt at project root, documenting the three requests GET face-ref, POST success, POST fail.
**Status**: pending
**Priority**: medium
**Depends on**: Task 5

### Work Items
Content:
* GET endpoint URL + headers Content-Type application/json + `?deviceId=PI-DEV-001` URL param; expected 200 response shape.
* POST face-verification success body + headers + PI-DEV-001 body true body.
* POST face-verification fail body.
* Known auth limitation comment.
* Device ↔ Patient relationship validation rule explainer.

---

## Task 9: Full Pipeline
**Status**: pending
**Priority**: high
**Depends on**: Task 1-8.
Pipeline steps strict order:
a. npx prisma validate
b. npx tsc --strict --noEmit
c. npx jest --forceExit → ALL 495 total 0 failures.
d. npm run build
e. Global grep src+tests forbidden identifiers heartbeat / / DrawerOpen medication mark medication taken sensors notification logic → outside existing files. (Scope correctness actually Task forbidden keyword grep is: `DispensingEvent|PhysicalDeviceEvent|Dht22Reading|reportDHT22|Drawer.*(open|close)|reportCurrentQuantity|INSIGHTFACE|face-engine|opencv` matches. 0 matches.

---

## Task 10: Final report per user §24 10-point structure.
**Status**: pending
**Priority**: medium.

---

## Phase Approve
After approve tasks finalize. Implement Tasks 1–10 in order. Only 1 task in_progress. Track. Pipeline. Review. Phase Review gate.

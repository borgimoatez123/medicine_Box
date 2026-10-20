# Tasks: Implement Patient Takes Medicine Backend

Work directory: `c:\Users\borgi\Desktop\app\server`

Pipelines required at end (Task 10): prisma validate → tsc strict → jest (new file + full suite) → npm build → forbidden-token grep. All must exit 0.

## Checklist 1 → 12

### Task 1 — Prisma schema delta + Prisma Generate
- Edit prisma/schema.prisma:
  1. Append `MISSED` to enum MedicationSessionResult.
  2. Add two columns to model MedicationSession:
     - occurrenceDate DateTime?
     - occurrenceTime String?
  3. Add @@unique([scheduleId, occurrenceDate, occurrenceTime], map: "...").
  4. Do not change any other models/fields.
- Run `npx prisma validate` locally. It must pass.
- Run `npx prisma generate` to update client types.
- Save this file. Expected result: TS types now include MedicationSessionResult.MISSED, MedicationSession.occurrenceDate, MedicationSession.occurrenceTime.

### Task 2 — Migration 0013 (Supabase pooler safe)
- Create folder prisma/migrations/20260923120000_add_missed_and_occurrence_unique/
- Create migration.sql inside with (all idempotent, pooler-safe):
  1. Use `DO $$ BEGIN IF NOT EXISTS ... END$$` to safely append MISSED enum token.
  2. `ALTER TABLE "MedicationSession" ADD COLUMN IF NOT EXISTS "occurrenceDate" TIMESTAMPTZ;`
  3. `ALTER TABLE "MedicationSession" ADD COLUMN IF NOT EXISTS "occurrenceTime" TEXT;`
  4. `CREATE UNIQUE INDEX IF NOT EXISTS "MedicationSession_schedule_occurrence_unique" ON "MedicationSession" ("scheduleId", "occurrenceDate", "occurrenceTime") WHERE "occurrenceDate" IS NOT NULL AND "occurrenceTime" IS NOT NULL;`
- Run `prisma migrate deploy --schema prisma/schema.prisma` using Direct_URL against Supabase, exit 0 required. If transient pooler error, Start-Sleep 3s, retry once.
- If the Supabase project already has the enum value added (race from prior drafts), migration.sql must still exit 0 (all IF NOT EXISTS / DO $$ guard).

### Task 3 — Domain layer repository interface additions
- Edit src/domain/repositories/IMedicationSessionRepository.ts:
  - Add type `CreateMedicationSessionWithOccurrenceData = CreateMedicationSessionData & {occurrenceDate?: Date | null, occurrenceTime?: string | null, result?: MedicationSessionResult | null, completedAt?: Date | null, quantityAfter?: number | null};`
  - Add domain interface method: `createWithOccurrence(data: CreateMedicationSessionWithOccurrenceData): Promise<MedicationSession>;`
  - Add domain method: `findByOccurrence(scheduleId: string, occurrenceDate: Date, occurrenceTime: string): Promise<MedicationSession | null>;`
- Edit src/domain/repositories/IScheduleRepository.ts if not present, otherwise leave unchanged (findById already existed — add convenience `findByIdWithMedication(id: string)` only if NOT present in IMedicationRepo path: prefer IMedicationRepository.findById to validate patient chain instead of nested include — document this choice. We use Medication.findById via existing repo to validate schedule.medicationId→patientId. No domain interface change for ISchedule required. No domain interface change for IMedicineBox/IPatient/IDrawer/IDrawerMedication needed today, they already have the methods we use.

### Task 4 — Infrastructure layer Prisma repo impl + transaction helper
- Edit src/infrastructure/database/prisma/repositories/PrismaMedicationSessionRepository.ts:
  - Implement createWithOccurrence: forwards to prisma.medicationSession.create with fields.
  - Implement findByOccurrence: where(scheduleId + occurrenceDate + occurrenceTime) with day-matching date column.
- Create NEW `IDeviceMedicationEventProcessor.ts` — no. Instead put transaction logic in use-case via a helper in PrismaDrawerMedicationRepository or in use-case directly with injected prisma client. Clean arch: expose a new prisma impl method in PrismaDrawerMedicationRepository (or a new dedicated prisma service class inside infrastructure):
  - Create `src/infrastructure/services/PrismaDeviceMedicationEventProcessor.ts` which imports PrismaTransaction callback and executes the 5-step TAKEN or MISSED flow. Export async `processEvent(validatedEventData)` that returns the shaped output `{session, remainingQuantity, refillRequired, missingQuantity, duplicate}`. This keeps prisma inside infrastructure layer; use-case only calls it with validated data.
- The processor:
  - validate quantities,
  - create/update session with occurrence fields,
  - handle unique index duplicate violation, read existing session, return duplicate:true,
  - for TAKEN update DM quantity and missing quantity,
  - update Drawer.status EMPTY when newQuantity === 0 and operational using drawerStatusPatch / shouldSyncStatus helpers (export from PrismaDrawerMedicationRepository to shared location like `src/shared/utils/drawer-status.ts` OR keep in infrastructure and duplicate 15 lines small helper inside processor — simpler: copy shouldSyncStatus + drawerStatusPatch + DRAWER_OPERATIONAL_SET inside processor to avoid circular imports; document).

### Task 5 — Application layer use-case
- Create NEW file `src/application/use-cases/device/ProcessPatientMedicationEvent.ts`.
- DI: IMedicineBoxRepository, IPatientRepository, IScheduleRepository, IMedicationRepository, IDrawerRepository, IDrawerMedicationRepository, IMedicationSessionRepository (existing), and the NEW `PrismaDeviceMedicationEventProcessor` instance OR an `IDeviceMedicationEventProcessor` domain interface that Prisma impl implements — cleaner option: add domain interface `IDeviceMedicationEventProcessor` to domain/services/ or simply call prisma processor as a typed import, since clean architect allows infrastructure use within use-cases via interface only. Create domain interface first to keep inverted dependency. Domain `IDeviceMedicationEventProcessor` interface + processor class implements it → use-case only depends on interface.
- Execute method signature: `execute(body: RecordMedicationEventBody): Promise<MedicationEventResult>`.
- Step order:
  1. Validated body already (strict zod) — if not valid bad request handled at controller.
  2. Device/box lookup + 404.
  3. Patient lookup + 404.
  4. userID gate 403.
  5. Schedule lookup + 404.
  6. Medication.findById(schedule.medicationId) + check med.patientId === patientId → 403.
  7. Drawer.findById + 404; drawer.medicineBoxId === box.id → 409.
  8. dm = dmRepo.findByDrawerId(drawerId); 404 not found; dm.medicationId !== med.id → 409.
  9. parse expectedDosage from schedule.dosage parseInt leading integer. If NaN → 400 BadRequest `"Schedule dosage format not supported: ${schedule.dosage}"`.
  10. For status=TAKEN: expectedDosage must === quantityTaken strict. Else 409 Conflict wrong dosage.
  11. For status=MISSED: quantityTaken === 0 strict, else 400.
  12. Compute server occurrence (occurrenceDate YYYY-MM-DD Tunisia midnight + occurrenceTime HH:mm slot).
  13. For TAKEN: current qty = dm.quantity ?? 0 → if current < quantityTaken → 409 insufficient.
  14. Call processor.processEvent with validated payload → returns session, duplicate, remainingQty, refill, missingQty.
  15. Return result (MedicationEventResult DTO in application types).
- All throws typed via @shared/errors: NotFoundError, ForbiddenError, ConflictError, BadRequestError.

### Task 6 — Presentation layer validator schema
- Append new strict zod schema `medicationEventSchema` to `src/presentation/validators/devices.validator.ts`.
- Schema rules per spec FR-2, exact TAKEN/MISSED qty constraint with superRefine or conditional refine.
- Export it. Reuse `formatZodErrors` existing helper.

### Task 7 — Presentation DevicesController + devices.routes.ts
- Edit `src/presentation/controllers/DevicesController.ts`:
  - Import schema, use-case, processor implementations via DI at top (constructor wiring matches existing pattern, review existing controller to match).
  - Add new public method `recordMedicationEvent(req, res, next)`.
  - SECURITY LIMITATION header comment block at top of method matching existing endpoints. Resolve deviceId via single-source `resolveRequestingDeviceId(req)` helper (fallback to body.deviceId for now; future overwrite req.deviceId if middleware set).
  - Parse/validate body → 400 fail envelope.
  - Wire use-case execute → catch typed errors (NotFound 404, Forbidden 403, Conflict 409, BadRequest 400).
  - Build response envelope consistent with existing endpoints.
- Edit `src/presentation/routes/devices.routes.ts`:
  - Append one new line: `devicesRouter.post('/medication-events', controller.recordMedicationEvent);` inside existing router export.

### Task 8 — DI wiring & server startup registration
- Inspect existing DI composition root (likely `src/server.ts` or `src/infrastructure/di.ts` or presentation/controllers constructor). Wire the new use-case and processor inside the existing composition pattern. Ensure no runtime undefined errors on import.
- If server uses per-controller manual instantiation at the bottom of devices.routes.ts, mirror that pattern for the new dependencies.

### Task 9 — Jest tests: device-medication-events.spec.ts (user T1–T8, 8 + bonus scenarios)
- NEW file `tests/device-medication-events.spec.ts`.
- Unit test only: mock every repository + processor with jest.fn(). Do NOT call real prisma.
- Mandatory it() blocks:
  1. T1 Successful TAKEN: quantity 10 dosage 2 qtyTaken=2 → expect result PATIENT_TAKEN, remaining 8, event created, refillRequired=false.
  2. T2 Zero quantity → newQuantity=0 refillRequired=true, missingQuantity = drawerCapacity-0, drawer EMPTY called inside processor.
  3. T3 MISSED status: quantity unchanged, no DM update, session created result=MISSED.
  4. T4 Insufficient quantity: quantity 1 dosage 2 → 409 Conflict. NO writes.
  5. T5 Wrong patient: same device but box.userId different from patient.userId → 403.
  6. T6 Wrong drawer: schedule medication belongs to drawer-1 but request drawer-2 → 409.
  7. T7 Wrong dosage: schedule.dosage='2 tablets', qtyTaken=1 → 409.
  8. T8 Duplicate event idempotent: send same twice → first qty 10→8, second returns duplicate=true remaining=8 unchanged.
- Bonus tests ≥2 to cover edge cases (e.g. body with quantityTaken=-2 zodschema 400; device not found 404; schedule not found 404; wrong dosage parse 'as needed' → 400).
- Run via `npx jest tests/device-medication-events.spec.ts --runInBand`. Must pass 10/10 ≥8 required.
- Then run full `npx jest` and entire suite must pass (verify no regressions; existing tests remain green).

### Task 10 — Pipeline verification 5-step
- Run sequentially and require all exit code 0.
  1. `npx prisma validate` exit 0.
  2. `npx tsc --noEmit --project tsconfig.json` (tsc strict mode) exit 0.
  3. `npx jest` exit 0 (all tests; no skip).
  4. `npm run build` OR equivalent build script (package.json check) exit 0.
  5. Scope forbidden grep: run grep (powershell select-string) on src+tests for tokens: `Open Drawer|Close Drawer|drawer open|drawer close|Motor|sensor hardware|FaceEngine|InsightFace|schedule timer|MQTT|WebSocket|OPEN_DRAWER|CLOSE_DRAWER` → case insensitive, match count 0.

### Task 11 — Postman test guide PATIENT-TAKES-MEDICATION-POSTMAN.txt
- At project root create this text file.
- Document: method URL Headers Body + 4 example requests (Success TAKEN, Zero drawer Empty Refill, MISSED status, Idempotent retry duplicate) + expected response body each.

### Task 12 — Final report user §33 (15-point structure)
- Deliver 15-point list verbatim structure §33.1-§33.15.
- Include: Files modified list, Prisma schema changes list, new migration summary, endpoint details, request/response formats, validation rules, device→box→patient rule, schedule→med→drawer chain, quantity update logic + transaction impl, idempotency impl, drawer empty/refill logic, test results, postman instructions, documented assumptions/limitations list.
- Do not claim feature works unless the 5-step pipeline is green + at least 10 jest tests green including user T1–T8.

Expected final exit status: 0 on every pipeline step. Commit message convention not required (user did not request git commit).

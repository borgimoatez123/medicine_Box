# TASKS: Raspberry Pi Schedule Synchronization Backend

Plan state 5 phases: Specify ✔ → Plan █ → Approve → Implement → Review.
Mapped 1:1 from spec.md Acceptance Criteria. Each task is atomic; only one in_progress at a time. No parallel writes to shared files (validator/controller/routes are serialized through Tasks 5-6).

---

## Task 1: Domain Layer — Repository interface additions (Schedule + Patient)

**Objective**: Add required find* method signatures on existing repository interfaces.
**Status**: pending
**Priority**: high
**Maps to AC**: AC-15, AC-5
**Dependencies**: none

### Work Items
1. Open `src/domain/repositories/IScheduleRepository.ts`. Add method signature:
   ```ts
   findAllActiveByPatientIdForDeviceSync(patientId: string): Promise<Array<{
     schedule: import('@domain/entities/Schedule').Schedule;
     medication: { id: string; name: string };
     drawerMedication: { id: string; drawerId: string; quantity: number; isActive: boolean; drawer: { medicineBoxId: string } } | null;
   }>>;
   ```
   (Define proper inline `type` exported at top of file to avoid inline `import`; actually better: create exported type alias `ScheduleDeviceSyncRow`.)
2. Open `src/domain/repositories/IPatientRepository.ts`. If `findFirstByUserId` does NOT exist, add the method signature:
   ```ts
   findFirstByUserId(userId: string): Promise<import('@domain/entities/Patient').Patient | null>;
   ```
   If it already exists, skip and only add a commented note.

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T1-1 | rule | TS compile on the interface files alone (no errors on new signatures). |

### Completion Evidence
(To fill after completing.)

---

## Task 2: Infrastructure Layer — Prisma implementations of new repository methods

**Objective**: Implement one prisma query (NO N+1) loading schedules + medication + drawerMedications(include drawer) with active filters, shape to typed rows.
**Status**: pending
**Priority**: high
**Maps to AC**: AC-5, AC-8, AC-9, AC-13 (prisma only in infra)
**Dependencies**: Task 1

### Work Items
1. Edit `src/infrastructure/database/prisma/repositories/PrismaScheduleRepository.ts`.
   - Implement `findAllActiveByPatientIdForDeviceSync`. Must be ONE prisma.schedule.findMany call with `include` nested:
     ```
     {
       where: {
         status: 'ACTIVE',
         isActive: true,
         medication: { patientId: <patientId> },
       },
       include: {
         medication: {
           select: { id: true, name: true },
           // Also include active drawer medications with drawer link.
           include: {
             drawerMedications: {
               where: { isActive: true },
               include: { drawer: { select: { id: true, medicineBoxId: true } } },
             },
           },
         },
       },
     }
     ```
   - Because drawerMedications.include shape may be array per medication, the returned flat structure from prisma will have `medication.drawerMedications[]`; we post-process in TypeScript (inside the same impl method, still ONE prisma call) to pair each schedule row with a single "best" drawerMedication candidate (active) for later linking by the use-case to a specific boxId.
   - Return structure: `{ schedule, medication:{id,name}, drawerMedication: (candidate or null) }[]`.
   - For each schedule+medication, pick the first drawerMedication candidate if any exists; or return null to allow use-case-level box filtering. The use-case will do the final filter of drawer.medicineBoxId === box.id since prisma can't efficiently deep-filter nested includes by a parameter not knowable at compile time.

2. If `findFirstByUserId` was added to the Patient interface, implement it in `PrismaPatientRepository.ts`:
   ```ts
   async findFirstByUserId(userId) {
     const p = await prisma.patient.findFirst({
       where: { userId },
       orderBy: { createdAt: 'asc' },
     });
     return p ? this.toDomain(p) : null;
   }
   ```

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T2-1 | rule | Code compiles (new method satisfies interface). |
| T2-2 | rule | Implementation contains exactly 1 `prisma.schedule.findMany` call — grep within method body, 1 occurrence. |
| T2-3 | rule | Active filters `status:'ACTIVE'` AND `isActive:true` are present in the prisma where clause. |

### Completion Evidence
(filled later)

---

## Task 3: Application Layer — New `GetDeviceSchedule` use-case

**Objective**: Resolve device → box → patient → filter schedules by matching drawerMedication.boxId → expand times per row → shape FR-5 payload ordered per FR-7.
**Status**: pending
**Priority**: high
**Maps to AC**: AC-2 through AC-10 inclusive
**Dependencies**: Task 1 + Task 2

### Work Items
1. Create file `src/application/use-cases/device/GetDeviceSchedule.ts`.
   Constructor DI:
   ```ts
   constructor(
     private readonly boxRepo: IMedicineBoxRepository,
     private readonly patientRepo: IPatientRepository,
     private readonly scheduleRepo: IScheduleRepository,
   ) {}
   ```

2. Execute method: `async execute(deviceIdRaw: string): Promise<{ patientId: string; schedules: DeviceScheduleRow[] }>`

   Ordering of operations (mirrors spec FR-2 order):
   1. `const deviceId = deviceIdRaw?.trim(); if (!deviceId) throw new BadRequestError('deviceId is required')` (AC-2).
   2. `box = await boxRepo.findByDeviceId(deviceId); if (!box) throw NotFoundError('Device not found')` (AC-3).
   3. if `box.userId` is null → 404 "No patient assigned to this medicine box".
   4. `patient = await patientRepo.findFirstByUserId(box.userId); if (!patient) throw NotFoundError('No patient assigned to this medicine box')` (AC-4).
   5. `rows = await scheduleRepo.findAllActiveByPatientIdForDeviceSync(patient.id)` — no pagination, all active.
   6. Filter drawerMedication by this specific box: for each row, if `row.drawerMedication && row.drawerMedication.drawer.medicineBoxId !== box.id`, set `drawerMedication = null`. (AC-9 linking to correct box's drawer).
   7. Per-row time expansion (FR-4):
      - Define helper `expandTimes(schedule): string[]` which validates `schedule.times` as `(string & HH:mm)[]`, dedupes. If empty → check timesPerDay >= 1 → yield `["00:00"]` sentinel; else → yield `[]` (skip).
      - For each `time` in the expanded list, push one shaped FR-5 row. Include `scheduleId, medicationId, medicationName, drawerId (d?.drawerId ?? null), dosage: schedule.dosage, time, quantity: (d ? d.quantity : null), daysOfWeek, startDate, endDate, timesPerDay, status, isActive`.
      - `startDate` → `schedule.startDate.toISOString().slice(0,10)` (TZ: no shift applied; NG6).
      - `endDate` → if non-null, same slice; else null.
      - `daysOfWeek` → `schedule.daysOfWeek` if is array of 1..7 numbers; else null.
   8. Stable Sort per FR-7: (a) time asc, (b) startDate asc, (c) scheduleId asc.
   9. Return `{ patientId: patient.id, schedules: sortedRows }`.

3. Export the use-case class and any public types.

### Test Requirements (local unit via Jest later in Task 7)
| ID | Type | Statement |
|---|---|---|
| T3-1 | rule | Empty deviceId → BadRequestError. |
| T3-2 | rule | Unknown deviceId → NotFound "Device not found". |
| T3-3 | rule | box.userId null / no patient → NotFound "No patient assigned to this medicine box". |
| T3-4 | rule | 0 schedules from repo → schedules empty array, no error thrown. |
| T3-5 | rule | 1 schedule times=[t1,t2] → output length=2 with same scheduleId. |
| T3-6 | rule | Inactive drawer (drawerMed mismatched boxId) → drawerId null. |
| T3-7 | rule | Output sorted by time asc. |

### Completion Evidence
(filled later)

---

## Task 4: Presentation Layer — Validator schema addition

**Objective**: Append `getDeviceScheduleSchema` to devices.validator.ts.
**Status**: pending
**Priority**: medium
**Maps to AC**: AC-2, AC-15, NR-4
**Dependencies**: none (independent, but combined through tasks 5 / 6)

### Work Items
1. Open `src/presentation/validators/devices.validator.ts`.
2. Add schema:
   ```ts
   export const getDeviceScheduleSchema = z.object({
     deviceId: z.string().trim().min(1, 'deviceId is required'),
   }).strict();
   ```
   Leave heartbeat / face schemas untouched.

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T4-1 | rule | `getDeviceScheduleSchema.safeParse({ deviceId: '' }).success === false` |
| T4-2 | rule | `getDeviceScheduleSchema.safeParse({ deviceId: 'PI-DEV-001' }).success === true` |

### Completion Evidence
(filled later)

---

## Task 5: Presentation Layer — Append method `getDeviceSchedule` to DevicesController

**Objective**: Wire router → controller → use-case invocation with correct envelope + resolveRequestingDeviceId hook + SECURITY LIMITATION comment.
**Status**: pending
**Priority**: high
**Maps to AC**: AC-11 envelope, AC-16 (auth hook comment), AC-1 (route wiring in Task 6)
**Dependencies**: Tasks 3 + 4

### Work Items
1. Open `src/presentation/controllers/DevicesController.ts`.
2. Import: `getDeviceScheduleSchema`, `GetDeviceSchedule`, required repo interfaces.
3. In constructor, instantiate the use case using the same pattern (new GetDeviceSchedule(this.medicineBoxRepo, patientRepo, scheduleRepo)). Re-use existing repo instances if available; instantiate the Prisma*Repository classes in the same style as heartbeat / face use-cases.
4. Add SECURITY LIMITATION comment block above the new method mirroring the existing one (document extension hook for req.deviceId / x-device-id header). Also update the class-level comment if needed to include this new endpoint.
5. Implement async getDeviceSchedule(req, res, next):
   a. Extract `deviceIdParam = req.params.deviceId`.
   b. Parse schema against `{ deviceId: deviceIdParam }` using same safeParse + formatZodErrors pattern. If invalid → 400 via BadRequestError.
   c. effectiveDeviceId = resolveRequestingDeviceId(req) ?? deviceIdParam. (Preference: trusted middleware → x-device-id header → fallback param).
   d. Call `await this.getDeviceScheduleUseCase.execute(effectiveDeviceId)`.
   e. Shape response: `patientId` unchanged; schedules array as returned. Inside each row, `startDate` and `endDate` are already strings per use-case; send as-is.
   f. Return envelope 200 using `okPublic` / same status envelope helper as heartbeat/face methods.
   g. Catch block → next(err) for middleware.

### Test Requirements
(Verified indirectly in Task 7 pipeline + TS strict).

| ID | Type | Statement |
|---|---|---|
| T5-1 | rule | TS strict: DevicesController compiles after adding method. |
| T5-2 | rule | Contains call to `resolveRequestingDeviceId(req)` in the new method. |

### Completion Evidence
(filled later)

---

## Task 6: Presentation Layer — Append route to devices.routes.ts

**Objective**: One line route GET /:deviceId/schedule → DevicesController.getDeviceSchedule (no auth middleware required per spec NG7; authorization inside use-case via device→box→patient chain).
**Status**: pending
**Priority**: high
**Maps to AC**: AC-1
**Dependencies**: Task 5

### Work Items
1. Open `src/presentation/routes/devices.routes.ts`.
2. Append after existing routes:
   ```ts
   devicesRouter.get('/:deviceId/schedule', (req, res, next) => devicesController.getDeviceSchedule(req, res, next));
   ```
   Keep existing heartbeat / face routes untouched.

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T6-1 | rule | File compiles (TS strict). |
| T6-2 | rule | Grep confirms route string "/:deviceId/schedule" present once. |

### Completion Evidence
(filled later)

---

## Task 7: Jest tests — `tests/device-schedule-sync.spec.ts` (7 cases T1–T7)

**Objective**: Unit test the use-case + validator for each user §21 scenario (T1–T7) using jest.fn mocks (same style as device-face-recognition.spec.ts). No real prisma / no supertest.
**Status**: pending
**Priority**: high
**Maps to AC**: AC-19 (0 failures)
**Dependencies**: Tasks 1-6 complete

### Work Items
1. Create file `tests/device-schedule-sync.spec.ts`.
2. Factory helpers: `mkBoxRepo({findByDeviceId})`, `mkPatientRepo({findFirstByUserId})`, `mkScheduleRepo({findAllActiveByPatientIdForDeviceSync})`.
3. Build functions: `buildBox`, `buildPatient`, `buildScheduleRow` helpers.
4. Jest it() blocks — EXACTLY 7 mandatory tests + 1 bonus optional if time allows:
   - **Test 1 T1** — happy path: valid deviceId → box → patient → 2 schedules with times → returns 200-equivalent (no throw), patientId correct, schedules[0] includes scheduleId/medicationId/medicationName/drawerId/dosage/time.
   - **Test 2 T2** — unknown device → NotFoundError "Device not found".
   - **Test 3 T3** — box.userId is null → 404 "No patient assigned to this medicine box".
   - **Test 4 T4** — box has userId but findFirstByUserId returns null → same 404 message.
   - **Test 5 T5** — patient exists, schedulesRepo returns [] → schedules: [] (no throw).
   - **Test 6 T6** — Multiple schedules each with multiple times → verify total rows = sum of times per schedule, ordered by time ascending.
   - **Test 7 T7** — Inactive schedules are filtered BEFORE they reach the use-case (i.e., mock repo intentionally returns ONLY active rows; verify use-case doesn't add rows that are inactive status). Actually we want to validate the use-case's implicit contract that the repo filters correctly. Implementation of this test: mock repo mix — include a status ACTIVE schedule along with no PAUSED ones; then verify output only contains ACTIVE status fields on each row.
   - Bonus: Verify inactive drawerMedication (drawerMed mismatched boxId) → drawerId null on row.

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T7-1 | rule | T1–T7 all pass. |
| T7-2 | rule | File has ≥7 `it(` blocks. |
| T7-3 | rule | No real prisma (grep for `@prisma/client` imports none; only domain interfaces used). |

### Completion Evidence
(filled later)

---

## Task 8: Postman guide — SCHEDULE-SYNC-POSTMAN.txt project root

**Objective**: Human-readable documentation mirroring §22 of user spec.
**Status**: pending
**Priority**: medium
**Maps to AC**: documentation §22 / §14 C3 assumptions
**Dependencies**: Tasks 1-7 (informs contents, no code dependency)

### Work Items
1. Create `SCHEDULE-SYNC-POSTMAN.txt` at project root. Contents:
   - Pre-req: box deviceId exists in MedicineBox table, box.userId set, at least one Patient with that userId + active schedules with drawer medications assigned.
   - GET request line verbatim §22.
   - Expected response shape (full example with 1+ schedule rows, 1 empty, 1 with drawerId null quantity null).
   - 400 / 404 response examples.
   - Security limitation section (no device-token auth yet; x-device-id hook / middleware planned).
   - Timezone notes (Tunisia wall clock; no shift; startDate/endDate YYYY-MM-DD slice only).
   - Multi-patient user assumption (first-by-createdAt patient used).

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T8-1 | rule | File exists, non-empty, contains route literal `GET /api/devices/:deviceId/schedule`. |

### Completion Evidence
(filled later)

---

## Task 9: Pipeline verification — prisma → tsc strict → jest → build → scope grep

**Objective**: Run all verification steps end-to-end and record results. If anything fails, mark the calling task as in_progress / fix.
**Status**: pending
**Priority**: high
**Maps to AC**: AC-12 writes, AC-13 scope grep, AC-14 prisma validate unchanged, AC-17 ts, AC-18 build, AC-19 T1–T7, AC-20 all tests pass
**Dependencies**: Tasks 1-8 complete

### Work Items (run serially, stop on failure):
1. `npx prisma validate` — must exit 0 (no schema changes, unchanged).
2. `npx tsc --strict --noEmit` — exit 0; 0 errors.
3. `npx jest tests/device-schedule-sync.spec.ts` — exit 0, 0 failures.
4. `npx jest --forceExit` — all suites, exit 0, 0 failures.
5. `npm run build` — exit 0 (tsc compile).
6. Scope grep `src/ tests/` for forbidden tokens (§23/§24):
   ```
   openDrawer|closeDrawer|markMedicationAs|markMedication|updateQuantity|quantity.*update|decrement|increment|sendNotification|notification.*send|triggerMotor|sensor.*read|reportCurrentQuantity|Dht22Reading|DispensingEvent|PhysicalDeviceEvent|setTimeout.*schedule|node-cron|cron\(
   ```
   Exclude existing heartbeat files. Verify 0 matches.
7. Grep `src/application/use-cases/device/GetDeviceSchedule.ts` and `PrismaScheduleRepository*` for `create(| update(| delete(| prisma\..*\.create(| prisma\..*\.update(| prisma\..*\.delete(` — confirm only find* / findMany* calls (AC-12 no writes).

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T9-1 | rule | Steps 1-6 all exit code 0. |
| T9-2 | rule | Scope grep 0 matches. |
| T9-3 | rule | Use-case + schedule repo contain zero prisma create/update/delete calls. |

### Completion Evidence
(record exact stdout snippets / counts / exit codes in this section after running)

---

## Task 10: Final report — user §25 14-point structure

**Objective**: Deliver user-visible final report enumerating §25 1–14 items exactly.
**Status**: pending
**Priority**: medium
**Maps to AC**: Reporting requirement
**Dependencies**: Task 9 green

### Work Items
1. Write assistant chat response containing exactly 14 sections:
   1. Files modified.
   2. Prisma schema changes, if any.
   3. Database migration required, if any.
   4. Endpoint implemented.
   5. Exact request format.
   6. Exact response format.
   7. Prisma query/relations used.
   8. Device → MedicineBox → Patient validation logic.
   9. Schedule ordering logic.
   10. Timezone handling.
   11. Quantity handling if included.
   12. Tests executed and their results.
   13. Postman testing instructions.
   14. Any assumptions or limitations.

### Test Requirements
| ID | Type | Statement |
|---|---|---|
| T10-1 | rule | Response contains all 14 numbered headers with content. |

### Completion Evidence
(assistant message printed to user)

# Drawer Unlock / Open Command API - Implementation Plan

## Task 1: Add DeviceCommand Prisma schema (enums + model) and run Prisma validate + generate
- **Status**: `pending`
- **Priority**: high
- **Depends On**: None
- **Description**:
  - Edit `prisma/schema.prisma`, append after DrawerSensorState model:
    - New enum `DeviceCommandType { OPEN_DRAWER }`.
    - New enum `DeviceCommandStatus { PENDING SENT EXECUTED FAILED EXPIRED }`.
    - New model `DeviceCommand` with all fields specified in spec FR-2.
    - Add inverse relation to `MedicineBox` (`commands DeviceCommand[]`) and `Drawer` (`commands DeviceCommand[]`).
    - Indexes: `@@index([deviceId, status])`, `@@index([drawerId, createdAt])`.
  - Run `npx prisma validate` (exit 0).
  - Run `npx prisma generate` (exit 0).
- **Acceptance Criteria Addressed**: AC-1, AC-2, FR-1, FR-2
- **Test Requirements**:
  - `rule` TR-1.1: Prisma validate + generate both exit 0. Evidence: CLI exit codes.
  - `rule` TR-1.2: Inverse relations exist on MedicineBox and Drawer models so Prisma FK generation succeeds without `P1012 relation unknown` errors.
  - `rule` TR-1.3: Model fields exactly match spec FR-2 (deviceId non-null, drawerId nullable, type/status as enums, 4 datetime + error nullable string).
- **Notes**: Do not delete / rename any existing models. No field type changes to existing models.

## Task 2: Create Supabase-safe idempotent migration SQL + deploy to remote Supabase via prisma migrate deploy
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - Create migration directory `prisma/migrations/<timestamp>_add_device_command/migration.sql`.
  - Write 3-statement safety pattern per PG<15 limitation:
    (1) `CREATE TABLE IF NOT EXISTS "DeviceCommand" (...)` with exact columns/types matching schema.
    (2) `CREATE INDEX IF NOT EXISTS "_DeviceCommandDeviceIdStatus_idx" ...` and `...DrawerIdCreatedAt_idx`.
    (3) `DO $$ BEGIN IF NOT EXISTS (SELECT ...pg_constraint...) THEN ALTER TABLE ADD CONSTRAINT ... END IF; END $$;` for the two FKs (deviceId FK MedicineBox.deviceId, drawerId FK Drawer.id on cascade delete set null / cascade exact as schema).
  - Run `npx prisma migrate deploy` against Supabase DIRECT_URL/DATABASE_URL from .env. Expected exit 0.
  - Confirm no `P3018 migration failed` / `PG 42601` syntax errors.
- **Acceptance Criteria Addressed**: AC-14, FR-3
- **Test Requirements**:
  - `rule` TR-2.1: `npx prisma migrate deploy` exit 0. Evidence: captured stdout/stderr showing "Migration add_device_command applied."
  - `rule` TR-2.2: Supabase SQL Editor `SELECT * FROM "DeviceCommand" LIMIT 0` works; table schema columns/types match schema.prisma exactly.
  - `rule` TR-2.3: Idempotent second `prisma migrate deploy` does not error.

## Task 3: Domain layer entity + repository interface
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 1
- **Description**:
  - Create `src/domain/entities/DeviceCommand.ts` class with TypeScript fields matching Prisma model, constructor param object pattern, optional fields correctly typed.
  - Create `src/domain/repositories/IDeviceCommandRepository.ts` interface with typed methods:
    ```
    create(data: CreateDeviceCommandData): Promise<DeviceCommand>
    findById(commandId: string): Promise<DeviceCommand | null>
    findPendingByDeviceId(deviceId: string): Promise<DeviceCommand[]>
    markManyAsSentInTransaction(commandIds: string[]): Promise<void>
    updateResult(commandId: string, result: UpdateCommandResultData): Promise<DeviceCommand | null>
    ```
    Add supporting type aliases CreateDeviceCommandData / UpdateCommandResultData.
- **Acceptance Criteria Addressed**: AC-17, FR-4
- **Test Requirements**:
  - `rule` TR-3.1: Path aliases resolve correctly. `tsc --noEmit` passes after files created (checked later in pipeline).
  - `rule` TR-3.2: Method signatures exactly match what application use-cases require (no missing fields).
  - `rubric` TR-3.3: Architecture fidelity. Scale 1-5. Anchors 1=no entity pattern, 3=types only no classes, 5=identical structure to DrawerSensorState domain files. Threshold >= 4.

## Task 4: Infrastructure Prisma repository implementation for DeviceCommand
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 3, Task 2
- **Description**:
  - Create `src/infrastructure/database/prisma/repositories/PrismaDeviceCommandRepository.ts` implementing IDeviceCommandRepository.
  - Implement mapper function `toDomainDeviceCommand(prismaRow: any): DeviceCommand` that always returns domain class (even if some fields null).
  - Use Prisma `$transaction` for the `markManyAsSentInTransaction` method: `updateMany({ where: { id: { in: ids } }, data: { status: 'SENT', sentAt: new Date() }})` to ensure atomic flip.
  - Wire the repository into the DI barrel exports: confirm `src/infrastructure/database/prisma/repositories/index.ts` exports the new class, and ensure `AppDependencies` object in application layer has an instance created. (If no container exists today, use the same direct instantiation pattern as the existing drawer sensor Prisma repository — instance created inside controller methods.)
- **Acceptance Criteria Addressed**: AC-17, FR-5
- **Test Requirements**:
  - `rule` TR-4.1: All 5 interface methods compile with no TS errors.
  - `rule` TR-4.2: `markManyAsSentInTransaction` uses Prisma `$transaction` OR `updateMany` in a single call (either is OK).
  - `rubric` TR-4.3: Fidelity to existing Prisma repository patterns. Scale 1-5, threshold >= 4.

## Task 5: Create application use-cases (CreateDrawerOpenCommand, GetPendingDeviceCommands, AcknowledgeDeviceCommandResult)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 4, Task 2
- **Description**:
  - Create 3 files under `src/application/use-cases/` following the same pattern as existing 6 device use-cases.
  - `CreateDrawerOpenCommand`:
    - Dependencies injected constructor: IDrawerRepository, IMedicineBoxRepository, IDeviceCommandRepository (or direct instantiation following existing pattern).
    - Async execute(userId, drawerId, reason? optional):
      (1) drawer = findById(drawerId). null → NotFoundError 404.
      (2) box = findById(drawer.medicineBoxId). null OR box.userId !== userId → NotFoundError 404 (obscurity, NOT 403).
      (3) if box.deviceId is null/whitespace → BadRequestError 400 with message "Cannot open drawer: the MedicineBox has no deviceId associated; configure a device first".
      (4) create DeviceCommand with deviceId = box.deviceId, drawerId, type=OPEN_DRAWER, status=PENDING, reason = (reason ?? "MANUAL").
      (5) return created command.
  - `GetPendingDeviceCommands`:
    - Async execute(deviceId):
      (1) validate box = findByDeviceId(deviceId). null → NotFoundError 404.
      (2) commands = repo.findPendingByDeviceId(deviceId) where status = PENDING.
      (3) if len > 0: markManyAsSentInTransaction(commands.map(c=>c.id)) — this is safe because it's idempotent: if status already SENT the updateMany data simply re-applies it.
      (4) return commands (sorted by createdAt ASC, oldest pending first).
  - `AcknowledgeDeviceCommandResult`:
    - Async execute(commandId, deviceId, status, error? optional):
      (1) cmd = repo.findById(commandId). null → NotFound 404.
      (2) if cmd.deviceId !== deviceId → ForbiddenError 403 `This command belongs to a different device; acknowledgement denied`.
      (3) switch status EXECUTED / FAILED. Any other string impossible because zod gates. But for safety: if not EXEC/FAILED → BadRequest 400.
      (4) update repo.updateResult: EXECUTED: status=EXECUTED, executedAt=now, error=null/empty. FAILED: status=FAILED, executedAt=null, error=passed error or keep original (either safe; documented behavior: FAILED sets error string).
      (5) return updated command.
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-12, AC-13, FR-6, FR-7, FR-8
- **Test Requirements**:
  - `rule` TR-5.1: All 3 use-case classes compile, correct imports of error classes.
  - `rule` TR-5.2: Ownership gating returns 404 (NotFoundError) for cross-user (not 403).
  - `rule` TR-5.3: findPendingByDeviceId return list NEVER contains rows with deviceId not matching parameter.
  - `rule` TR-5.4: After markManyAsSentInTransaction, repository direct select confirms status=SENT for returned ids.

## Task 6: Append Zod validators to existing validator files
- **Status**: `pending`
- **Priority**: medium
- **Depends On**: Task 1
- **Description**:
  - Edit `src/presentation/validators/drawers.validator.ts`, APPEND (not overwrite) new schemas:
    - `drawerOpenCommandSchema = z.object({ reason: z.string().max(200).optional().nullable() }).strict();`
  - Edit `src/presentation/validators/devices.validator.ts`, APPEND new schemas:
    - `getDeviceCommandsSchema = z.object({ deviceId: z.string().min(1) }).strict();`
    - `deviceCommandResultSchema = z.object({ deviceId: z.string().min(1), status: z.enum(['EXECUTED', 'FAILED']), error: z.string().max(1000).optional().nullable() }).strict();`
- **Acceptance Criteria Addressed**: AC-18, FR-9
- **Test Requirements**:
  - `rule` TR-6.1: All three new schemas parse valid JSON; `.strict()` rejects extra fields.
  - `rule` TR-6.2: deviceCommandResultSchema rejects status "OTHER", "pending", lowercase "executed".
  - `rubric` TR-6.3: Validator fidelity. Scale 1-5, threshold >= 4 (identical pattern to existing schemas in same file).

## Task 7: Append controller methods + new routes (literal-first order)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 5, Task 6
- **Description**:
  - Edit `src/presentation/controllers/DrawerController.ts`:
    - Add import of CreateDrawerOpenCommand use-case and repositories, plus `drawerOpenCommandSchema` import, plus formatZodErrors new tag literal `drawer-open`.
    - Add `async openDrawer(req: Request, res: Response, next: NextFunction)` method: resolve `req.params.drawerId`, validate body via schema with formatZodErrors tag `drawer-open`, create instance of use-case, call `execute(req.auth.userId, drawerId, reason?)`, respond 200 success envelope message `"Drawer open command created successfully"` with DTO keys commandId drawerId deviceId type status createdAt mapped from returned domain.
  - Edit `src/presentation/routes/drawer.routes.ts`:
    - Insert literal route `drawerRouter.post('/:drawerId/open', DrawerController.openDrawer)` BEFORE the generic `drawerRouter.route('/:id')...` line (drawer route `:id` is a param match; `/open` literal must precede it to avoid param hijack, identical pattern already used for drawer sensors route L25 today).
  - Edit `src/presentation/controllers/DevicesController.ts`:
    - Append two new methods: `async getPendingCommands(req, res, next)` and `async acknowledgeCommandResult(req, res, next)`. Reuse resolveRequestingDeviceId priority for cross-check. Add formatZodErrors two new literal tags `get-device-commands` and `device-command-result` for validator messages.
  - Edit `src/presentation/routes/devices.routes.ts`:
    - Append three new routes AFTER existing 6 routes:
      ```
      devicesRouter.get('/:deviceId/commands', DevicesController.getPendingCommands);
      devicesRouter.post('/commands/:commandId/result', DevicesController.acknowledgeCommandResult);
      ```
      (Note the different URL patterns: `/:deviceId/commands` vs `/commands/:commandId/result` to avoid overlap since one starts with a URL param `:deviceId` and the other starts with literal `commands` segment; they don't collide but ordering is still safe literal first.)
- **Acceptance Criteria Addressed**: FR-10, FR-11, FR-15
- **Test Requirements**:
  - `rule` TR-7.1: Express route mounts occur exactly at the three user-specified paths: `POST /api/drawers/:drawerId/open`, `GET /api/devices/:deviceId/commands`, `POST /api/devices/commands/:commandId/result`.
  - `rule` TR-7.2: Drawer open route is inserted BEFORE generic `/:id` so test request to `/open` does NOT fall into generic param route (causing wrong validator).
  - `rubric` TR-7.3: Controller fidelity (thin controller, logic in use-case). Scale 1-5, threshold >= 4.

## Task 8: Update DI / app dependencies (if required)
- **Status**: `pending`
- **Priority**: medium
- **Depends On**: Task 4, Task 5
- **Description**:
  - If the project uses a central dependency container / factory, instantiate `PrismaDeviceCommandRepository` and attach to the object used by controllers.
  - If not (the existing pattern for drawer sensors is direct instantiation inside controller methods), instantiate the repo and use cases the same way — do NOT introduce a new DI container.
- **Acceptance Criteria Addressed**: NFR-2
- **Test Requirements**:
  - `rule` TR-8.1: No new DI library installed. Package.json diff empty for new deps.
  - `rule` TR-8.2: Controller instantiation pattern matches existing pattern (exact same lines as the drawer sensor controller methods).

## Task 9: Create jest test suite drawer-open-command.spec.ts covering lifecycle and negative matrix
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 1-8 complete
- **Description**:
  - Create file `tests/drawer-open-command.spec.ts` following the same in-memory DB / real supertest / setupServer bootstrap pattern used by `tests/drawer-sensor.spec.ts` and `tests/device-heartbeat.spec.ts`.
  - At minimum 13 it-blocks (one per ACs 1-13), plus additional idempotency tests.
  - Positive lifecycle T1–T13 per spec FR-13.
  - Tests should exercise the full supertest HTTP layer so it tests route mounts, auth middleware, validator strictness, status codes exact, envelope shapes exact.
- **Acceptance Criteria Addressed**: AC-1 through AC-13, FR-13
- **Test Requirements**:
  - `rule` TR-9.1: Each it-block passes (all green), 0 flaky.
  - `rule` TR-9.2: At least 13 it-blocks minimum, covers positive lifecycle plus each negative gate from error matrix (400/401/403/404).
  - `rubric` TR-9.3: Test fidelity (setup/teardown identical to existing tests, no new patterns introduced). Scale 1-5, threshold >= 4.

## Task 10: Pipeline verification (tsc strict, build, full jest suite 528+N green, no regression)
- **Status**: `pending`
- **Priority**: high
- **Depends On**: Task 9
- **Description**:
  - Run 4 commands in sequence, each must exit 0:
    (1) `npx prisma validate`
    (2) `npx tsc --noEmit -p tsconfig.json`
    (3) `npx jest --colors=false` (all suites)
    (4) `npm run build`
  - Forbidden grep: verify NO source file in src/ contains the forbidden patterns (WebSocket/MQTT/Redis/FCM etc.) from non-goals.
  - Verify migration deploy exit 0 (Task 2 evidence) was already captured.
- **Acceptance Criteria Addressed**: AC-15, NFR-1, NFR-3
- **Test Requirements**:
  - `rule` TR-10.1: All 4 commands exit 0.
  - `rule` TR-10.2: Jest suite >= 528 existing + at least 13 new tests passing, 0 failing.
  - `rule` TR-10.3: Forbidden grep zero matches for push/MQTT/WS (proves non-goals enforced).

## Task 11: Update the authoritative Postman guide .txt with TEST #9 / #10 / #11 (1 file only, no duplicates)
- **Status**: `pending`
- **Priority**: medium
- **Depends On**: Task 10 passes
- **Description**:
  - Open project root `RASPBERRY_PI_BACKEND_POSTMAN_TEST_GUIDE.txt`.
  - Insert a new section after the existing TEST #8 `MOBILE: SINGLE DRAWER SENSOR STATE (optional drawer view)` to append tests #9, #10, #11 as per §15 natural language spec.
  - Each of #9, #10, #11 follows the EXACT same structural section format as #1..#8: METHOD, FULL URL, AUTH pattern (A=JWT B=device body/query), HEADERS, BODY JSON, POSTMAN STEPS 1–10, EXPECTED HTTP STATUS, EXPECTED RESPONSE (full data inside envelope), DATABASE EFFECT with real Prisma model field names, Positive/Negative sub-tests (A/B/C/...), CURL equivalents.
  - Update §20 FINAL POSTMAN CHECKLIST appending new checkboxes for #9/#10/#11 exactly matching the natural language.
  - Update §22 SCOPE SUMMARY counts: endpoints documented from 9 → 12, add "Draw Open / Command API" feature group.
  - After edit, confirm Glob for `*.txt` on project root returns exactly 1 file.
- **Acceptance Criteria Addressed**: AC-16, FR-14, NFR-8
- **Test Requirements**:
  - `rule` TR-11.1: Glob `**/*.txt` in project root returns exactly 1 file (still RASPBERRY_PI_BACKEND_POSTMAN_TEST_GUIDE.txt, no new .txt created elsewhere).
  - `rule` TR-11.2: Grep for TEST #9 / #10 / #11 sections present with correct URL patterns.
  - `rubric` TR-11.3: Documentation fidelity (identical structural template to existing tests 1–8, same step list, same success criteria, same common errors). Scale 1-5, threshold >= 4.

## (Post-Implement) Review Issue Template (unused during plan, used only if failed review)

## Issue I-1: [placeholder]
- **Status**: `pending`
- **Priority**: high
- **Depends On**: None
- **Discovered By**: Review R1
- **Description**:
  - [finding here]
- **Acceptance Criteria Addressed**: [AC IDs]
- **Test Requirements**:
  - `rule` TR-I-1.1: [Binary condition]
- **Notes**: Only filled if failed review findings need remediation.

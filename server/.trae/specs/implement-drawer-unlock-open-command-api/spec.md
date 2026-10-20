# Smart Medicine Box - Drawer Unlock / Open Command API Product Requirements Document

## Overview

- **Summary**: Implement a secure REST-based drawer unlock command workflow for the existing Smart Medicine Box backend. Authenticated Flutter users create an `OPEN_DRAWER` PENDING command for a drawer; the Raspberry Pi polls a dedicated device endpoint to receive pending commands, marks them SENT when retrieved, then reports EXECUTED / FAILED result back with optional error. The whole lifecycle is persisted in a dedicated PostgreSQL table via Prisma. Existing APIs (heartbeat, face-*, schedule, medication-events, sensors, mobile sensor GETs) remain 100% backward compatible with unchanged contracts.
- **Purpose**: Add the missing Mobile → Backend → Raspberry Pi command channel for physical drawer unlock, which is required for remote manual open, caregiver-assisted open, and emergency open flows.
- **Target Users**: End users / caregivers via Flutter mobile app (Bearer JWT authenticated, ownership-gated), and trusted Raspberry Pi hardware devices (device identified by current resolveRequestingDeviceId body/query pattern, no new X-Device headers).

## Goals

- Expose `POST /api/drawers/:drawerId/open` for Flutter mobile to create a new PENDING `OPEN_DRAWER` DeviceCommand record, validated for drawer existence, MedicineBox ownership, MedicineBox.validDeviceId presence.
- Expose `GET /api/devices/:deviceId/commands` for Raspberry Pi polling (REST only, no push infrastructure added). Returns only pending commands for the EXACT deviceId requested; flips each returned command status atomically from PENDING→SENT so repeat polls do not duplicate work.
- Expose `POST /api/devices/commands/:commandId/result` for Raspberry Pi to report final lifecycle status (EXECUTED / FAILED with optional error string). Cross-device command acknowledgement is rejected with 403 because device must match command.deviceId.
- Enforce complete lifecycle PENDING→SENT→EXECUTED or PENDING→SENT→FAILED, never mark EXECUTED from Flutter creation endpoint (only Pi can confirm motor result).
- Add Prisma model `DeviceCommand`, enums `DeviceCommandType { OPEN_DRAWER }` and `DeviceCommandStatus { PENDING SENT EXECUTED FAILED EXPIRED }` following existing Prisma conventions; safe migration with FKs to MedicineBox.deviceId, Drawer.id cascade delete.
- Integrate with existing architecture: domain entity/repository interfaces, Prisma repository implementation, 3 dedicated use-case classes, Zod validators in existing validator files, controller methods appended to existing DrawerController and DevicesController, routes appended to existing drawerRouter and devicesRouter (literal-first order so no param hijack on drawers `:id` route).
- Pass full TypeScript strict (noEmit) + existing jest 528 tests green + new jest test suite for drawer-open command flow + zero existing regression.
- Update the authoritative Postman test guide `.txt` with TEST #9/10/11 so manual testers can run the complete end-to-end flow.

## Non-Goals

- No WebSocket, SSE, MQTT, Rabbit, Redis pub/sub, FCM/APNs push, or any other real-time infrastructure (backend remains REST-only as per current architecture).
- No automatic MedicationSession creation and NO DrawerMedication.quantity decrement when a drawer is opened. Those side effects remain EXCLUSIVE to the existing `POST /api/devices/medication-events` flow after the Pi independently determines medication was actually consumed.
- No X-Device-Id / X-Device-Token header middleware added (keeps current resolveRequestingDeviceId priority per DevicesController SECURITY LIMITATION comment).
- No new drawer-motor / relay / GPIO abstraction on the backend side. Backend only persists commands, does not control hardware.
- No new Prisma enum for drawer-open reason values. Reason is a free-form optional nullable String with default MANUAL if omitted, no strict enum validation (per spec §12 Do not hard-code restrictive enum).
- No automatic command expiry daemon / scheduled jobs for EXPIRED status (column exists, lifecycle rules documented, future scheduler can flip it; no cron implemented today).
- No delta / since / limit parameters on GET commands endpoint (returns all pending for device today; optional limit can be added later but not in this spec).
- No additional notification infrastructure (FCM, SMS) for command results (Flutter polls existing endpoints if needed).

## Background & Context

- The existing backend already exposes 6 device endpoints under `/api/devices/*` documented in the authoritative Postman guide: heartbeat, face-reference GET, face-verification POST, schedule GET, medication-events POST, sensor-readings POST.
- Mobile side has 2 requireAuth JWT-protected sensor GETs: `/api/medicine-boxes/:id/sensors` (inserted before generic `:id` so literal-first route order) and `/api/drawers/:id/sensors`.
- Existing security patterns used for ownership gating: `findByIdAndUserId(boxId, userId)` returns NotFoundError 404 if the JWT user does not own the row (security by obscurity; attackers guessing foreign UUIDs get generic NotFound not Forbidden). Drawer ownership validated via Drawer.medicineBox → MedicineBox.userId chain.
- Device identification pattern today (DevicesController.ts L1–L93): `resolveRequestingDeviceId(req)` priority: `req.deviceId (future middleware, empty today) → req.query.deviceId → req.body.deviceId`. No header middleware. We reuse this exact priority for all new device command endpoints, adding zero new header requirements.
- Standard response envelope from `okPublic()` helper / `errorMiddleware.ts` is mandatory for all new endpoints. `{ status, statusCode, data }` success shape for 2xx; `{ status: 'fail'|'error', statusCode, message }` for 4xx/5xx.
- Validators already live in a single file pattern: `devices.validator.ts` for device routes, `drawers.validator.ts` for drawer routes (we append new schemas).
- Jest test suites already exist for 8 feature groups with 528 tests total; we add a dedicated 9th drawer-open-command spec file with positive/negative lifecycle tests.

## Functional Requirements

- **FR-1**: New Prisma enum `DeviceCommandType` with value `OPEN_DRAWER`; new enum `DeviceCommandStatus` with values `PENDING SENT EXECUTED FAILED EXPIRED`.
- **FR-2**: New Prisma model `DeviceCommand` with fields: `id uuid PK`, `deviceId String FK to MedicineBox.deviceId (non-null)`, `drawerId String? FK to Drawer.id (nullable for future commands unrelated to a drawer)`, `type DeviceCommandType`, `status DeviceCommandStatus`, `reason String?`, `createdAt DateTime now()`, `sentAt DateTime?`, `executedAt DateTime?`, `error String?`. Indexes: `@@index([deviceId, status])` for fast pending scans; `@@index([drawerId, createdAt])` for drawer history. FK `deviceId` references MedicineBox.deviceId which already has a `@unique` constraint on the Prisma model so FK target is valid.
- **FR-3**: Supabase-safe idempotent migration SQL created under `prisma/migrations/<timestamp>_add_device_command/migration.sql`. Cannot use `ADD CONSTRAINT IF NOT EXISTS` because PG pooler target is < PG15 so uses the project's established 3-statement safe idempotent pattern used in migration 0014 (CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS, DO $$ BEGIN IF NOT EXISTS for FK checks).
- **FR-4**: Domain layer at `src/domain/entities/DeviceCommand.ts` class matching model fields; `src/domain/repositories/IDeviceCommandRepository.ts` interface with typed methods: `create(data:CreateDeviceCommandData):Promise<DeviceCommand>`, `findPendingByDeviceId(deviceId,{markSent?:boolean} in transaction)`, `findById(commandId)`, `updateResult(commandId, {status, error?, executedAt?})`, `markManySentInTx(ids[])` for atomic PENDING→SENT.
- **FR-5**: Infrastructure layer `PrismaDeviceCommandRepository.ts` implementing the above with safe FK lookups using `toDomainDeviceCommand()` mapper.
- **FR-6**: Application use-case `CreateDrawerOpenCommand` for mobile API flow: takes { userId, drawerId, reason? optional }, performs the 4 ownership/validity gates in order: drawer exists 404 → drawer's MedicineBox exists + userId owns it 404 → MedicineBox.deviceId is non-empty 400 (reason: device must be associated with box to receive commands) → creates DeviceCommand with type OPEN_DRAWER status PENDING, returns the created row.
- **FR-7**: Application use-case `GetPendingDeviceCommands` for device polling: validates deviceId exists → MedicineBox.row found with that deviceId (404 else), returns only pending commands, ATOMICALLY marks all returned commands status PENDING→SENT + populates sentAt=now() inside a Prisma $transaction so second poll within same millisecond doesn't double-return SENT rows. The returned array NEVER contains rows from a different deviceId.
- **FR-8**: Application use-case `AcknowledgeDeviceCommandResult`: validates commandId exists 404 → validates body.deviceId matches command.deviceId 403 Forbidden if mismatch (cross-device protection) → validates status enum is exactly EXECUTED or FAILED (400 else) → updates: if EXECUTED { status=EXECUTED, executedAt=now(), error=undefined/null clear if previous non-empty }; if FAILED { status=FAILED, error=body.error optional string, executedAt=null }. Updates are idempotent so Pi can retry result report.
- **FR-9**: Zod validators added to existing validator files: (a) `drawers.validator.ts` append `drawerOpenCommandSchema = z.object({ reason?: z.string().optional().nullable(), ...strict() })`. (b) `devices.validator.ts` append `getDeviceCommandsSchema deviceId param non-empty string`, `deviceCommandResultSchema deviceId non-empty, status z.enum(['EXECUTED','FAILED']), error?: z.string().max(1000).optional()`, all schemas use `.strict()` per project convention.
- **FR-10**: DrawerController new method `openDrawer(req,res)` mounted as `POST /api/drawers/:drawerId/open` on the existing drawerRouter. Route inserted as literal-first BEFORE the generic `drawerRouter.route('/:id')...` line (so param-hijack cannot happen; matches existing pattern for sensors route at drawer.routes.ts L25 today). Controller uses `requireAuth` (automatically applied whole router, so no duplicate wrapper), calls CreateDrawerOpenCommand, responds with success envelope message `Drawer open command created successfully` + keys `{ commandId drawerId deviceId type status createdAt }` exactly as user example in §5 of the natural language spec.
- **FR-11**: DevicesController new methods `getPendingCommands` + `acknowledgeCommandResult` mounted on existing devicesRouter (routes appended after existing 6 so 9th/10th/11th overall). Method bodies follow the EXACT SECURITY LIMITATION pattern: resolveRequestingDeviceId priority order unchanged. GET responds with `data: { commands: [...] }` each command row contains `commandId type drawerId reason createdAt` per user §6 example. Result POST responds with message `Command result updated successfully` + data `{ commandId status }`.
- **FR-12**: No existing API contract is modified. Verify this with the existing 528 jest baseline suite pass and diff check showing only new route appends / new controller methods / no existing method edits.
- **FR-13**: Jest tests created in a new `tests/drawer-open-command.spec.ts` file covering (minimum 9 tests) the complete lifecycle: T1 Flutter open-drawer valid JWT creates PENDING row, T2 JWT missing 401, T3 foreign-user drawer 404, T4 no-device-associated box 400, T5 Pi GET pending returns row and flips to SENT (repeat poll returns empty not duplicate), T6 nonexistent deviceId 404 GET commands, T7 Device-A cannot GET Device-B commands (empty result, no leak), T8 result POST EXECUTED updates DB correctly with executedAt, T9 result POST FAILED with error string stored executedAt null, T10 wrong device result 403, T11 nonexistent command result 404, T12 invalid status string OTHER 400 validator, T13 command creation does NOT create MedicationSession row and does NOT decrement DrawerMedication.quantity (assertion via direct prisma select count after call).
- **FR-14**: Authoritative Postman documentation file `RASPBERRY_PI_BACKEND_POSTMAN_TEST_GUIDE.txt` is UPDATED (not a second parallel file, no new .txt created, not markdown) with new TEST #9 / TEST #10 / TEST #11 exactly matching the natural language §15 Postman specification, including cURL equivalents for each new endpoint, and the command lifecycle PENDING → SENT → EXECUTED diagram. The §20 final TEST CHECKLIST appends the 3 new tests.
- **FR-15**: Endpoint route paths match EXACTLY the natural language: `POST /api/drawers/:drawerId/open`, `GET /api/devices/:deviceId/commands`, `POST /api/devices/commands/:commandId/result`. Note the difference between the two device routes: one has a URL param `:deviceId` the other a URL param `:commandId` — they are separate routes, NOT mounted under a common `/commands/:deviceId` path (per §6/§7 URLs provided verbatim from user input).

## Non-Functional Requirements

- **NFR-1 Code quality**: Strict TypeScript strict mode (noEmit) passes with zero errors. All new TS files follow the project's path alias pattern (`@domain`, `@application`, `@infrastructure`, `@presentation`, `@shared`). No `// @ts-ignore`, no `any` except where explicitly used in existing codebase patterns.
- **NFR-2 Architecture fidelity**: New code follows the project's 4-layer Clean Architecture exactly. Domain depends on nothing. Application depends only on domain interfaces. Infrastructure depends on Prisma / domain interfaces. Presentation depends on application / shared error classes. Zero new business logic inside controller methods (controllers only do: validate → resolve IDs → call use case → format response → throw/ok).
- **NFR-3 Zero regression**: Existing jest suite 528 tests PASS without modification (unless a bug is found in existing code). `npm run build` exits with 0.
- **NFR-4 Database safety**: Migration deployed to Supabase via `npx prisma migrate deploy` with exit 0; no existing row deleted, no destructive ALTER commands. DO$$ pattern used for FK per PG<15 limitation documented in the project's baseline.
- **NFR-5 Error consistency**: All gate errors use existing Shared error classes (`BadRequestError`, `UnauthorizedError`, `ForbiddenError`, `NotFoundError`, `ConflictError`). Existing errorMiddleware maps these classes to correct envelope HTTP codes: 400/401/403/404/409/500. Zod validator failures are routed through existing `formatZodErrors` branch for their respective controller with the literal tag pattern.
- **NFR-6 Security**: Drawer open endpoint cannot leak existence of another user's drawer (must return NotFound 404, NOT 403). Pi cross-device acknowledgements return explicit 403 (the case where device identity is already resolved to a specific device and tries to ack a command owned by another).
- **NFR-7 Idempotency**: Result POST / repeated poll GET are idempotent operations. Duplicate polls do not create new rows; duplicate result submissions do not throw.
- **NFR-8 Postman documentation completeness**: Updated Postman .txt contains EXACT sample JSON payloads, expected statuses, expected DB effects, exact example cURL lines, step-by-step 10-step Postman sections for the 3 new tests as per the original file's convention for existing tests 1–8.

## Constraints

- **Technical**: Node.js 20 LTS; Express 5.x; TypeScript 5.x; Prisma 5.22.0 exactly (no upgrade); PostgreSQL on Supabase PG<15 via PgBouncer pooler so ADD CONSTRAINT IF NOT EXISTS unsupported; REST only (no WS/MQTT).
- **Business**: Do not modify existing API contracts of 8 documented endpoints. Do not introduce side effects like automatic MedicationSession/DrawerMedication writes (§13). Existing ownership/validator patterns must be followed verbatim.
- **Dependencies**: Existing 4-layer architecture + repositories already in place. Existing domain entity pattern already established for DrawerSensorState (mirror for DeviceCommand). Existing DrawerByIdAndUserId lookup pattern in drawer.controller.ts re-used verbatim.
- **Process**: Strict Spec Mode lifecycle: spec.md → tasks.md → user approval → implement → review.md → final report. No implementation proceeds before explicit approval.
- **Migration**: No `prisma migrate reset`. No destructive statements. Deploy via `prisma migrate deploy` only.

## Assumptions

- The MedicineBox table's existing `deviceId` column has `@unique` and all devices associated with open commands have `deviceId` SET on the MedicineBox row (this is validated with 400 gate per FR-6 if unset).
- The Raspberry Pi polling interval is managed by the Pi firmware and is not backend-configured in this feature. Backend supports 1 poll/s without performance concerns at this scale.
- Supabase storage / bucket setup is irrelevant for this feature.
- No additional seed data required; test suite uses existing jest in-memory SQLite / or the established mocked prisma pattern from other spec test files.

## Acceptance Criteria

### AC-1: Flutter creates OPEN_DRAWER PENDING command with ownership gates

- **Type**: `rule`
- **Given**: Valid JWT for user A, valid drawerId D1 that belongs to user A's MedicineBox MB1 with MB1.deviceId non-empty.
- **When**: POST `{{baseUrl}}/api/drawers/D1/open` `{ "reason":"MEDICATION_TIME" }`.
- **Then**: HTTP 200 success envelope with message `Drawer open command created successfully`, data containing `commandId drawerId deviceId type=OPEN_DRAWER status=PENDING createdAt`. Device table DeviceCommand contains 1 new row deviceId=MB1.deviceId, type OPEN_DRAWER status=PENDING, drawerId=D1, reason=MEDICATION_TIME.
- **Pass Condition**: New row exists with correct fields. No MedicationSession inserted. DrawerMedication.quantity unchanged.
- **Evidence**: Jest tests T1 + T13 assertions + prisma select count. DB verification via Prisma Studio documented in updated Postman guide.

### AC-2: Cross-owner drawer is 404 not 403

- **Type**: `rule`
- **Given**: User A's JWT. Drawer D2 belongs to User B's MedicineBox.
- **When**: User A calls POST open-drawer with D2.
- **Then**: HTTP 404, response status 'fail', message is generic NotFound drawer/box not found.
- **Pass Condition**: No DeviceCommand row created. Error status code 404 exact.
- **Evidence**: Jest T3.

### AC-3: Box without deviceId associated → BadRequest 400

- **Type**: `rule`
- **Given**: Valid drawer owner, MB row deviceId is null.
- **When**: Call POST drawer open.
- **Then**: HTTP 400, message states deviceId not associated with the MedicineBox.
- **Pass Condition**: No command created. Status 400 exact.
- **Evidence**: Jest T4.

### AC-4: JWT missing/invalid drawer open → 401

- **Type**: `rule`
- **Given**: No auth header or tampered JWT.
- **When**: POST drawers/D1/open.
- **Then**: HTTP 401 Unauthorized (exact UnauthorizedError path, not generic 500).
- **Pass Condition**: Status 401 exact. Middleware returns before controller invocation.
- **Evidence**: Jest T2.

### AC-5: Raspberry Pi polls PENDING commands → returned + atomically flipped SENT

- **Type**: `rule`
- **Given**: Exactly 1 PENDING OPEN_DRAWER command exists for deviceId PI-DEV-001.
- **When**: First call GET `/api/devices/PI-DEV-001/commands`.
- **Then**: HTTP 200 data.commands = [ { commandId, type: "OPEN_DRAWER", drawerId: D1, reason, createdAt } ]. After the call completes, DB DeviceCommand.status = SENT, sentAt non-null.
- **Pass Condition**: Second identical call returns data.commands = [] (not the same object again; no duplicate delivery).
- **Evidence**: Jest T5 (two sequential GETs; first call array len 1, second len 0; prisma assert status SENT).

### AC-6: Cross-device command isolation on GET

- **Type**: `rule`
- **Given**: Pending command for PI-DEV-A.
- **When**: GET /api/devices/PI-DEV-B/commands
- **Then**: 200 data.commands empty []; zero rows leaked.
- **Pass Condition**: Array length 0.
- **Evidence**: Jest T7.

### AC-7: Nonexistent deviceId on GET commands → 404

- **Type**: `rule`
- **Given**: No MB row with deviceId NO-SUCH-DEVICE.
- **When**: GET /api/devices/NO-SUCH-DEVICE/commands.
- **Then**: 404 NotFound.
- **Pass Condition**: Status 404 exact.
- **Evidence**: Jest T6.

### AC-8: Pi acknowledges EXECUTED result

- **Type**: `rule`
- **Given**: DeviceCommand C1 in status SENT with deviceId PI-DEV-001.
- **When**: POST `/api/devices/commands/C1/result` body `{ "deviceId":"PI-DEV-001", "status":"EXECUTED" }`.
- **Then**: HTTP 200 message "Command result updated successfully" data `{ commandId status }`. DB row: status=EXECUTED, executedAt=recent timestamp, error cleared if previously set.
- **Pass Condition**: DB updated correctly. Idempotent second POST yields same result without errors.
- **Evidence**: Jest T8 + double-send check.

### AC-9: Pi acknowledges FAILED result with error

- **Type**: `rule`
- **Given**: C1 status SENT.
- **When**: POST result `{ deviceId:..., status:"FAILED", error:"Motor jammed" }`.
- **Then**: DB status=FAILED, error="Motor jammed", executedAt=null.
- **Pass Condition**: executedAt remains null (not populated). Error string persisted correctly.
- **Evidence**: Jest T9.

### AC-10: Cross-device acknowledgement 403

- **Type**: `rule`
- **Given**: C1 owned by PI-DEV-001.
- **When**: POST result body `{ deviceId:"PI-DEV-002", status:"EXECUTED" }`.
- **Then**: HTTP 403 Forbidden. DB row untouched.
- **Pass Condition**: Status exact 403. Error message descriptive.
- **Evidence**: Jest T10.

### AC-11: Nonexistent command id result 404

- **Type**: `rule`
- **Given**: UUID 00000000-0000-0000-0000-000000000000.
- **When**: POST result.
- **Then**: 404 NotFound.
- **Evidence**: Jest T11.
- **Pass Condition**: exact 404 status.

### AC-12: Invalid status string → 400 validator

- **Type**: `rule`
- **Given**: Valid command, valid device. Body status "OTHER".
- **When**: POST result.
- **Then**: HTTP 400 from zod enum validator.
- **Evidence**: Jest T12.
- **Pass Condition**: exact 400, no DB change.

### AC-13: No automatic medication side effects (quantity decrement / session creation)

- **Type**: `rule`
- **Given**: DrawerMedication row D quantity=10, MedicationSession count=N.
- **When**: Run full lifecycle: Flutter create open → Pi GET pending → Pi result EXECUTED.
- **Then**: Select DrawerMedication quantity still = 10; MedicationSession count = N.
- **Pass Condition**: Zero changes to those two tables (proven in T13 direct prisma selects).
- **Evidence**: Jest T13 assertions.

### AC-14: Migration deployed Supabase deploy exit 0, safety pattern correct

- **Type**: `rule`
- **Given**: Migration file created with CREATE TABLE IF NOT EXISTS, CREATE UNIQUE INDEX IF NOT EXISTS, DO $$ BEGIN IF NOT EXISTS FK pattern.
- **When**: npx prisma migrate deploy.
- **Then**: Exit 0.
- **Evidence**: migrate deploy output. Prisma validate 0, generate 0.
- **Pass Condition**: No rollback needed, no P3018 error (FK applied correctly).

### AC-15: TypeScript strict + build + existing 528 jest suite all green

- **Type**: `rule`
- **Given**: All new files in place.
- **When**: (a) npx tsc --noEmit -p tsconfig.json, (b) npm run build, (c) npx jest all 16 suites.
- **Then**: (a) exit 0, (b) exit 0, (c) >= 528 + new tests added, all pass, 0 failing.
- **Evidence**: CLI output for all three commands.
- **Pass Condition**: Zero existing tests modified to pass (if existing tests had to change, that's a regression failure of this AC).

### AC-16: Updated Postman txt guide single authoritative file

- **Type**: `rule`
- **Given**: After implementation, project root `*.txt` Glob returns exactly 1 file.
- **When**: Grep for "TEST #9" and "OPEN_DRAWER" and "GET /api/devices/:deviceId/commands" in that .txt.
- **Then**: All three strings are present. Each of TEST #9/#10/#11 includes: Method, Purpose, Auth, Headers, JSON example, HTTP status, Response, DB effect, 10 Postman Steps, Success criteria, Common errors, cURL equivalent.
- **Pass Condition**: Glob exactly 1 .txt; grep strings present; sections follow existing TXT template structure 1-22.
- **Evidence**: Glob output + grep lines in evidence.

### AC-17: Architecture fidelity (4-layer separation)

- **Type**: `rubric`
- **Dimension**: How strictly does the new code follow the project's existing 4-layer Clean Architecture and path alias conventions?
- **Scale**: 1–5
- **Anchors**: 1 = business logic dumped in controllers, no domain interfaces, direct prisma calls everywhere; 3 = basic entities + repositories present but some logic leaked into controllers, some raw prisma calls outside repo layer; 5 = perfect separation: domain entities + repository interfaces at `@domain`, pure use-cases at `@application` depending only on interfaces, Prisma repos at `@infrastructure` implementing interfaces directly, presentation controllers only thin orchestration + validation.
- **Pass Threshold**: >= 4
- **Evidence**: Code review + file locations match exactly DrawerSensorState feature pattern (baseline existing feature for comparison drawer sensors).

### AC-18: Validator and error pattern fidelity

- **Type**: `rubric`
- **Dimension**: How closely do the new validators/error responses match the existing devices.validator / drawers.validator / formatZodErrors envelope conventions.
- **Scale**: 1–5
- **Anchors**: 1 = custom JSON response format, no zod, manual string parsing; 3 = zod used but loose, no strict() schema, inconsistent messages; 5 = schemas appended to EXISTING validator files under src/presentation/validators, use `.strict()` exact, enum validation matches existing zod enum pattern, formatZodErrors branch tags match existing verbatim literal pattern in the two controller files (DrawerController + DevicesController).
- **Pass Threshold**: >= 4
- **Evidence**: Diff of validator files (only appends) + controller formatZodErrors edits (new branches for drawer-open-schema literal and device-command-result-schema / get-commands literal tags).

## Open Questions

- [ ] **Optional limit / since on GET commands**: User spec §10 doesn't mention pagination. Assumed out of scope (return all pending). Confirm with user if limit should be enforced (e.g. 50 pending max) — default: no, return all pending.
- [ ] **EXPIRED auto-flip**: Column exists per enum but no scheduler. User spec §4 proposed EXPIRED but §8 lifecycle only documents PENDING/SENT/EXECUTED/FAILED. Assumed no background scheduler in this feature release. Acceptable to leave EXPIRED as manual/DBA state for now.
- [ ] **Open Questions closed only upon explicit user response or default assumption acceptance.** Approval of the spec implies agreement with the documented default assumptions above.

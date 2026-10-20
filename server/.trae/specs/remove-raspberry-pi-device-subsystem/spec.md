# SPEC: Remove Raspberry Pi / Physical Device Subsystem

## 1. Problem

The backend project still contains a complete **Raspberry Pi / Medicine Box physical device communication layer** built in earlier steps (Steps 0–4A incl. DHT22/Quantity telemetry, device heartbeat, dispensing events, `X-Device-Id` / `X-Device-Token` authentication, `lastSeenAt`, `deviceStatus`, `DispensingEvent` table, Postman guide, and Jest suites).

The user now wants this subsystem **completely removed** while preserving **all Flutter-facing medication-management functionality** (authentication, users, patients, medications, schedules, medicine-box CRUD, drawer provisioning, drawer medication assignment, Medication Session domain).

## 2. Goals

- **Remove all Raspberry Pi–device-only endpoints, middleware, controllers, validators, use cases, repositories, domain entities, tests, docs, and seed/smoke data.**
- **Remove exclusively-device-related Prisma models, enums, fields, relations, and indexes** via a new safe incremental Prisma migration.
- Preserve every unrelated backend feature (Flutter JWT auth, users, patients, medications, schedules, medicine-box user/CRUD/admin CRUD, drawer provisioning, drawer medication CRUD, Medication Session domain entities/repos).
- After cleanup, produce **passing prisma validate / tsc strict / build / jest / global grep for leftover Raspberry strings**.

## 3. Non-Goals

- **DO NOT** delete medicine-box business features for Flutter (Add / Activate / Unassign / Update / Get etc.) even though they mention `deviceId`/`deviceToken` as activation key input from the app.
- **DO NOT** redesign MedicationSession, Drawer/DrawerMedication.
- **DO NOT** remove Supabase, Postgres, JWT, user/patient/medication flows.
- **DO NOT** remove the Schedule / MedicationSession domain (PATIENT_TAKEN / PATIENT_SKIPPED etc. inside the session layer remain).
- **DO NOT** leave dead imports, unmounted routers, empty controllers, or unused repo method signatures behind.

## 4. Requirements (Functional)

### 4.1 Endpoints

- Delete all routes mounted at `/api/devices` including:
  - POST /api/devices/heartbeat
  - POST /api/devices/telemetry/dht22
  - POST /api/devices/telemetry/quantity
  - POST /api/devices/events/dispensing
- Remove the router registration `app.use('/api/devices', devicesRouter)` and import.

### 4.2 Device Authentication

- Remove file `deviceAuthMiddleware.ts` (`requireDeviceAuth`, `DeviceIdentity` Request augmentation).
- Remove repo methods that exist only for device auth (`verifyDeviceCredentials`).

### 4.3 Heartbeat / Device Connectivity

- Delete `DeviceHeartbeat.ts` UC.
- Remove heartbeat-only repo methods (`touchLastSeenAndSetActiveByDeviceId`, `markDeviceSeen`, `DeviceHeartbeatResult`, `MarkDeviceSeenResult`).
- Remove DB fields from MedicineBox: `deviceStatus`, `lastSeenAt`, enum `DeviceStatus` itself (remove if not referenced elsewhere).

### 4.4 Physical Telemetry (DHT22 / Quantity)

- Remove ReportDrawerDHT22 + ReportDrawerQuantity use cases.
- Remove related DevicesController methods.
- From Drawer entity/repo/prisma: remove `temperature`, `humidity`, `reportDHT22()` repo interface method.

### 4.5 Dispensing Event system

- Delete `DispensingEvent` domain entity + `IDispensingEventRepository` interface + `PrismaDispensingEventRepository`.
- Delete `ReportPhysicalDispensingEvent` UC.
- Remove `DispensingEvent` Prisma model + enum `PhysicalDeviceEvent`.
- Remove virtual back-references `dispensingEvents[]` from MedicineBox + Drawer in Prisma schema.
- Remove `ReportPhysicalDispensingResult` + `reportPhysicalDispensing()` method from `IDrawerMedicationRepository` and Prisma impl.

### 4.6 Device-only fields still on MedicineBox (careful split)

MedicineBox currently has device-related fields. **Decision rules** for each field:

- If the field is used ONLY by the Raspberry Pi physical subsystem → REMOVE.
- If the field is also used by Flutter-facing business features (provisioning / activation key / UI listing) → PRESERVE.

Classification:

| Field                         | Preserved / Removed | Rationale                                                                                                                               |
| ----------------------------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `MedicineBox.id`              | ✅ KEEP             | PK                                                                                                                                      |
| `deviceId`                    | ✅ KEEP             | Used by ActivateMedicineBox (Flutter sends deviceId+token to provision), AddMedicineBox admin flow, and repo.findByDeviceId             |
| `deviceToken`                 | ✅ KEEP             | ActivateMedicineBox validates token match (Flutter-side pair)                                                                           |
| `status (MedicineBoxStatus)`  | ✅ KEEP             | Admin/CRUD/Activate/Unassign flows READY/ACTIVE/MAINTENANCE                                                                             |
| `deviceStatus (DeviceStatus)` | ❌ REMOVE           | Only used by Pi heartbeat/lastSeen/telemetry marking device ACTIVE/OFFLINE. No Flutter/UC non-device code path reads this after cleanup |
| `lastSeenAt`                  | ❌ REMOVE           | Same                                                                                                                                    |
| `userId`                      | ✅ KEEP             | Ownership                                                                                                                               |
| `numberOfDrawers`             | ✅ KEEP             | Drawer provisioning                                                                                                                     |
| `drawerCapacity`              | ✅ KEEP             | Drawer capacity validation in medication assignment                                                                                     |
| `createdAt/updatedAt`         | ✅ KEEP             |                                                                                                                                         |

Enum classification:

| Enum                                                                 | Preserved / Removed        | Rationale                                                                                                                                                                           |
| -------------------------------------------------------------------- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MedicineBoxStatus`                                                  | ✅ KEEP                    | READY/ACTIVE/MAINTENANCE still used by CRUD/Activate                                                                                                                                |
| `DeviceStatus`                                                       | ❌ REMOVE                  | only heartbeat/telemetry/physical ops                                                                                                                                               |
| `PhysicalDeviceEvent`                                                | ❌ REMOVE                  | DispensingEvent only                                                                                                                                                                |
| `MedicationSessionResult` with `DISPENSING_FAILED`, `DEVICE_FAILURE` | ✅ KEEP + review carefully | Keep as Session domain classification enum — it's business logic classification, not the Raspberry PHYSICAL enum. Physical enum PhysicalDeviceEvent already separate & gets deleted |
| `DrawerStatus` EMPTY/LOADED/LOCKED/DISPENSING/ERROR                  | ✅ KEEP                    | Drawer state still referenced by domain provisioning / UC                                                                                                                           |

### 4.7 MedicationSession quantityBefore / quantityAfter

- Keep. These are session-biz-logic fields not the physical DispensingEvent ones. Not part of Raspberry subsystem.

### 4.8 Validators / Controllers / Routes cleanup

- Remove file `deviceTelemetry.validator.ts`
- Remove file `DevicesController.ts`
- Remove file `devices.routes.ts`
- Remove file `assertUsableForPhysicalOps.ts` (refers to deviceStatus ACTIVE offline check)
- Remove `deviceStatus` field from validator `adminUpdateMedicineBoxSchema`, remove reference import `DeviceStatus`.
- Update `PublicMedicineBox = Omit<MedicineBox, 'deviceToken'>` still remains (preserve because deviceToken stays, just internal).
- In Prisma MedicineBox repo: remove method bodies of deleted interface methods, keep methods still required by interface.

### 4.9 Tests

- Remove test files that are entirely device-subsystem:
  - `tests/device-heartbeat.spec.ts`
  - `tests/device-telemetry-dht22.spec.ts`
  - `tests/device-telemetry-quantity.spec.ts`
  - `tests/step4a-dispensing-events.spec.ts`
- Update mocks in remaining test suites that reference deleted repo interface methods (e.g. `MockDrawerMedRepo.reportPhysicalDispensing`, `IMedicineBoxRepo.markDeviceSeen / findByDeviceId still kept because AddMedicineBox/Activate still use findByDeviceId.

### 4.10 Documentation / Postman

- Delete `RASPBERRY-PI-POSTMAN-TESTS.txt`
- Delete `TEST-ENDPOINTS.txt` if it contains `/api/devices` routes OR clean those sections.
- Grep `README.md` / `.env.example` / docs for any Raspberry Pi device endpoints/instructions and remove only those lines.

### 4.11 Seed data cleanup

- Remove `PI-DEV-001` / `PI-SECRET-T0K3N` / `smoke-mb-pi-dev-001` / `0ce917ee-88ae-4005-aa62-db4244e0fa1c` / `postman-started-001` etc. from smoke outputs (`_smoke_output.txt`, seed-admin.ts references if any, TEST-ENDPOINTS.txt).

## 5. Non-functional

- Final Jest exit 0.
- Final tsc --strict --noEmit exit 0.
- prisma validate, migrate status OK.
- Global grep of codebase for keywords shows zero Raspberry Pi–specific hits, excluding legitimate business concepts kept on purpose (MedicineBox/deviceId as provisioning identifier).
- No package.json deps removed unless provably unused — leave as-is unless tsc/jest are both unaffected.

## 6. Constraints & Assumptions

- NO `prisma migrate reset`. New migration 0010 in `prisma/migrations/0010_remove_device_fields/` only DROPs columns/tables/enums/indexes that are Raspberry Pi device-only.
- Keep `prisma/migrations/0001..0009` history intact. Don't edit old migration files.
- Keep MedicineBox/Drawer/DrawerMedication/Dht22Reading/QuantityReading tables if still referenced elsewhere. Specifically:
  - `Dht22Reading` KEEP or DELETE? Decision: DELETE model. Dht22 reading is pure Pi sensor telemetry — no Flutter non-device use case references Dht22 data.
  - `QuantityReading` KEEP or DELETE? Decision: DELETE. The use case is Raspberry device telemetry endpoint. There's no Flutter UI/non-device endpoint querying listQuantityReadings after removing the device telemetry.
  - Keep Drawer back-reference lists: remove dispensingEvents/Dht22Readings/quantityReadings once models drop.

## 7. Open Questions Resolved (default decisions)

1. Remove Drawer.temperature and Drawer.humidity fields? → YES, remove — only written via ReportDrawerDHT22 (device endpoint). No admin provisioning or Flutter assignment logic persists to them. This is a Raspberry Pi sensor reading only.
2. Keep MedicineBox.deviceId / deviceToken even without physical API? → YES, user spec says "Do not automatically delete all of them". Flutter ActivateMedicineBox flow still uses these fields as the activation key pair (admin provisions a box by deviceId/token, user activates by same). So keep.
3. Keep MedicationSession enum values that sound device-like (DISPENSING_FAILED/DEVICE_FAILURE)? → YES keep these, they are session business results (Step 4/Medication Session layer concept), not the raw hardware event. The physical event enum `PhysicalDeviceEvent` will still be removed; session result enum entries are not the same.

## 8. Acceptance Criteria (rule/rubric)

All AC below are **rule** type except the last which is rubric.

**AC-1 (rule)**. No route mounted at `/api/devices*` in `app.ts` or anywhere else. Verified by: grep of src for `/api/devices` returns empty; test for `devicesRouter` identifier absent.
**AC-2 (rule)**. `requireDeviceAuth` / `X-Device-Id` / `X-Device-Token` middleware file and all usages are absent. Verified by: global grep for these header names (excluding comments/.env we don't add, already excluded env vars, keep env values only if referenced from code now).
**AC-3 (rule)**. `DispensingEvent` Prisma model dropped and enum `PhysicalDeviceEvent` dropped. Verified by: grep schema.prisma → no match + prisma validate ok.
**AC-4 (rule)**. Prisma MedicineBox stripped of `deviceStatus`, `lastSeenAt`; `DeviceStatus` enum removed; migration 0010 applied (deployed locally) and prisma migrate status says DB up to date.
**AC-5 (rule)**. DevicesController, device routes, device telemetry validator, device auth middleware, device UCs (Heartbeat/DHT22/Quantity/ReportPhysicalDispensing) all files removed and no dead imports.
**AC-6 (rule)**. All Repository interface signatures updated: no `verifyDeviceCredentials`, no `markDeviceSeen`, no `touchLastSeenAndSetActiveByDeviceId`, no `reportPhysicalDispensing`, no `reportDHT22`, no `listQuantityReadings`, no `reportCurrentQuantity`, no `findActive...` if only used by device. Verified by tsc strict 0.
**AC-7 (rule)**. Files device-heartbeat.spec.ts, device-telemetry-dht22.spec.ts, device-telemetry-quantity.spec.ts, step4a-dispensing-events.spec.ts deleted, RASPBERRY-PI-POSTMAN-TESTS.txt deleted.
**AC-8 (rule)**. Jest suite (15 suites before Step4 added → after removal → number of suites correct for remainder, 0 failed).
**AC-9 (rule)**. `npm run build` OR `tsc --strict --noEmit` returns 0 (both, if build exists in package.json).
**AC-10 (rule)**. Global grep of project files (excluding `node_modules`, `.env` private values — but not strings in TS/JS/TXT/README) for these keywords returns NO matches that are Raspberry Pi device–specific: `raspberry`, `PI-DEV-001`, `PI-SECRET-T0K3N`, `smoke-mb-pi-dev-001`, `X-Device-Id`, `X-Device-Token`, `DISPENSING_STARTED`, `DISPENSING_SUCCESS`, `DISPENSING_FAILED` (except MedicationSessionResult enum values, which are legitimate keep), `dispensing` except session-result only; `lastSeenAt`, `deviceStatus`. Exception: any kept `deviceId`/`deviceToken` identifiers as provisioning fields in MedicineBox ARE ALLOWED (Activation flow/Admin CRUD).
**AC-11 (rubric)**. No dead code left behind. Scale 0-2. 2 = no unused imports, no empty controllers, no unused method signatures in interfaces; 1 = 1-2 minor harmless dead lines; 0 = >2 dead code.

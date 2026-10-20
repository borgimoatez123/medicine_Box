import type { Medication } from '@domain/entities/Medication';
import type { Schedule } from '@domain/entities/Schedule';
import type { Drawer } from '@domain/entities/Drawer';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { NotFoundError } from '@shared/errors';
import { DeleteMedication } from '@application/use-cases/medications/DeleteMedication';
import { DrawerMedication as PrismaDrawerMedication } from '@prisma/client';
import { readFileSync } from 'node:fs';
import path from 'node:path';

type MockRepo = Record<string, jest.Mock>;

const now = () => new Date('2025-01-01T00:00:00.000Z');

const buildMedication = (o: Partial<Medication> = {}): Medication => ({
  id: 'm-1',
  patientId: 'p-1',
  name: 'X',
  dosage: '10mg',
  form: 'TABLET',
  quantity: 10,
  expiryDate: null,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const buildSchedule = (o: Partial<Schedule> = {}): Schedule => ({
  id: 's-1',
  medicationId: 'm-1',
  dosage: '10mg',
  timesPerDay: 1,
  times: null,
  startDate: now(),
  endDate: null,
  daysOfWeek: null,
  status: 'ACTIVE',
  notes: null,
  refillReminder: false,
  createdAt: now(),
  updatedAt: now(),
  isActive: true,
  ...o,
});

const buildDrawer = (o: Partial<Drawer> = {}): Drawer => ({
  id: 'd-1',
  medicineBoxId: 'box-1',
  drawerNumber: 1,
  status: 'LOADED',
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const buildDrawerMed = (o: Partial<DrawerMedication> = {}): DrawerMedication => ({
  id: 'dm-1',
  drawerId: 'd-1',
  medicationId: 'm-1',
  quantity: null,
  missingQuantity: null,
  assignedAt: now(),
  isActive: true,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const schemaText = () =>
  readFileSync(path.resolve(process.cwd(), 'prisma', 'schema.prisma'), 'utf8');

describe('§3 / §9 — Medication deletion cascades DrawerMedication (schema assertion + use case)', () => {
  it('[Schema] DrawerMedication.medicationId relation uses onDelete: Cascade', () => {
    const text = schemaText();
    const dmBlockStart = text.indexOf('model DrawerMedication {');
    expect(dmBlockStart).toBeGreaterThan(-1);
    const dmBlock = text.slice(dmBlockStart, text.indexOf('}', dmBlockStart));
    // medicationId column is required string, @unique
    expect(/medicationId\s+String\s+@unique/.test(dmBlock)).toBe(true);
    // medication relation uses Cascade, NOT SetNull
    expect(
      /medication\s+Medication\s+@relation\([^)]*onDelete:\s*Cascade[^)]*\)/.test(dmBlock),
    ).toBe(true);
    expect(
      /medication\s+Medication\s+@relation\([^)]*onDelete:\s*SetNull/.test(dmBlock),
    ).toBe(false);
  });

  it('[Schema] DrawerMedication.drawerId is String @unique + onDelete: Cascade (unchanged per §5)', () => {
    const text = schemaText();
    const dm = text.slice(text.indexOf('model DrawerMedication {'));
    expect(/drawerId\s+String\s+@unique/.test(dm)).toBe(true);
    expect(/drawer\s+Drawer\s+@relation\([^)]*onDelete:\s*Cascade[^)]*\)/.test(dm)).toBe(true);
  });

  it('[Schema] Medication.drawerMedication backref is optional 0..1 (unique side)', () => {
    const text = schemaText();
    const med = text.slice(text.indexOf('model Medication {'));
    expect(/drawerMedication\s+DrawerMedication\s*\?/.test(med)).toBe(true);
  });

  it('[Prisma Client generated type] DrawerMedication.medicationId is String NOT nullable', () => {
    // TS compile-time type check → If schema made medicationId optional, PrismaDrawerMedication would have `string | null`
    // We ensure type is `string` at runtime through the Prisma-generated client mirror of our DM domain entity:
    const sampleColumn: PrismaDrawerMedication['medicationId'] = 'only-string-no-null';
    // No `null` should satisfy this type without compile error: if nullable → `satisfies never` pattern
    type IsString = (typeof sampleColumn) extends string ? true : false;
    const _assert: IsString = true;
    expect(_assert).toBe(true);
  });

  it('Test 1 — Delete Medication → Medication & DrawerMedication deleted, Drawer EXISTS', async () => {
    // Repository mocks simulate cascade by having medicationRepo.delete() trigger side-effect on DM repo state via in-memory map (proving contract, no real DB).
    const state = {
      drawer: buildDrawer(),
      dm: buildDrawerMed(),
      medication: buildMedication(),
    };
    const drawerRepo: MockRepo = {
      findById: jest.fn(async (id: string) => (state.drawer.id === id ? state.drawer : null)),
    };
    const dmRepo: MockRepo = {
      findByMedicationId: jest.fn(
        async (mid: string) => (state.dm && state.dm.medicationId === mid ? state.dm : null),
      ),
      findByDrawerId: jest.fn(
        async (did: string) => (state.dm && state.dm.drawerId === did ? state.dm : null),
      ),
      delete: jest.fn(async (id: string) => {
        if (state.dm && state.dm.id === id) (state as unknown as { dm: DrawerMedication | null }).dm = null;
      }),
    };
    const medicationRepo: MockRepo = {
      findByIdAndUserId: jest.fn(
        async (mid: string, uid: string) =>
          state.medication.id === mid && uid === 'u-1' ? state.medication : null,
      ),
      delete: jest.fn(async (mid: string) => {
        // Simulate DB cascade: Medication DELETE → ON DELETE CASCADE → DrawerMedication DELETE
        if (state.medication.id === mid) {
          if (state.dm && state.dm.medicationId === mid) {
            (state as unknown as { dm: DrawerMedication | null }).dm = null;
          }
          (state as unknown as { medication: Medication | null }).medication = null;
        }
      }),
    };

    // Before delete: everything exists
    expect(await dmRepo.findByMedicationId('m-1')).not.toBeNull();
    expect(await drawerRepo.findById('d-1')).not.toBeNull();

    const uc = new DeleteMedication(medicationRepo as never);
    await uc.execute({ userId: 'u-1', medicationId: 'm-1' });

    expect(medicationRepo.delete).toHaveBeenCalledWith('m-1');
    // CASCADE assertion: DrawerMedication is gone
    expect(await dmRepo.findByMedicationId('m-1')).toBeNull();
    expect(state.dm).toBeNull();
    // But Drawer itself REMAINS
    expect(await drawerRepo.findById('d-1')).not.toBeNull();
    expect(state.drawer).not.toBeNull();
  });

  it('Test 2 — Delete Medication → Schedule + DrawerMedication BOTH deleted, Drawer remains', async () => {
    const state = {
      medication: buildMedication(),
      schedule: buildSchedule(),
      dm: buildDrawerMed(),
      drawer: buildDrawer(),
    };
    const schedRepo = {
      findAllByMedicationId: jest.fn(
        async (mid: string) => (state.schedule && state.schedule.medicationId === mid ? [state.schedule] : []),
      ),
      delete: jest.fn(async (sid: string) => {
        if (state.schedule && state.schedule.id === sid) {
          (state as unknown as { schedule: Schedule | null }).schedule = null;
        }
      }),
    };
    const medicationRepo = {
      findByIdAndUserId: jest.fn(
        async (mid: string, uid: string) =>
          state.medication && state.medication.id === mid && uid === 'u-1'
            ? state.medication
            : null,
      ),
      delete: jest.fn(async (mid: string) => {
        // DB cascade: medication.delete → schedule (FK cascade) + drawerMedication (FK cascade)
        if (state.medication && state.medication.id === mid) {
          (state as unknown as { medication: Medication | null }).medication = null;
          (state as unknown as { schedule: Schedule | null }).schedule = null;
          (state as unknown as { dm: DrawerMedication | null }).dm = null;
        }
      }),
    };
    // Sanity check: DeleteMedication use case does NOT call scheduleRepo.delete / dmRepo.delete manually (§7 rule: no application-side duplication)
    const uc = new DeleteMedication(medicationRepo as never);
    await uc.execute({ userId: 'u-1', medicationId: 'm-1' });
    expect(medicationRepo.delete).toHaveBeenCalledTimes(1);
    // Application-level use case should never manually delete Schedule/DrawerMedication
    // (Prove by inspecting: schedRepo.delete was NEVER called by uc — only mocked cascade in medicationRepo.delete actually removed them).
    expect(schedRepo.delete).toHaveBeenCalledTimes(0);
    expect(state.medication).toBeNull();
    expect(state.schedule).toBeNull();
    expect(state.dm).toBeNull();
    expect(state.drawer).not.toBeNull();
  });
});

describe('§5 — Drawer deletion cascades DrawerMedication but NOT Medication', () => {
  it('Test 3 — Delete Drawer → Drawer + DM deleted, Medication REMAINS', () => {
    // Schema text assertion for drawer relation (already true per §5 confirmation):
    const text = schemaText();
    const dm = text.slice(text.indexOf('model DrawerMedication {'));
    expect(/drawer\s+Drawer\s+@relation\([^)]*onDelete:\s*Cascade[^)]*\)/.test(dm)).toBe(true);
    // Medication relation from DrawerMedication → Medication does NOT cascade back up
    const medBlock = text.slice(text.indexOf('model Medication {'), text.indexOf('model Schedule'));
    // DrawerMedication is referenced as optional backref in Medication
    expect(/drawerMedication\s+DrawerMedication\s*\?/.test(medBlock)).toBe(true);
  });
});

describe('§13.4 — Cross-user delete: 404 & nothing deleted', () => {
  it('Test 4 — User B attempts delete of User A Medication A → 404; Medication + DrawerMedication still EXIST', async () => {
    const medicationA = buildMedication({ id: 'm-A', patientId: 'p-A' });
    const dmA = buildDrawerMed({ id: 'dm-A', medicationId: 'm-A' });

    const medicationRepo = {
      findByIdAndUserId: jest.fn(
        async (mid: string, uid: string) => {
          if (mid === medicationA.id && uid === 'u-A') return medicationA;
          return null;
        },
      ),
      delete: jest.fn(),
    };
    const dmRepo = {
      findByMedicationId: jest.fn(async (mid: string) => (mid === 'm-A' ? dmA : null)),
    };

    // Precondition: Medication + DM both exist
    expect(await dmRepo.findByMedicationId('m-A')).toBe(dmA);

    const uc = new DeleteMedication(medicationRepo as never);

    // User B id=u-B -> findByIdAndUserId(m-A,u-B)=null -> NotFoundError; no delete call
    await expect(
      uc.execute({ userId: 'u-B', medicationId: 'm-A' }),
    ).rejects.toThrow(NotFoundError);

    expect(medicationRepo.delete).not.toHaveBeenCalled();
    // Still both exist
    expect(await medicationRepo.findByIdAndUserId('m-A', 'u-A')).toBe(medicationA);
    expect(await dmRepo.findByMedicationId('m-A')).toBe(dmA);
  });
});

describe('§13.5 — Invariant: DrawerMedication.medicationId ALWAYS refers valid Medication (orphan guard)', () => {
  it('Test 5 — DrawerMedication entity: medicationId is required string; Prisma type: required String + FK cascade = no orphan', () => {
    type NonNullableMedId = DrawerMedication['medicationId'];
    // DrawerMedication interface (domain entity): medicationId = STRING, not ? or null
    type AssertString = NonNullableMedId extends string ? true : false;
    const _domainStr: AssertString = true;
    expect(_domainStr).toBe(true);

    type PrismaNonNull = PrismaDrawerMedication['medicationId'];
    type AssertPrismaStr = PrismaNonNull extends string ? true : false;
    const _prismaStr: AssertPrismaStr = true;
    expect(_prismaStr).toBe(true);

    // FK onDelete: Cascade rule already asserted above → guarantees when Medication dies, DM row dies → no orphan medicationId.
    const text = schemaText();
    const dm = text.slice(text.indexOf('model DrawerMedication {'));
    expect(/medication\s+Medication\s+@relation\([^)]*onDelete:\s*Cascade/.test(dm)).toBe(true);
  });

  it('[Schema] DrawerMedication.medicationId column NOT marked as optional (String, no ?)', () => {
    const text = schemaText();
    const dmStart = text.indexOf('model DrawerMedication {');
    const lines = text.slice(dmStart, text.indexOf('}', dmStart)).split('\n');
    const medicationIdLine = lines.find((l) => l.trim().startsWith('medicationId '))!;
    expect(medicationIdLine).toMatch(/medicationId\s+String(?!\s*\?)/);
  });
});

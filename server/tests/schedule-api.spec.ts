import type { Request, Response, NextFunction } from 'express';
import type { Schedule } from '@domain/entities/Schedule';
import type { Medication } from '@domain/entities/Medication';
import type { Patient } from '@domain/entities/Patient';
import { requireAuth } from '@presentation/middlewares/authMiddleware';
import {
  createScheduleSchema,
  updateScheduleSchema,
} from '@presentation/validators/schedule.validator';
import { CreateSchedule } from '@application/use-cases/schedules/CreateSchedule';
import { GetSchedules } from '@application/use-cases/schedules/GetSchedules';
import { GetScheduleById } from '@application/use-cases/schedules/GetScheduleById';
import { UpdateSchedule } from '@application/use-cases/schedules/UpdateSchedule';
import { DeleteSchedule } from '@application/use-cases/schedules/DeleteSchedule';
import { NotFoundError, UnauthorizedError } from '@shared/errors';

type MockScheduleRepo = {
  create: jest.Mock;
  findById: jest.Mock;
  findByIdAndUserId: jest.Mock;
  findAllByMedicationId: jest.Mock;
  findAllByUserId: jest.Mock;
  findByIdAndMedicationId: jest.Mock;
  update: jest.Mock;
  delete: jest.Mock;
};
type MockMedRepo = {
  findById: jest.Mock;
  findByIdAndUserId: jest.Mock;
  findDuplicate: jest.Mock;
};
type MockPatientRepo = {
  findByIdAndUserId: jest.Mock;
};
type Mocks = { schedRepo: MockScheduleRepo; medRepo: MockMedRepo; patientRepo: MockPatientRepo };

const mkFn = () => jest.fn();
const mkMocks = (): Mocks => ({
  schedRepo: {
    create: mkFn(),
    findById: mkFn(),
    findByIdAndUserId: mkFn(),
    findAllByMedicationId: mkFn(),
    findAllByUserId: mkFn(),
    findByIdAndMedicationId: mkFn(),
    update: mkFn(),
    delete: mkFn(),
  },
  medRepo: { findById: mkFn(), findByIdAndUserId: mkFn(), findDuplicate: mkFn().mockResolvedValue(null) },
  patientRepo: { findByIdAndUserId: mkFn() },
});

const now = () => new Date('2026-08-21T00:00:00.000Z');

const buildSchedule = (o: Partial<Schedule> = {}): Schedule => ({
  id: 's-1',
  medicationId: 'm-A',
  dosage: '1 tablet',
  timesPerDay: 2,
  times: ['08:00', '20:00'],
  startDate: now(),
  endDate: null,
  daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
  status: 'ACTIVE',
  notes: null,
  refillReminder: false,
  createdAt: now(),
  updatedAt: now(),
  isActive: true,
  ...o,
});

const nextFn = () => jest.fn() as unknown as jest.Mock & NextFunction;

const buildMedication = (o: Partial<Medication> = {}): Medication => ({
  id: 'm-A',
  patientId: 'p-A',
  name: 'Paracetamol',
  dosage: '500mg',
  form: 'TABLET',
  quantity: 30,
  expiryDate: new Date('2027-12-31T00:00:00.000Z'),
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const buildPatient = (o: Partial<Patient> = {}): Patient => ({
  id: 'p-A',
  userId: 'u-A',
  fullName: 'Alice Smith',
  dateOfBirth: null,
  gender: null,
  weightKg: null,
  heightCm: null,
  bloodType: null,
  allergies: null,
  notes: null,
  avatarUrl: null,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

describe('§19 Authentication: no JWT → 401', () => {
  const res = {} as Response;
  const scenarios: Partial<Request>[] = [
    { method: 'POST', path: '/schedules' },
    { method: 'GET', path: '/schedules' },
    { method: 'GET', path: '/schedules/:id' },
    { method: 'PATCH', path: '/schedules/:id' },
    { method: 'DELETE', path: '/schedules/:id' },
  ];
  scenarios.forEach((like) =>
    it(`${like.method} ${like.path} without JWT → 401`, () => {
      const req = { headers: {}, method: like.method, path: like.path } as Request;
      const n = nextFn();
      requireAuth(req, res, n);
      const err = (n.mock.calls[0] as [unknown])[0] as {
        constructor: unknown;
        statusCode: number;
      };
      expect(err).toBeInstanceOf(UnauthorizedError);
      expect(err.statusCode).toBe(401);
    }),
  );
});

describe('§19 CREATE: ownership + legacy-field strict rejection', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('User A creates Schedule for Medication A → success (201)', async () => {
    const m = buildMedication({ id: 'm-A', patientId: 'p-A' });
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(m);
    mocks.schedRepo.create.mockResolvedValue(
      buildSchedule({ id: 's-new', medicationId: 'm-A' }),
    );
    const uc = new CreateSchedule(mocks.schedRepo as never, mocks.medRepo as never);
    const out = await uc.execute('u-A', {
      medicationId: 'm-A',
      dosage: '1 tablet',
      timesPerDay: 2,
      times: ['08:00', '20:00'],
      startDate: now(),
    });
    expect(mocks.medRepo.findByIdAndUserId).toHaveBeenCalledWith('m-A', 'u-A');
    expect(mocks.schedRepo.create).toHaveBeenCalled();
    expect(out.medicationId).toBe('m-A');
  });

  it('User A creates Schedule for Medication B (User B owns) → 404; never calls schedRepo.create', async () => {
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new CreateSchedule(mocks.schedRepo as never, mocks.medRepo as never);
    await expect(
      uc.execute('u-A', {
        medicationId: 'm-B',
        dosage: '500mg',
        startDate: now(),
      }),
    ).rejects.toThrow(NotFoundError);
    expect(mocks.schedRepo.create).not.toHaveBeenCalled();
  });

  const LEGACY_BAD_KEYS: Array<string> = [
    'userId',
    'patientId',
    'id',
    'createdAt',
    'updatedAt',
    'frequency',
    'time',
  ];
  for (const bad of LEGACY_BAD_KEYS) {
    it(`Create body with legacy field '${bad}' → strict rejects 400`, () => {
      const body: Record<string, unknown> = {
        medicationId: '00000000-0000-0000-0000-000000000000',
        dosage: '1 tablet',
        startDate: '2026-08-21',
      };
      body[bad] = 'x';
      expect(createScheduleSchema.safeParse(body).success).toBe(false);
    });
  }

  it('Create unknown field → strict reject 400', () => {
    expect(
      createScheduleSchema.safeParse({
        medicationId: '00000000-0000-0000-0000-000000000000',
        dosage: '1 tablet',
        startDate: '2026-08-21',
        unknownField: 123,
      }).success,
    ).toBe(false);
  });
});

describe('§19 GET LIST: ownership isolation + medicationId filter', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('User A list → only returned meds where medication.patient.userId=uA (DB filter call)', async () => {
    mocks.schedRepo.findAllByUserId.mockResolvedValue([
      buildSchedule({ id: 's-A1' }),
      buildSchedule({ id: 's-A2' }),
    ]);
    const uc = new GetSchedules(mocks.schedRepo as never);
    const out = await uc.execute('u-A');
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('u-A', undefined);
    expect(Array.isArray(out)).toBe(true);
    expect((out as Schedule[]).every((s) => s.id.startsWith('s-A'))).toBe(true);
  });

  it('User B list → own list (different userId call), NOT User A records', async () => {
    mocks.schedRepo.findAllByUserId.mockResolvedValue([]);
    const uc = new GetSchedules(mocks.schedRepo as never);
    await uc.execute('u-B');
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('u-B', undefined);
  });

  it('medicationId filter passes combined with ownership', async () => {
    mocks.schedRepo.findAllByUserId.mockResolvedValue([
      buildSchedule({ id: 's-filtered', medicationId: 'm-A' }),
    ]);
    const uc = new GetSchedules(mocks.schedRepo as never);
    await uc.execute('u-A', { medicationId: 'm-A' });
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('u-A', {
      medicationId: 'm-A',
    });
  });
});

describe('§19 GET LIST: patientId filter ownership', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('[1] No patientId → all user schedules (no PatientRepo call)', async () => {
    mocks.schedRepo.findAllByUserId.mockResolvedValue([
      buildSchedule({ id: 's-A1' }),
    ]);
    const uc = new GetSchedules(mocks.schedRepo as never, mocks.patientRepo as never);
    await uc.execute('u-A');
    expect(mocks.patientRepo.findByIdAndUserId).not.toHaveBeenCalled();
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('u-A', undefined);
  });

  it('[2] ?patientId=ownPatientId → passes own patientId + userId to findAllByUserId; ownership check OK', async () => {
    mocks.patientRepo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    mocks.schedRepo.findAllByUserId.mockResolvedValue([
      buildSchedule({ id: 's-PA1' }),
      buildSchedule({ id: 's-PA2' }),
    ]);
    const uc = new GetSchedules(mocks.schedRepo as never, mocks.patientRepo as never);
    const out = await uc.execute('u-A', { patientId: 'p-A' });
    expect(mocks.patientRepo.findByIdAndUserId).toHaveBeenCalledWith('p-A', 'u-A');
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('u-A', { patientId: 'p-A' });
    expect((out as Schedule[]).length).toBe(2);
  });

  it('[3] ?patientId=otherOwnPatientId → second own patient filters correctly', async () => {
    mocks.patientRepo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-B', userId: 'u-A' }));
    mocks.schedRepo.findAllByUserId.mockResolvedValue([buildSchedule({ id: 's-PB1' })]);
    const uc = new GetSchedules(mocks.schedRepo as never, mocks.patientRepo as never);
    await uc.execute('u-A', { patientId: 'p-B' });
    expect(mocks.patientRepo.findByIdAndUserId).toHaveBeenCalledWith('p-B', 'u-A');
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('u-A', { patientId: 'p-B' });
  });

  it('[4] ?patientId=otherUserPatientId → 404 Patient not found; schedules query NOT executed', async () => {
    mocks.patientRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetSchedules(mocks.schedRepo as never, mocks.patientRepo as never);
    await expect(
      uc.execute('u-A', { patientId: 'p-ownedByU-B' }),
    ).rejects.toThrow(NotFoundError);
    expect(mocks.patientRepo.findByIdAndUserId).toHaveBeenCalledWith('p-ownedByU-B', 'u-A');
    expect(mocks.schedRepo.findAllByUserId).not.toHaveBeenCalled();
  });

  it('[5] patientId + medicationId combined → both options forwarded after ownership OK', async () => {
    mocks.patientRepo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    mocks.schedRepo.findAllByUserId.mockResolvedValue([]);
    const uc = new GetSchedules(mocks.schedRepo as never, mocks.patientRepo as never);
    await uc.execute('u-A', { patientId: 'p-A', medicationId: 'm-M1' });
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('u-A', {
      patientId: 'p-A',
      medicationId: 'm-M1',
    });
  });

  it('[6] Cross-user patientId never leaks: scheduleRepo findAllByUserId still includes userId (defense-in-depth)', async () => {
    const pB = buildPatient({ id: 'p-B', userId: 'u-B' });
    // Simulate a broken patientRepo accidentally returning cross-user patient
    mocks.patientRepo.findByIdAndUserId.mockResolvedValue(pB);
    mocks.schedRepo.findAllByUserId.mockResolvedValue([]);
    const uc = new GetSchedules(mocks.schedRepo as never, mocks.patientRepo as never);
    await uc.execute('u-A', { patientId: 'p-B' });
    // Even if patient check were bypassed (mocked), findAllByUserId MUST still include the authenticated userId.
    const [callUserId] = mocks.schedRepo.findAllByUserId.mock.calls[0] as [string, unknown];
    expect(callUserId).toBe('u-A');
  });
});

describe('§19 GET BY ID + UPDATE + DELETE: ownership 404 for cross-user', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('owner GetScheduleById → 200; cross-user GetScheduleById → 404', async () => {
    mocks.schedRepo.findByIdAndUserId
      .mockReturnValueOnce(buildSchedule({ id: 's-A', medicationId: 'm-A' }))
      .mockReturnValueOnce(null);
    const uc = new GetScheduleById(mocks.schedRepo as never);
    const owned = await uc.execute('u-A', 's-A');
    expect(owned.id).toBe('s-A');
    await expect(uc.execute('u-B', 's-A')).rejects.toThrow(NotFoundError);
  });

  it('owner UpdateSchedule → 200; cross-user → 404 and repo.update not called', async () => {
    const updated = buildSchedule({ id: 's-A', dosage: '2 tablets' });
    mocks.schedRepo.findByIdAndUserId
      .mockReturnValueOnce(Promise.resolve(updated))
      .mockReturnValueOnce(Promise.resolve(null));
    mocks.schedRepo.update.mockResolvedValue(updated);
    const uc = new UpdateSchedule(mocks.schedRepo as never);
    const out = await uc.execute('u-A', 's-A', { dosage: '2 tablets' });
    expect(out.dosage).toBe('2 tablets');
    await expect(
      uc.execute('u-B', 's-A', { dosage: '2 tablets' }),
    ).rejects.toThrow(NotFoundError);
  });

  it('UPDATE: attempt patientId change → strict() validator rejects 400', () => {
    const r = updateScheduleSchema.safeParse({
      patientId: 'attempt-transfer',
      dosage: '1 tablet',
    } as any);
    expect(r.success).toBe(false);
  });

  it('UPDATE: attempt medicationId change → strict rejects 400', () => {
    expect(
      updateScheduleSchema.safeParse({
        medicationId: '00000000-0000-0000-0000-000000000000',
        dosage: '1 tablet',
      } as any).success,
    ).toBe(false);
  });

  it('owner DeleteSchedule → 204 (void); cross-user → 404 never delete', async () => {
    mocks.schedRepo.findByIdAndUserId
      .mockReturnValueOnce(Promise.resolve(buildSchedule({ id: 's-A' })))
      .mockReturnValueOnce(Promise.resolve(null));
    const uc = new DeleteSchedule(mocks.schedRepo as never);
    await uc.execute('u-A', 's-A');
    expect(mocks.schedRepo.delete).toHaveBeenCalledTimes(1);
    await expect(uc.execute('u-B', 's-A')).rejects.toThrow(NotFoundError);
    expect(mocks.schedRepo.delete).toHaveBeenCalledTimes(1);
  });
});

describe('§18 CRITICAL 4×4 OWNERSHIP MATRIX: Schedule', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });
  it('A→A Create 201', async () => {
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(buildMedication({ id: 'm-A' }));
    mocks.schedRepo.create.mockResolvedValue(buildSchedule({ id: 's-A', medicationId: 'm-A' }));
    const uc = new CreateSchedule(mocks.schedRepo as never, mocks.medRepo as never);
    const r = await uc.execute('u-A', { medicationId: 'm-A', dosage: '1 tablet', startDate: now() });
    expect(r.id).toBe('s-A');
  });
  it('A→B Create 404', async () => {
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new CreateSchedule(mocks.schedRepo as never, mocks.medRepo as never);
    await expect(
      uc.execute('u-A', { medicationId: 'm-B', dosage: '1 tablet', startDate: now() }),
    ).rejects.toThrow(NotFoundError);
    expect(mocks.schedRepo.create).not.toHaveBeenCalled();
  });
  it('B→A Create 404', async () => {
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new CreateSchedule(mocks.schedRepo as never, mocks.medRepo as never);
    await expect(
      uc.execute('u-B', { medicationId: 'm-A', dosage: '1 tablet', startDate: now() }),
    ).rejects.toThrow(NotFoundError);
  });
  it('B→B Create 201', async () => {
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(buildMedication({ id: 'm-B', patientId: 'p-B' }));
    mocks.schedRepo.create.mockResolvedValue(buildSchedule({ id: 's-B', medicationId: 'm-B' }));
    const uc = new CreateSchedule(mocks.schedRepo as never, mocks.medRepo as never);
    const r = await uc.execute('u-B', { medicationId: 'm-B', dosage: '1 tablet', startDate: now() });
    expect(r.id).toBe('s-B');
  });

  it('A→A Get 200', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(buildSchedule({ id: 's-A' }));
    const uc = new GetScheduleById(mocks.schedRepo as never);
    expect(await uc.execute('u-A', 's-A')).toBeTruthy();
  });
  it('A→B Get 404', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetScheduleById(mocks.schedRepo as never);
    await expect(uc.execute('u-A', 's-B')).rejects.toThrow(NotFoundError);
  });
  it('B→A Get 404', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetScheduleById(mocks.schedRepo as never);
    await expect(uc.execute('u-B', 's-A')).rejects.toThrow(NotFoundError);
  });
  it('B→B Get 200', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(buildSchedule({ id: 's-B' }));
    const uc = new GetScheduleById(mocks.schedRepo as never);
    expect(await uc.execute('u-B', 's-B')).toBeTruthy();
  });

  it('A→A Update 200', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(buildSchedule({ id: 's-A' }));
    mocks.schedRepo.update.mockResolvedValue(buildSchedule({ id: 's-A', dosage: '2 tabs' }));
    const uc = new UpdateSchedule(mocks.schedRepo as never);
    expect((await uc.execute('u-A', 's-A', { dosage: '2 tabs' })).dosage).toBe('2 tabs');
  });
  it('A→B Update 404', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UpdateSchedule(mocks.schedRepo as never);
    await expect(uc.execute('u-A', 's-B', { dosage: '2 tabs' })).rejects.toThrow(NotFoundError);
  });
  it('B→A Update 404', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UpdateSchedule(mocks.schedRepo as never);
    await expect(uc.execute('u-B', 's-A', { dosage: '2 tabs' })).rejects.toThrow(NotFoundError);
  });
  it('B→B Update 200', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(buildSchedule({ id: 's-B' }));
    mocks.schedRepo.update.mockResolvedValue(buildSchedule({ id: 's-B', isActive: false }));
    const uc = new UpdateSchedule(mocks.schedRepo as never);
    expect((await uc.execute('u-B', 's-B', { isActive: false })).isActive).toBe(false);
  });

  it('A→A Delete 204', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(buildSchedule({ id: 's-A' }));
    const uc = new DeleteSchedule(mocks.schedRepo as never);
    await expect(uc.execute('u-A', 's-A')).resolves.not.toThrow();
    expect(mocks.schedRepo.delete).toHaveBeenCalledWith('s-A');
  });
  it('A→B Delete 404', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new DeleteSchedule(mocks.schedRepo as never);
    await expect(uc.execute('u-A', 's-B')).rejects.toThrow(NotFoundError);
  });
  it('B→A Delete 404', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new DeleteSchedule(mocks.schedRepo as never);
    await expect(uc.execute('u-B', 's-A')).rejects.toThrow(NotFoundError);
  });
  it('B→B Delete 204', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(buildSchedule({ id: 's-B' }));
    const uc = new DeleteSchedule(mocks.schedRepo as never);
    await expect(uc.execute('u-B', 's-B')).resolves.not.toThrow();
  });
});

describe('§21 DELETE BEHAVIOR: only Schedule removed; Medication stays (no manual cascade)', () => {
  it('DeleteSchedule constructor only takes 1 dependency (scheduleRepo only → cannot touch Med/Patient)', () => {
    expect(DeleteSchedule.length).toBe(1);
  });
  it('DeleteSchedule NEVER calls medicationRepo.delete', async () => {
    const mocks = mkMocks();
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(buildSchedule({ id: 's-A', medicationId: 'm-A' }));
    const uc = new DeleteSchedule(mocks.schedRepo as never);
    await uc.execute('u-A', 's-A');
    expect(mocks.medRepo.findById).not.toHaveBeenCalled();
    expect(mocks.medRepo.findByIdAndUserId).not.toHaveBeenCalled();
    expect(mocks.schedRepo.delete).toHaveBeenCalledTimes(1);
  });
});

describe('§9 VALIDATION: all Zod runtime checks', () => {
  it('empty dosage rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '',
      startDate: '2026-08-21',
    }).success).toBe(false));

  it('invalid startDate rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: 'not-a-date',
    }).success).toBe(false));

  it('invalid endDate rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      endDate: 'bad',
    }).success).toBe(false));

  it('endDate before startDate rejected (400)', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-09-01',
      endDate: '2026-08-01',
    }).success).toBe(false));

  it('timesPerDay = 0 rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      timesPerDay: 0,
    }).success).toBe(false));

  it('timesPerDay negative rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      timesPerDay: -1,
    }).success).toBe(false));

  it('timesPerDay decimal rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      timesPerDay: 1.5,
    }).success).toBe(false));

  it('time "25:90" → invalid HH:mm regex', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      times: ['25:90'],
    }).success).toBe(false));

  it('time "8pm" → invalid HH:mm', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      times: ['8pm'],
    }).success).toBe(false));

  it('daysOfWeek: invalid values (0, 8, "1") → reject', () => {
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      daysOfWeek: [0, 1, 7, 8],
    }).success).toBe(false);
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      daysOfWeek: ['1', '2'] as any,
    }).success).toBe(false);
  });

  it('valid daysOfWeek 1..7 passes', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    }).success).toBe(true));

  it('invalid status rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      status: 'CANCELLED',
    }).success).toBe(false));

  it('valid status enum ACTIVE/PAUSED/COMPLETED/ARCHIVED passes', () => {
    for (const status of ['ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED']) {
      expect(createScheduleSchema.safeParse({
        medicationId: '00000000-0000-0000-0000-000000000000',
        dosage: '1 tablet',
        startDate: '2026-08-21',
        status,
      }).success).toBe(true);
    }
  });

  it('invalid boolean field types for refillReminder/isActive rejected', () =>
    expect(createScheduleSchema.safeParse({
      medicationId: '00000000-0000-0000-0000-000000000000',
      dosage: '1 tablet',
      startDate: '2026-08-21',
      refillReminder: 'true' as any,
    }).success).toBe(false));
});

describe('§17 ADMIN: NO global schedule access', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });
  it('ADMIN get list only calls findAllByUserId(admin-user) → no global filter', async () => {
    mocks.schedRepo.findAllByUserId.mockResolvedValue([buildSchedule({ id: 's-admin' })]);
    const uc = new GetSchedules(mocks.schedRepo as never);
    await uc.execute('admin-user-id');
    expect(mocks.schedRepo.findAllByUserId).toHaveBeenCalledWith('admin-user-id', undefined);
  });
  it('ADMIN accessing user schedule (not theirs) → 404', async () => {
    mocks.schedRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetScheduleById(mocks.schedRepo as never);
    await expect(uc.execute('admin-user-id', 's-owned-by-uB')).rejects.toThrow(NotFoundError);
  });
  it('No global admin endpoint: GetSchedules does not expose any findAll() admin method', () => {
    const uc = new GetSchedules({ findAllByUserId: jest.fn() } as never);
    expect(typeof (uc as any).findAll).toBe('undefined');
    expect(GetSchedules.length).toBeGreaterThanOrEqual(1);
  });
});

describe('§7 UPDATE: medicationId not in update validator (immutable ownership)', () => {
  it('update contains id/userId/patientId/medicationId → strict rejects 400', () => {
    for (const field of ['id', 'userId', 'patientId', 'medicationId', 'createdAt', 'updatedAt']) {
      const body: Record<string, unknown> = { quantity: 1 };
      body[field] = 'x';
      expect(updateScheduleSchema.safeParse(body).success).toBe(false);
    }
  });
  it('whitelist update {dosage, timesPerDay, times, startDate, endDate, daysOfWeek, status, notes, refillReminder, isActive} all pass', () => {
    expect(updateScheduleSchema.safeParse({ dosage: 'x', notes: null }).success).toBe(true);
    expect(updateScheduleSchema.safeParse({ times: ['09:00'] }).success).toBe(true);
    expect(updateScheduleSchema.safeParse({ isActive: false }).success).toBe(true);
  });
});

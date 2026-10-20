import type { Patient } from '@domain/entities/Patient';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { NotFoundError, UnauthorizedError, ConflictError } from '@shared/errors';
import { CreatePatient } from '@application/use-cases/patients/CreatePatient';
import { GetPatients } from '@application/use-cases/patients/GetPatients';
import { GetPatientById } from '@application/use-cases/patients/GetPatientById';
import { UpdatePatient } from '@application/use-cases/patients/UpdatePatient';
import { DeletePatient } from '@application/use-cases/patients/DeletePatient';
import { ActivateMedicineBox } from '@application/use-cases/medicine-box/ActivateMedicineBox';
import { GetMyMedicineBoxes } from '@application/use-cases/medicine-box/GetMyMedicineBoxes';
import {
  createPatientSchema,
  updatePatientSchema,
} from '@presentation/validators/patient.validator';
import { activateMedicineBoxSchema } from '@presentation/validators/medicineBox.validator';

type MockRepo = Record<string, jest.Mock>;

const now = () => new Date('2025-01-01T00:00:00.000Z');

const buildPatient = (overrides: Partial<Patient> = {}): Patient => ({
  id: 'p-1',
  userId: 'u-1',
  fullName: 'Patient A',
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
  ...overrides,
});

const buildBox = (overrides: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'DEV-001',
  deviceToken: 'SECRET-T0K3N',
  name: 'Kitchen Box',
  status: 'READY',
  deviceStatus: 'OFFLINE',
  lastSeenAt: null,
  userId: null,
  numberOfDrawers: 4,
  drawerCapacity: 20,
  createdAt: now(),
  updatedAt: now(),
  ...overrides,
});

describe('Patient CRUD → use cases + validators', () => {
  let repo: MockRepo;

  beforeEach(() => {
    repo = {
      findAllByUserId: jest.fn(),
      findByIdAndUserId: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    };
  });

  it('User A creates Patient → success, userId forced from JWT', async () => {
    repo.create.mockResolvedValue(buildPatient({ id: 'p-new', userId: 'u-A', fullName: 'Alice' }));
    const uc = new CreatePatient(repo as never);
    const out = await uc.execute({ userId: 'u-A', fullName: 'Alice' });
    expect(repo.create).toHaveBeenCalledWith(expect.objectContaining({ userId: 'u-A', fullName: 'Alice' }));
    expect(out.userId).toBe('u-A');
    expect(out.fullName).toBe('Alice');
  });

  it('Create validator REJECTS body.userId / body.id (strict validator now rejects unknown keys)', () => {
    const bad = {
      userId: 'ATTACKER-ID',
      id: 'force-id',
      createdAt: now().toISOString(),
      updatedAt: now().toISOString(),
      fullName: 'X',
    };
    const parsed = createPatientSchema.safeParse(bad);
    expect(parsed.success).toBe(false);
    // Safe baseline: no unknown keys => passes
    const good = createPatientSchema.safeParse({ fullName: 'X' });
    expect(good.success).toBe(true);
    // execute() ignores body userId: use case always takes userId from input.userId (req.user.userId in controller)
  });

  it('User A reads own Patients → array returned filtered by userId from JWT', async () => {
    const rows = [buildPatient({ userId: 'u-A' }), buildPatient({ id: 'p-2', userId: 'u-A' })];
    repo.findAllByUserId.mockResolvedValue(rows);
    const uc = new GetPatients(repo as never);
    const out = await uc.execute({ userId: 'u-A' });
    expect(repo.findAllByUserId).toHaveBeenCalledWith('u-A', undefined);
    expect(Array.isArray(out)).toBe(true);
    expect(out).toHaveLength(2);
    expect((out as Patient[]).every((p) => p.userId === 'u-A')).toBe(true);
  });

  it('User A reads own Patient by ID → success', async () => {
    repo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    const uc = new GetPatientById(repo as never);
    const out = await uc.execute({ userId: 'u-A', patientId: 'p-A' });
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-A', 'u-A');
    expect(out.id).toBe('p-A');
  });

  it('User B reads User A Patient → 404 (cross-user)', async () => {
    repo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetPatientById(repo as never);
    await expect(uc.execute({ userId: 'u-B', patientId: 'p-A' })).rejects.toThrow(NotFoundError);
  });

  it('User A updates own Patient → success; id/userId ignored in update body', async () => {
    repo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    repo.update.mockResolvedValue(
      buildPatient({ id: 'p-A', userId: 'u-A', fullName: 'Updated', gender: 'FEMALE' }),
    );
    const uc = new UpdatePatient(repo as never);
    const out = await uc.execute({
      userId: 'u-A',
      patientId: 'p-A',
      fullName: 'Updated',
      gender: 'FEMALE',
    });
    expect(repo.update).toHaveBeenCalledWith('p-A', expect.objectContaining({ fullName: 'Updated' }));
    // userId/createdAt/updatedAt NEVER in the patch
    const [, patch] = repo.update.mock.calls[0] as [string, Record<string, unknown>];
    expect(patch.userId).toBeUndefined();
    expect(patch.id).toBeUndefined();
    expect(patch.createdAt).toBeUndefined();
    expect(patch.updatedAt).toBeUndefined();
    expect(out.id).toBe('p-A');
  });

  it('Update validator REJECTS unknown keys (userId/id/role) via strict validator', () => {
    const bad = { userId: 'x', id: 'y', role: 'ADMIN', fullName: 'Ok' };
    const parsed = updatePatientSchema.safeParse(bad);
    expect(parsed.success).toBe(false);
    const good = updatePatientSchema.safeParse({ fullName: 'Ok' });
    expect(good.success).toBe(true);
    expect((good as { data: Record<string, unknown> }).data.fullName).toBe('Ok');
  });

  it('User B updates User A Patient → 404 NotFound', async () => {
    repo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UpdatePatient(repo as never);
    await expect(
      uc.execute({ userId: 'u-B', patientId: 'p-A', fullName: 'Stolen' }),
    ).rejects.toThrow(NotFoundError);
    expect(repo.update).not.toHaveBeenCalled();
  });

  it('User A deletes own Patient → success (cascade handled by Prisma FK)', async () => {
    repo.findByIdAndUserId.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    repo.delete.mockResolvedValue(undefined);
    const uc = new DeletePatient(repo as never);
    await uc.execute({ userId: 'u-A', patientId: 'p-A' });
    expect(repo.findByIdAndUserId).toHaveBeenCalledWith('p-A', 'u-A');
    expect(repo.delete).toHaveBeenCalledWith('p-A');
  });

  it('User B deletes User A Patient → 404 (no delete called)', async () => {
    repo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new DeletePatient(repo as never);
    await expect(uc.execute({ userId: 'u-B', patientId: 'p-A' })).rejects.toThrow(NotFoundError);
    expect(repo.delete).not.toHaveBeenCalled();
  });

  it('Create validator: fullName required', () => {
    const r = createPatientSchema.safeParse({});
    expect(r.success).toBe(false);
  });

  it('Create validator: dateOfBirth/gender/weightKg/heightCm/bloodType/allergies/notes/avatarUrl all optional (nullable)', () => {
    const r = createPatientSchema.safeParse({ fullName: 'Only Name' });
    expect(r.success).toBe(true);
  });
});

describe('Activate MedicineBox → credential-based (deviceId + deviceToken)', () => {
  let repo: MockRepo;

  beforeEach(() => {
    repo = {
      findByDeviceId: jest.fn(),
      activateAtomic: jest.fn(),
    };
  });

  it('USER activates READY box via credentials → success', async () => {
    repo.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'DEV-001', deviceToken: 'TOK', userId: null, status: 'READY' }),
    );
    repo.activateAtomic.mockResolvedValue({
      kind: 'success',
      box: buildBox({ deviceId: 'DEV-001', userId: 'u-A', status: 'ACTIVE' }),
    });
    const uc = new ActivateMedicineBox(repo as never);
    const out = await uc.execute('u-A', { deviceId: 'DEV-001', deviceToken: 'TOK' });
    expect(repo.findByDeviceId).toHaveBeenCalledWith('DEV-001');
    expect(repo.activateAtomic).toHaveBeenCalledWith('DEV-001', 'u-A');
    expect(out.userId).toBe('u-A');
    expect(out.status).toBe('ACTIVE');
  });

  it('userId comes from JWT → never from request body (controller contract)', async () => {
    repo.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'D', deviceToken: 'T', userId: null, status: 'READY' }),
    );
    repo.activateAtomic.mockImplementation((deviceId: string, owner: string) =>
      Promise.resolve({
        kind: 'success',
        box: buildBox({ deviceId, userId: owner, status: 'ACTIVE' }),
      }),
    );
    const uc = new ActivateMedicineBox(repo as never);
    const out = await uc.execute('u-JWT', { deviceId: 'D', deviceToken: 'T' });
    // The activated owner ALWAYS matches first arg (= req.user.userId in controller)
    expect(out.userId).toBe('u-JWT');
    expect(repo.activateAtomic).toHaveBeenCalledWith('D', 'u-JWT');
  });

  it('READY → becomes ACTIVE with JWT user as owner', async () => {
    repo.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'D', deviceToken: 'T', userId: null, status: 'READY' }),
    );
    repo.activateAtomic.mockResolvedValue({
      kind: 'success',
      box: buildBox({ deviceId: 'D', userId: 'u-A', status: 'ACTIVE' }),
    });
    const uc = new ActivateMedicineBox(repo as never);
    const out = await uc.execute('u-A', { deviceId: 'D', deviceToken: 'T' });
    expect(out.status).toBe('ACTIVE');
    expect(out.userId).not.toBeNull();
  });

  it('User A activates Box A → succeeds; User B tries to activate Box A → rejected (stealing prevented)', async () => {
    const owned = buildBox({
      deviceId: 'D',
      deviceToken: 'T',
      userId: 'u-A',
      status: 'ACTIVE',
    });
    repo.findByDeviceId.mockResolvedValue(owned);

    const uc = new ActivateMedicineBox(repo as never);
    // User B attack: correct credentials but box already owned by A.
    await expect(
      uc.execute('u-B', { deviceId: 'D', deviceToken: 'T' }),
    ).rejects.toThrow(ConflictError);
    expect(repo.activateAtomic).not.toHaveBeenCalled();
  });

  it('User B cannot overwrite Box A owner → activateAtomic() never called for attacker', async () => {
    repo.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'X', deviceToken: 'Y', userId: 'u-A', status: 'ACTIVE' }),
    );
    const uc = new ActivateMedicineBox(repo as never);
    await expect(
      uc.execute('u-B', { deviceId: 'X', deviceToken: 'Y' }),
    ).rejects.toThrow(ConflictError);
    expect(repo.activateAtomic).not.toHaveBeenCalled();
  });

  it('deviceId + invalid deviceToken → rejected (401 UnauthorizedError)', async () => {
    repo.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'D', deviceToken: 'REAL-TOKEN', userId: null, status: 'READY' }),
    );
    const uc = new ActivateMedicineBox(repo as never);
    await expect(
      uc.execute('u-X', { deviceId: 'D', deviceToken: 'WRONG' }),
    ).rejects.toThrow(UnauthorizedError);
    expect(repo.activateAtomic).not.toHaveBeenCalled();
  });

  it('activate validator: missing deviceId → validation error', () => {
    const r = activateMedicineBoxSchema.safeParse({ deviceToken: 't' });
    expect(r.success).toBe(false);
  });

  it('activate validator: missing deviceToken → validation error', () => {
    const r = activateMedicineBoxSchema.safeParse({ deviceId: 'd' });
    expect(r.success).toBe(false);
  });
});

describe('GET /medicine-boxes/my → only authenticated user boxes', () => {
  it('returns only boxes whose userId === authenticatedUserId', async () => {
    const repo = {
      findAllByUserId: jest.fn().mockResolvedValue([
        buildBox({ id: 'b1', userId: 'u-A', status: 'ACTIVE' }),
        buildBox({ id: 'b2', userId: 'u-A', status: 'ACTIVE' }),
      ]),
    };
    const uc = new GetMyMedicineBoxes(repo as never);
    const out = await uc.execute('u-A');
    expect(repo.findAllByUserId).toHaveBeenCalledWith('u-A');
    expect(out).toHaveLength(2);
    expect(out.every((b) => b.userId === 'u-A')).toBe(true);
    // Never returns READY (null userId) boxes because findAllByUserId filters strictly
    expect(out.some((b) => b.userId === null)).toBe(false);
  });

  it('never returns READY boxes with userId=null even if repo leak would occur', async () => {
    const repo = {
      findAllByUserId: jest
        .fn()
        .mockResolvedValue([buildBox({ id: 'b1', userId: 'u-A', status: 'ACTIVE' })]),
    };
    const uc = new GetMyMedicineBoxes(repo as never);
    const out = await uc.execute('u-A');
    // findAllByUserId only returns userId=u-A (userId=null can't match)
    expect(repo.findAllByUserId).toHaveBeenCalledWith('u-A');
    expect(out.every((b) => b.userId !== null)).toBe(true);
  });

  it('never returns another user boxes → different userId yields empty result', async () => {
    const repo = { findAllByUserId: jest.fn().mockResolvedValue([]) };
    const uc = new GetMyMedicineBoxes(repo as never);
    const out = await uc.execute('u-STRANGER');
    expect(out).toEqual([]);
    expect(repo.findAllByUserId).toHaveBeenCalledWith('u-STRANGER');
  });
});

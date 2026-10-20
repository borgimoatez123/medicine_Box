import type { User } from '@domain/entities/User';
import type { Patient } from '@domain/entities/Patient';
import type { Medication } from '@domain/entities/Medication';
import type { Schedule } from '@domain/entities/Schedule';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { Drawer } from '@domain/entities/Drawer';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { NotFoundError, UnauthorizedError, ForbiddenError, ConflictError } from '@shared/errors';
import { LoginUser } from '@application/use-cases/auth/LoginUser';
import { UpdateMyProfile } from '@application/use-cases/users/UpdateMyProfile';
import { CreateMedication } from '@application/use-cases/medications/CreateMedication';
import { GetMedicationById } from '@application/use-cases/medications/GetMedicationById';
import { CreateSchedule } from '@application/use-cases/schedules/CreateSchedule';
import { DeleteSchedule } from '@application/use-cases/schedules/DeleteSchedule';
import { AddMedicineBox } from '@application/use-cases/medicine-box/AddMedicineBox';
import { ActivateMedicineBox } from '@application/use-cases/medicine-box/ActivateMedicineBox';
import { GetDrawers } from '@application/use-cases/medicine-box/GetDrawers';
import { AssignMedicationToDrawer } from '@application/use-cases/medicine-box/AssignMedicationToDrawer';
import { requireRole, requireAuth } from '@presentation/middlewares/authMiddleware';
import type { Request, Response, NextFunction } from 'express';
import { JwtService } from '@infrastructure/auth/JwtService';
import { PasswordService } from '@infrastructure/auth/PasswordService';

type MockRepo = {
  findById?: jest.Mock;
  findByEmail?: jest.Mock;
  findAllByUserId?: jest.Mock;
  findAllByPatientId?: jest.Mock;
  findByIdAndPatientId?: jest.Mock;
  findByIdAndUserId?: jest.Mock;
  findByIdAndMedicineBoxId?: jest.Mock;
  findAllByMedicineBoxId?: jest.Mock;
  findByDeviceId?: jest.Mock;
  findDuplicate?: jest.Mock;
  create?: jest.Mock;
  update?: jest.Mock;
  delete?: jest.Mock;
  updatePassword?: jest.Mock;
  existsByDeviceId?: jest.Mock;
  activate?: jest.Mock;
  activateAtomic?: jest.Mock;
  upsert?: jest.Mock;
  findByDrawerId?: jest.Mock;
  findByMedicationId?: jest.Mock;
};

const now = () => new Date('2025-01-01T00:00:00.000Z');

const buildUser = (overrides: Partial<User> = {}): User => ({
  id: 'u-1',
  firstName: 'John',
  lastName: 'Doe',
  email: 'john@example.com',
  passwordHash: '$2b$12$hashhashhashhashhashhashhashhashhashhashhashh',
  phone: null,
  role: 'USER',
  createdAt: now(),
  updatedAt: now(),
  ...overrides,
});

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

const buildMedication = (overrides: Partial<Medication> = {}): Medication => ({
  id: 'm-1',
  patientId: 'p-1',
  name: 'Paracetamol',
  dosage: '500mg',
  form: 'TABLET',
  quantity: 20,
  expiryDate: null,
  createdAt: now(),
  updatedAt: now(),
  ...overrides,
});

const buildSchedule = (overrides: Partial<Schedule> = {}): Schedule => ({
  id: 's-1',
  medicationId: 'm-1',
  dosage: '500mg',
  timesPerDay: 2,
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
  ...overrides,
});

const buildMedicineBox = (overrides: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'DEV-001',
  deviceToken: 'tok1',
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

const buildDrawer = (overrides: Partial<Drawer> = {}): Drawer => ({
  id: 'd-1',
  medicineBoxId: 'box-1',
  drawerNumber: 1,
  status: 'EMPTY',
  createdAt: now(),
  updatedAt: now(),
  ...overrides,
});

const buildDrawerMedication = (overrides: Partial<DrawerMedication> = {}): DrawerMedication => ({
  id: 'dm-1',
  drawerId: 'd-1',
  medicationId: 'm-1',
  quantity: null,
  missingQuantity: null,
  assignedAt: now(),
  isActive: true,
  createdAt: now(),
  updatedAt: now(),
  ...overrides,
});

const mk = jest.fn;
const nextErr = (calls: unknown[]): Error => (calls[0] as unknown) as Error;
const nextMock = () => jest.fn() as unknown as jest.Mock & NextFunction;

describe('Authentication (LoginUser use case)', () => {
  let userRepo: MockRepo;
  let passwordSvc: PasswordService;
  let jwtSign: jest.Mock;
  let jwtSvc: { sign: jest.Mock };

  beforeEach(() => {
    userRepo = { findById: mk(), findByEmail: mk() };
    passwordSvc = new PasswordService(4);
    jwtSign = mk();
    jwtSvc = { sign: jwtSign };
  });

  it('valid login → returns token with minimal {userId, role} payload', async () => {
    const plain = 'superSecret1!';
    const hash = await passwordSvc.hash(plain);
    const user = buildUser({ id: 'u-42', role: 'USER', passwordHash: hash });
    userRepo.findByEmail!.mockResolvedValue(user);
    jwtSign.mockReturnValue('jwt-token');

    const uc = new LoginUser(userRepo as never, passwordSvc, jwtSvc as never);
    const out = await uc.execute({ email: user.email!, password: plain });

    expect(userRepo.findByEmail).toHaveBeenCalledWith(user.email);
    expect(jwtSign).toHaveBeenCalledWith({ userId: 'u-42', role: 'USER' });
    expect(out.token).toBe('jwt-token');
    expect((out.user as Record<string, unknown>).passwordHash).toBeUndefined();
  });

  it('wrong password → 401 UnauthorizedError', async () => {
    const hash = await passwordSvc.hash('correctPassword');
    userRepo.findByEmail!.mockResolvedValue(buildUser({ passwordHash: hash }));
    const uc = new LoginUser(userRepo as never, passwordSvc, jwtSvc as never);
    await expect(uc.execute({ email: 'x@y.z', password: 'wrong' })).rejects.toThrow(
      UnauthorizedError,
    );
    expect(jwtSign).not.toHaveBeenCalled();
  });
});

describe('JWT service + auth middleware payload shape', () => {
  const original = process.env.JWT_SECRET;
  beforeAll(() => {
    process.env.JWT_SECRET = 'test-secret-change-me';
  });
  afterAll(() => {
    process.env.JWT_SECRET = original;
  });

  it('sign/verify round-trip exposes only userId + role', () => {
    const svc = new JwtService('test-secret-change-me', '1h');
    const token = svc.sign({ userId: 'abc', role: 'ADMIN' });
    const payload = svc.verify(token);
    expect(payload).toEqual({ userId: 'abc', role: 'ADMIN' });
    expect(Object.keys(payload).sort()).toEqual(['role', 'userId']);
  });

  it('expired token → UnauthorizedError', () => {
    const svc = new JwtService('test-secret-change-me', '-1ms');
    const token = svc.sign({ userId: 'x', role: 'USER' });
    expect(() => svc.verify(token)).toThrow(/Expired|Invalid/);
  });

  it('invalid signature → UnauthorizedError', () => {
    const svc = new JwtService('test-secret-A', '1h');
    const token = svc.sign({ userId: 'x', role: 'USER' });
    const other = new JwtService('test-secret-B', '1h');
    expect(() => other.verify(token)).toThrow(/Invalid|Expired/);
  });

  it('malformed token → UnauthorizedError', () => {
    const svc = new JwtService('test-secret-change-me', '1h');
    expect(() => svc.verify('not.a.jwt')).toThrow(/Invalid/);
  });

  const mockRes = {} as Response;

  it('requireAuth with no Authorization → 401', () => {
    const req = { headers: {} } as Request;
    const mockNext = nextMock();
    requireAuth(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledTimes(1);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(UnauthorizedError);
    expect((err as unknown as { statusCode: number }).statusCode).toBe(401);
  });

  it('requireAuth with Bearer <malformed> → 401', () => {
    const req = { headers: { authorization: 'Bearer badtoken' } } as Request;
    const mockNext = nextMock();
    requireAuth(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledTimes(1);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(UnauthorizedError);
  });

  it('requireAuth with valid Bearer token → attaches req.user with userId+role only', () => {
    const svc = new JwtService('test-secret-change-me', '1h');
    const token = svc.sign({ userId: 'u-99', role: 'USER' });
    const req = { headers: { authorization: `Bearer ${token}` } } as Request;
    const mockNext = nextMock();
    requireAuth(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledWith();
    expect(req.user).toEqual({ userId: 'u-99', role: 'USER' });
    expect(Object.keys(req.user!).sort()).toEqual(['role', 'userId']);
  });
});

describe('RBAC: requireRole middleware factory', () => {
  const mockRes = {} as Response;

  it('ADMIN → requireRole(ADMIN) → passes', () => {
    const req = { user: { userId: 'a', role: 'ADMIN' } } as Request;
    const mockNext = nextMock();
    requireRole('ADMIN')(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledWith();
  });

  it('USER → requireRole(ADMIN) → 403 Forbidden', () => {
    const req = { user: { userId: 'u', role: 'USER' } } as Request;
    const mockNext = nextMock();
    requireRole('ADMIN')(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledTimes(1);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(ForbiddenError);
    expect((err as unknown as { statusCode: number }).statusCode).toBe(403);
  });

  it('no user → requireRole → 401 Unauthorized', () => {
    const req = {} as Request;
    const mockNext = nextMock();
    requireRole('ADMIN')(req, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledTimes(1);
    const err = nextErr(mockNext.mock.calls[0]);
    expect(err).toBeInstanceOf(UnauthorizedError);
  });
});

describe('Ownership → User → Patient → Medication', () => {
  let patientRepo: MockRepo;
  let medicationRepo: MockRepo;

  beforeEach(() => {
    patientRepo = { findById: mk(), findByIdAndUserId: mk() };
    medicationRepo = {
      findById: mk(),
      findByIdAndPatientId: mk(),
      findByIdAndUserId: mk(),
      findDuplicate: mk().mockResolvedValue(null),
      create: mk(),
    };
  });

  it('User A → Patient A medication create → success', async () => {
    patientRepo.findByIdAndUserId!.mockResolvedValue(
      buildPatient({ id: 'p-1', userId: 'u-A' }),
    );
    medicationRepo.create!.mockResolvedValue(
      buildMedication({ id: 'm-new', patientId: 'p-1' }),
    );

    const uc = new CreateMedication(medicationRepo as never, patientRepo as never);
    const out = await uc.execute({
      userId: 'u-A',
      patientId: 'p-1',
      name: 'X',
      dosage: '10mg',
      quantity: 10,
    });

    expect(patientRepo.findByIdAndUserId).toHaveBeenCalledWith('p-1', 'u-A');
    expect(out.patientId).toBe('p-1');
  });

  it('User B tries to create medication for Patient A → NotFound (404) avoids enumeration', async () => {
    patientRepo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new CreateMedication(medicationRepo as never, patientRepo as never);
    await expect(
      uc.execute({
        userId: 'u-B',
        patientId: 'p-1',
        name: 'X',
        dosage: '10mg',
        quantity: 10,
      }),
    ).rejects.toThrow(NotFoundError);
    expect(medicationRepo.create).not.toHaveBeenCalled();
  });

  it('User B reads Medication A (through Patient A) → NotFound', async () => {
    medicationRepo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new GetMedicationById(medicationRepo as never);
    await expect(
      uc.execute({ userId: 'u-B', medicationId: 'm-1' }),
    ).rejects.toThrow(NotFoundError);
    expect(medicationRepo.findByIdAndUserId).toHaveBeenCalledWith('m-1', 'u-B');
  });
});

describe('Ownership → User → Medication (via Patient) → Schedule', () => {
  let medicationRepo: MockRepo;
  let scheduleRepo: MockRepo;

  beforeEach(() => {
    medicationRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    scheduleRepo = {
      findByIdAndUserId: mk(),
      findById: mk(),
      create: mk(),
      delete: mk(),
    };
  });

  it('Owner creates Schedule for their Medication → success', async () => {
    medicationRepo.findByIdAndUserId!.mockResolvedValue(
      buildMedication({ id: 'm-1', patientId: 'p-A' }),
    );
    scheduleRepo.create!.mockResolvedValue(
      buildSchedule({ id: 's-new', medicationId: 'm-1' }),
    );

    const uc = new CreateSchedule(scheduleRepo as never, medicationRepo as never);
    const out = await uc.execute('u-A', {
      medicationId: 'm-1',
      dosage: '500mg',
      startDate: now(),
    });

    expect(medicationRepo.findByIdAndUserId).toHaveBeenCalledWith('m-1', 'u-A');
    expect(out.medicationId).toBe('m-1');
  });

  it('Non-owner cannot create Schedule for someone else’s Medication → NotFound', async () => {
    medicationRepo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new CreateSchedule(scheduleRepo as never, medicationRepo as never);
    await expect(
      uc.execute('u-B', {
        medicationId: 'm-1',
        dosage: '500mg',
        startDate: now(),
      }),
    ).rejects.toThrow(NotFoundError);
    expect(scheduleRepo.create).not.toHaveBeenCalled();
  });

  it('Non-owner cannot delete Schedule → NotFound', async () => {
    scheduleRepo.findByIdAndUserId!.mockResolvedValue(null);

    const uc = new DeleteSchedule(scheduleRepo as never);
    await expect(uc.execute('u-B', 's-1')).rejects.toThrow(NotFoundError);
    expect(scheduleRepo.delete).not.toHaveBeenCalled();
    expect(scheduleRepo.findByIdAndUserId).toHaveBeenCalledWith('s-1', 'u-B');
  });
});

describe('Privilege escalation: profile update DTO rejects role', () => {
  it('UpdateMyProfile only writes firstName/lastName/phone (never role/passwordHash)', async () => {
    const userRepo: MockRepo = {
      findById: mk(),
      update: mk(),
    };
    const existing = buildUser({ id: 'u-1', role: 'USER' });
    userRepo.findById!.mockResolvedValue(existing);
    userRepo.update!.mockResolvedValue(existing);

    const uc = new UpdateMyProfile(userRepo as never);
    await uc.execute({ userId: 'u-1', firstName: 'M' } as never);

    expect(userRepo.update).toHaveBeenCalledTimes(1);
    const [, patch] = userRepo.update!.mock.calls[0] as [string, Partial<User>];
    expect((patch as Record<string, unknown>).role).toBeUndefined();
    expect((patch as Record<string, unknown>).passwordHash).toBeUndefined();
  });
});

describe('MedicineBox: ADMIN provision (userId=NULL, READY) + USER activation', () => {
  let boxRepo: MockRepo;

  beforeEach(() => {
    boxRepo = {
      findById: mk(),
      create: mk(),
      existsByDeviceId: mk(),
      activateAtomic: mk(),
      findByDeviceId: mk(),
    };
  });

  it('ADMIN provision → status READY, userId NULL (admin not owner)', async () => {
    boxRepo.existsByDeviceId!.mockResolvedValue(false);
    boxRepo.create!.mockResolvedValue(
      buildMedicineBox({ id: 'box-new', userId: null, status: 'READY' }),
    );

    const uc = new AddMedicineBox(boxRepo as never);
    const out = await uc.execute({
      deviceId: 'DEV-NEW',
      deviceToken: 't',
      name: 'B',
      numberOfDrawers: 4,
      drawerCapacity: 15,
    });

    expect(boxRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({ userId: null, status: 'READY' }),
    );
    expect(out.userId).toBeNull();
    expect(out.status).toBe('READY');
  });

  it('USER activates a READY box → owner becomes authenticatedUser.id, status ACTIVE', async () => {
    const registered = buildMedicineBox({ id: 'box-1', userId: null, status: 'READY', deviceId: 'DEV-001', deviceToken: 'tok-ok' });
    boxRepo.findByDeviceId!.mockResolvedValue(registered);
    boxRepo.activateAtomic!.mockResolvedValue({
      kind: 'success',
      box: { ...registered, userId: 'u-A', status: 'ACTIVE', updatedAt: now() },
    });

    const uc = new ActivateMedicineBox(boxRepo as never);
    const out = await uc.execute('u-A', { deviceId: 'DEV-001', deviceToken: 'tok-ok' });
    expect(boxRepo.activateAtomic).toHaveBeenCalledWith('DEV-001', 'u-A');
    expect(out.userId).toBe('u-A');
    expect(out.status).toBe('ACTIVE');
  });

  it('USER tries to activate already-owned box → ConflictError (prevents stealing)', async () => {
    boxRepo.findByDeviceId!.mockResolvedValue(
      buildMedicineBox({ id: 'box-1', deviceId: 'DEV-X', deviceToken: 'tok', userId: 'someone-else', status: 'ACTIVE' }),
    );
    const uc = new ActivateMedicineBox(boxRepo as never);
    await expect(uc.execute('attacker', { deviceId: 'DEV-X', deviceToken: 'tok' })).rejects.toThrow(
      ConflictError,
    );
    expect(boxRepo.activateAtomic).not.toHaveBeenCalled();
  });
});

describe('Drawer + DrawerMedication ownership', () => {
  let boxRepo: MockRepo;
  let drawerRepo: MockRepo;
  let drawerMedRepo: MockRepo;
  let medicationRepo: MockRepo;
  let patientRepo: MockRepo;

  beforeEach(() => {
    boxRepo = { findById: mk(), findByIdAndUserId: mk() };
    drawerRepo = {
      findById: mk(),
      findByIdAndMedicineBoxId: mk(),
      findAllByMedicineBoxId: mk(),
    };
    drawerMedRepo = { upsert: mk(), create: mk(), findByDrawerId: mk().mockResolvedValue(null), findByMedicationId: mk().mockResolvedValue(null) };
    medicationRepo = { findById: mk(), findDuplicate: mk().mockResolvedValue(null) };
    patientRepo = { findById: mk() };
  });

  it('owner reads drawers from their Box A → success', async () => {
    boxRepo.findByIdAndUserId!.mockResolvedValue(
      buildMedicineBox({ id: 'box-A', userId: 'u-A', status: 'ACTIVE' }),
    );
    drawerRepo.findAllByMedicineBoxId!.mockResolvedValue([
      buildDrawer({ id: 'd-1', medicineBoxId: 'box-A', drawerNumber: 1 }),
      buildDrawer({ id: 'd-2', medicineBoxId: 'box-A', drawerNumber: 2 }),
    ]);

    const uc = new GetDrawers(drawerRepo as never, boxRepo as never);
    const out = await uc.execute({ userId: 'u-A', boxId: 'box-A' });
    expect(out).toHaveLength(2);
  });

  it('non-owner reads Box A drawers → NotFound (404)', async () => {
    boxRepo.findByIdAndUserId!.mockResolvedValue(null);
    const uc = new GetDrawers(drawerRepo as never, boxRepo as never);
    await expect(uc.execute({ userId: 'u-B', boxId: 'box-A' })).rejects.toThrow(NotFoundError);
  });

  it('AssignMedicationToDrawer requires ownership on BOTH sides (Drawer + Medication)', async () => {
    boxRepo.findByIdAndUserId!.mockResolvedValue(
      buildMedicineBox({ id: 'box-A', userId: 'u-A', status: 'ACTIVE' }),
    );
    drawerRepo.findByIdAndMedicineBoxId!.mockResolvedValue(
      buildDrawer({ id: 'd-1', medicineBoxId: 'box-A' }),
    );
    medicationRepo.findById!.mockResolvedValue(buildMedication({ id: 'm-B', patientId: 'p-B' }));
    patientRepo.findById!.mockResolvedValue(buildPatient({ id: 'p-B', userId: 'u-B' }));
    drawerMedRepo.create!.mockResolvedValue(buildDrawerMedication());

    const uc = new AssignMedicationToDrawer(
      drawerMedRepo as never,
      drawerRepo as never,
      boxRepo as never,
      medicationRepo as never,
      patientRepo as never,
    );

    await expect(
      uc.execute({
        userId: 'u-A',
        boxId: 'box-A',
        drawerId: 'd-1',
        medicationId: 'm-B',
        quantity: 20,
        missingQuantity: 70,
      }),
    ).rejects.toThrow(NotFoundError);
    expect(drawerMedRepo.create).not.toHaveBeenCalled();
  });

  it('Both owned by same user → assignment allowed', async () => {
    boxRepo.findByIdAndUserId!.mockResolvedValue(
      buildMedicineBox({ id: 'box-A', userId: 'u-A', status: 'ACTIVE' }),
    );
    drawerRepo.findByIdAndMedicineBoxId!.mockResolvedValue(
      buildDrawer({ id: 'd-1', medicineBoxId: 'box-A' }),
    );
    medicationRepo.findById!.mockResolvedValue(buildMedication({ id: 'm-A', patientId: 'p-A', quantity: 90 }));
    patientRepo.findById!.mockResolvedValue(buildPatient({ id: 'p-A', userId: 'u-A' }));
    drawerMedRepo.create!.mockResolvedValue(
      buildDrawerMedication({ drawerId: 'd-1', medicationId: 'm-A', quantity: 20, missingQuantity: 70 }),
    );

    const uc = new AssignMedicationToDrawer(
      drawerMedRepo as never,
      drawerRepo as never,
      boxRepo as never,
      medicationRepo as never,
      patientRepo as never,
    );
    const out = await uc.execute({
      userId: 'u-A',
      boxId: 'box-A',
      drawerId: 'd-1',
      medicationId: 'm-A',
      quantity: 20,
      missingQuantity: 70,
    });
    expect(drawerMedRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({ quantity: 20, missingQuantity: 70 }),
    );
    expect(out.drawerId).toBe('d-1');
    expect(out.medicationId).toBe('m-A');
    expect(out.quantity).toBe(20);
    expect(out.missingQuantity).toBe(70);
  });
});

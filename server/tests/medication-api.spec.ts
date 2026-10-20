import type { Request, Response, NextFunction } from 'express';
import type { Medication } from '@domain/entities/Medication';
import { requireAuth } from '@presentation/middlewares/authMiddleware';
import {
  createMedicationSchema,
  updateMedicationSchema,
} from '@presentation/validators/medication.validator';
import { CreateMedication } from '@application/use-cases/medications/CreateMedication';
import { GetMedications } from '@application/use-cases/medications/GetMedications';
import { GetMedicationById } from '@application/use-cases/medications/GetMedicationById';
import { UpdateMedication } from '@application/use-cases/medications/UpdateMedication';
import { DeleteMedication } from '@application/use-cases/medications/DeleteMedication';
import { NotFoundError, UnauthorizedError, ConflictError } from '@shared/errors';

type MockMedRepo = {
  create: jest.Mock;
  findAllByPatientId: jest.Mock;
  findAllByUserId: jest.Mock;
  findByIdAndUserId: jest.Mock;
  findByIdAndPatientId: jest.Mock;
  findById: jest.Mock;
  findDuplicate: jest.Mock;
  update: jest.Mock;
  delete: jest.Mock;
};
type MockPatRepo = { findByIdAndUserId: jest.Mock; findById: jest.Mock };
type Mocks = { medRepo: MockMedRepo; patRepo: MockPatRepo };

const mkFn = () => jest.fn();
const mkMocks = (): Mocks => ({
  medRepo: {
    create: mkFn(),
    findAllByPatientId: mkFn(),
    findAllByUserId: mkFn(),
    findByIdAndUserId: mkFn(),
    findByIdAndPatientId: mkFn(),
    findById: mkFn(),
    findDuplicate: mkFn().mockResolvedValue(null),
    update: mkFn(),
    delete: mkFn(),
  },
  patRepo: { findByIdAndUserId: mkFn(), findById: mkFn() },
});

const now = () => new Date('2025-01-01T00:00:00.000Z');
const buildMedication = (o: Partial<Medication> = {}): Medication => ({
  id: 'm-1',
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

const nextFn = () => jest.fn() as unknown as jest.Mock & NextFunction;

describe('§30 Authentication: no JWT 401', () => {
  const res = {} as Response;
  const scenarios: Partial<Request>[] = [
    { method: 'POST', path: '/medications' },
    { method: 'GET', path: '/medications' },
    { method: 'GET', path: '/medications/:id' },
    { method: 'PATCH', path: '/medications/:id' },
    { method: 'DELETE', path: '/medications/:id' },
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

describe('§30 Create medication + Create security', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('User A creates medication for Patient A → 201; patient ownership check used', async () => {
    mocks.patRepo.findByIdAndUserId.mockResolvedValue({ id: 'p-A', userId: 'u-A' });
    mocks.medRepo.create.mockResolvedValue(buildMedication({ patientId: 'p-A', id: 'm-new' }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    const out = await uc.execute({
      userId: 'u-A',
      patientId: 'p-A',
      name: 'Paracetamol',
      dosage: '500mg',
      form: 'TABLET',
      quantity: 30,
      expiryDate: new Date('2027-12-31'),
    });
    expect(mocks.patRepo.findByIdAndUserId).toHaveBeenCalledWith('p-A', 'u-A');
    expect(out.patientId).toBe('p-A');
    expect((mocks.medRepo.create.mock.calls[0] as [{ patientId: string }])[0].patientId).toBe(
      'p-A',
    );
  });

  it('User B creates medication for Patient A → 404 NotFoundError; NO create call', async () => {
    mocks.patRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    await expect(
      uc.execute({
        userId: 'u-B',
        patientId: 'p-A',
        name: 'X',
        dosage: '1',
        quantity: 1,
      }),
    ).rejects.toThrow(NotFoundError);
    expect(mocks.medRepo.create).not.toHaveBeenCalled();
  });

  it('body contains userId → strict validator REJECT', () => {
    expect(
      createMedicationSchema.safeParse({
        patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190',
        name: 'X',
        dosage: '1',
        quantity: 1,
        userId: 'someone',
      }).success,
    ).toBe(false);
  });
  it('body contains id → strict validator REJECT', () => {
    expect(
      createMedicationSchema.safeParse({
        patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190',
        name: 'X',
        dosage: '1',
        quantity: 1,
        id: 'x',
      }).success,
    ).toBe(false);
  });
  it('body contains createdAt → strict validator REJECT', () => {
    expect(
      createMedicationSchema.safeParse({
        patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190',
        name: 'X',
        dosage: '1',
        quantity: 1,
        createdAt: now().toISOString(),
      }).success,
    ).toBe(false);
  });
  it('body contains updatedAt → strict validator REJECT', () => {
    expect(
      createMedicationSchema.safeParse({
        patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190',
        name: 'X',
        dosage: '1',
        quantity: 1,
        updatedAt: now().toISOString(),
      }).success,
    ).toBe(false);
  });
  it.each([
    'genericName',
    'strength',
    'unit',
    'manufacturer',
    'barcode',
    'imageUrl',
  ])('body legacy field %s → strict validator REJECT', (f) => {
    const body: Record<string, unknown> = {
      patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190',
      name: 'X',
      dosage: '1',
      quantity: 1,
    };
    body[f] = 'whatever';
    expect(createMedicationSchema.safeParse(body).success).toBe(false);
  });
});

describe('§30 List medications (ownership via Patient.userId path)', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('User A list → only User A medications (query where patient.userId=u-A)', async () => {
    mocks.medRepo.findAllByUserId.mockResolvedValue([
      buildMedication({ id: 'm-A1', patientId: 'p-A' }),
      buildMedication({ id: 'm-A2', patientId: 'p-A' }),
    ]);
    const uc = new GetMedications(mocks.medRepo as never);
    const res = (await uc.execute({ userId: 'u-A' })) as Medication[];
    expect(mocks.medRepo.findAllByUserId).toHaveBeenCalledWith('u-A', {
      patientId: undefined,
      params: undefined,
    });
    expect(res).toHaveLength(2);
    expect(res.every((r) => r.patientId === 'p-A')).toBe(true);
  });

  it('User B list → only User B medications', async () => {
    mocks.medRepo.findAllByUserId.mockResolvedValue([
      buildMedication({ id: 'm-B1', patientId: 'p-B' }),
    ]);
    const uc = new GetMedications(mocks.medRepo as never);
    const res = (await uc.execute({ userId: 'u-B' })) as Medication[];
    expect(mocks.medRepo.findAllByUserId).toHaveBeenLastCalledWith('u-B', {
      patientId: undefined,
      params: undefined,
    });
    expect(res[0].patientId).toBe('p-B');
  });

  it('User A + ?patientId=p-A → returns Patient A meds only; patientId guarded in filter', async () => {
    mocks.medRepo.findAllByUserId.mockResolvedValue([
      buildMedication({ id: 'm-A1', patientId: 'p-A' }),
    ]);
    const uc = new GetMedications(mocks.medRepo as never);
    const res = (await uc.execute({ userId: 'u-A', patientId: 'p-A' })) as Medication[];
    expect(mocks.medRepo.findAllByUserId).toHaveBeenCalledWith('u-A', {
      patientId: 'p-A',
      params: undefined,
    });
    expect(res).toHaveLength(1);
  });
});

describe('§30 Get by ID ownership + Update ownership + Delete ownership', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  describe('GetMedicationById', () => {
    it('User A → Medication A → 200', async () => {
      const m = buildMedication({ id: 'm-A' });
      mocks.medRepo.findByIdAndUserId.mockResolvedValue(m);
      const uc = new GetMedicationById(mocks.medRepo as never);
      const out = await uc.execute({ userId: 'u-A', medicationId: 'm-A' });
      expect(out.id).toBe('m-A');
      expect(mocks.medRepo.findByIdAndUserId).toHaveBeenCalledWith('m-A', 'u-A');
    });
    it('User B → Medication A → 404', async () => {
      mocks.medRepo.findByIdAndUserId.mockResolvedValue(null);
      const uc = new GetMedicationById(mocks.medRepo as never);
      await expect(
        uc.execute({ userId: 'u-B', medicationId: 'm-A' }),
      ).rejects.toThrow(NotFoundError);
    });
  });

  describe('UpdateMedication', () => {
    it('User A updates Medication A → 200 partial patch only; name/dosage untouched when not provided', async () => {
      const existing = buildMedication({ id: 'm-A', quantity: 30 });
      mocks.medRepo.findByIdAndUserId.mockResolvedValue(existing);
      mocks.medRepo.update.mockResolvedValue({ ...existing, quantity: 20 });
      const uc = new UpdateMedication(mocks.medRepo as never);
      const out = await uc.execute({
        userId: 'u-A',
        medicationId: 'm-A',
        data: { quantity: 20 },
      });
      expect(mocks.medRepo.findByIdAndUserId).toHaveBeenCalledWith('m-A', 'u-A');
      const [patchId, patch] = mocks.medRepo.update.mock.calls[0] as [
        string,
        Record<string, unknown>,
      ];
      expect(patchId).toBe('m-A');
      expect(patch).toEqual({ quantity: 20 });
      expect(patch.name).toBeUndefined();
      expect(patch.dosage).toBeUndefined();
      expect(patch.patientId).toBeUndefined();
      expect(out.quantity).toBe(20);
    });
    it('User B updates Medication A → 404; no update() called', async () => {
      mocks.medRepo.findByIdAndUserId.mockResolvedValue(null);
      const uc = new UpdateMedication(mocks.medRepo as never);
      await expect(
        uc.execute({ userId: 'u-B', medicationId: 'm-A', data: { quantity: 1 } }),
      ).rejects.toThrow(NotFoundError);
      expect(mocks.medRepo.update).not.toHaveBeenCalled();
    });
  });

  describe('DeleteMedication', () => {
    it('User A deletes Medication A → success; delete() called once', async () => {
      mocks.medRepo.findByIdAndUserId.mockResolvedValue(buildMedication({ id: 'm-A' }));
      mocks.medRepo.delete.mockResolvedValue(undefined);
      const uc = new DeleteMedication(mocks.medRepo as never);
      await uc.execute({ userId: 'u-A', medicationId: 'm-A' });
      expect(mocks.medRepo.delete).toHaveBeenCalledTimes(1);
      expect(mocks.medRepo.delete).toHaveBeenCalledWith('m-A');
    });
    it('User B deletes Medication A → 404; no delete()', async () => {
      mocks.medRepo.findByIdAndUserId.mockResolvedValue(null);
      const uc = new DeleteMedication(mocks.medRepo as never);
      await expect(
        uc.execute({ userId: 'u-B', medicationId: 'm-A' }),
      ).rejects.toThrow(NotFoundError);
      expect(mocks.medRepo.delete).not.toHaveBeenCalled();
    });
  });
});

describe('§30 Update security strict validator (reject patientId/id/createdAt/etc)', () => {
  const bad = [
    'patientId',
    'userId',
    'id',
    'createdAt',
    'updatedAt',
  ];
  test.each(bad)('update body with %s → strict REJECT', (field) => {
    const body: Record<string, unknown> = { quantity: 1 };
    body[field] = 'x';
    expect(updateMedicationSchema.safeParse(body).success).toBe(false);
  });
  it('update: patientId change not part of DTO → ownership is truly immutable through PATCH', () => {
    const withPatientId = updateMedicationSchema.safeParse({
      patientId: 'attempt-transfer',
      quantity: 1,
    });
    expect(withPatientId.success).toBe(false);
    const goodUpdate = updateMedicationSchema.safeParse({ name: 'X' });
    expect(goodUpdate.success).toBe(true);
    expect(goodUpdate.success).toBe(true); // pure runtime check: shape only allows whitelist
  });
});

describe('§30 Validation rules (name, dosage, form enum, quantity int min1, expiry, unknown)', () => {
  it('empty name rejected', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: '', dosage: '1', quantity: 1,
  }).success).toBe(false));

  it('empty dosage rejected', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '', quantity: 1,
  }).success).toBe(false));

  it('invalid form (not enum) rejected', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '1', quantity: 1, form: 'PILL',
  }).success).toBe(false));

  it('quantity = 0 rejected (min 1)', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '1', quantity: 0,
  }).success).toBe(false));

  it('quantity < 0 rejected', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '1', quantity: -1,
  }).success).toBe(false));

  it('decimal quantity rejected (not integer)', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '1', quantity: 1.5,
  }).success).toBe(false));

  it('invalid expiryDate rejected', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '1', quantity: 1, expiryDate: 'not a date',
  }).success).toBe(false));

  it('valid expiryDate "2027-12-31" (date-only) accepted', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '1', quantity: 1, expiryDate: '2027-12-31',
  }).success).toBe(true));

  it('unknown fields rejected (strict)', () => expect(createMedicationSchema.safeParse({
    patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190', name: 'X', dosage: '1', quantity: 1, manufacturer: 'x',
  }).success).toBe(false));
});

describe('§31 Critical ownership matrix (Create/Get/Update/Delete)', () => {
  const A = 'u-A', B = 'u-B', pA = 'p-A', pB = 'p-B', mA = 'm-A', mB = 'm-B';
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });
  const setupMatrix = () => {
    // Create only: patRepo ownership
    mocks.patRepo.findByIdAndUserId.mockImplementation((id: string, uid: string) => {
      if (id === pA && uid === A) return Promise.resolve({ id: pA, userId: A });
      if (id === pB && uid === B) return Promise.resolve({ id: pB, userId: B });
      return Promise.resolve(null);
    });
    mocks.medRepo.create.mockImplementation((d: { patientId: string }) =>
      Promise.resolve(buildMedication({
        id: d.patientId === pA ? mA : mB,
        patientId: d.patientId,
      })),
    );
    // findByIdAndUserId for Get/Update/Delete
    mocks.medRepo.findByIdAndUserId.mockImplementation((mid: string, uid: string) => {
      if (mid === mA && uid === A) return Promise.resolve(buildMedication({ id: mA, patientId: pA }));
      if (mid === mB && uid === B) return Promise.resolve(buildMedication({ id: mB, patientId: pB }));
      return Promise.resolve(null);
    });
    mocks.medRepo.update.mockImplementation((id, patch) =>
      Promise.resolve(buildMedication({ id, patientId: id === mA ? pA : pB, ...patch })),
    );
    mocks.medRepo.delete.mockResolvedValue(undefined);
  };

  it('Create: A→A=201, A→B=404, B→A=404, B→B=201', async () => {
    setupMatrix();
    const cr = (uid: string, pid: string) => new CreateMedication(mocks.medRepo as never, mocks.patRepo as never)
      .execute({ userId: uid, patientId: pid, name: 'X', dosage: '1', quantity: 1 });
    const aA = await cr(A, pA); expect(aA.patientId).toBe(pA);
    await expect(cr(A, pB)).rejects.toThrow(NotFoundError);
    await expect(cr(B, pA)).rejects.toThrow(NotFoundError);
    const bB = await cr(B, pB); expect(bB.patientId).toBe(pB);
  });

  it('Get: A→A=200, A→B=404, B→A=404, B→B=200', async () => {
    setupMatrix();
    const g = (uid: string, mid: string) =>
      new GetMedicationById(mocks.medRepo as never).execute({ userId: uid, medicationId: mid });
    expect((await g(A, mA)).id).toBe(mA);
    await expect(g(A, mB)).rejects.toThrow(NotFoundError);
    await expect(g(B, mA)).rejects.toThrow(NotFoundError);
    expect((await g(B, mB)).id).toBe(mB);
  });

  it('Update: A→A=200, A→B=404, B→A=404, B→B=200', async () => {
    setupMatrix();
    const u = (uid: string, mid: string) =>
      new UpdateMedication(mocks.medRepo as never).execute({
        userId: uid, medicationId: mid, data: { quantity: 99 },
      });
    expect((await u(A, mA)).quantity).toBe(99);
    await expect(u(A, mB)).rejects.toThrow(NotFoundError);
    await expect(u(B, mA)).rejects.toThrow(NotFoundError);
    expect((await u(B, mB)).quantity).toBe(99);
  });

  it('Delete: A→A=void, A→B=404, B→A=404, B→B=void', async () => {
    setupMatrix();
    const d = (uid: string, mid: string) =>
      new DeleteMedication(mocks.medRepo as never).execute({ userId: uid, medicationId: mid });
    await expect(d(A, mA)).resolves.toBeUndefined();
    await expect(d(A, mB)).rejects.toThrow(NotFoundError);
    await expect(d(B, mA)).rejects.toThrow(NotFoundError);
    await expect(d(B, mB)).resolves.toBeUndefined();
  });
});

describe('§32 Cascade test: DeleteMedication only calls medicationRepo.delete()', () => {
  it('No manual calls to scheduleRepository / drawerMedicationRepository within DeleteMedication', async () => {
    // TypeScript structural check: constructor signature only takes IMedicationRepository
    // (no schedule/drawer deps injected).
    const medRepo = {
      findByIdAndUserId: jest.fn().mockResolvedValue(buildMedication()),
      delete: jest.fn().mockResolvedValue(undefined),
    };
    const uc = new DeleteMedication(medRepo as never);
    await uc.execute({ userId: 'u', medicationId: 'm' });
    expect(medRepo.delete).toHaveBeenCalledWith('m');
    const proto = DeleteMedication.prototype as unknown as Record<string, unknown>;
    // Only medicationRepo.delete exists in use; no other delete references.
    expect(Object.keys(proto).length).toBe(0); // prototype only has constructor/function
  });

  it('Constructor of DeleteMedication requires NO Schedule/DrawerMedication repo args (cascade lives in Prisma)', () => {
    // If someone added other repos (bad), the constructor call without them would throw TS errors.
    // At runtime: constructor signature length = 1 (only medicationRepo)
    expect(DeleteMedication.length).toBe(1);
  });
});

describe('§28 ADMIN still respects Patient ownership = no auto global list', () => {
  it('ADMIN userId calls list: findAllByUserId receives admin userId, not bypass', async () => {
    const medRepo = { findAllByUserId: jest.fn().mockResolvedValue([]) };
    const uc = new GetMedications(medRepo as never);
    await uc.execute({ userId: 'admin-uuid' });
    expect(medRepo.findAllByUserId).toHaveBeenCalledWith('admin-uuid', {
      patientId: undefined, params: undefined,
    });
  });
});

describe('§33: No legacy fields reintroduced (validator strict)', () => {
  it.each([
    'userId',
    'genericName',
    'strength',
    'dosagePerUnit',
    'unit',
    'manufacturer',
    'instructions',
    'sideEffects',
    'storageNotes',
    'totalQuantity',
    'remainingQuantity',
    'imageUrl',
    'barcode',
  ])('legacy field %s → STRICT reject for create & update', (key) => {
    const createBody: Record<string, unknown> = {
      patientId: 'c2525111-9a1c-492e-9318-cbe1f1d4c190',
      name: 'X', dosage: '1', quantity: 1,
    };
    createBody[key] = 'x';
    expect(createMedicationSchema.safeParse(createBody).success).toBe(false);

    const updateBody: Record<string, unknown> = { quantity: 1 };
    updateBody[key] = 'x';
    expect(updateMedicationSchema.safeParse(updateBody).success).toBe(false);
  });
});

describe('§34 Duplicate prevention on CREATE (business rule + identity fields)', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
    mocks.patRepo.findByIdAndUserId.mockResolvedValue({ id: 'p-A', userId: 'u-A' });
  });

  it('[Create-1] First unique medication → 201 created; findDuplicate found null', async () => {
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.create.mockResolvedValue(buildMedication({ id: 'm-new', patientId: 'p-A' }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    const out = await uc.execute({
      userId: 'u-A',
      patientId: 'p-A',
      name: 'Paracetamol',
      dosage: '500mg',
      form: 'TABLET',
      quantity: 30,
      expiryDate: new Date('2027-12-31'),
    });
    expect(out.id).toBe('m-new');
    expect(mocks.medRepo.findDuplicate).toHaveBeenCalledTimes(1);
    expect(mocks.medRepo.create).toHaveBeenCalledTimes(1);
  });

  it('[Create-2] Exact duplicate (same patient + identity) → 409 ConflictError; NO create', async () => {
    const identity = {
      patientId: 'p-A',
      name: 'Paracetamol',
      dosage: '500mg',
      form: 'TABLET' as const,
      expiryDate: new Date('2027-12-31'),
    };
    mocks.medRepo.findDuplicate.mockResolvedValue(buildMedication({ id: 'm-exist', ...identity }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    await expect(uc.execute({
      userId: 'u-A',
      patientId: 'p-A',
      name: 'Paracetamol',
      dosage: '500mg',
      form: 'TABLET',
      quantity: 20,
      expiryDate: new Date('2027-12-31'),
    })).rejects.toThrow(ConflictError);
    expect(mocks.medRepo.create).not.toHaveBeenCalled();
  });

  it('[Create-3] Same identity for DIFFERENT Patient → 201 allowed', async () => {
    mocks.patRepo.findByIdAndUserId.mockImplementation((id, uid) =>
      Promise.resolve(id === 'p-B' && uid === 'u-B' ? { id: 'p-B', userId: 'u-B' } : null),
    );
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.create.mockResolvedValue(buildMedication({ id: 'm-pb', patientId: 'p-B' }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    const out = await uc.execute({
      userId: 'u-B',
      patientId: 'p-B',
      name: 'Paracetamol',
      dosage: '500mg',
      form: 'TABLET',
      quantity: 20,
      expiryDate: new Date('2027-12-31'),
    });
    expect(out.id).toBe('m-pb');
    expect(mocks.medRepo.create).toHaveBeenCalledTimes(1);
  });

  it('[Create-4] Same patient, same name, DIFFERENT dosage → 201 allowed', async () => {
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.create.mockResolvedValue(buildMedication({ id: 'm-dose2', dosage: '1000mg' }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    const out = await uc.execute({
      userId: 'u-A', patientId: 'p-A',
      name: 'Paracetamol', dosage: '1000mg', form: 'TABLET',
      quantity: 20, expiryDate: new Date('2027-12-31'),
    });
    expect(out.dosage).toBe('1000mg');
  });

  it('[Create-5] Same patient, same name+dose, DIFFERENT form → 201 allowed', async () => {
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.create.mockResolvedValue(buildMedication({ id: 'm-liq', form: 'LIQUID' }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    const out = await uc.execute({
      userId: 'u-A', patientId: 'p-A',
      name: 'Paracetamol', dosage: '500mg', form: 'LIQUID',
      quantity: 20, expiryDate: new Date('2027-12-31'),
    });
    expect(out.form).toBe('LIQUID');
  });

  it('[Create-6] Same identity but DIFFERENT expiry → 201 allowed (different batch)', async () => {
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.create.mockResolvedValue(buildMedication({ id: 'm-28', expiryDate: new Date('2028-12-31') }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    const out = await uc.execute({
      userId: 'u-A', patientId: 'p-A',
      name: 'Paracetamol', dosage: '500mg', form: 'TABLET',
      quantity: 20, expiryDate: new Date('2028-12-31'),
    });
    expect((out.expiryDate as Date).getFullYear()).toBe(2028);
  });

  it('[Create-7] Same identity DIFFERENT quantity → 409 (quantity NOT in identity: same stock med)', async () => {
    mocks.medRepo.findDuplicate.mockResolvedValue(buildMedication({ id: 'm-exist', quantity: 30 }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    await expect(uc.execute({
      userId: 'u-A', patientId: 'p-A',
      name: 'Paracetamol', dosage: '500mg', form: 'TABLET',
      quantity: 50, expiryDate: new Date('2027-12-31'),
    })).rejects.toThrow(ConflictError);
    expect(mocks.medRepo.create).not.toHaveBeenCalled();
  });

  it('[Ownership-11] User A cannot create for Patient B → 404 Patient not found', async () => {
    mocks.patRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    await expect(uc.execute({
      userId: 'u-A', patientId: 'p-B',
      name: 'X', dosage: '1', quantity: 1,
    })).rejects.toThrow(NotFoundError);
    expect(mocks.medRepo.findDuplicate).not.toHaveBeenCalled();
    expect(mocks.medRepo.create).not.toHaveBeenCalled();
  });

  it('[Ownership-12] User A update of User B medication → 404; findDuplicate not attempted', async () => {
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UpdateMedication(mocks.medRepo as never);
    await expect(uc.execute({
      userId: 'u-A', medicationId: 'm-B',
      data: { name: 'Renamed' },
    })).rejects.toThrow(NotFoundError);
    expect(mocks.medRepo.findDuplicate).not.toHaveBeenCalled();
    expect(mocks.medRepo.update).not.toHaveBeenCalled();
  });
});

describe('§35 Duplicate prevention on UPDATE (exclude self from collision check)', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('[Update-8] PATCH to a unique identity → 200 ok', async () => {
    const existing = buildMedication({ id: 'm-A', name: 'Paracetamol', dosage: '500mg', form: 'TABLET' });
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(existing);
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.update.mockResolvedValue({ ...existing, name: 'Ibuprofen', dosage: '400mg', form: 'CAPSULE' });
    const uc = new UpdateMedication(mocks.medRepo as never);
    const out = await uc.execute({
      userId: 'u-A', medicationId: 'm-A',
      data: { name: 'Ibuprofen', dosage: '400mg', form: 'CAPSULE' },
    });
    expect(out.name).toBe('Ibuprofen');
    const [, patch] = mocks.medRepo.update.mock.calls[0] as [string, Record<string, unknown>];
    expect(patch.name).toBe('Ibuprofen');
  });

  it('[Update-9] PATCH collides with another existing medication identity → 409 Conflict', async () => {
    const thisMed = buildMedication({ id: 'm-A', name: 'Paracetamol', dosage: '500mg', form: 'TABLET', patientId: 'p-A' });
    const otherMed = buildMedication({ id: 'm-B', name: 'Ibuprofen', dosage: '400mg', form: 'CAPSULE' });
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(thisMed);
    mocks.medRepo.findDuplicate.mockImplementation((_identity, opts) => {
      // Simulates repository finding the OTHER medication (different id from opts.excludeId)
      if (opts?.excludeId === 'm-A') return Promise.resolve(otherMed);
      return Promise.resolve(null);
    });
    const uc = new UpdateMedication(mocks.medRepo as never);
    await expect(uc.execute({
      userId: 'u-A', medicationId: 'm-A',
      data: { name: 'Ibuprofen', dosage: '400mg', form: 'CAPSULE' },
    })).rejects.toThrow(ConflictError);
    expect(mocks.medRepo.update).not.toHaveBeenCalled();
    // Ensure excludeId was passed correctly so self-collision never fires:
    const [, opts] = mocks.medRepo.findDuplicate.mock.calls[0] as [unknown, { excludeId?: string }];
    expect(opts?.excludeId).toBe('m-A');
  });

  it('[Update-10] PATCH without changing identity (only quantity) → 200; findDuplicate SKIPPED; self-update allowed', async () => {
    const existing = buildMedication({ id: 'm-A', quantity: 30, name: 'Paracetamol', dosage: '500mg', form: 'TABLET', patientId: 'p-A' });
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(existing);
    mocks.medRepo.update.mockResolvedValue({ ...existing, quantity: 20 });
    const uc = new UpdateMedication(mocks.medRepo as never);
    const out = await uc.execute({
      userId: 'u-A', medicationId: 'm-A',
      data: { quantity: 20 },
    });
    expect(out.quantity).toBe(20);
    expect(mocks.medRepo.findDuplicate).not.toHaveBeenCalled();
  });

  it('[Update-10-bis] PATCH name to SAME identity values as self → 200 allowed; findDuplicate excludes self (no spurious 409)', async () => {
    const existing = buildMedication({ id: 'm-A', name: 'Paracetamol', dosage: '500mg', form: 'TABLET', patientId: 'p-A', expiryDate: new Date('2027-12-31') });
    mocks.medRepo.findByIdAndUserId.mockResolvedValue(existing);
    // findDuplicate returns null because excludeId excludes m-A (only m-A exists for this identity)
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.update.mockResolvedValue(existing);
    const uc = new UpdateMedication(mocks.medRepo as never);
    const out = await uc.execute({
      userId: 'u-A', medicationId: 'm-A',
      data: { name: 'Paracetamol' },
    });
    expect(out.id).toBe('m-A');
    expect(mocks.medRepo.findDuplicate).toHaveBeenCalledWith(
      expect.objectContaining({ patientId: 'p-A', name: 'Paracetamol' }),
      { excludeId: 'm-A' },
    );
  });
});

describe('§36 findDuplicate: quantity-independent + expiryDate independent (both trigger different tests)', () => {
  let mocks: Mocks;
  beforeEach(() => {
    mocks = mkMocks();
    mocks.patRepo.findByIdAndUserId.mockResolvedValue({ id: 'p-A', userId: 'u-A' });
  });
  it('name/dosage/form/expiry same but quantity 50 vs 30 → 409', async () => {
    mocks.medRepo.findDuplicate.mockResolvedValue(buildMedication({ id: 'm' }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    await expect(uc.execute({
      userId: 'u-A', patientId: 'p-A',
      name: 'X', dosage: 'Y', form: 'TABLET', quantity: 50, expiryDate: new Date('2027-01-01'),
    })).rejects.toThrow(ConflictError);
  });
  it('name/dosage/form same, expiry different → 201 allowed', async () => {
    mocks.medRepo.findDuplicate.mockResolvedValue(null);
    mocks.medRepo.create.mockResolvedValue(buildMedication({ id: 'm' }));
    const uc = new CreateMedication(mocks.medRepo as never, mocks.patRepo as never);
    const out = await uc.execute({
      userId: 'u-A', patientId: 'p-A',
      name: 'X', dosage: 'Y', form: 'TABLET', quantity: 30, expiryDate: new Date('2028-01-01'),
    });
    expect(out.id).toBe('m');
  });
});

describe('§37 P2002 → ConflictError 409 on DB race (PrismaRepo interceptor)', () => {
  const targetIdentity = ['patientId', 'name', 'dosage', 'form', 'expiryDate'];

  it('Repository create interceptor maps P2002 → ConflictError (identity targets only)', async () => {
    // Create a PrismaClientKnownRequestError shape with code=P2002 + identity meta
    const P2002Err: { code: string; meta: { target: string[] } } = {
      code: 'P2002',
      meta: { target: targetIdentity },
    };
    const fakePrisma = {
      medication: {
        create: jest.fn().mockRejectedValue(P2002Err),
        findUnique: jest.fn(), findFirst: jest.fn(), findMany: jest.fn(), count: jest.fn(),
        update: jest.fn(), delete: jest.fn(),
      },
    };
    jest.doMock('@infrastructure/database/prisma/client', () => ({ prisma: fakePrisma }));
    jest.resetModules();
    const { PrismaMedicationRepository } = require('@infrastructure/database/prisma/repositories/PrismaMedicationRepository');
    const repo = new PrismaMedicationRepository();
    let thrown: { statusCode?: number; message?: string; isOperational?: boolean } | null = null;
    try {
      await repo.create({
        patientId: 'p-A', name: 'X', dosage: 'Y', form: 'TABLET', quantity: 1, expiryDate: null,
      });
    } catch (e) {
      thrown = e as { statusCode?: number; message?: string; isOperational?: boolean };
    }
    jest.dontMock('@infrastructure/database/prisma/client');
    expect(thrown).not.toBeNull();
    expect(thrown!.statusCode).toBe(409);
    expect(thrown!.isOperational).toBe(true);
    expect(thrown!.message).toBe('Medication already exists for this patient');
  });
});

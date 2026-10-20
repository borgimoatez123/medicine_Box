import type { Request, Response, NextFunction } from 'express';
import type { DrawerMedication } from '@domain/entities/DrawerMedication';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import {
  createDrawerMedicationSchema,
  updateDrawerMedicationSchema,
} from '@presentation/validators/drawerMedication.validator';
import { AssignMedicationToDrawer } from '@application/use-cases/drawer-medications/AssignMedicationToDrawer';
import { GetMyDrawerMedications } from '@application/use-cases/drawer-medications/GetMyDrawerMedications';
import { GetDrawerMedicationById } from '@application/use-cases/drawer-medications/GetDrawerMedicationById';
import { UpdateDrawerMedication } from '@application/use-cases/drawer-medications/UpdateDrawerMedication';
import { UnassignMedicationFromDrawer } from '@application/use-cases/drawer-medications/UnassignMedicationFromDrawer';
import { GetAllDrawerMedications } from '@application/use-cases/drawer-medications/GetAllDrawerMedications';
import { GetDrawerMedicationByIdAdmin } from '@application/use-cases/drawer-medications/GetDrawerMedicationByIdAdmin';
import {
  NotFoundError,
  UnauthorizedError,
  ForbiddenError,
  ConflictError,
  BadRequestError,
} from '@shared/errors';
import { PrismaDrawerMedicationRepository } from '@infrastructure/database/prisma/repositories/PrismaDrawerMedicationRepository';

const mk = () => jest.fn();
const now = () => new Date('2026-01-01T00:00:00.000Z');
const nextFn = () => jest.fn() as unknown as jest.Mock & NextFunction;
const emptyRes = () => ({} as Response);

type MockDrawerMedRepo = {
  create: jest.Mock;
  findAll: jest.Mock;
  findAllByUserId: jest.Mock;
  findAllByMedicineBoxId: jest.Mock;
  findById: jest.Mock;
  findByIdAndUserId: jest.Mock;
  findByDrawerId: jest.Mock;
  findByMedicationId: jest.Mock;
  upsert: jest.Mock;
  update: jest.Mock;
  delete: jest.Mock;
};
type MockDrawerRepo = { findByIdAndUserId: jest.Mock };
type MockMedRepo = { findByIdAndUserId: jest.Mock; findDuplicate: jest.Mock };
type MockMedicineBoxRepo = { findByIdAndUserId: jest.Mock };

const mockDm = (): MockDrawerMedRepo => ({
  create: mk(),
  findAll: mk(),
  findAllByUserId: mk(),
  findAllByMedicineBoxId: mk(),
  findById: mk(),
  findByIdAndUserId: mk(),
  findByDrawerId: mk(),
  findByMedicationId: mk(),
  upsert: mk(),
  update: mk(),
  delete: mk(),
});

const mockMb = (): MockMedicineBoxRepo => ({ findByIdAndUserId: mk().mockResolvedValue({ status: 'ACTIVE', drawerCapacity: 30, userId: 'u-A' }) });

const buildDm = (o: Partial<DrawerMedication> = {}): DrawerMedication => ({
  id: 'dm-1',
  drawerId: 'dr-A',
  medicationId: 'med-A',
  quantity: null,
  missingQuantity: null,
  assignedAt: now(),
  isActive: true,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const req = (o: Partial<Request> = {}) =>
  ({
    user: { userId: 'u-A', role: 'USER' },
    body: {},
    params: {},
    query: {},
    ...o,
  }) as Request;

const jsonRes = () => {
  const r = {} as Response;
  const payload: { status?: number; body?: unknown } = {};
  (r as unknown as { status: unknown }).status = jest.fn().mockImplementation((s: number) => {
    payload.status = s;
    return { json: (body: unknown) => { payload.body = body; return { status: () => ({}) }; }, end: () => {} };
  });
  (r as unknown as { json: unknown }).json = jest.fn().mockImplementation((b: unknown) => {
    payload.body = b;
    return r;
  });
  (r as unknown as { end: unknown }).end = jest.fn().mockImplementation(() => undefined);
  return { res: r, payload };
};

const authScenarios = [
  { label: 'POST /api/drawer-medications', method: 'POST', path: '/api/drawer-medications' },
  { label: 'GET /api/drawer-medications', method: 'GET', path: '/api/drawer-medications' },
  { label: 'GET /api/drawer-medications/:id', method: 'GET', path: '/api/drawer-medications/x' },
  { label: 'PATCH /api/drawer-medications/:id', method: 'PATCH', path: '/api/drawer-medications/x' },
  { label: 'DELETE /api/drawer-medications/:id', method: 'DELETE', path: '/api/drawer-medications/x' },
  { label: 'GET /api/drawer-medications/admin/all', method: 'GET', path: '/admin/all' },
  { label: 'GET /api/drawer-medications/admin/:id', method: 'GET', path: '/admin/x' },
];

describe('AUTH: no JWT → 401 on every DrawerMedication endpoint', () => {
  authScenarios.forEach((s) =>
    it(`${s.label} without JWT → 401 Unauthorized`, () => {
      const r = { headers: {}, method: s.method, path: s.path } as Request;
      const n = nextFn();
      requireAuth(r, emptyRes(), n);
      const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
      expect(err).toBeInstanceOf(UnauthorizedError);
      expect(err.statusCode).toBe(401);
    }),
  );
});

describe('AUTH: USER → 403 on admin DrawerMedication endpoints', () => {
  [
    { label: 'GET /admin/all', method: 'GET', path: '/admin/all' },
    { label: 'GET /admin/:id', method: 'GET', path: '/admin/x' },
  ].forEach((s) =>
    it(`USER role ${s.label} → 403 Forbidden`, () => {
      const r = {
        user: { userId: 'u-A', role: 'USER' },
        method: s.method,
        path: s.path,
      } as Request;
      const n = nextFn();
      requireRole('ADMIN')(r, emptyRes(), n);
      const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
      expect(err).toBeInstanceOf(ForbiddenError);
      expect(err.statusCode).toBe(403);
    }),
  );
});

describe('CREATE validators', () => {
  it('valid body (quantity + missingQuantity both non-neg integers) → success', () => {
    const r = createDrawerMedicationSchema.safeParse({ drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 });
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.quantity).toBe(20);
      expect(r.data.missingQuantity).toBe(70);
    }
  });
  it('valid body missingQuantity=0 or 1 accepted', () => {
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: 15, missingQuantity: 0 }).success).toBe(true);
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: 1, missingQuantity: 1 }).success).toBe(true);
  });
  it('missing quantity OR missingQuantity → rejected (both required)', () => {
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1' }).success).toBe(false);
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: 20 }).success).toBe(false);
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', missingQuantity: 70 }).success).toBe(false);
  });
  it('missingQuantity negative → rejected', () => {
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: 20, missingQuantity: -1 }).success).toBe(false);
  });
  it('missingQuantity float 1.5 → rejected', () => {
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: 20, missingQuantity: 1.5 }).success).toBe(false);
  });
  it('missingQuantity string "70" → rejected (strict number type only)', () => {
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: 20, missingQuantity: '70' }).success).toBe(false);
  });
  it('quantity negative / float → rejected', () => {
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: -5, missingQuantity: 70 }).success).toBe(false);
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'dr-1', medicationId: 'med-1', quantity: 20.5, missingQuantity: 0 }).success).toBe(false);
  });
  it.each([
    [{ id: 'x', quantity: 1, missingQuantity: 1 }, 'id'],
    [{ userId: 'u', quantity: 1, missingQuantity: 1 }, 'userId'],
    [{ patientId: 'p', quantity: 1, missingQuantity: 1 }, 'patientId'],
    [{ medicineBoxId: 'mb', quantity: 1, missingQuantity: 1 }, 'medicineBoxId'],
    [{ assignedAt: new Date().toISOString(), quantity: 1, missingQuantity: 1 }, 'assignedAt'],
    [{ isActive: true, quantity: 1, missingQuantity: 1 }, 'isActive'],
    [{ createdAt: new Date().toISOString(), quantity: 1, missingQuantity: 1 }, 'createdAt'],
    [{ updatedAt: new Date().toISOString(), quantity: 1, missingQuantity: 1 }, 'updatedAt'],
    [{ dosage: '1', quantity: 1, missingQuantity: 1 }, 'dosage'],
    [{ drawerId: 'a', medicationId: 'b', quantity: 1, missingQuantity: 1, extra: 'x' }, 'unknown field'],
  ])('reject %s → BadRequest 400', (body, _label) => {
    const r = createDrawerMedicationSchema.safeParse(body);
    expect(r.success).toBe(false);
  });
  it('empty drawerId/medicationId → 400', () => {
    expect(createDrawerMedicationSchema.safeParse({ drawerId: '', medicationId: 'a', quantity: 1, missingQuantity: 0 }).success).toBe(false);
    expect(createDrawerMedicationSchema.safeParse({ drawerId: 'a', medicationId: '', quantity: 1, missingQuantity: 0 }).success).toBe(false);
  });
});

describe('UPDATE validators', () => {
  it('isActive=false/true both ok', () => {
    expect(updateDrawerMedicationSchema.safeParse({ isActive: false }).success).toBe(true);
    expect(updateDrawerMedicationSchema.safeParse({ isActive: true }).success).toBe(true);
    expect(updateDrawerMedicationSchema.safeParse({}).success).toBe(true);
  });
  it('quantity ok in update (config correction)', () => {
    const r = updateDrawerMedicationSchema.safeParse({ quantity: 1 });
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.quantity).toBe(1);
  });
  it('missingQuantity ok in update (correction)', () => {
    const r = updateDrawerMedicationSchema.safeParse({ missingQuantity: 50 });
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.missingQuantity).toBe(50);
  });
  it.each([
    [{ drawerId: 'x' }, 'drawerId'],
    [{ medicationId: 'x' }, 'medicationId'],
    [{ userId: 'x' }, 'userId'],
    [{ assignedAt: 'x' }, 'assignedAt'],
    [{ dosage: '1' }, 'dosage'],
    [{ isActive: true, extra: 1 }, 'unknown field'],
  ])('reject %s → BadRequest 400', (body, _label) => {
    const r = updateDrawerMedicationSchema.safeParse(body);
    expect(r.success).toBe(false);
  });
});

describe('CREATE AssignMedicationToDrawer use case', () => {
  it('valid assignment → returns 201 shape with quantity+missingQuantity persisted', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(null);
    const created = buildDm({ drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 });
    dmRepo.create.mockResolvedValue(created);
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    const r = await uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 });
    expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 }));
    expect(r.id).toBeTruthy();
    expect(r.drawerId).toBe('dr-A');
    expect(r.medicationId).toBe('med-A');
    expect(r.isActive).toBe(true);
    expect(r.assignedAt).toBeTruthy();
    expect(r.quantity).toBe(20);
    expect(r.missingQuantity).toBe(70);
    expect(dmRepo.create).toHaveBeenCalledTimes(1);
  });
  it('valid assignment qty 15 missing 0 → both written as-is (§9 test2)', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 15, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(null);
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-A', drawerCapacity: 20 });
    const created = buildDm({ drawerId: 'dr-A', medicationId: 'med-A', quantity: 15, missingQuantity: 0 });
    dmRepo.create.mockResolvedValue(created);
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    const r = await uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-A', quantity: 15, missingQuantity: 0 });
    expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 15, missingQuantity: 0 }));
    expect(r.quantity).toBe(15);
    expect(r.missingQuantity).toBe(0);
  });
  it('quantity exceeds drawerCapacity → BadRequest (existing logic preserved)', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(null);
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-A', drawerCapacity: 20 });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-A', quantity: 21, missingQuantity: 69 })).rejects.toThrow(BadRequestError);
    expect(dmRepo.create).not.toHaveBeenCalled();
  });
  it('quantity exceeds medStock → BadRequest (existing logic preserved)', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 15, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(null);
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-A', drawerCapacity: 30 });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-A', quantity: 16, missingQuantity: 0 })).rejects.toThrow(BadRequestError);
    expect(dmRepo.create).not.toHaveBeenCalled();
  });
  it('drawer not owned → 404', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue(null);
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 10, patientId: 'p-A' });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-B', medicationId: 'med-A', quantity: 1, missingQuantity: 0 })).rejects.toThrow(NotFoundError);
  });
  it('medication not owned → 404', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-B', quantity: 1, missingQuantity: 0 })).rejects.toThrow(NotFoundError);
  });
  it('drawer already assigned → Conflict 409', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(buildDm());
    dmRepo.findByMedicationId.mockResolvedValue(null);
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 })).rejects.toThrow(ConflictError);
  });
  it('medication already assigned → Conflict 409', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(buildDm());
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 })).rejects.toThrow(ConflictError);
  });
});

describe('OWNERSHIP security matrix cross-user', () => {
  const ownMatrix = [
    { drawerOwner: 'u-A', medOwner: 'u-A', userId: 'u-A', ok: true, label: 'A + Drawer A + Med A' },
    { drawerOwner: 'u-B', medOwner: 'u-B', userId: 'u-B', ok: true, label: 'B + Drawer B + Med B' },
    { drawerOwner: 'u-A', medOwner: 'u-B', userId: 'u-A', ok: false, label: 'A + Drawer A + Med B' },
    { drawerOwner: 'u-B', medOwner: 'u-A', userId: 'u-A', ok: false, label: 'A + Drawer B + Med A' },
    { drawerOwner: 'u-B', medOwner: 'u-B', userId: 'u-A', ok: false, label: 'A + Drawer B + Med B' },
    { drawerOwner: 'u-A', medOwner: 'u-B', userId: 'u-B', ok: false, label: 'B + Drawer A + Med B' },
  ];
  ownMatrix.forEach((c) =>
    it(`${c.label} → ${c.ok ? '201' : '404'}`, async () => {
      const dmRepo = mockDm();
      const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
      const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
      const mbRepo = mockMb();
      drRepo.findByIdAndUserId.mockImplementation(async (id: string, uid: string) =>
        uid === c.drawerOwner ? { id, medicineBoxId: 'mb-X' } : null,
      );
      medRepo.findByIdAndUserId.mockImplementation(async (id: string, uid: string) =>
        uid === c.medOwner ? { id, quantity: 90, patientId: 'p-X' } : null,
      );
      dmRepo.findByDrawerId.mockResolvedValue(null);
      dmRepo.findByMedicationId.mockResolvedValue(null);
      dmRepo.create.mockResolvedValue(buildDm());
      mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-X', drawerCapacity: 20 });
      const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
      const p = uc.execute(c.userId, { drawerId: 'dr-X', medicationId: 'med-X', quantity: 1, missingQuantity: 0 });
      if (c.ok) await expect(p).resolves.toBeTruthy();
      else await expect(p).rejects.toThrow(NotFoundError);
    }),
  );

  it('cross-user GET by id → 404', async () => {
    const dmRepo = mockDm();
    dmRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetDrawerMedicationById(dmRepo);
    await expect(uc.execute('u-B', 'dm-1')).rejects.toThrow(NotFoundError);
    expect(dmRepo.findByIdAndUserId).toHaveBeenCalledWith('dm-1', 'u-B');
  });

  it('cross-user PATCH → 404', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const mbRepo = mockMb();
    dmRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UpdateDrawerMedication(dmRepo, drRepo as never, mbRepo as never);
    await expect(uc.execute('u-B', 'dm-1', { isActive: false })).rejects.toThrow(NotFoundError);
    expect(dmRepo.update).not.toHaveBeenCalled();
  });

  it('cross-user DELETE → 404', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const mbRepo = mockMb();
    dmRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UnassignMedicationFromDrawer(dmRepo, drRepo as never, mbRepo as never);
    await expect(uc.execute('u-B', 'dm-1')).rejects.toThrow(NotFoundError);
    expect(dmRepo.delete).not.toHaveBeenCalled();
  });

  it('list only returns owned assignments (DB-level)', async () => {
    const dmRepo = mockDm();
    dmRepo.findAllByUserId.mockResolvedValue([buildDm({ drawerId: 'dr-A', medicationId: 'med-A' })]);
    const uc = new GetMyDrawerMedications(dmRepo);
    const list = await uc.execute('u-A');
    expect(dmRepo.findAllByUserId).toHaveBeenCalledWith('u-A', undefined);
    expect(list.length).toBe(1);
    expect(list[0].drawerId).toBe('dr-A');
  });

  it('list with drawerId/medicationId filters still enforces ownership', async () => {
    const dmRepo = mockDm();
    dmRepo.findAllByUserId.mockResolvedValue([]);
    const uc = new GetMyDrawerMedications(dmRepo);
    await uc.execute('u-A', { drawerId: 'dr-B', medicationId: 'med-C' });
    expect(dmRepo.findAllByUserId).toHaveBeenCalledWith('u-A', { drawerId: 'dr-B', medicationId: 'med-C' });
  });
});

describe('UNIQUE conflict tests', () => {
  it('same drawer twice → 409', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-B', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(buildDm({ drawerId: 'dr-A' }));
    dmRepo.findByMedicationId.mockResolvedValue(null);
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-A', drawerCapacity: 30 });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-B', quantity: 10, missingQuantity: 0 })).rejects.toThrow(ConflictError);
  });
  it('same medication twice → 409', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-B', medicineBoxId: 'mb-B' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(buildDm({ medicationId: 'med-A' }));
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-B', drawerCapacity: 30 });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-B', medicationId: 'med-A', quantity: 10, missingQuantity: 0 })).rejects.toThrow(ConflictError);
  });
});

describe('UPDATE drawer medication use case', () => {
  it('isActive false → ok 200', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk().mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' }) };
    const mbRepo = mockMb();
    dmRepo.findByIdAndUserId.mockResolvedValue(buildDm());
    dmRepo.update.mockResolvedValue(buildDm({ isActive: false }));
    const uc = new UpdateDrawerMedication(dmRepo, drRepo as never, mbRepo as never);
    const r = await uc.execute('u-A', 'dm-1', { isActive: false });
    expect(r.isActive).toBe(false);
    expect(dmRepo.update).toHaveBeenCalledWith('dm-1', { isActive: false });
  });
  it('isActive true → ok 200', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk().mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' }) };
    const mbRepo = mockMb();
    dmRepo.findByIdAndUserId.mockResolvedValue(buildDm({ isActive: false }));
    dmRepo.update.mockResolvedValue(buildDm({ isActive: true }));
    const uc = new UpdateDrawerMedication(dmRepo, drRepo as never, mbRepo as never);
    const r = await uc.execute('u-A', 'dm-1', { isActive: true });
    expect(r.isActive).toBe(true);
  });
  it('cross user → 404', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const mbRepo = mockMb();
    dmRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UpdateDrawerMedication(dmRepo, drRepo as never, mbRepo as never);
    await expect(uc.execute('u-B', 'dm-1', { isActive: false })).rejects.toThrow(NotFoundError);
  });
});

describe('DELETE / Unassign use case', () => {
  it('owner → 204 removes only DrawerMedication', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk().mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' }) };
    const mbRepo = mockMb();
    dmRepo.findByIdAndUserId.mockResolvedValue(buildDm());
    dmRepo.delete.mockResolvedValue(undefined);
    const uc = new UnassignMedicationFromDrawer(dmRepo, drRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', 'dm-1')).resolves.toBeUndefined();
    expect(dmRepo.delete).toHaveBeenCalledWith('dm-1');
    expect(dmRepo.findByIdAndUserId).toHaveBeenCalledWith('dm-1', 'u-A');
  });
  it('not owned → 404', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const mbRepo = mockMb();
    dmRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UnassignMedicationFromDrawer(dmRepo, drRepo as never, mbRepo as never);
    await expect(uc.execute('u-B', 'dm-1')).rejects.toThrow(NotFoundError);
    expect(dmRepo.delete).not.toHaveBeenCalled();
  });
});

describe('ADMIN READ use cases', () => {
  it('admin list → system-wide all', async () => {
    const dmRepo = mockDm();
    dmRepo.findAll.mockResolvedValue([buildDm({ id: 'dm-1' }), buildDm({ id: 'dm-2' })]);
    const uc = new GetAllDrawerMedications(dmRepo);
    const r = await uc.execute();
    expect(r.length).toBe(2);
    expect(dmRepo.findAll).toHaveBeenCalledTimes(1);
  });
  it('admin get by id → not-found throws 404', async () => {
    const dmRepo = mockDm();
    dmRepo.findById.mockResolvedValue(null);
    const uc = new GetDrawerMedicationByIdAdmin(dmRepo);
    await expect(uc.execute('dm-missing')).rejects.toThrow(NotFoundError);
  });
  it('admin get by id → returns assignment system-wide', async () => {
    const dmRepo = mockDm();
    const expected = buildDm({ id: 'dm-X', drawerId: 'dr-OTHER', medicationId: 'med-OTHER' });
    dmRepo.findById.mockResolvedValue(expected);
    const uc = new GetDrawerMedicationByIdAdmin(dmRepo);
    const r = await uc.execute('dm-X');
    expect(r).toMatchObject({ id: 'dm-X', drawerId: 'dr-OTHER', medicationId: 'med-OTHER' });
  });
  it('admin user list still ownership filtered (dual-join userId)', async () => {
    const dmRepo = mockDm();
    dmRepo.findAllByUserId.mockResolvedValue([buildDm({ id: 'dm-ownedByAdmin' })]);
    const uc = new GetMyDrawerMedications(dmRepo);
    const r = await uc.execute('admin-1');
    expect(dmRepo.findAllByUserId).toHaveBeenCalledWith('admin-1', undefined);
    expect(r.length).toBe(1);
    expect(r[0].id).toBe('dm-ownedByAdmin');
  });
});

describe('Controller response shape', () => {
  it('GET by id → {status, statusCode, data} 200', async () => {
    const dmRepo = mockDm();
    dmRepo.findByIdAndUserId.mockResolvedValue(buildDm());
    jest.doMock('@infrastructure/database/prisma/repositories/PrismaDrawerMedicationRepository', () => ({
      PrismaDrawerMedicationRepository: jest.fn().mockImplementation(() => dmRepo),
    }));
    const { DrawerMedicationController } = require('@presentation/controllers/DrawerMedicationController');
    const { res, payload } = jsonRes();
    const n = nextFn();
    await DrawerMedicationController.getById(req({ params: { id: 'dm-1' } }), res, n);
    expect(n).not.toHaveBeenCalled();
    expect(payload.status).toBe(200);
    const body = payload.body as { status: string; statusCode: number; data: DrawerMedication };
    expect(body.status).toBe('success');
    expect(body.statusCode).toBe(200);
    expect(body.data.id).toBeTruthy();
    expect(body.data.drawerId).toBeTruthy();
    expect(body.data.medicationId).toBeTruthy();
    expect(body.data.assignedAt).toBeTruthy();
    expect(Object.hasOwn(body.data, 'isActive')).toBe(true);
    expect(Object.hasOwn(body.data, 'deviceToken')).toBe(false);
  });
});

describe('§2 Drawer.status sync ↔ isActive', () => {
  const mkDrawer = (status: string) => ({ id: 'dr-A', medicineBoxId: 'mb-A', drawerNumber: 1, status, createdAt: now(), updatedAt: now() });

  it('[CREATE-1] Drawer.status EMPTY + create active → updates to LOADED inside $transaction', async () => {
    const expected = buildDm();
    const { prisma } = require('@infrastructure/database/prisma/client');
    const drawer = mkDrawer('EMPTY');

    const findUniqueDrawer = jest.spyOn(prisma.drawer, 'findUnique').mockResolvedValue(drawer as never);
    const drawerUpdate = jest.spyOn(prisma.drawer, 'update').mockResolvedValue({ ...drawer, status: 'LOADED' } as never);
    jest.spyOn(prisma.drawerMedication, 'create').mockResolvedValue(expected as never);
    let txRan = false;
    jest.spyOn(prisma, '$transaction').mockImplementation(async (fn: any) => {
      txRan = true;
      return fn(prisma);
    });
    const repo = new PrismaDrawerMedicationRepository();
    const out = await repo.create({ drawerId: 'dr-A', medicationId: 'med-A' });
    expect(txRan).toBe(true);
    expect(out.drawerId).toBe(expected.drawerId);
    expect(findUniqueDrawer).toHaveBeenCalled();
    expect(drawerUpdate).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'dr-A' }, data: { status: 'LOADED' } }));
  });

  it('[CREATE-2] LOCKED hardware state → NOT overwritten during create', async () => {
    const { prisma } = require('@infrastructure/database/prisma/client');
    const drawer = mkDrawer('LOCKED');
    const repo = new PrismaDrawerMedicationRepository();
    const findUniqueDrawer = jest.spyOn(prisma.drawer, 'findUnique').mockResolvedValue(drawer as never);
    const drawerUpdate = jest.spyOn(prisma.drawer, 'update');
    const dmCreate = jest.spyOn(prisma.drawerMedication, 'create').mockResolvedValue(buildDm() as never);
    jest.spyOn(prisma, '$transaction').mockImplementation(async (fn: any) => fn(prisma));
    await repo.create({ drawerId: 'dr-A', medicationId: 'med-A' });
    expect(findUniqueDrawer).toHaveBeenCalled();
    expect(drawerUpdate).not.toHaveBeenCalled();
    expect(dmCreate).toHaveBeenCalledTimes(1);
  });

  it('[CREATE-3] DISPENSING/ERROR hardware states → NOT overwritten during create', async () => {
    const { prisma } = require('@infrastructure/database/prisma/client');
    const repo = new PrismaDrawerMedicationRepository();
    for (const s of ['DISPENSING', 'ERROR']) {
      const drawer = mkDrawer(s);
      const drawerUpdate = jest.spyOn(prisma.drawer, 'update');
      jest.spyOn(prisma.drawer, 'findUnique').mockResolvedValue(drawer as never);
      jest.spyOn(prisma.drawerMedication, 'create').mockResolvedValue(buildDm() as never);
      jest.spyOn(prisma, '$transaction').mockImplementation(async (fn: any) => fn(prisma));
      await repo.create({ drawerId: 'dr-A', medicationId: 'med-A' });
      expect(drawerUpdate).not.toHaveBeenCalled();
    }
  });

  it('[UPDATE-3] isActive=false from LOADED → EMPTY', async () => {
    const { prisma } = require('@infrastructure/database/prisma/client');
    const repo = new PrismaDrawerMedicationRepository();
    const drawer = mkDrawer('LOADED');
    const dmRow = { id: 'dm-1', drawerId: 'dr-A', medicationId: 'med-A', assignedAt: now(), isActive: false, createdAt: now(), updatedAt: now(), drawer };
    const drawerUpdate = jest.spyOn(prisma.drawer, 'update').mockResolvedValue({ ...drawer, status: 'EMPTY' } as never);
    jest.spyOn(prisma.drawerMedication, 'update').mockResolvedValue(dmRow as never);
    jest.spyOn(prisma, '$transaction').mockImplementation(async (fn: any) => fn(prisma));
    await repo.update('dm-1', { isActive: false });
    expect(drawerUpdate).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'dr-A' }, data: { status: 'EMPTY' } }));
  });

  it('[UPDATE-4] isActive=true from EMPTY → LOADED', async () => {
    const { prisma } = require('@infrastructure/database/prisma/client');
    const repo = new PrismaDrawerMedicationRepository();
    const drawer = mkDrawer('EMPTY');
    const dmRow = { id: 'dm-1', drawerId: 'dr-A', medicationId: 'med-A', assignedAt: now(), isActive: true, createdAt: now(), updatedAt: now(), drawer };
    const drawerUpdate = jest.spyOn(prisma.drawer, 'update').mockResolvedValue({ ...drawer, status: 'LOADED' } as never);
    jest.spyOn(prisma.drawerMedication, 'update').mockResolvedValue(dmRow as never);
    jest.spyOn(prisma, '$transaction').mockImplementation(async (fn: any) => fn(prisma));
    await repo.update('dm-1', { isActive: true });
    expect(drawerUpdate).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'dr-A' }, data: { status: 'LOADED' } }));
  });

  it('[DELETE-5] Delete → EMPTY', async () => {
    const { prisma } = require('@infrastructure/database/prisma/client');
    const repo = new PrismaDrawerMedicationRepository();
    const drawer = mkDrawer('LOADED');
    const dmRow = { id: 'dm-1', drawerId: 'dr-A', medicationId: 'med-A', assignedAt: now(), isActive: true, createdAt: now(), updatedAt: now(), drawer };
    const drawerUpdate = jest.spyOn(prisma.drawer, 'update').mockResolvedValue({ ...drawer, status: 'EMPTY' } as never);
    jest.spyOn(prisma.drawerMedication, 'findUnique').mockResolvedValue(dmRow as never);
    jest.spyOn(prisma.drawerMedication, 'delete').mockResolvedValue(dmRow as never);
    jest.spyOn(prisma, '$transaction').mockImplementation(async (fn: any) => fn(prisma));
    await repo.delete('dm-1');
    expect(drawerUpdate).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'dr-A' }, data: { status: 'EMPTY' } }));
  });

  it('[TRANSACTION-9] Drawer update failure → error propagates; atomic boundary preserved via $transaction wrapper', async () => {
    const { prisma } = require('@infrastructure/database/prisma/client');
    const repo = new PrismaDrawerMedicationRepository();
    const drawer = mkDrawer('EMPTY');
    let txInvoked = false;
    jest.spyOn(prisma.drawer, 'findUnique').mockResolvedValue(drawer as never);
    jest.spyOn(prisma.drawerMedication, 'create').mockResolvedValue(buildDm() as never);
    jest.spyOn(prisma.drawer, 'update').mockRejectedValue(new Error('hardware write failed'));
    jest.spyOn(prisma, '$transaction').mockImplementation(async (fn: any) => {
      txInvoked = true;
      return fn(prisma);
    });
    const promise = repo.create({ drawerId: 'dr-A', medicationId: 'med-A' });
    await expect(promise).rejects.toThrow('hardware write failed');
    expect(txInvoked).toBe(true);
  });

  it('[POST-resp] Use-case Create response 201 shape with missingQuantity in stored entity', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', patientId: 'p-A', quantity: 90 });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(null);
    const created = buildDm({ drawerId: 'dr-A', medicationId: 'med-A', isActive: true, quantity: 20, missingQuantity: 70 });
    dmRepo.create.mockResolvedValue(created);
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-A', drawerCapacity: 30 });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    const r = await uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 });
    expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ drawerId: 'dr-A', medicationId: 'med-A', quantity: 20, missingQuantity: 70 }));
    expect(r.drawerId).toBe('dr-A');
    expect(r.medicationId).toBe('med-A');
    expect(r.isActive).toBe(true);
    expect(typeof r.id).toBe('string');
    expect(Object.hasOwn(r, 'id')).toBe(true);
    expect(r.missingQuantity).toBe(70);
    expect(r.quantity).toBe(20);
  });

  it('[UNIQUE-7] Same drawer twice → 409', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-A', medicineBoxId: 'mb-A' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-NEW', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(buildDm({ drawerId: 'dr-A', medicationId: 'med-EXIST' }));
    dmRepo.findByMedicationId.mockResolvedValue(null);
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-A', drawerCapacity: 30 });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-A', medicationId: 'med-NEW', quantity: 10, missingQuantity: 0 })).rejects.toThrow(ConflictError);
  });

  it('[UNIQUE-8] Same medication twice → 409', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-NEW', medicineBoxId: 'mb-NEW' });
    medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-A', quantity: 90, patientId: 'p-A' });
    dmRepo.findByDrawerId.mockResolvedValue(null);
    dmRepo.findByMedicationId.mockResolvedValue(buildDm({ drawerId: 'dr-EXIST', medicationId: 'med-A' }));
    mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-NEW', drawerCapacity: 30 });
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-NEW', medicationId: 'med-A', quantity: 10, missingQuantity: 0 })).rejects.toThrow(ConflictError);
  });

  it('[OWNERSHIP-6] Cross-user create → 404 before DM create', async () => {
    const dmRepo = mockDm();
    const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
    const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
    const mbRepo = mockMb();
    drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-ownedBy-uB', medicineBoxId: 'mb-uB' });
    medRepo.findByIdAndUserId.mockResolvedValue(null);
    const uc = new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never);
    await expect(uc.execute('u-A', { drawerId: 'dr-ownedBy-uB', medicationId: 'med-ownedBy-uB', quantity: 1, missingQuantity: 0 })).rejects.toThrow(NotFoundError);
    expect(dmRepo.create).not.toHaveBeenCalled();
  });

  describe('§9 missingQuantity persistence tests', () => {
    function setup(medQuantity: number, capacity: number) {
      const dmRepo = mockDm();
      const drRepo: MockDrawerRepo = { findByIdAndUserId: mk() };
      const medRepo: MockMedRepo = { findByIdAndUserId: mk(), findDuplicate: mk().mockResolvedValue(null) };
      const mbRepo = mockMb();
      drRepo.findByIdAndUserId.mockResolvedValue({ id: 'dr-1', medicineBoxId: 'mb-1' });
      medRepo.findByIdAndUserId.mockResolvedValue({ id: 'med-1', quantity: medQuantity, patientId: 'p-1' });
      mbRepo.findByIdAndUserId!.mockResolvedValue({ id: 'mb-1', drawerCapacity: capacity });
      dmRepo.findByDrawerId.mockResolvedValue(null);
      dmRepo.findByMedicationId.mockResolvedValue(null);
      dmRepo.create.mockImplementation(async (d) => buildDm({ ...d, id: 'dm-new', isActive: true }));
      return {
        uc: new AssignMedicationToDrawer(dmRepo, drRepo as never, medRepo as never, mbRepo as never),
        dmRepo,
      };
    }

    it('[§9-Test1] qty20 missing70 → both persisted exactly as sent (stock90/cap20)', async () => {
      const { uc, dmRepo } = setup(90, 20);
      const r = await uc.execute('u-A', { drawerId: 'dr-1', medicationId: 'med-1', quantity: 20, missingQuantity: 70 });
      expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 20, missingQuantity: 70 }));
      expect(r.quantity).toBe(20);
      expect(r.missingQuantity).toBe(70);
    });

    it('[§9-Test2] qty15 missing0 → both persisted exactly as sent', async () => {
      const { uc, dmRepo } = setup(15, 20);
      const r = await uc.execute('u-A', { drawerId: 'dr-1', medicationId: 'med-1', quantity: 15, missingQuantity: 0 });
      expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 15, missingQuantity: 0 }));
      expect(r.quantity).toBe(15);
      expect(r.missingQuantity).toBe(0);
    });

    it('missingQuantity is NEVER replaced by backend (§6): sent 5 → stored 5 even if formula says 0', async () => {
      const { uc, dmRepo } = setup(15, 20);
      const r = await uc.execute('u-A', { drawerId: 'dr-1', medicationId: 'med-1', quantity: 15, missingQuantity: 5 });
      expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ missingQuantity: 5 }));
      expect(r.missingQuantity).toBe(5);
    });
  });
});

import type { Request, Response, NextFunction } from 'express';
import type { Drawer } from '@domain/entities/Drawer';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import {
  updateDrawerSchema,
  adminUpdateDrawerSchema,
} from '@presentation/validators/drawer.validator';
import { ProvisionDrawers } from '@application/use-cases/drawers/ProvisionDrawers';
import { GetMyDrawers } from '@application/use-cases/drawers/GetMyDrawers';
import { GetDrawerById } from '@application/use-cases/drawers/GetDrawerById';
import { UpdateDrawer } from '@application/use-cases/drawers/UpdateDrawer';
import { GetAllDrawers } from '@application/use-cases/drawers/GetAllDrawers';
import { GetDrawerByIdAdmin } from '@application/use-cases/drawers/GetDrawerByIdAdmin';
import { AdminUpdateDrawer } from '@application/use-cases/drawers/AdminUpdateDrawer';
import {
  NotFoundError,
  UnauthorizedError,
  ForbiddenError,
  BadRequestError,
} from '@shared/errors';

type MockDrawerRepo = {
  findById: jest.Mock;
  findAll: jest.Mock;
  findAllByMedicineBoxId: jest.Mock;
  findAllByUserId: jest.Mock;
  findByIdAndMedicineBoxId: jest.Mock;
  findByIdAndUserId: jest.Mock;
  findByMedicineBoxIdAndDrawerNumber: jest.Mock;
  findNumbersByMedicineBoxId: jest.Mock;
  create: jest.Mock;
  createMany: jest.Mock;
  update: jest.Mock;
};

type MockBoxRepo = {
  findById: jest.Mock;
  findAllByUserId: jest.Mock;
  findAll: jest.Mock;
  findByIdAndUserId: jest.Mock;
  findByDeviceId: jest.Mock;
  existsByDeviceId: jest.Mock;
  activateAtomic: jest.Mock;
  update: jest.Mock;
  adminUpdate: jest.Mock;
};

const mk = () => jest.fn();
const now = () => new Date('2026-01-01T00:00:00.000Z');
const nextFn = () => jest.fn() as unknown as jest.Mock & NextFunction;
const emptyRes = () => ({} as Response);
const buildDrawer = (o: Partial<Drawer> = {}): Drawer => ({
  id: 'd-1',
  medicineBoxId: 'box-1',
  drawerNumber: 1,
  status: 'EMPTY',
  createdAt: now(),
  updatedAt: now(),
  ...o,
});
const buildBox = (o: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'DEV-1',
  deviceToken: 'SENSITIVE',
  name: 'Box 1',
  status: 'ACTIVE',
  deviceStatus: 'OFFLINE',
  lastSeenAt: null,
  userId: null,
  numberOfDrawers: 4,
  drawerCapacity: 10,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const drawerScenarios: Array<Partial<Request> & { label: string }> = [
  { label: 'GET /api/drawers', method: 'GET', path: '/api/drawers' },
  { label: 'GET /api/drawers/:id', method: 'GET', path: '/api/drawers/x' },
  { label: 'PATCH /api/drawers/:id', method: 'PATCH', path: '/api/drawers/x' },
  { label: 'GET /api/drawers/admin/all', method: 'GET', path: '/admin/all' },
  { label: 'GET /api/drawers/admin/:id', method: 'GET', path: '/admin/x' },
  { label: 'PATCH /api/drawers/admin/:id', method: 'PATCH', path: '/admin/x' },
  { label: 'POST /api/medicine-boxes/:id/drawers', method: 'POST', path: '/api/medicine-boxes/b/drawers' },
];

describe('§26 AUTH: no JWT → 401 on every Drawer endpoint', () => {
  drawerScenarios.forEach((s) =>
    it(`${s.label} without JWT → 401 Unauthorized`, () => {
      const req = { headers: {}, method: s.method, path: s.path } as Request;
      const n = nextFn();
      requireAuth(req, emptyRes(), n);
      const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
      expect(err).toBeInstanceOf(UnauthorizedError);
      expect(err.statusCode).toBe(401);
    }),
  );
});

describe('§26 ADMIN REQUIRE ROLE: USER → 403 on admin Drawer endpoints', () => {
  const scenarios: Array<Partial<Request> & { label: string }> = [
    { label: 'GET /drawers/admin/all', method: 'GET', path: '/admin/all' },
    { label: 'GET /drawers/admin/:id', method: 'GET', path: '/admin/xyz' },
    { label: 'PATCH /drawers/admin/:id', method: 'PATCH', path: '/admin/xyz' },
    { label: 'POST /medicine-boxes/:id/drawers provision', method: 'POST', path: '/admin' },
  ];
  scenarios.forEach((s) =>
    it(`USER role calling ${s.label} → 403 Forbidden`, () => {
      const req = {
        user: { userId: 'u-1', role: 'USER' },
        method: s.method,
        path: s.path,
      } as Request;
      const n = nextFn();
      requireRole('ADMIN')(req, emptyRes(), n);
      const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
      expect(err).toBeInstanceOf(ForbiddenError);
      expect(err.statusCode).toBe(403);
    }),
  );
});

describe('§26 DRAWER PROVISIONING: POST /api/medicine-boxes/:medicineBoxId/drawers', () => {
  let dr: MockDrawerRepo;
  let mr: MockBoxRepo;
  beforeEach(() => {
    dr = {
      findById: mk(),
      findAll: mk(),
      findAllByMedicineBoxId: mk(),
      findAllByUserId: mk(),
      findByIdAndMedicineBoxId: mk(),
      findByIdAndUserId: mk(),
      findByMedicineBoxIdAndDrawerNumber: mk(),
      findNumbersByMedicineBoxId: mk(),
      create: mk(),
      createMany: mk(),
      update: mk(),
    };
    mr = {
      findById: mk(),
      findAllByUserId: mk(),
      findAll: mk(),
      findByIdAndUserId: mk(),
      findByDeviceId: mk(),
      existsByDeviceId: mk(),
      activateAtomic: mk(),
      update: mk(),
      adminUpdate: mk(),
    };
  });

  it('ADMIN success: numberOfDrawers=4 → createMany [1,2,3,4] all EMPTY', async () => {
    mr.findById.mockResolvedValue(buildBox({ id: 'box-4', numberOfDrawers: 4 }));
    dr.findNumbersByMedicineBoxId.mockResolvedValue([]);
    dr.createMany.mockImplementation((rows: Array<{ drawerNumber: number }>) =>
      Promise.resolve(
        rows.map((r) =>
          buildDrawer({ id: `d-${r.drawerNumber}`, medicineBoxId: 'box-4', drawerNumber: r.drawerNumber }),
        ),
      ),
    );
    dr.findAllByMedicineBoxId.mockImplementation(async (_id: string) => {
      const created = await dr.createMany.mock.results[0]?.value ?? [];
      return created as Drawer[];
    });
    const uc = new ProvisionDrawers(dr as never, mr as never);
    const rows = await uc.execute('box-4');
    expect(dr.findNumbersByMedicineBoxId).toHaveBeenCalledWith('box-4');
    expect(dr.createMany).toHaveBeenCalledWith([
      { medicineBoxId: 'box-4', drawerNumber: 1, status: 'EMPTY' },
      { medicineBoxId: 'box-4', drawerNumber: 2, status: 'EMPTY' },
      { medicineBoxId: 'box-4', drawerNumber: 3, status: 'EMPTY' },
      { medicineBoxId: 'box-4', drawerNumber: 4, status: 'EMPTY' },
    ]);
    expect(rows.map((r) => r.drawerNumber)).toEqual([1, 2, 3, 4]);
    expect(rows.every((r) => r.status === 'EMPTY')).toBe(true);
  });

  it('USER role → requireRole ADMIN → 403 (never reaches ProvisionDrawers)', () => {
    const req = { user: { userId: 'u1', role: 'USER' } } as Request;
    const n = nextFn();
    requireRole('ADMIN')(req, emptyRes(), n);
    const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
    expect(err).toBeInstanceOf(ForbiddenError);
    expect(err.statusCode).toBe(403);
  });

  it('nonexistent MedicineBox → NotFoundError 404, nothing created', async () => {
    mr.findById.mockResolvedValue(null);
    const uc = new ProvisionDrawers(dr as never, mr as never);
    await expect(uc.execute('ghost-box')).rejects.toThrow(NotFoundError);
    expect(dr.findNumbersByMedicineBoxId).not.toHaveBeenCalled();
    expect(dr.createMany).not.toHaveBeenCalled();
  });

  it('repeated provisioning (idempotent) → no duplicates, same count, createMany called with empty payload second time', async () => {
    mr.findById.mockResolvedValue(buildBox({ id: 'box-i', numberOfDrawers: 4 }));
    const all4 = [1, 2, 3, 4];
    dr.findNumbersByMedicineBoxId
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce(all4);
    dr.createMany.mockImplementation(async (payload: unknown[]) => {
      const arr = payload as Array<{ drawerNumber: number }>;
      return arr.map((p) => buildDrawer({ id: `id-${p.drawerNumber}`, medicineBoxId: 'box-i', drawerNumber: p.drawerNumber }));
    });
    dr.findAllByMedicineBoxId.mockImplementation(async () =>
      all4.map((n) => buildDrawer({ id: `id-${n}`, medicineBoxId: 'box-i', drawerNumber: n })),
    );
    const uc = new ProvisionDrawers(dr as never, mr as never);
    const first = await uc.execute('box-i');
    const second = await uc.execute('box-i');
    // Second execution: existing numbers covers 1..4 → missing.length === 0 → returns early; createMany NOT recalled
    expect(dr.createMany).toHaveBeenCalledTimes(1);
    expect(first).toHaveLength(4);
    expect(second).toHaveLength(4);
    const uniqueNumbers = new Set(second.map((d) => d.drawerNumber));
    expect(uniqueNumbers.size).toBe(4);
  });

  it('partial existing drawers 1,2 present numberOfDrawers=5 → createMany creates missing 3,4,5 only', async () => {
    mr.findById.mockResolvedValue(buildBox({ id: 'box-p', numberOfDrawers: 5 }));
    dr.findNumbersByMedicineBoxId.mockResolvedValue([1, 2]);
    dr.createMany.mockImplementation((rows: Array<{ drawerNumber: number }>) =>
      Promise.resolve(rows.map((r) => buildDrawer({ id: `d-${r.drawerNumber}`, medicineBoxId: 'box-p', drawerNumber: r.drawerNumber }))),
    );
    dr.findAllByMedicineBoxId.mockResolvedValue([
      buildDrawer({ id: 'e1', medicineBoxId: 'box-p', drawerNumber: 1 }),
      buildDrawer({ id: 'e2', medicineBoxId: 'box-p', drawerNumber: 2 }),
      buildDrawer({ id: 'd-3', medicineBoxId: 'box-p', drawerNumber: 3 }),
      buildDrawer({ id: 'd-4', medicineBoxId: 'box-p', drawerNumber: 4 }),
      buildDrawer({ id: 'd-5', medicineBoxId: 'box-p', drawerNumber: 5 }),
    ]);
    const uc = new ProvisionDrawers(dr as never, mr as never);
    const r = await uc.execute('box-p');
    expect(dr.createMany).toHaveBeenCalledWith([
      { medicineBoxId: 'box-p', drawerNumber: 3, status: 'EMPTY' },
      { medicineBoxId: 'box-p', drawerNumber: 4, status: 'EMPTY' },
      { medicineBoxId: 'box-p', drawerNumber: 5, status: 'EMPTY' },
    ]);
    expect(r.map((d) => d.drawerNumber)).toEqual([1, 2, 3, 4, 5]);
  });

  it('respects numberOfDrawers=3 with 1..3 existing → creates nothing (no Drawer 4)', async () => {
    mr.findById.mockResolvedValue(buildBox({ id: 'box-3', numberOfDrawers: 3 }));
    dr.findNumbersByMedicineBoxId.mockResolvedValue([1, 2, 3]);
    dr.findAllByMedicineBoxId.mockResolvedValue([
      buildDrawer({ id: 'e1', medicineBoxId: 'box-3', drawerNumber: 1 }),
      buildDrawer({ id: 'e2', medicineBoxId: 'box-3', drawerNumber: 2 }),
      buildDrawer({ id: 'e3', medicineBoxId: 'box-3', drawerNumber: 3 }),
    ]);
    const uc = new ProvisionDrawers(dr as never, mr as never);
    const r = await uc.execute('box-3');
    expect(dr.createMany).not.toHaveBeenCalled();
    expect(r).toHaveLength(3);
    expect(r.some((d) => d.drawerNumber === 4)).toBe(false);
  });
});

describe('§25 CROSS-USER OWNERSHIP: user A A, B B, cross 404', () => {
  let dr: MockDrawerRepo;
  let mr: MockBoxRepo;
  beforeEach(() => {
    dr = {
      findById: mk(),
      findAll: mk(),
      findAllByMedicineBoxId: mk(),
      findAllByUserId: mk(),
      findByIdAndMedicineBoxId: mk(),
      findByIdAndUserId: mk(),
      findByMedicineBoxIdAndDrawerNumber: mk(),
      findNumbersByMedicineBoxId: mk(),
      create: mk(),
      createMany: mk(),
      update: mk(),
    };
    mr = {
      findById: mk(),
      findAllByUserId: mk(),
      findAll: mk(),
      findByIdAndUserId: mk(),
      findByDeviceId: mk(),
      existsByDeviceId: mk(),
      activateAtomic: mk(),
      update: mk(),
      adminUpdate: mk(),
    };
  });

  it('User A GET list → findAllByUserId("uA") returns only A drawers (no JS filter)', async () => {
    dr.findAllByUserId.mockResolvedValue([
      buildDrawer({ id: 'a1', medicineBoxId: 'box-A', drawerNumber: 1 }),
      buildDrawer({ id: 'a2', medicineBoxId: 'box-A', drawerNumber: 2 }),
    ]);
    const uc = new GetMyDrawers(dr as never);
    const out = await uc.execute('uA');
    expect(dr.findAllByUserId).toHaveBeenCalledWith('uA', undefined);
    expect(out.every((d) => d.id.startsWith('a'))).toBe(true);
  });

  it('User B GET list → only B drawers; ?medicineBoxId option applied with userId filter (cannot bypass)', async () => {
    dr.findAllByUserId.mockResolvedValue([
      buildDrawer({ id: 'b1', medicineBoxId: 'box-B', drawerNumber: 1 }),
    ]);
    const uc = new GetMyDrawers(dr as never);
    const out = await uc.execute('uB', { medicineBoxId: 'box-B' });
    expect(dr.findAllByUserId).toHaveBeenCalledWith('uB', { medicineBoxId: 'box-B' });
    expect(out).toHaveLength(1);
  });

  it('User A GET own drawer A → 200; User B GET drawer A → findByIdAndUserId(B, A-drawerId) returns null → NotFound 404 (not 403)', async () => {
    dr.findByIdAndUserId.mockImplementation((drawerId: string, userId: string) => {
      if (userId === 'uA' && drawerId === 'drawer-A') return Promise.resolve(buildDrawer({ id: 'drawer-A', medicineBoxId: 'box-A' }));
      return Promise.resolve(null);
    });
    const get = new GetDrawerById(dr as never);
    const okA = await get.execute('uA', 'drawer-A');
    expect(okA.id).toBe('drawer-A');
    // B requesting A's drawer:
    await expect(get.execute('uB', 'drawer-A')).rejects.toThrow(NotFoundError);
  });

  it('nonexistent drawer id → NotFoundError 404 (enumeration safe, never 403)', async () => {
    dr.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetDrawerById(dr as never);
    await expect(uc.execute('uA', 'ghost')).rejects.toThrow(NotFoundError);
  });

  it('User A PATCH status own drawer A → 200; User B PATCH drawer A → NotFound 404 never 403', async () => {
    dr.findByIdAndUserId.mockImplementation((drawerId: string, userId: string) => {
      if (userId === 'uA' && drawerId === 'drawer-A') {
        return Promise.resolve(buildDrawer({ id: 'drawer-A', medicineBoxId: 'box-A', status: 'EMPTY' }));
      }
      return Promise.resolve(null);
    });
    mr.findByIdAndUserId.mockImplementation((boxId: string, userId: string) => {
      if (userId === 'uA' && boxId === 'box-A') {
        return Promise.resolve(buildBox({ id: 'box-A', userId: 'uA', status: 'ACTIVE' }));
      }
      return Promise.resolve(null);
    });
    dr.update.mockImplementation((_id: string, patch: { status?: Drawer['status'] }) =>
      Promise.resolve(buildDrawer({ id: 'drawer-A', medicineBoxId: 'box-A', status: patch.status ?? 'EMPTY' })),
    );
    const uc = new UpdateDrawer(dr as never, mr as never);
    const ok = await uc.execute('uA', 'drawer-A', { status: 'LOADED' });
    expect(ok.status).toBe('LOADED');
    expect(dr.update).toHaveBeenCalledWith('drawer-A', { status: 'LOADED' });
    await expect(uc.execute('uB', 'drawer-A', { status: 'LOADED' })).rejects.toThrow(NotFoundError);
  });

  it('no userId bypass: UpdateDrawer ALWAYS takes authenticated userId from first arg, not body', async () => {
    dr.findByIdAndUserId.mockResolvedValue(
      buildDrawer({ id: 'drawer-A', medicineBoxId: 'box-A', status: 'EMPTY' }),
    );
    mr.findByIdAndUserId.mockResolvedValue(
      buildBox({ id: 'box-A', userId: 'uA', status: 'ACTIVE' }),
    );
    dr.update.mockResolvedValue(buildDrawer({ id: 'drawer-A', medicineBoxId: 'box-A', status: 'LOADED' }));
    const uc = new UpdateDrawer(dr as never, mr as never);
    // Even if a body somehow contained userId, use case signature never accepts it
    const typedUc: { execute: (u: string, id: string, d: { status?: Drawer['status'] }) => Promise<Drawer> } = uc;
    void typedUc;
    await uc.execute('uA', 'drawer-A', { status: 'LOADED' });
    // Find always uses the authenticated userId:
    expect(dr.findByIdAndUserId).toHaveBeenCalledWith('drawer-A', 'uA');
  });
});

describe('§26 VALIDATION: invalid/unknown/blocked fields → 400 BadRequest (strict validator)', () => {
  it('invalid status string → rejected by both user and admin schemas', () => {
    for (const s of ['OPEN', 'CLOSED', 'AVAILABLE', 'ACTIVE', 'INACTIVE', '', 'GARBAGE']) {
      expect(updateDrawerSchema.safeParse({ status: s }).success).toBe(false);
      expect(adminUpdateDrawerSchema.safeParse({ status: s }).success).toBe(false);
    }
  });

  it('valid 5 enum statuses → accepted by both user and admin schemas', () => {
    for (const s of ['EMPTY', 'LOADED', 'LOCKED', 'DISPENSING', 'ERROR'] as const) {
      const r1 = updateDrawerSchema.safeParse({ status: s });
      const r2 = adminUpdateDrawerSchema.safeParse({ status: s });
      expect(r1.success).toBe(true);
      expect(r2.success).toBe(true);
    }
  });

  it('unknown key / structural mutation → strict validator rejects 400 on both schemas', () => {
    const badPayloads: Record<string, unknown>[] = [
      { id: 'hax' },
      { medicineBoxId: 'steal' },
      { drawerNumber: 99 },
      { userId: 'other' },
      { createdAt: now().toISOString() },
      { updatedAt: now().toISOString() },
      { medicationId: 'bad-phase' },
      { drawerMedicationId: 'x' },
      { assignedAt: now().toISOString() },
      { isActive: true },
      { status: 'LOADED', __extra: 1 },
      { capacity: 10 },
      { currentCount: 2 },
    ];
    for (const b of badPayloads) {
      expect(updateDrawerSchema.safeParse(b).success).toBe(false);
      expect(adminUpdateDrawerSchema.safeParse(b).success).toBe(false);
    }
  });

  it('empty body allowed (PATCH is partial); but status with bad value still 400', () => {
    expect(updateDrawerSchema.safeParse({}).success).toBe(true);
    expect(adminUpdateDrawerSchema.safeParse({}).success).toBe(true);
    expect(updateDrawerSchema.safeParse({ status: 'BAD' }).success).toBe(false);
  });
});

describe('§26 ADMIN ENDPOINTS: list/get/update all 200 success; USER → 403', () => {
  let dr: MockDrawerRepo;
  beforeEach(() => {
    dr = {
      findById: mk(),
      findAll: mk(),
      findAllByMedicineBoxId: mk(),
      findAllByUserId: mk(),
      findByIdAndMedicineBoxId: mk(),
      findByIdAndUserId: mk(),
      findByMedicineBoxIdAndDrawerNumber: mk(),
      findNumbersByMedicineBoxId: mk(),
      create: mk(),
      createMany: mk(),
      update: mk(),
    };
  });

  it('admin list all → 200 ok returns every drawer', async () => {
    dr.findAll.mockResolvedValue([
      buildDrawer({ id: 'a1', medicineBoxId: 'box-A', drawerNumber: 1 }),
      buildDrawer({ id: 'b1', medicineBoxId: 'box-B', drawerNumber: 1 }),
    ]);
    const uc = new GetAllDrawers(dr as never);
    const out = await uc.execute();
    expect(out).toHaveLength(2);
    expect(dr.findAll).toHaveBeenCalled();
  });

  it('admin get drawer by id → exists 200; nonexistent → NotFoundError 404', async () => {
    dr.findById
      .mockResolvedValueOnce(buildDrawer({ id: 'd-x' }))
      .mockResolvedValueOnce(null);
    const uc = new GetDrawerByIdAdmin(dr as never);
    const ok = await uc.execute('d-x');
    expect(ok.id).toBe('d-x');
    await expect(uc.execute('ghost')).rejects.toThrow(NotFoundError);
  });

  it('admin update status → allowed (only status passed to repo.update); nonexistent → NotFound', async () => {
    dr.findById.mockResolvedValue(buildDrawer({ id: 'd-1', status: 'EMPTY' }));
    dr.update.mockResolvedValue(buildDrawer({ id: 'd-1', status: 'ERROR' }));
    const uc = new AdminUpdateDrawer(dr as never);
    const out = await uc.execute('d-1', { status: 'ERROR' });
    expect(out.status).toBe('ERROR');
    expect(dr.update).toHaveBeenCalledWith('d-1', { status: 'ERROR' });
    dr.findById.mockResolvedValueOnce(null);
    await expect(uc.execute('ghost', { status: 'LOADED' })).rejects.toThrow(NotFoundError);
  });

  it('USER role calling admin endpoints → requireRole("ADMIN") throws 403 every time', () => {
    const calls: Array<Partial<Request> & { label: string }> = [
      { label: 'GET /drawers/admin/all', path: '/admin/all' },
      { label: 'GET /drawers/admin/:id', path: '/admin/x' },
      { label: 'PATCH /drawers/admin/:id', path: '/admin/x' },
      { label: 'POST provision drawers', path: '/drawers' },
    ];
    for (const c of calls) {
      const req = { user: { userId: 'u1', role: 'USER' }, path: c.path } as Request;
      const n = nextFn();
      requireRole('ADMIN')(req, emptyRes(), n);
      const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
      expect(err).toBeInstanceOf(ForbiddenError);
      expect(err.statusCode).toBe(403);
    }
  });

  it('ADMIN accessing GET /drawers → still enforces normal ownership filter via GetMyDrawers(userId), not admin auto-global', async () => {
    dr.findAllByUserId.mockResolvedValue([buildDrawer({ id: 'admin-owned-1' })]);
    const uc = new GetMyDrawers(dr as never);
    const out = await uc.execute('admin-1');
    // Admin calling normal GET /drawers passes their own JWT userId → only boxes THEY activated
    expect(dr.findAllByUserId).toHaveBeenCalledWith('admin-1', undefined);
    expect(out.map((d) => d.id)).toEqual(['admin-owned-1']);
  });
});

// Small sanity test: BadRequestError actually defined / is instanceof AppError
describe('Validation wiring: BadRequestError class instanceof check', () => {
  it('BadRequestError has statusCode 400', () => {
    const e = new BadRequestError('x');
    expect(e.statusCode).toBe(400);
  });
});

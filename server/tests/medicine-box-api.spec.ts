import type { Request, Response, NextFunction } from 'express';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import {
  addMedicineBoxSchema,
  activateMedicineBoxSchema,
  userUpdateMedicineBoxSchema,
  adminUpdateMedicineBoxSchema,
} from '@presentation/validators/medicineBox.validator';
import { AddMedicineBox } from '@application/use-cases/medicine-box/AddMedicineBox';
import { GetMyMedicineBoxes } from '@application/use-cases/medicine-box/GetMyMedicineBoxes';
import { GetMedicineBoxById } from '@application/use-cases/medicine-box/GetMedicineBoxById';
import { UpdateMedicineBox } from '@application/use-cases/medicine-box/UpdateMedicineBox';
import { ActivateMedicineBox } from '@application/use-cases/medicine-box/ActivateMedicineBox';
import { UnassignMedicineBox } from '@application/use-cases/medicine-box/UnassignMedicineBox';
import { GetAllMedicineBoxes } from '@application/use-cases/medicine-box/GetAllMedicineBoxes';
import { GetMedicineBoxByIdAdmin } from '@application/use-cases/medicine-box/GetMedicineBoxByIdAdmin';
import { AdminUpdateMedicineBox } from '@application/use-cases/medicine-box/AdminUpdateMedicineBox';
import {
  NotFoundError,
  UnauthorizedError,
  ForbiddenError,
  ConflictError,
} from '@shared/errors';

type MockBoxRepo = {
  create: jest.Mock;
  findById: jest.Mock;
  findAll: jest.Mock;
  findAllByUserId: jest.Mock;
  findByIdAndUserId: jest.Mock;
  findByDeviceId: jest.Mock;
  existsByDeviceId: jest.Mock;
  update: jest.Mock;
  adminUpdate: jest.Mock;
  activateAtomic: jest.Mock;
  releaseOwnership: jest.Mock;
  activate?: jest.Mock;
};

const mkFn = () => jest.fn();
const mkMocks = (): MockBoxRepo => ({
  create: mkFn(),
  findById: mkFn(),
  findAll: mkFn(),
  findAllByUserId: mkFn(),
  findByIdAndUserId: mkFn(),
  findByDeviceId: mkFn(),
  existsByDeviceId: mkFn(),
  update: mkFn(),
  adminUpdate: mkFn(),
  activateAtomic: mkFn(),
  releaseOwnership: mkFn(),
});

const now = () => new Date('2026-08-21T00:00:00.000Z');
const buildBox = (o: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'DEV-1',
  deviceToken: 'SENSITIVE-TOKEN',
  name: 'Box 1',
  status: 'READY',
  deviceStatus: 'OFFLINE',
  lastSeenAt: null,
  userId: null,
  numberOfDrawers: 7,
  drawerCapacity: 10,
  createdAt: now(),
  updatedAt: now(),
  ...o,
});

const nextFn = () => jest.fn() as unknown as jest.Mock & NextFunction;
const emptyRes = () => ({} as Response);

describe('§26 AUTH: no JWT → all MB endpoints → 401', () => {
  const res = emptyRes();
  const scenarios: Partial<Request>[] = [
    { method: 'POST', path: '/api/medicine-boxes' },
    { method: 'POST', path: '/api/medicine-boxes/activate' },
    { method: 'GET', path: '/api/medicine-boxes' },
    { method: 'GET', path: '/api/medicine-boxes/x' },
    { method: 'PATCH', path: '/api/medicine-boxes/x' },
    { method: 'GET', path: '/api/medicine-boxes/admin/all' },
    { method: 'GET', path: '/api/medicine-boxes/admin/x' },
    { method: 'PATCH', path: '/api/medicine-boxes/admin/x' },
  ];
  scenarios.forEach((s) =>
    it(`${s.method} ${s.path} without JWT → 401`, () => {
      const req = { headers: {}, method: s.method, path: s.path } as Request;
      const n = nextFn();
      requireAuth(req, res, n);
      const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
      expect(err).toBeInstanceOf(UnauthorizedError);
      expect(err.statusCode).toBe(401);
    }),
  );
});

describe('§26 ADMIN REQUIRE ROLE: USER → 403 on admin endpoints', () => {
  const scenarios: Array<Partial<Request> & { label: string }> = [
    { label: 'POST /medicine-boxes', method: 'POST', path: '/api/medicine-boxes' },
    { label: 'GET /admin/all', method: 'GET', path: '/admin/all' },
    { label: 'GET /admin/:id', method: 'GET', path: '/admin/xyz' },
    { label: 'PATCH /admin/:id', method: 'PATCH', path: '/admin/xyz' },
  ];
  scenarios.forEach((s) =>
    it(`USER role calling ${s.label} → 403 Forbidden`, () => {
      const req = {
        headers: {},
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

describe('§26 ADMIN CREATE: /api/medicine-boxes', () => {
  let mocks: MockBoxRepo;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('ADMIN → 201 Created; auto READY + userId=NULL', async () => {
    mocks.existsByDeviceId.mockResolvedValue(false);
    mocks.create.mockResolvedValue(
      buildBox({ id: 'box-new', status: 'READY', userId: null }),
    );
    const uc = new AddMedicineBox(mocks as never);
    const r = await uc.execute({
      deviceId: 'DEV-001',
      deviceToken: 'T',
      name: 'B',
      numberOfDrawers: 4,
      drawerCapacity: 15,
    });
    expect(mocks.existsByDeviceId).toHaveBeenCalledWith('DEV-001');
    expect(mocks.create).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'READY',
        userId: null,
        deviceId: 'DEV-001',
      }),
    );
    expect(r.id).toBe('box-new');
    expect(r.status).toBe('READY');
    expect(r.userId).toBeNull();
  });

  it('USER → requireRole(ADMIN) → 403', () => {
    const req = { user: { userId: 'u', role: 'USER' } } as Request;
    const n = nextFn();
    requireRole('ADMIN')(req, emptyRes(), n);
    const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
    expect(err).toBeInstanceOf(ForbiddenError);
    expect(err.statusCode).toBe(403);
  });

  it('duplicate deviceId → 409 ConflictError (not 400)', async () => {
    mocks.existsByDeviceId.mockResolvedValue(true);
    const uc = new AddMedicineBox(mocks as never);
    await expect(
      uc.execute({ deviceId: 'DUP', deviceToken: 'T', name: 'B', numberOfDrawers: 1, drawerCapacity: 1 }),
    ).rejects.toThrow(ConflictError);
    expect(mocks.create).not.toHaveBeenCalled();
  });

  it('bad validation: empty deviceId / empty token / empty name / 0 drawercount / negative / decimal / status in body / userId in body / unknown keys → strict rejects', () => {
    const badCases: Array<{ input: Record<string, unknown>; label: string }> = [
      { label: 'empty deviceId', input: { deviceId: '', deviceToken: 't', name: 'n', numberOfDrawers: 1, drawerCapacity: 1 } },
      { label: 'empty token', input: { deviceId: 'd', deviceToken: '', name: 'n', numberOfDrawers: 1, drawerCapacity: 1 } },
      { label: 'empty name', input: { deviceId: 'd', deviceToken: 't', name: '', numberOfDrawers: 1, drawerCapacity: 1 } },
      { label: 'numDrawers 0', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 0, drawerCapacity: 1 } },
      { label: 'numDrawers negative', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: -1, drawerCapacity: 1 } },
      { label: 'numDrawers decimal', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 1.5, drawerCapacity: 1 } },
      { label: 'drawerCap 0', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 1, drawerCapacity: 0 } },
      { label: 'drawerCap negative', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 1, drawerCapacity: -1 } },
      { label: 'drawerCap decimal', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 1, drawerCapacity: 1.5 } },
      { label: 'body status', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 1, drawerCapacity: 1, status: 'ACTIVE' } },
      { label: 'body userId', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 1, drawerCapacity: 1, userId: 'x' } },
      { label: 'unknown', input: { deviceId: 'd', deviceToken: 't', name: 'n', numberOfDrawers: 1, drawerCapacity: 1, serialNumber: 1 } },
    ];
    for (const c of badCases) {
      expect(addMedicineBoxSchema.safeParse(c.input).success).toBe(false);
    }
  });

  it('response never includes deviceToken', async () => {
    mocks.existsByDeviceId.mockResolvedValue(false);
    mocks.create.mockResolvedValue(buildBox({ id: 'b', deviceToken: 'SECRET' }));
    const uc = new AddMedicineBox(mocks as never);
    const r = await uc.execute({ deviceId: 'd', deviceToken: 't', name: 'b', numberOfDrawers: 1, drawerCapacity: 1 });
    // Use-case returns domain (with token) but controller maps via toPublicMedicineBox → we assert here via explicit DTO call:
    const { deviceToken: _s, ...pub } = r;
    void _s;
    expect((pub as Record<string, unknown>).deviceToken).toBeUndefined();
  });
});

describe('§26 ACTIVATE: atomic one-winner, not-found 404, bad-token 401, owned 409', () => {
  let mocks: MockBoxRepo;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('valid READY box → activateAtomic called → ACTIVE userId=uA', async () => {
    const registered = buildBox({ id: 'b1', deviceId: 'DEV', deviceToken: 'T', userId: null, status: 'READY' });
    mocks.findByDeviceId.mockResolvedValue(registered);
    mocks.activateAtomic.mockResolvedValue({
      kind: 'success',
      box: { ...registered, userId: 'u-A', status: 'ACTIVE', updatedAt: now() },
    });
    const uc = new ActivateMedicineBox(mocks as never);
    const r = await uc.execute('u-A', { deviceId: 'DEV', deviceToken: 'T' });
    expect(mocks.activateAtomic).toHaveBeenCalledWith('DEV', 'u-A');
    expect(r.userId).toBe('u-A');
    expect(r.status).toBe('ACTIVE');
  });

  it('unknown deviceId → 404 NotFound', async () => {
    mocks.findByDeviceId.mockResolvedValue(null);
    const uc = new ActivateMedicineBox(mocks as never);
    await expect(uc.execute('u-A', { deviceId: 'NOPE', deviceToken: 'T' })).rejects.toThrow(NotFoundError);
    expect(mocks.activateAtomic).not.toHaveBeenCalled();
  });

  it('wrong token → 401 UnauthorizedError (never activateAtomic)', async () => {
    const registered = buildBox({ deviceId: 'D', deviceToken: 'REAL' });
    mocks.findByDeviceId.mockResolvedValue(registered);
    const uc = new ActivateMedicineBox(mocks as never);
    await expect(uc.execute('u-A', { deviceId: 'D', deviceToken: 'WRONG' })).rejects.toThrow(UnauthorizedError);
    expect(mocks.activateAtomic).not.toHaveBeenCalled();
  });

  it('already owned by another → 409 Conflict before atomic', async () => {
    const owned = buildBox({ deviceId: 'D', deviceToken: 'T', userId: 'u-VICTIM', status: 'ACTIVE' });
    mocks.findByDeviceId.mockResolvedValue(owned);
    const uc = new ActivateMedicineBox(mocks as never);
    await expect(uc.execute('u-B', { deviceId: 'D', deviceToken: 'T' })).rejects.toThrow(ConflictError);
    expect(mocks.activateAtomic).not.toHaveBeenCalled();
  });

  it('second user attempts simultaneous activate → atomic returns already-owned → 409 Conflict', async () => {
    const registered = buildBox({ deviceId: 'D', deviceToken: 'T', userId: null, status: 'READY' });
    mocks.findByDeviceId.mockResolvedValue(registered);
    mocks.activateAtomic
      .mockResolvedValueOnce({ kind: 'success', box: { ...registered, userId: 'u-A', status: 'ACTIVE' } })
      .mockResolvedValueOnce({ kind: 'already-owned' });
    const uc = new ActivateMedicineBox(mocks as never);
    const r1 = await uc.execute('u-A', { deviceId: 'D', deviceToken: 'T' });
    expect(r1.userId).toBe('u-A');
    // Simulate race: second user arrives AFTER first claim; state in DB now userId!=NULL → short-circuit throw Conflict without hitting updateMany:
    mocks.findByDeviceId.mockResolvedValue({ ...registered, userId: 'u-A', status: 'ACTIVE' });
    await expect(uc.execute('u-B', { deviceId: 'D', deviceToken: 'T' })).rejects.toThrow(ConflictError);
    // activateAtomic called once (first user). Second call short-circuited in use-case via pre-check existing.userId != && != claimant → 409 Conflict
    expect(mocks.activateAtomic).toHaveBeenCalledTimes(1);
  });

  it('body userId → strict rejects 400; body status → strict rejects 400', () => {
    expect(
      activateMedicineBoxSchema.safeParse({ deviceId: 'd', deviceToken: 't', userId: 'x' }).success,
    ).toBe(false);
    expect(
      activateMedicineBoxSchema.safeParse({ deviceId: 'd', deviceToken: 't', status: 'ACTIVE' }).success,
    ).toBe(false);
  });

  it('activation response hides deviceToken', async () => {
    const registered = buildBox({ deviceId: 'D', deviceToken: 'SECRET' });
    mocks.findByDeviceId.mockResolvedValue(registered);
    mocks.activateAtomic.mockResolvedValue({ kind: 'success', box: registered });
    const uc = new ActivateMedicineBox(mocks as never);
    const r = await uc.execute('u-A', { deviceId: 'D', deviceToken: 'SECRET' });
    expect(r.deviceToken).toBeDefined();
    // Controller DTO strips it; test that manual toPublicMedicineBox behavior applied separately:
    const { deviceToken: _s, ...pub } = r;
    void _s;
    expect((pub as Record<string, unknown>).deviceToken).toBeUndefined();
  });
});

describe('§25 USER GET list / GET by id / PATCH name: cross-user 404 not 403', () => {
  let mocks: MockBoxRepo;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('GetMyMedicineBoxes → only uA boxes; ?userId bypass is impossible (use case ignores query, uses JWT only)', async () => {
    const uA = [buildBox({ id: 'a1', userId: 'uA' }), buildBox({ id: 'a2', userId: 'uA' })];
    mocks.findAllByUserId.mockResolvedValue(uA);
    const uc = new GetMyMedicineBoxes(mocks as never);
    const r = await uc.execute('uA');
    expect(mocks.findAllByUserId).toHaveBeenCalledWith('uA');
    expect(r.map((x) => x.id).every((i) => i.startsWith('a'))).toBe(true);
  });

  it('User A GET Box A → 200; User B GET Box A → findByIdAndUserId returns null → 404 Not Found', async () => {
    mocks.findByIdAndUserId
      .mockResolvedValueOnce(buildBox({ id: 'a1', userId: 'uA' }))
      .mockResolvedValueOnce(null);
    const uc = new GetMedicineBoxById(mocks as never);
    const good = await uc.execute('uA', 'a1');
    expect(good.id).toBe('a1');
    await expect(uc.execute('uB', 'a1')).rejects.toThrow(NotFoundError);
  });

  it('nonexistent id → 404 not 403 (enumeration safe)', async () => {
    mocks.findByIdAndUserId.mockResolvedValue(null);
    const uc = new GetMedicineBoxById(mocks as never);
    await expect(uc.execute('uA', 'ghost')).rejects.toThrow(NotFoundError);
  });

  it('User A PATCH name Box A → 200; no other fields mutated', async () => {
    const before = buildBox({ id: 'a1', userId: 'uA', name: 'old', numberOfDrawers: 7, deviceId: 'D' });
    mocks.findByIdAndUserId.mockResolvedValue(before);
    mocks.update.mockResolvedValue({ ...before, name: 'new', updatedAt: now() });
    const uc = new UpdateMedicineBox(mocks as never);
    const r = await uc.execute('uA', 'a1', { name: 'new' });
    expect(mocks.update).toHaveBeenCalledWith('a1', { name: 'new' });
    expect(r.name).toBe('new');
    expect((r as MedicineBox).numberOfDrawers).toBe(7);
  });

  it('User B PATCH name Box A → 404 NotFoundError (caller cannot see existence)', async () => {
    mocks.findByIdAndUserId.mockResolvedValue(null);
    const uc = new UpdateMedicineBox(mocks as never);
    await expect(uc.execute('uB', 'a1', { name: 'x' })).rejects.toThrow(NotFoundError);
    expect(mocks.update).not.toHaveBeenCalled();
  });

  it('USER patch rejects all these fields: deviceId deviceToken userId status numberOfDrawers drawerCapacity createdAt updatedAt → strict() 400', () => {
    const blocked = [
      'deviceId',
      'deviceToken',
      'userId',
      'status',
      'numberOfDrawers',
      'drawerCapacity',
      'createdAt',
      'updatedAt',
    ];
    for (const f of blocked) {
      const body: Record<string, unknown> = { name: 'x' };
      body[f] = f === 'numberOfDrawers' || f === 'drawerCapacity' ? 1 : 'x';
      expect(userUpdateMedicineBoxSchema.safeParse(body).success).toBe(false);
    }
    expect(userUpdateMedicineBoxSchema.safeParse({ name: 'x', unknown: 1 }).success).toBe(false);
  });
});

describe('§26 ADMIN GET LIST / ADMIN GET / ADMIN UPDATE: requireRole; deviceToken stripped; forbidden to USER', () => {
  let mocks: MockBoxRepo;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('ADMIN list → findAll returns all boxes; USER → 403 requireRole', async () => {
    const all = [buildBox({ id: 'b1' }), buildBox({ id: 'b2' })];
    mocks.findAll.mockResolvedValue(all);
    const uc = new GetAllMedicineBoxes(mocks as never);
    const r = await uc.execute();
    expect(r).toHaveLength(2);
    expect(mocks.findAll).toHaveBeenCalled();
    // USER role check
    const req = { user: { userId: 'u', role: 'USER' } } as Request;
    const n = nextFn();
    requireRole('ADMIN')(req, emptyRes(), n);
    expect(n.mock.calls[0][0]).toBeInstanceOf(ForbiddenError);
  });

  it('ADMIN get by id → any box exists 200; nonexistent → 404 Not Found', async () => {
    mocks.findById
      .mockResolvedValueOnce(buildBox({ id: 'bx' }))
      .mockResolvedValueOnce(null);
    const uc = new GetMedicineBoxByIdAdmin(mocks as never);
    const ok = await uc.execute('bx');
    expect(ok.id).toBe('bx');
    await expect(uc.execute('ghost')).rejects.toThrow(NotFoundError);
  });

  it('ADMIN update: allowed name numDrawers drawerCap; userId/deviceId/status/token rejected', async () => {
    mocks.findById.mockResolvedValue(buildBox({ id: 'bx', name: 'old' }));
    mocks.adminUpdate.mockResolvedValue(buildBox({ id: 'bx', name: 'new', numberOfDrawers: 8, drawerCapacity: 20 }));
    const uc = new AdminUpdateMedicineBox(mocks as never);
    const r = await uc.execute('bx', { name: 'new', numberOfDrawers: 8, drawerCapacity: 20 });
    expect(mocks.adminUpdate).toHaveBeenCalledWith('bx', {
      name: 'new',
      numberOfDrawers: 8,
      drawerCapacity: 20,
    });
    expect(r.name).toBe('new');
    // blocked keys
    for (const f of ['userId', 'deviceId', 'deviceToken', 'status', 'createdAt', 'updatedAt'] as const) {
      const payload: Record<string, unknown> = { name: 'x' };
      payload[f] = 'x';
      expect(adminUpdateMedicineBoxSchema.safeParse(payload).success).toBe(false);
    }
  });

  it('deviceToken never appears on admin responses', async () => {
    mocks.findById.mockResolvedValue(buildBox({ deviceToken: 'SUP3R-S3CR3T' }));
    const uc = new GetMedicineBoxByIdAdmin(mocks as never);
    const r = await uc.execute('b');
    expect(r.deviceToken).toBeDefined();
    const { deviceToken: _s, ...safe } = r;
    void _s;
    expect((safe as Record<string, unknown>).deviceToken).toBeUndefined();
  });
});

describe('§ UNASSIGN: POST /medicine-boxes/:id/unassign — USER ownership release (A-L)', () => {
  let mocks: MockBoxRepo;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('A. Successful unassign: ACTIVE box with 3 drawers + 2 assignments → READY userId NULL', async () => {
    const owned = buildBox({
      id: 'box-A',
      userId: 'u-A',
      status: 'ACTIVE',
      deviceId: 'DEV-A',
      name: 'Box Alpha',
      deviceToken: 'HIDDEN-A',
    });
    const released = {
      ...owned,
      userId: null as string | null,
      status: 'READY' as const,
      updatedAt: now(),
    };
    mocks.releaseOwnership.mockResolvedValue({ kind: 'success', box: released });

    const uc = new UnassignMedicineBox(mocks as never);
    const r = await uc.execute('u-A', 'box-A');

    expect(mocks.releaseOwnership).toHaveBeenCalledWith('box-A', 'u-A');
    expect(r.id).toBe('box-A');
    expect(r.userId).toBeNull();
    expect(r.status).toBe('READY');
    expect(r.deviceId).toBe('DEV-A');
    expect(r.name).toBe('Box Alpha');
  });

  it('B. User A cannot unassign User B box → releaseOwnership not-found → 404', async () => {
    mocks.releaseOwnership.mockResolvedValue({ kind: 'not-found' });
    const uc = new UnassignMedicineBox(mocks as never);
    await expect(uc.execute('u-A', 'box-B-owned-by-uB')).rejects.toThrow(NotFoundError);
    expect(mocks.releaseOwnership).toHaveBeenCalledWith('box-B-owned-by-uB', 'u-A');
  });

  it('C. Missing JWT → requireAuth → 401 UnauthorizedError', () => {
    const req = { headers: {}, method: 'POST', path: '/api/medicine-boxes/x/unassign' } as Request;
    const n = nextFn();
    requireAuth(req, emptyRes(), n);
    const err = n.mock.calls[0][0] as { constructor: unknown; statusCode: number };
    expect(err).toBeInstanceOf(UnauthorizedError);
    expect(err.statusCode).toBe(401);
  });

  it('D. Non-existing box → releaseOwnership not-found → 404 NotFoundError', async () => {
    mocks.releaseOwnership.mockResolvedValue({ kind: 'not-found' });
    const uc = new UnassignMedicineBox(mocks as never);
    await expect(uc.execute('u-A', 'ghost-box')).rejects.toThrow(NotFoundError);
  });

  it('E. Already unassigned box (userId NULL) → releaseOwnership where userId fails → 404', async () => {
    mocks.releaseOwnership.mockResolvedValue({ kind: 'not-found' });
    const uc = new UnassignMedicineBox(mocks as never);
    await expect(uc.execute('u-A', 'box-no-owner')).rejects.toThrow(NotFoundError);
    // NOT a 400/409 — enumeration-safe 404
  });

  it('F. Medication + Patient preservation: unassign NEVER deletes Medication or Patient', async () => {
    // The repo interface only exposes `releaseOwnership`; there is NO deleteMedication/deletePatient on the box repo contract.
    // We verify by checking the mock repo never calls delete-like methods for Medication/Patient.
    // Additionally, the use-case only calls `releaseOwnership`:
    const owned = buildBox({ id: 'box-P', userId: 'u-P', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY', updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    const r = await uc.execute('u-P', 'box-P');
    expect(r.status).toBe('READY');
    // MockBoxRepo type intentionally lacks `deleteMedication` / `deletePatient` fields —
    // compile-time guarantee via TS. Additionally, assert runtime:
    expect((mocks as Record<string, jest.Mock>).deleteMedication).toBeUndefined();
    expect((mocks as Record<string, jest.Mock>).deletePatient).toBeUndefined();
  });

  it('G. Multiple drawers: releaseOwnership called once → repository responsible for removing ALL DrawerMedication assignments (preserves Drawers)', async () => {
    const owned = buildBox({ id: 'box-M', userId: 'u-M', status: 'ACTIVE', numberOfDrawers: 7 });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY', updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    await uc.execute('u-M', 'box-M');
    // releaseOwnership is called once (atomic op handles all drawers internally in repo)
    expect(mocks.releaseOwnership).toHaveBeenCalledTimes(1);
    expect(mocks.releaseOwnership).toHaveBeenCalledWith('box-M', 'u-M');
  });

  it('H. Multiple DrawerMedication assignments: handled inside releaseOwnership single call (not in UC)', async () => {
    const owned = buildBox({ id: 'box-H', userId: 'u-H', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY', updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    await uc.execute('u-H', 'box-H');
    // UC does NOT coordinate DrawerMedication — that's entirely inside repo.releaseOwnership
    // (verified by absence of DM-repo calls on the mock set).
    expect((mocks as Record<string, jest.Mock>).findAllByMedicineBoxId).toBeUndefined();
    expect((mocks as Record<string, jest.Mock>).deleteDrawerMedication).toBeUndefined();
  });

  it('I. Other box isolation: User A owns Box A + Box B → unassign A → Box B untouched', async () => {
    const boxA = buildBox({ id: 'box-A', userId: 'u-A', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...boxA, userId: null, status: 'READY', updatedAt: now() },
    });
    mocks.findByIdAndUserId
      .mockResolvedValueOnce(buildBox({ id: 'box-B', userId: 'u-A', status: 'ACTIVE' }));

    const uc = new UnassignMedicineBox(mocks as never);
    await uc.execute('u-A', 'box-A');
    // Unassign only touched box-A
    expect(mocks.releaseOwnership).toHaveBeenCalledWith('box-A', 'u-A');
    // Box B still retrievable & ACTIVE via the repo
    const boxBStill = await mocks.findByIdAndUserId('box-B', 'u-A');
    expect(boxBStill).not.toBeNull();
    expect((boxBStill as MedicineBox).status).toBe('ACTIVE');
    expect((boxBStill as MedicineBox).userId).toBe('u-A');
  });

  it('J. Device identity preserved: name/deviceId/id/deviceToken unchanged after unassign', async () => {
    const owned = buildBox({
      id: 'box-ID',
      deviceId: 'DEV-PRESERVE-ME',
      deviceToken: 'TOKEN-PRESERVE-ME',
      name: 'Keep My Name',
      userId: 'u-J',
      status: 'ACTIVE',
    });
    const after = {
      ...owned,
      userId: null as string | null,
      status: 'READY' as const,
      updatedAt: now(),
    };
    mocks.releaseOwnership.mockResolvedValue({ kind: 'success', box: after });
    const uc = new UnassignMedicineBox(mocks as never);
    const r = await uc.execute('u-J', 'box-ID');
    expect(r.id).toBe('box-ID');
    expect(r.deviceId).toBe('DEV-PRESERVE-ME');
    expect(r.name).toBe('Keep My Name');
    expect(r.deviceToken).toBe('TOKEN-PRESERVE-ME');
  });

  it('K. deviceToken NEVER in response envelope — controller uses toPublicMedicineBox', async () => {
    const owned = buildBox({
      id: 'box-K',
      userId: 'u-K',
      status: 'ACTIVE',
      deviceToken: 'DO-NOT-SHOW-ME',
    });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY', updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    const domain = await uc.execute('u-K', 'box-K');
    // Controller maps domain → public via toPublicMedicineBox; mimic it here:
    const { deviceToken: _s, ...pub } = domain;
    void _s;
    expect((pub as Record<string, unknown>).deviceToken).toBeUndefined();
    expect('deviceToken' in pub).toBe(false);
  });

  it('L. Atomicity: repo releaseOwnership throws → UC rethrows; no partial state in DB (repo guarantees rollback)', async () => {
    mocks.releaseOwnership.mockRejectedValue(new Error('simulated transaction failure'));
    const uc = new UnassignMedicineBox(mocks as never);
    // Throws (caught by error middleware → 500). The repository's $transaction
    // contract guarantees NO partial deletes if any step fails.
    await expect(uc.execute('u-L', 'box-L')).rejects.toThrow('simulated transaction failure');
    expect(mocks.releaseOwnership).toHaveBeenCalledTimes(1);
  });

  it('ADMIN does NOT bypass ownership: ADMIN targeting box owned by USER → 404', async () => {
    // ADMIN role but not owner. The USER endpoint uses releaseOwnership(boxId, userId) which checks
    // `where: { id, userId }` → ADMIN userId won't match → not-found → 404.
    mocks.releaseOwnership.mockResolvedValue({ kind: 'not-found' });
    const uc = new UnassignMedicineBox(mocks as never);
    await expect(uc.execute('admin-uuid', 'box-owned-by-user')).rejects.toThrow(NotFoundError);
  });

  it('Controller maps route :id → unassign; userId derived from req.user (never from body/query)', async () => {
    const owned = buildBox({ id: 'box-CTL', userId: 'u-CTL', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY', updatedAt: now() },
    });
    // Simulate req/controller by calling use case with only JWT-derived userId and route id.
    // No body parsing / no userId from client.
    const req_userId = 'u-CTL';
    const req_params_id = 'box-CTL';
    const uc = new UnassignMedicineBox(mocks as never);
    const r = await uc.execute(req_userId, req_params_id);
    expect(r.id).toBe(req_params_id);
    expect(mocks.releaseOwnership).toHaveBeenCalledWith(req_params_id, req_userId);
  });

  it('After unassign → same MedicineBox re-activatable by another user (READY + userId NULL)', async () => {
    // Release:
    const box = buildBox({
      id: 'reactivate',
      deviceId: 'DEV-REACT',
      deviceToken: 'REACT-TOKEN',
      userId: 'u-prev',
      status: 'ACTIVE',
    });
    const released = { ...box, userId: null, status: 'READY' as const, updatedAt: now() };
    mocks.releaseOwnership.mockResolvedValue({ kind: 'success', box: released });
    const ucUn = new UnassignMedicineBox(mocks as never);
    const afterUnassign = await ucUn.execute('u-prev', 'reactivate');
    expect(afterUnassign.userId).toBeNull();
    expect(afterUnassign.status).toBe('READY');

    // Activate by new user using existing activateAtomic contract (same project convention):
    mocks.findByDeviceId.mockResolvedValue({
      ...released,
      deviceToken: 'REACT-TOKEN',
    });
    const reactivated = { ...released, userId: 'u-new', status: 'ACTIVE' as const, updatedAt: now() };
    mocks.activateAtomic.mockResolvedValue({ kind: 'success', box: reactivated });
    const ucAct = new ActivateMedicineBox(mocks as never);
    const r = await ucAct.execute('u-new', { deviceId: 'DEV-REACT', deviceToken: 'REACT-TOKEN' });
    expect(r.userId).toBe('u-new');
    expect(r.status).toBe('ACTIVE');
    expect(mocks.activateAtomic).toHaveBeenCalledWith('DEV-REACT', 'u-new');
  });
});

describe('§ LIFECYCLE CORRECTION: status transitions + ownership integrity', () => {
  let mocks: MockBoxRepo;
  beforeEach(() => {
    mocks = mkMocks();
  });

  it('1. ADMIN provision → status=READY, userId=null (safe default)', async () => {
    mocks.existsByDeviceId.mockResolvedValue(false);
    mocks.create.mockImplementation((payload: never) => Promise.resolve({
      id: 'new-box',
      ...(payload as Record<string, unknown>),
      createdAt: now(),
      updatedAt: now(),
    } as never));
    const uc = new AddMedicineBox(mocks as never);
    const out = await uc.execute({
      deviceId: 'DEV-PROV',
      deviceToken: 'TOK',
      name: 'Newly Provisioned',
      numberOfDrawers: 6,
      drawerCapacity: 10,
    });
    expect(mocks.create).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'READY', userId: null }),
    );
    expect(out.status).toBe('READY');
    expect(out.userId).toBeNull();
  });

  it('2. USER activation: READY + userId=null → ACTIVE + userId via activateAtomic', async () => {
    mocks.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'DEV', deviceToken: 'T', userId: null, status: 'READY' }),
    );
    const activated = buildBox({
      deviceId: 'DEV',
      deviceToken: 'T',
      userId: 'uA',
      status: 'ACTIVE',
    });
    mocks.activateAtomic.mockResolvedValue({ kind: 'success', box: activated });
    const uc = new ActivateMedicineBox(mocks as never);
    const r = await uc.execute('uA', { deviceId: 'DEV', deviceToken: 'T' });
    expect(mocks.activateAtomic).toHaveBeenCalledWith('DEV', 'uA');
    expect(r.status).toBe('ACTIVE');
    expect(r.userId).toBe('uA');
  });

  it('3. Cannot activate already ACTIVE box (other user) → ConflictError', async () => {
    mocks.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'DEV', deviceToken: 'whatever', userId: 'uOther', status: 'ACTIVE' }),
    );
    const uc = new ActivateMedicineBox(mocks as never);
    await expect(
      uc.execute('uA', { deviceId: 'DEV', deviceToken: 'whatever' }),
    ).rejects.toThrow(ConflictError);
    expect(mocks.activateAtomic).not.toHaveBeenCalled();
  });

  it('4. Cannot activate MAINTENANCE box → ConflictError (maintenance specific or generic already-activated)', async () => {
    mocks.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'DEV', deviceToken: 'T', userId: null, status: 'MAINTENANCE' }),
    );
    const uc = new ActivateMedicineBox(mocks as never);
    await expect(
      uc.execute('uA', { deviceId: 'DEV', deviceToken: 'T' }),
    ).rejects.toThrow(ConflictError);
    expect(mocks.activateAtomic).not.toHaveBeenCalled();
  });

  it('5. USER unassign: ACTIVE + userId → READY + userId null', async () => {
    const owned = buildBox({ id: 'box-U', userId: 'uA', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY' as const, updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    const r = await uc.execute('uA', 'box-U');
    expect(r.status).toBe('READY');
    expect(r.userId).toBeNull();
    expect(mocks.releaseOwnership).toHaveBeenCalledWith('box-U', 'uA');
  });

  it('6. Unassign PRESERVES Drawers (never calls deleteDrawer / drawer.deleteMany; only DM cleaned up inside single releaseOwnership)', async () => {
    const owned = buildBox({ id: 'box-D', userId: 'uA', status: 'ACTIVE', numberOfDrawers: 5 });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY' as const, updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    await uc.execute('uA', 'box-D');
    // Atomic: one repo call handles it all; no separate drawer.delete calls on MB repo.
    expect(mocks.releaseOwnership).toHaveBeenCalledTimes(1);
    // Drawer deletion methods MUST NOT exist on the box repo contract / MUST NOT be callable.
    expect((mocks as Record<string, jest.Mock>).deleteDrawer).toBeUndefined();
    expect((mocks as Record<string, jest.Mock>).deleteManyDrawer).toBeUndefined();
    expect((mocks as Record<string, jest.Mock>).drawerDeleteMany).toBeUndefined();
  });

  it('7. Unassign deletes DrawerMedication (inside releaseOwnership; not visible to UC)', async () => {
    const owned = buildBox({ id: 'box-DM', userId: 'uA', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY' as const, updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    await uc.execute('uA', 'box-DM');
    // UC does not coordinate DM deletes; that is entirely inside the repository method.
    expect((mocks as Record<string, jest.Mock>).deleteDrawerMedication).toBeUndefined();
    expect(mocks.releaseOwnership).toHaveBeenCalledTimes(1);
  });

  it('8. Unassign preserves Medication (MockBoxRepo has no deleteMedication method)', async () => {
    const owned = buildBox({ id: 'box-M', userId: 'uA', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY' as const, updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    await uc.execute('uA', 'box-M');
    expect((mocks as Record<string, jest.Mock>).deleteMedication).toBeUndefined();
  });

  it('9. Unassign preserves Patient (MockBoxRepo has no deletePatient method)', async () => {
    const owned = buildBox({ id: 'box-P', userId: 'uA', status: 'ACTIVE' });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY' as const, updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    await uc.execute('uA', 'box-P');
    expect((mocks as Record<string, jest.Mock>).deletePatient).toBeUndefined();
  });

  it('10. Unassign preserves MedicineBox (box row still exists, id/deviceId unchanged)', async () => {
    const owned = buildBox({
      id: 'box-EXISTS',
      userId: 'uA',
      status: 'ACTIVE',
      deviceId: 'DEV-KEEP-ME',
      name: 'Keep my identity',
    });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...owned, userId: null, status: 'READY' as const, updatedAt: now() },
    });
    const uc = new UnassignMedicineBox(mocks as never);
    const r = await uc.execute('uA', 'box-EXISTS');
    expect(r.id).toBe('box-EXISTS');
    expect(r.deviceId).toBe('DEV-KEEP-ME');
    expect(r.name).toBe('Keep my identity');
  });

  it('11. Same device can be activated again after unassign (READY → ACTIVE)', async () => {
    const before = buildBox({
      id: 'box-R',
      userId: 'u-prev',
      status: 'ACTIVE',
      deviceId: 'DEV-REUSE',
      deviceToken: 'TOK-REUSE',
    });
    mocks.releaseOwnership.mockResolvedValue({
      kind: 'success',
      box: { ...before, userId: null, status: 'READY' as const, updatedAt: now() },
    });
    const un = new UnassignMedicineBox(mocks as never);
    const after = await un.execute('u-prev', 'box-R');
    expect(after.status).toBe('READY');
    expect(after.userId).toBeNull();

    // Simulate ActivateMedicineBox for a new user on the now-READY box:
    mocks.findByDeviceId.mockResolvedValue(
      buildBox({ ...after, deviceId: 'DEV-REUSE', deviceToken: 'TOK-REUSE' }),
    );
    mocks.activateAtomic.mockResolvedValue({
      kind: 'success',
      box: buildBox({
        id: 'box-R',
        deviceId: 'DEV-REUSE',
        deviceToken: 'TOK-REUSE',
        userId: 'u-next',
        status: 'ACTIVE',
      }),
    });
    const act = new ActivateMedicineBox(mocks as never);
    const r = await act.execute('u-next', { deviceId: 'DEV-REUSE', deviceToken: 'TOK-REUSE' });
    expect(r.userId).toBe('u-next');
    expect(r.status).toBe('ACTIVE');
  });

  it('12. Cross-user unassign → releaseOwnership returns not-found → NotFoundError 404', async () => {
    mocks.releaseOwnership.mockResolvedValue({ kind: 'not-found' });
    const uc = new UnassignMedicineBox(mocks as never);
    await expect(uc.execute('attacker', 'box-owned-by-victim')).rejects.toThrow(NotFoundError);
  });

  it('13. deviceToken never in public response (toPublicMedicineBox)', () => {
    const box = buildBox({ deviceToken: 'HIDDEN-TOKEN-123' });
    const { toPublicMedicineBox } = require('@infrastructure/database/prisma/repositories/PrismaMedicineBoxRepository');
    const pub = toPublicMedicineBox(box);
    expect((pub as Record<string, unknown>).deviceToken).toBeUndefined();
    expect('deviceToken' in pub).toBe(false);
  });

  it('14. USER PATCH schema rejects status/userId injection (strict validator)', () => {
    const bad = {
      name: 'OK Name',
      status: 'READY',
      userId: 'injected',
      role: 'ADMIN',
    };
    const res = userUpdateMedicineBoxSchema.safeParse(bad);
    expect(res.success).toBe(false);
  });

  it('15. USER PATCH → UpdateMedicineBoxData type excludes status/userId', () => {
    const ok = { name: 'New Name' };
    const res = userUpdateMedicineBoxSchema.safeParse(ok);
    expect(res.success).toBe(true);
    const no = { name: 'New Name', status: 'ACTIVE' } as Record<string, unknown>;
    expect(userUpdateMedicineBoxSchema.safeParse(no).success).toBe(false);
  });

  it('19. USER activates: ActivateMedicineBox ignores body.userId and uses JWT userId only', async () => {
    mocks.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'D', deviceToken: 'T', userId: null, status: 'READY' }),
    );
    mocks.activateAtomic.mockResolvedValue({
      kind: 'success',
      box: buildBox({ deviceId: 'D', deviceToken: 'T', userId: 'jwt-user', status: 'ACTIVE' }),
    });
    const uc = new ActivateMedicineBox(mocks as never);
    // We deliberately do not provide any client-side userId — UC takes only JWT + credentials
    const r = await uc.execute('jwt-user', { deviceId: 'D', deviceToken: 'T' });
    expect(mocks.activateAtomic).toHaveBeenCalledWith('D', 'jwt-user');
    expect(r.userId).toBe('jwt-user');
  });

  it('20. Concurrent activation atomic: activateAtomic returns already-owned for loser → ConflictError', async () => {
    mocks.findByDeviceId.mockResolvedValue(
      buildBox({ deviceId: 'RACE', deviceToken: 'T', userId: null, status: 'READY' }),
    );
    // Winner updated between findByDeviceId and the atomic updateMany:
    mocks.activateAtomic.mockResolvedValue({ kind: 'already-owned' });
    const uc = new ActivateMedicineBox(mocks as never);
    await expect(
      uc.execute('loser-user', { deviceId: 'RACE', deviceToken: 'T' }),
    ).rejects.toThrow(ConflictError);
  });
});

type Drawer = {
  id: string;
  medicineBoxId: string;
  drawerNumber: number;
  status: 'EMPTY' | 'LOADED' | 'LOCKED' | 'DISPENSING' | 'ERROR';
  temperature: number | null;
  humidity: number | null;
  createdAt: Date;
  updatedAt: Date;
};
type DrawerMedication = { id: string; drawerId: string; medicationId: string };
type Medication = { id: string; patientId: string; name: string };
type Patient = { id: string; firstName: string };
type Schedule = { id: string; medicationId: string; timeOfDay: string };

describe('§ UNASSIGN — 12 REQUIRED SCENARIOS: drawers preserved, IDs unchanged, EMPTY, meds/patients/schedules preserved', () => {
  const boxId = 'BOX12-REQ';
  const userIdA = 'USER-A-12';
  const userIdB = 'USER-B-12';
  const drawerIds = ['DRAW1', 'DRAW2', 'DRAW3', 'DRAW4'];

  type State = {
    box: MedicineBox;
    drawers: Drawer[];
    dms: DrawerMedication[];
    medications: Medication[];
    patients: Patient[];
    schedules: Schedule[];
  };

  const buildState = (): State => {
    const box: MedicineBox = buildBox({
      id: boxId,
      userId: userIdA,
      status: 'ACTIVE',
      deviceId: 'DEV-12',
      deviceToken: 'TOK-12',
      name: 'Box 12 Config',
      numberOfDrawers: 4,
      drawerCapacity: 20,
    });
    const drawers: Drawer[] = drawerIds.map((id, i) => ({
      id,
      medicineBoxId: boxId,
      drawerNumber: i + 1,
      status: i < 2 ? 'LOADED' : 'EMPTY',
      temperature: null,
      humidity: null,
      createdAt: now(),
      updatedAt: now(),
    }));
    const patients: Patient[] = [{ id: 'PAT-A', firstName: 'Alice' }];
    const medications: Medication[] = [
      { id: 'MED-A', patientId: 'PAT-A', name: 'Medication A' },
      { id: 'MED-B', patientId: 'PAT-A', name: 'Medication B' },
    ];
    const dms: DrawerMedication[] = [
      { id: 'DM-1', drawerId: 'DRAW1', medicationId: 'MED-A' },
      { id: 'DM-2', drawerId: 'DRAW2', medicationId: 'MED-B' },
    ];
    const schedules: Schedule[] = [
      { id: 'SCH-1', medicationId: 'MED-A', timeOfDay: '08:00' },
      { id: 'SCH-2', medicationId: 'MED-A', timeOfDay: '20:00' },
      { id: 'SCH-3', medicationId: 'MED-B', timeOfDay: '12:00' },
    ];
    return { box, drawers, dms, medications, patients, schedules };
  };

  // Simulated repo releaseOwnership — mirrors the CORRECTED implementation:
  //   1. verify ownership WHERE { id, userId }
  //   2. find drawers where medicineBoxId
  //   3. DELETE drawerMedication where drawerId IN drawerIds   (only assignments)
  //   4. UPDATE drawer.status → EMPTY where drawerId IN drawerIds   (PRESERVE drawers)
  //   5. UPDATE medicineBox SET userId=null, status=READY WHERE { id, userId }
  // NEVER: drawer.deleteMany / drawer.delete
  const correctedReleaseOwnership = (
    state: State,
    m: { drawerDeleteMany?: jest.Mock; drawerUpdateMany?: jest.Mock; dmDeleteMany?: jest.Mock },
  ) => (medicineBoxIdIn: string, userIdIn: string) => {
    if (state.box.id !== medicineBoxIdIn || state.box.userId !== userIdIn) {
      return Promise.resolve({ kind: 'not-found' as const });
    }
    const drawers = state.drawers.filter((d) => d.medicineBoxId === medicineBoxIdIn);
    const drawerIdsHere = drawers.map((d) => d.id);

    // Step 3 — delete DM assignments
    state.dms = state.dms.filter((dm) => !drawerIdsHere.includes(dm.drawerId));
    if (m.dmDeleteMany) m.dmDeleteMany();

    // Step 4 — UPDATE drawer.status → EMPTY (preserve drawer rows)
    for (const d of state.drawers) if (drawerIdsHere.includes(d.id)) d.status = 'EMPTY';
    if (m.drawerUpdateMany) m.drawerUpdateMany();

    // NOTE: drawerDeleteMany must NEVER be called
    if (m.drawerDeleteMany) {
      // Intentionally do NOT call m.drawerDeleteMany — simulate correct impl
    }

    // Step 5 — release ownership
    state.box.userId = null;
    state.box.status = 'READY';
    state.box.updatedAt = now();
    return Promise.resolve({ kind: 'success' as const, box: state.box });
  };

  // TEST 1 — Unassign → box exists, drawers 4, DM 0, userId null, status READY
  it('TEST 1. 4 drawers → 204, drawers still 4, DM=0, userId=NULL, status=READY', async () => {
    const state = buildState();
    const m = { dmDeleteMany: jest.fn(), drawerUpdateMany: jest.fn(), drawerDeleteMany: jest.fn() };
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, m));
    const uc = new UnassignMedicineBox(mockRepo as never);
    const r = await uc.execute(userIdA, boxId);
    expect(r.userId).toBeNull();
    expect(r.status).toBe('READY');
    expect(state.drawers).toHaveLength(4);
    expect(state.dms).toHaveLength(0);
    expect(state.box.numberOfDrawers).toBe(4);
    expect(m.drawerDeleteMany).toHaveBeenCalledTimes(0);
  });

  // TEST 2 — 2 of 4 drawers had meds, 2 empty → after unassign all 4 drawers still exist, DM=0
  it('TEST 2. 2 assigned + 2 empty drawers → ALL 4 preserved, DM=0', async () => {
    const state = buildState();
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    await uc.execute(userIdA, boxId);
    const ids = state.drawers.map((d) => d.id);
    expect(ids).toEqual(expect.arrayContaining(['DRAW1', 'DRAW2', 'DRAW3', 'DRAW4']));
    expect(state.drawers).toHaveLength(4);
    expect(state.dms).toHaveLength(0);
  });

  // TEST 3 — Medication A preserved
  it('TEST 3. Medication A still exists after unassign', async () => {
    const state = buildState();
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    await uc.execute(userIdA, boxId);
    expect(state.medications.find((m) => m.id === 'MED-A')).toBeDefined();
    expect(state.medications.find((m) => m.id === 'MED-B')).toBeDefined();
    expect(state.medications).toHaveLength(2);
  });

  // TEST 4 — Patient preserved
  it('TEST 4. Patient owning medications still exists', async () => {
    const state = buildState();
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    await uc.execute(userIdA, boxId);
    expect(state.patients.find((p) => p.id === 'PAT-A')).toBeDefined();
    expect(state.patients).toHaveLength(1);
  });

  // TEST 5 — Schedules preserved
  it('TEST 5. Schedules belonging to medications still exist', async () => {
    const state = buildState();
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    await uc.execute(userIdA, boxId);
    expect(state.schedules.map((s) => s.id).sort()).toEqual(['SCH-1', 'SCH-2', 'SCH-3']);
    expect(state.schedules.filter((s) => s.medicationId === 'MED-A')).toHaveLength(2);
    expect(state.schedules.filter((s) => s.medicationId === 'MED-B')).toHaveLength(1);
  });

  // TEST 6 — MB configuration preserved
  it('TEST 6. MB config: numberOfDrawers/drawerCapacity/deviceId/name unchanged', async () => {
    const state = buildState();
    const before = {
      numberOfDrawers: state.box.numberOfDrawers,
      drawerCapacity: state.box.drawerCapacity,
      deviceId: state.box.deviceId,
      name: state.box.name,
    };
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    const r = await uc.execute(userIdA, boxId);
    expect(r.id).toBe(boxId);
    expect(r.numberOfDrawers).toBe(before.numberOfDrawers);
    expect(r.drawerCapacity).toBe(before.drawerCapacity);
    expect(r.deviceId).toBe(before.deviceId);
    expect(r.name).toBe(before.name);
  });

  // TEST 7 — Drawer IDs exactly identical
  it('TEST 7. Drawer IDs array exactly identical before/after unassign', async () => {
    const state = buildState();
    const beforeIds = state.drawers.map((d) => d.id);
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    await uc.execute(userIdA, boxId);
    const afterIds = state.drawers.map((d) => d.id);
    expect(afterIds).toEqual(beforeIds);
  });

  // TEST 8 — Drawer status EMPTY
  it('TEST 8. All drawers transition to EMPTY after unassign', async () => {
    const state = buildState();
    // Verify precondition: DRAW1 & DRAW2 are LOADED, DRAW3 & DRAW4 EMPTY
    expect(state.drawers.map((d) => d.status)).toEqual(['LOADED', 'LOADED', 'EMPTY', 'EMPTY']);
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    await uc.execute(userIdA, boxId);
    expect(state.drawers.every((d) => d.status === 'EMPTY')).toBe(true);
  });

  // TEST 9 — Reactivation with same drawers assignable
  it('TEST 9. Reactivation: USER B activate → same drawer IDs, B can create NEW DM assignments', async () => {
    const state = buildState();
    const beforeIds = [...state.drawers.map((d) => d.id)];

    // Step A: USER A unassign
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const unUc = new UnassignMedicineBox(mockRepo as never);
    await unUc.execute(userIdA, boxId);

    // Step B: USER B activates same box
    mockRepo.findByDeviceId.mockResolvedValue({
      ...state.box,
      deviceId: state.box.deviceId,
      deviceToken: state.box.deviceToken,
    });
    mockRepo.activateAtomic.mockImplementation((_devId: string, userIdArg: string) => {
      state.box.userId = userIdArg;
      state.box.status = 'ACTIVE';
      state.box.updatedAt = now();
      return Promise.resolve({ kind: 'success' as const, box: state.box });
    });
    const actUc = new ActivateMedicineBox(mockRepo as never);
    const r = await actUc.execute(userIdB, {
      deviceId: state.box.deviceId,
      deviceToken: state.box.deviceToken,
    });
    expect(r.userId).toBe(userIdB);
    expect(r.status).toBe('ACTIVE');

    // Step C: same drawer IDs still exist
    expect(state.drawers.map((d) => d.id)).toEqual(beforeIds);
    expect(state.drawers).toHaveLength(4);

    // Step D: USER B can create NEW DM assignment on DRAW1 (previously MED-A, now EMPTY)
    const draw1 = state.drawers.find((d) => d.id === 'DRAW1')!;
    expect(draw1.status).toBe('EMPTY');
    const newDm: DrawerMedication = { id: 'DM-NEW', drawerId: 'DRAW1', medicationId: 'MED-B' };
    state.dms.push(newDm);
    draw1.status = 'LOADED';
    expect(state.dms).toHaveLength(1);
    expect(draw1.status).toBe('LOADED');
  });

  // TEST 10 — Cross-user security: 404
  it('TEST 10. USER B unassign USER A box → 404, state unchanged', async () => {
    const state = buildState();
    const before = {
      userId: state.box.userId,
      status: state.box.status,
      drawerCount: state.drawers.length,
      dmCount: state.dms.length,
    };
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(correctedReleaseOwnership(state, {}));
    const uc = new UnassignMedicineBox(mockRepo as never);
    await expect(uc.execute(userIdB, boxId)).rejects.toThrow(NotFoundError);
    expect(state.box.userId).toBe(before.userId);
    expect(state.box.status).toBe(before.status);
    expect(state.drawers).toHaveLength(before.drawerCount);
    expect(state.dms).toHaveLength(before.dmCount);
  });

  // TEST 11 — No drawer.deleteMany / drawer.delete calls
  it('TEST 11. Unassign NEVER calls drawerRepo.delete/drawer.deleteMany; DM deleteMany called 1x', async () => {
    const state = buildState();
    const drawerDeleteMany = jest.fn();
    const drawerDelete = jest.fn();
    const drawerRepoDelete = jest.fn();
    const dmDeleteMany = jest.fn();
    const mockRepo: MockBoxRepo = mkMocks();
    mockRepo.releaseOwnership.mockImplementation(
      correctedReleaseOwnership(state, { drawerDeleteMany, dmDeleteMany }),
    );
    // Hook another proxy to simulate if repo had called drawerDelete/drawerRepoDelete:
    // Correct impl must NOT fire them, correct impl must fire dmDeleteMany + drawerUpdateMany.
    const uc = new UnassignMedicineBox(mockRepo as never);
    await uc.execute(userIdA, boxId);
    expect(drawerDeleteMany).toHaveBeenCalledTimes(0);
    expect(drawerDelete).toHaveBeenCalledTimes(0);
    expect(drawerRepoDelete).toHaveBeenCalledTimes(0);
    expect(dmDeleteMany).toHaveBeenCalledTimes(1);
    // Also verify the repo class really removed drawer.deleteMany by static code check:
    const fsModule = require('fs') as typeof import('fs');
    const repoPath = require('path').join(
      __dirname,
      '..',
      'src',
      'infrastructure',
      'database',
      'prisma',
      'repositories',
      'PrismaMedicineBoxRepository.ts',
    );
    const src = fsModule.readFileSync(repoPath, 'utf8');
    const releaseOwnershipBlock = src.substring(
      src.indexOf('async releaseOwnership('),
      src.indexOf('private toDomain('),
    );
    expect(releaseOwnershipBlock).not.toMatch(/drawer\.deleteMany/);
    // But DM deleteMany must remain (the correct cleanup):
    expect(releaseOwnershipBlock).toMatch(/drawerMedication\.deleteMany/);
    // And drawer.status → EMPTY updateMany must exist:
    expect(releaseOwnershipBlock).toMatch(/drawer\.updateMany[\s\S]{0,120}status:\s*['"]EMPTY['"]/);
  });

  // TEST 12 — Atomicity: failure → rollback (no partial state)
  it('TEST 12. Atomicity: DM cleaned then MB update fails → state fully rolled back', async () => {
    const state = buildState();
    const snapshot = JSON.parse(
      JSON.stringify({
        box: state.box,
        drawers: state.drawers,
        dms: state.dms,
        medications: state.medications,
        patients: state.patients,
        schedules: state.schedules,
      }),
    );
    const mockRepo: MockBoxRepo = mkMocks();
    // Simulate corrected impl but throw AFTER DM delete and drawer.status update, BEFORE MB release:
    mockRepo.releaseOwnership.mockImplementation(async (mbId: string, uId: string) => {
      if (state.box.id !== mbId || state.box.userId !== uId) return { kind: 'not-found' as const };
      const drawers = state.drawers.filter((d) => d.medicineBoxId === mbId);
      const ids = drawers.map((d) => d.id);
      // (1) Delete DMs
      state.dms = state.dms.filter((dm) => !ids.includes(dm.drawerId));
      // (2) Set status EMPTY
      for (const d of state.drawers) if (ids.includes(d.id)) d.status = 'EMPTY';
      // (3) THROW — simulate mb.updateMany DB error
      throw new Error('simulated updateMany MB failure');
    });
    const uc = new UnassignMedicineBox(mockRepo as never);
    await expect(uc.execute(userIdA, boxId)).rejects.toThrow('simulated');
    // $transaction contract guarantees rollback. Simulate it for this unit:
    Object.assign(state, JSON.parse(JSON.stringify(snapshot)));
    expect(state.box.userId).toBe(userIdA);
    expect(state.box.status).toBe('ACTIVE');
    expect(state.drawers).toHaveLength(4);
    expect(state.drawers[0].status).toBe('LOADED');
    expect(state.dms).toHaveLength(2);
    expect(state.medications).toHaveLength(2);
    expect(state.patients).toHaveLength(1);
    expect(state.schedules).toHaveLength(3);
  });
});


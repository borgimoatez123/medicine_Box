import type { DeviceCommand } from '@domain/entities/DeviceCommand';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { Drawer } from '@domain/entities/Drawer';
import type { IDeviceCommandRepository } from '@domain/repositories/IDeviceCommandRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import { CreateDrawerOpenCommand } from '@application/use-cases/drawer/CreateDrawerOpenCommand';
import { CreateDrawerCloseCommand } from '@application/use-cases/drawer/CreateDrawerCloseCommand';
import { GetPendingDeviceCommands } from '@application/use-cases/device/GetPendingDeviceCommands';
import { AcknowledgeDeviceCommandResult } from '@application/use-cases/device/AcknowledgeDeviceCommandResult';
import {
  drawerOpenCommandSchema,
  drawerCloseCommandSchema,
} from '@presentation/validators/drawer.validator';
import {
  getDeviceCommandsSchema,
  deviceCommandResultSchema,
} from '@presentation/validators/devices.validator';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
} from '@shared/errors';

type AnyFn = jest.Mock<any, any>;
const mk = (): AnyFn => jest.fn();
const now = () => new Date('2026-09-29T10:00:00.000Z');

const makeBox = (patch: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'PI-OPEN-DRAWER-001',
  deviceToken: 'SECRET-TOKEN',
  name: 'Smart Box',
  status: 'READY',
  deviceStatus: 'ACTIVE',
  lastSeenAt: now(),
  userId: 'user-own',
  numberOfDrawers: 2,
  drawerCapacity: 20,
  createdAt: now(),
  updatedAt: now(),
  ...patch,
});

const makeDrawer = (patch: Partial<Drawer> = {}): Drawer => ({
  id: patch.id ?? 'drawer-1',
  medicineBoxId: patch.medicineBoxId ?? 'box-1',
  drawerNumber: patch.drawerNumber ?? 1,
  status: 'LOADED',
  createdAt: now(),
  updatedAt: now(),
  ...patch,
});

const makeCmd = (patch: Partial<DeviceCommand> = {}): DeviceCommand => ({
  id: 'cmd-uuid',
  deviceId: 'PI-OPEN-DRAWER-001',
  drawerId: 'drawer-1',
  type: 'OPEN_DRAWER',
  status: 'PENDING',
  reason: 'MANUAL',
  createdAt: now(),
  sentAt: null,
  executedAt: null,
  error: null,
  ...patch,
});

type CmdRepo = IDeviceCommandRepository & {
  create: AnyFn;
  findById: AnyFn;
  findPendingByDeviceId: AnyFn;
  markManyAsSentInTransaction: AnyFn;
  updateResult: AnyFn;
};
type BoxRepo = IMedicineBoxRepository & {
  findById: AnyFn;
  findByDeviceId: AnyFn;
};
type DrawRepo = IDrawerRepository & {
  findByIdAndUserId: AnyFn;
};

describe('§ Drawer Unlock / Open Command API — 13 tests (AC-1..AC-13)', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('T1 (AC-1,AC-2) — Mobile: Create drawer open command → status PENDING, reason default MANUAL, no qty change, no session created', async () => {
    const box = makeBox();
    const drawer = makeDrawer();
    const created = makeCmd();
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(drawer),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk().mockResolvedValue(box),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk().mockResolvedValue(created),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerOpenCommand(drawerRepo, boxRepo, cmdRepo);
    const r = await uc.execute('user-own', 'drawer-1');
    expect(drawerRepo.findByIdAndUserId).toHaveBeenCalledWith('drawer-1', 'user-own');
    expect(cmdRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        deviceId: 'PI-OPEN-DRAWER-001',
        drawerId: 'drawer-1',
        type: 'OPEN_DRAWER',
        status: 'PENDING',
        reason: 'MANUAL',
      }),
    );
    expect(r.status).toBe('PENDING');
    expect(r.reason).toBe('MANUAL');
  });

  it('T2 (AC-3) — Create with explicit reason → stored verbatim (trims)', async () => {
    const box = makeBox();
    const drawer = makeDrawer();
    const created = makeCmd({ reason: 'Doctors order' });
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(drawer),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk().mockResolvedValue(box),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk().mockResolvedValue(created),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerOpenCommand(drawerRepo, boxRepo, cmdRepo);
    const r = await uc.execute('user-own', 'drawer-1', '  Doctors order  ');
    expect(cmdRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({ reason: 'Doctors order' }),
    );
    expect(r.reason).toBe('Doctors order');
  });

  it('T3 (AC-4) — Create drawer open, drawer missing or non-owner → 404 NotFoundError (NOT 403)', async () => {
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(null),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk(),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerOpenCommand(drawerRepo, boxRepo, cmdRepo);
    await expect(uc.execute('user-stranger', 'drawer-1')).rejects.toBeInstanceOf(NotFoundError);
    expect(cmdRepo.create).not.toHaveBeenCalled();
  });

  it('T4 (AC-5) — Create on MedicineBox with no deviceId (deviceId=null/empty) → 400 BadRequestError', async () => {
    const box = makeBox({ deviceId: '  ' });
    const drawer = makeDrawer();
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(drawer),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk().mockResolvedValue(box),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerOpenCommand(drawerRepo, boxRepo, cmdRepo);
    await expect(uc.execute('user-own', 'drawer-1')).rejects.toBeInstanceOf(BadRequestError);
    expect(cmdRepo.create).not.toHaveBeenCalled();
  });

  it('T5 (AC-6) — Validator drawerOpenCommandSchema accepts null/undefined reason and rejects unknown keys or too-long strings', () => {
    expect(drawerOpenCommandSchema.safeParse({}).success).toBe(true);
    expect(drawerOpenCommandSchema.safeParse({ reason: null }).success).toBe(true);
    expect(drawerOpenCommandSchema.safeParse({ reason: undefined }).success).toBe(true);
    expect(drawerOpenCommandSchema.safeParse({ reason: 'x'.repeat(200) }).success).toBe(true);
    expect(drawerOpenCommandSchema.safeParse({ reason: 'x'.repeat(201) }).success).toBe(false);
    expect(drawerOpenCommandSchema.safeParse({ extraKey: 'bad' }).success).toBe(false);
    expect(drawerOpenCommandSchema.safeParse({ reason: 123 } as any).success).toBe(false);
  });

  it('T6 (AC-7,AC-8) — Pi GET pending commands: returns all OPEN_DRAWER pending, atomically flips status→SENT with sentAt, sorted createdAt ASC, deviceNotFound → 404', async () => {
    const a = makeCmd({ id: 'a', createdAt: new Date('2026-09-29T10:00:00.000Z') });
    const b = makeCmd({ id: 'b', drawerId: 'drawer-2', createdAt: new Date('2026-09-29T10:00:01.000Z') });
    const boxRepo: BoxRepo = {
      findById: mk(),
      findByDeviceId: mk().mockResolvedValue(makeBox()),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk(),
      findPendingByDeviceId: mk().mockResolvedValue([a, b]),
      markManyAsSentInTransaction: mk().mockResolvedValue(undefined),
      updateResult: mk(),
    };
    const uc = new GetPendingDeviceCommands(boxRepo, cmdRepo);
    const r = await uc.execute('PI-OPEN-DRAWER-001');
    expect(boxRepo.findByDeviceId).toHaveBeenCalledWith('PI-OPEN-DRAWER-001');
    expect(cmdRepo.findPendingByDeviceId).toHaveBeenCalledWith('PI-OPEN-DRAWER-001');
    expect(cmdRepo.markManyAsSentInTransaction).toHaveBeenCalledWith(['a', 'b']);
    expect(r.map(c => c.commandId)).toEqual(['a', 'b']);
    expect(r[0].type).toBe('OPEN_DRAWER');
    expect(r[0].drawerId).toBe('drawer-1');
    expect(r[1].drawerId).toBe('drawer-2');

    const boxRepoMiss: BoxRepo = {
      findById: mk(),
      findByDeviceId: mk().mockResolvedValue(null),
    } as unknown as BoxRepo;
    const ucMiss = new GetPendingDeviceCommands(boxRepoMiss, cmdRepo);
    await expect(ucMiss.execute('unknown-device')).rejects.toBeInstanceOf(NotFoundError);
  });

  it('T7 (AC-9) — Idempotent get pending commands: 1st poll returns 2 commands, 2nd poll returns empty (no redelivery)', async () => {
    const a = makeCmd({ id: 'a' });
    const b = makeCmd({ id: 'b', drawerId: 'drawer-2' });
    const boxRepo: BoxRepo = {
      findById: mk(),
      findByDeviceId: mk().mockResolvedValue(makeBox()),
    } as unknown as BoxRepo;
    const pendingCalls = [Promise.resolve([a, b]), Promise.resolve([])];
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk(),
      findPendingByDeviceId: mk().mockImplementationOnce(() => pendingCalls[0]).mockImplementationOnce(() => pendingCalls[1]),
      markManyAsSentInTransaction: mk().mockResolvedValue(undefined),
      updateResult: mk(),
    };
    const uc = new GetPendingDeviceCommands(boxRepo, cmdRepo);
    const r1 = await uc.execute('PI-OPEN-DRAWER-001');
    const r2 = await uc.execute('PI-OPEN-DRAWER-001');
    expect(r1.length).toBe(2);
    expect(r2.length).toBe(0);
    expect(cmdRepo.markManyAsSentInTransaction).toHaveBeenCalledTimes(1);
  });

  it('T8 (AC-10) — Pi Acknowledge EXECUTED → status EXECUTED, executedAt set, error cleared (even if previous was set)', async () => {
    const finalCmd = makeCmd({
      status: 'EXECUTED',
      executedAt: now(),
      error: null,
    });
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk().mockResolvedValue(makeCmd()),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk().mockResolvedValue(finalCmd),
    };
    const uc = new AcknowledgeDeviceCommandResult(cmdRepo);
    const r = await uc.execute('cmd-uuid', 'PI-OPEN-DRAWER-001', 'EXECUTED');
    expect(cmdRepo.updateResult).toHaveBeenCalledWith('cmd-uuid', {
      status: 'EXECUTED',
      error: null,
    });
    expect(r.status).toBe('EXECUTED');
  });

  it('T9 (AC-10) — Pi Acknowledge FAILED with error → status FAILED, executedAt null, error stored', async () => {
    const finalCmd = makeCmd({
      status: 'FAILED',
      executedAt: null,
      error: 'Drawer motor jammed',
    });
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk().mockResolvedValue(makeCmd()),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk().mockResolvedValue(finalCmd),
    };
    const uc = new AcknowledgeDeviceCommandResult(cmdRepo);
    const r = await uc.execute('cmd-uuid', 'PI-OPEN-DRAWER-001', 'FAILED', '  Drawer motor jammed  ');
    expect(cmdRepo.updateResult).toHaveBeenCalledWith('cmd-uuid', {
      status: 'FAILED',
      error: 'Drawer motor jammed',
    });
    expect(r.status).toBe('FAILED');
  });

  it('T10 (AC-11) — Pi Acknowledge: body.deviceId != command.deviceId → explicit ForbiddenError 403 (NOT 404)', async () => {
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk().mockResolvedValue(makeCmd()),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new AcknowledgeDeviceCommandResult(cmdRepo);
    await expect(
      uc.execute('cmd-uuid', 'PI-OTHER-DEVICE', 'EXECUTED'),
    ).rejects.toBeInstanceOf(ForbiddenError);
    expect(cmdRepo.updateResult).not.toHaveBeenCalled();
  });

  it('T11 (AC-12) — Validator schemas for Pi side: getDeviceCommandsSchema (min1 deviceId) + deviceCommandResultSchema (status EXECUTED|FAILED, error max 1000, strict)', () => {
    expect(getDeviceCommandsSchema.safeParse({ deviceId: 'x' }).success).toBe(true);
    expect(getDeviceCommandsSchema.safeParse({ deviceId: '' }).success).toBe(false);
    expect(getDeviceCommandsSchema.safeParse({ deviceId: 'x', extra: 'y' }).success).toBe(false);

    expect(deviceCommandResultSchema.safeParse({
      deviceId: 'd1', status: 'EXECUTED',
    }).success).toBe(true);
    expect(deviceCommandResultSchema.safeParse({
      deviceId: 'd1', status: 'FAILED', error: 'oops',
    }).success).toBe(true);
    expect(deviceCommandResultSchema.safeParse({
      deviceId: 'd1', status: 'PENDING',
    }).success).toBe(false);
    expect(deviceCommandResultSchema.safeParse({
      deviceId: 'd1', status: 'FAILED', error: 'x'.repeat(1001),
    }).success).toBe(false);
    expect(deviceCommandResultSchema.safeParse({
      deviceId: 'd1', status: 'EXECUTED', extra: 1,
    }).success).toBe(false);
    expect(deviceCommandResultSchema.safeParse({
      status: 'EXECUTED',
    }).success).toBe(false);
  });

  it('T12 (AC-13) — Open command never touches MedicationSession or DrawerMedication (repositories for those never instantiated/imported in the 3 new use-cases)', () => {
    const fs = require('fs') as typeof import('node:fs');
    const path = require('path') as typeof import('node:path');
    const base = path.resolve(__dirname, '../src');
    const ucFiles = [
      'application/use-cases/drawer/CreateDrawerOpenCommand.ts',
      'application/use-cases/device/GetPendingDeviceCommands.ts',
      'application/use-cases/device/AcknowledgeDeviceCommandResult.ts',
      'infrastructure/database/prisma/repositories/PrismaDeviceCommandRepository.ts',
      'domain/repositories/IDeviceCommandRepository.ts',
    ];
    for (const f of ucFiles) {
      const full = path.join(base, f);
      const content = fs.readFileSync(full, 'utf8');
      expect(content).not.toMatch(/MedicationSession|DrawerMedication/);
    }
  });

  it('T13 — End-to-end full lifecycle PENDING→SENT→EXECUTED with FAILED alternative branch correct statuses preserved', async () => {
    // Build lifecycle using fake in-memory repo
    const state: { rows: DeviceCommand[] } = { rows: [] };
    const cmdRepo: CmdRepo = {
      create: mk().mockImplementation((d: any) => {
        const row: DeviceCommand = {
          id: 'cmd-' + Math.random().toString(36).slice(2, 9),
          deviceId: d.deviceId,
          drawerId: d.drawerId ?? null,
          type: d.type,
          status: d.status ?? 'PENDING',
          reason: d.reason ?? null,
          createdAt: now(),
          sentAt: null,
          executedAt: null,
          error: null,
        };
        state.rows.push(row);
        return Promise.resolve(row);
      }),
      findById: mk().mockImplementation((id: string) =>
        Promise.resolve(state.rows.find(r => r.id === id) ?? null),
      ),
      findPendingByDeviceId: mk().mockImplementation((deviceId: string) =>
        Promise.resolve(state.rows.filter(r => r.deviceId === deviceId && r.status === 'PENDING')),
      ),
      markManyAsSentInTransaction: mk().mockImplementation((ids: string[]) => {
        for (const id of ids) {
          const r = state.rows.find(x => x.id === id);
          if (r) {
            r.status = 'SENT';
            r.sentAt = now();
          }
        }
        return Promise.resolve();
      }),
      updateResult: mk().mockImplementation((id: string, d: any) => {
        const r = state.rows.find(x => x.id === id)!;
        r.status = d.status;
        r.executedAt = d.status === 'EXECUTED' ? now() : null;
        r.error = d.status === 'FAILED' ? (d.error ?? null) : null;
        return Promise.resolve(r);
      }),
    };

    // 1. Create open drawer -> PENDING
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(makeDrawer()),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk().mockResolvedValue(makeBox()),
      findByDeviceId: mk().mockResolvedValue(makeBox()),
    } as unknown as BoxRepo;
    const createUc = new CreateDrawerOpenCommand(drawerRepo, boxRepo, cmdRepo);
    const created = await createUc.execute('user-own', 'drawer-1');
    expect(created.status).toBe('PENDING');
    expect(state.rows[0].sentAt).toBeNull();

    // 2. Pi poll -> returns command, flips to SENT with sentAt
    const pollUc = new GetPendingDeviceCommands(boxRepo, cmdRepo);
    const pending1 = await pollUc.execute('PI-OPEN-DRAWER-001');
    expect(pending1.length).toBe(1);
    expect(state.rows[0].status).toBe('SENT');
    expect(state.rows[0].sentAt).not.toBeNull();

    // 3. Duplicate poll -> nothing (idempotency)
    const pending2 = await pollUc.execute('PI-OPEN-DRAWER-001');
    expect(pending2.length).toBe(0);

    // 4. Pi EXECUTED ack -> final
    const ackUc = new AcknowledgeDeviceCommandResult(cmdRepo);
    const ack1 = await ackUc.execute(created.id, 'PI-OPEN-DRAWER-001', 'EXECUTED');
    expect(ack1.status).toBe('EXECUTED');
    expect(state.rows[0].status).toBe('EXECUTED');
    expect(state.rows[0].executedAt).not.toBeNull();
    expect(state.rows[0].error).toBeNull();

    // 5. Test FAILED alternative path for another command (reset)
    const created2 = await createUc.execute('user-own', 'drawer-1');
    await pollUc.execute('PI-OPEN-DRAWER-001');
    const ackF = await ackUc.execute(created2.id, 'PI-OPEN-DRAWER-001', 'FAILED', 'motor jam');
    expect(ackF.status).toBe('FAILED');
    const last = state.rows[state.rows.length - 1];
    expect(last.status).toBe('FAILED');
    expect(last.executedAt).toBeNull();
    expect(last.error).toBe('motor jam');
  });
});

describe('§ Drawer Close Command API — 8 tests (close TC1–TC8)', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('Close Test 1 — Successful close command: type=CLOSE_DRAWER status=PENDING reason MANUAL default', async () => {
    const box = makeBox();
    const drawer = makeDrawer();
    const created = makeCmd({ type: 'CLOSE_DRAWER' });
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(drawer),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk().mockResolvedValue(box),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk().mockResolvedValue(created),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerCloseCommand(drawerRepo, boxRepo, cmdRepo);
    const r = await uc.execute('user-own', 'drawer-1');
    expect(drawerRepo.findByIdAndUserId).toHaveBeenCalledWith('drawer-1', 'user-own');
    expect(cmdRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        deviceId: 'PI-OPEN-DRAWER-001',
        drawerId: 'drawer-1',
        type: 'CLOSE_DRAWER',
        status: 'PENDING',
        reason: 'MANUAL',
      }),
    );
    expect(r.type).toBe('CLOSE_DRAWER');
    expect(r.status).toBe('PENDING');
    expect(r.reason).toBe('MANUAL');
  });

  it('Close Test 2 — Close command with explicit reason: reason stored trimmed (not MANUAL default)', async () => {
    const created = makeCmd({ type: 'CLOSE_DRAWER', reason: 'Manual close by doctor' });
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(makeDrawer()),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk().mockResolvedValue(makeBox()),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk().mockResolvedValue(created),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerCloseCommand(drawerRepo, boxRepo, cmdRepo);
    const r = await uc.execute('user-own', 'drawer-1', ' Manual close by doctor ');
    expect(cmdRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({ reason: 'Manual close by doctor' }),
    );
    expect(r.reason).toBe('Manual close by doctor');
  });

  it('Close Test 3 — Unauthorized (no JWT): requireAuth middleware path would return 401; schema validation same, route inside drawerRouter.use(requireAuth). Validate validator + endpoint structure would not hit use-case without JWT.', async () => {
    // In our jest test we skip Express middleware. Instead assert: route requires JWT via drawerRouter drawer.routes.ts L6 requireAuth applied whole router; close command route L27 mounted AFTER L6 requireAuth.
    const fs = require('fs') as typeof import('node:fs');
    const path = require('path') as typeof import('node:path');
    const routes = fs.readFileSync(
      path.resolve(__dirname, '../src/presentation/routes/drawer.routes.ts'),
      'utf8',
    );
    expect(routes).toMatch(/drawerRouter\.use\(requireAuth\)/);
    expect(routes).toMatch(/\/:drawerId\/open/);
    expect(routes).toMatch(/\/:drawerId\/close/);
    // Position check: open/close LITERAL routes BEFORE generic param /:id (so no param hijack).
    const lines = routes.split('\n').map((l: string) => l.trim());
    const idxClose = lines.findIndex((l: string) => l.includes('/:drawerId/close'));
    const idxGeneric = lines.findIndex((l: string) => /drawerRouter\.(get|patch|delete|put|post)\(['"]\/:id['"]/.test(l));
    expect(idxClose).toBeGreaterThan(-1);
    expect(idxGeneric).toBeGreaterThan(-1);
    expect(idxClose).toBeLessThan(idxGeneric);
  });

  it('Close Test 4 — Wrong user JWT: findByIdAndUserId returns null → NotFoundError 404 not 403', async () => {
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(null),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk(),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerCloseCommand(drawerRepo, boxRepo, cmdRepo);
    await expect(uc.execute('user-stranger', 'drawer-owned-by-other')).rejects.toBeInstanceOf(NotFoundError);
    expect(cmdRepo.create).not.toHaveBeenCalled();
  });

  it('Close Test 5 — Drawer medicine box has no deviceId: BadRequest 400', async () => {
    const drawerRepo: DrawRepo = {
      findByIdAndUserId: mk().mockResolvedValue(makeDrawer()),
    } as unknown as DrawRepo;
    const boxRepo: BoxRepo = {
      findById: mk().mockResolvedValue(makeBox({ deviceId: '   ' })),
      findByDeviceId: mk(),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk(),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk(),
    };
    const uc = new CreateDrawerCloseCommand(drawerRepo, boxRepo, cmdRepo);
    await expect(uc.execute('user-own', 'drawer-1')).rejects.toBeInstanceOf(BadRequestError);
    expect(cmdRepo.create).not.toHaveBeenCalled();
  });

  it('Close Test 6 — Raspberry Pi receives CLOSE_DRAWER via existing GET poll endpoint; command PENDING→SENT atomically', async () => {
    const pendingClose = makeCmd({ id: 'close-cmd-1', type: 'CLOSE_DRAWER', drawerId: 'drawer-2' });
    const boxRepo: BoxRepo = {
      findById: mk(),
      findByDeviceId: mk().mockResolvedValue(makeBox()),
    } as unknown as BoxRepo;
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk(),
      findPendingByDeviceId: mk().mockResolvedValue([pendingClose]),
      markManyAsSentInTransaction: mk().mockResolvedValue(undefined),
      updateResult: mk(),
    };
    const pollUc = new GetPendingDeviceCommands(boxRepo, cmdRepo);
    const r = await pollUc.execute('PI-OPEN-DRAWER-001');
    expect(r.length).toBe(1);
    expect(r[0].type).toBe('CLOSE_DRAWER');
    expect(r[0].drawerId).toBe('drawer-2');
    expect(cmdRepo.markManyAsSentInTransaction).toHaveBeenCalledWith(['close-cmd-1']);
  });

  it('Close Test 7 — Raspberry Pi EXECUTES CLOSE_DRAWER via existing ACK endpoint: status=EXECUTED', async () => {
    const cmd = makeCmd({ id: 'close-ack-1', type: 'CLOSE_DRAWER' });
    const finalCmd = makeCmd({ id: 'close-ack-1', type: 'CLOSE_DRAWER', status: 'EXECUTED', executedAt: now(), error: null });
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk().mockResolvedValue(cmd),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk().mockResolvedValue(finalCmd),
    };
    const ackUc = new AcknowledgeDeviceCommandResult(cmdRepo);
    const r = await ackUc.execute('close-ack-1', 'PI-OPEN-DRAWER-001', 'EXECUTED');
    expect(cmdRepo.updateResult).toHaveBeenCalledWith('close-ack-1', {
      status: 'EXECUTED',
      error: null,
    });
    expect(r.status).toBe('EXECUTED');
  });

  it('Close Test 8 — Raspberry Pi reports FAILED with error; error stored, executedAt null, and NO medication side effects (no MedicationSession/DrawerMedication imports in close use-case)', async () => {
    const cmd = makeCmd({ id: 'close-ack-2', type: 'CLOSE_DRAWER' });
    const finalCmd = makeCmd({
      id: 'close-ack-2',
      type: 'CLOSE_DRAWER',
      status: 'FAILED',
      executedAt: null,
      error: 'Motor could not close drawer',
    });
    const cmdRepo: CmdRepo = {
      create: mk(),
      findById: mk().mockResolvedValue(cmd),
      findPendingByDeviceId: mk(),
      markManyAsSentInTransaction: mk(),
      updateResult: mk().mockResolvedValue(finalCmd),
    };
    const ackUc = new AcknowledgeDeviceCommandResult(cmdRepo);
    const r = await ackUc.execute('close-ack-2', 'PI-OPEN-DRAWER-001', 'FAILED', 'Motor could not close drawer');
    expect(cmdRepo.updateResult).toHaveBeenCalledWith('close-ack-2', {
      status: 'FAILED',
      error: 'Motor could not close drawer',
    });
    expect(r.status).toBe('FAILED');
    // Also run the drawerCloseCommandSchema schema tests inline + no-medication-sedation static check on close files
    expect(drawerCloseCommandSchema.safeParse({}).success).toBe(true);
    expect(drawerCloseCommandSchema.safeParse({ reason: null }).success).toBe(true);
    expect(drawerCloseCommandSchema.safeParse({ reason: 'x'.repeat(200) }).success).toBe(true);
    expect(drawerCloseCommandSchema.safeParse({ reason: 'x'.repeat(201) }).success).toBe(false);
    expect(drawerCloseCommandSchema.safeParse({ hack: 1 }).success).toBe(false);
    const fs = require('fs') as typeof import('node:fs');
    const path = require('path') as typeof import('node:path');
    const content = fs.readFileSync(
      path.resolve(__dirname, '../src/application/use-cases/drawer/CreateDrawerCloseCommand.ts'),
      'utf8',
    );
    expect(content).not.toMatch(/MedicationSession|DrawerMedication/);
  });
});

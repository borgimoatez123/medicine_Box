import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { Drawer } from '@domain/entities/Drawer';
import type { DrawerSensorState } from '@domain/entities/DrawerSensorState';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IDrawerSensorStateRepository } from '@domain/repositories/IDrawerSensorStateRepository';
import { RecordDrawerSensorReading } from '@application/use-cases/device/RecordDrawerSensorReading';
import { GetMedicineBoxSensorReadings } from '@application/use-cases/medicine-box/GetMedicineBoxSensorReadings';
import {
  drawerSensorReadingSchema,
} from '@presentation/validators/devices.validator';
import {
  formatZodErrors,
} from '@presentation/controllers/DevicesController';
import {
  ForbiddenError,
  NotFoundError,
} from '@shared/errors';

type AnyFn = jest.Mock<any, any>;

const mk = (): AnyFn => jest.fn();

type Repos = {
  boxRepo: IMedicineBoxRepository & {
    findByDeviceId: AnyFn;
    findByIdAndUserId: AnyFn;
  };
  drawerRepo: IDrawerRepository & {
    findById: AnyFn;
    findByIdAndUserId: AnyFn;
    findAllByMedicineBoxId: AnyFn;
  };
  sensorRepo: IDrawerSensorStateRepository & {
    upsert: AnyFn;
    findByDrawerId: AnyFn;
    findManyByDrawerIds: AnyFn;
  };
};

const now = () => new Date('2026-09-23T18:30:00.000Z');

const makeBox = (patch: Partial<MedicineBox> = {}): MedicineBox => ({
  id: 'box-1',
  deviceId: 'PI-DEV-001',
  deviceToken: 'SECRET-TOKEN',
  name: 'Smart Box Alpha',
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

const makeSensorState = (patch: Partial<DrawerSensorState> = {}): DrawerSensorState => ({
  id: 'sensor-state-uuid',
  drawerId: patch.drawerId ?? 'drawer-1',
  temperature: patch.temperature ?? 27.4,
  humidity: patch.humidity ?? 58.2,
  fireDetected: patch.fireDetected ?? false,
  createdAt: now(),
  updatedAt: patch.updatedAt ?? now(),
  ...patch,
});

describe('§ Drawer DHT11 + Fire Sensor Feature — 9 tests', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  const makeRecordRepos = (
    data: {
      box?: MedicineBox | null;
      drawer?: Drawer | null;
      saved?: DrawerSensorState;
    } = {},
  ): Repos & { uc: RecordDrawerSensorReading } => {
    const boxRepo = {
      findByDeviceId: mk().mockResolvedValue(
        data.box === undefined ? makeBox() : data.box,
      ),
      findByIdAndUserId: mk(),
    } as unknown as Repos['boxRepo'];
    const drawerRepo = {
      findById: mk().mockResolvedValue(
        data.drawer === undefined ? makeDrawer() : data.drawer,
      ),
      findByIdAndUserId: mk(),
      findAllByMedicineBoxId: mk(),
    } as unknown as Repos['drawerRepo'];
    const sensorRepo = {
      upsert: mk().mockResolvedValue(
        data.saved === undefined ? makeSensorState() : data.saved,
      ),
      findByDrawerId: mk(),
      findManyByDrawerIds: mk(),
    } as unknown as Repos['sensorRepo'];
    const uc = new RecordDrawerSensorReading(boxRepo, drawerRepo, sensorRepo);
    return { boxRepo, drawerRepo, sensorRepo, uc };
  };

  it('T1 — Valid sensor reading → upsert succeeds, returns 5-field DTO with updatedAt', async () => {
    const t = now();
    const saved = makeSensorState({
      drawerId: 'drawer-1',
      temperature: 27.4,
      humidity: 58.2,
      fireDetected: false,
      updatedAt: t,
    });
    const { uc, sensorRepo, boxRepo, drawerRepo } = makeRecordRepos({ saved });
    const result = await uc.execute({
      deviceId: 'PI-DEV-001',
      drawerId: 'drawer-1',
      temperature: 27.4,
      humidity: 58.2,
      fireDetected: false,
    });
    expect(boxRepo.findByDeviceId).toHaveBeenCalledWith('PI-DEV-001');
    expect(drawerRepo.findById).toHaveBeenCalledWith('drawer-1');
    expect(sensorRepo.upsert).toHaveBeenCalledWith({
      drawerId: 'drawer-1',
      temperature: 27.4,
      humidity: 58.2,
      fireDetected: false,
    });
    expect(result.drawerId).toBe('drawer-1');
    expect(result.temperature).toBe(27.4);
    expect(result.humidity).toBe(58.2);
    expect(result.fireDetected).toBe(false);
    expect(result.updatedAt).toBe(t);
  });

  it('T2 — Fire detected (true) → persisted correctly in result DTO', async () => {
    const t = now();
    const saved = makeSensorState({
      drawerId: 'drawer-1',
      temperature: 45.8,
      humidity: 30.2,
      fireDetected: true,
      updatedAt: t,
    });
    const { uc, sensorRepo } = makeRecordRepos({ saved });
    const result = await uc.execute({
      deviceId: 'PI-DEV-001',
      drawerId: 'drawer-1',
      temperature: 45.8,
      humidity: 30.2,
      fireDetected: true,
    });
    expect(sensorRepo.upsert).toHaveBeenCalledWith(
      expect.objectContaining({ fireDetected: true }),
    );
    expect(result.fireDetected).toBe(true);
    expect(result.temperature).toBe(45.8);
    expect(result.humidity).toBe(30.2);
  });

  it('T3 — humidity=150 (impossible) → zod validation fails 400', () => {
    const bad = drawerSensorReadingSchema.safeParse({
      deviceId: 'PI-DEV-001',
      drawerId: 'drawer-1',
      temperature: 27.4,
      humidity: 150,
      fireDetected: false,
    });
    expect(bad.success).toBe(false);
    if (!bad.success) {
      const firstPath = bad.error.issues[0]?.path?.[0];
      expect(firstPath).toBe('humidity');
      const msg = formatZodErrors(bad.error, 'sensor-reading');
      expect(msg).toMatch(/0\.\.100|SENSOR_READING/);
    }
  });

  it('T4 — Device not found → NotFoundError 404', async () => {
    const { uc, sensorRepo } = makeRecordRepos({ box: null });
    await expect(
      uc.execute({
        deviceId: 'NO-SUCH-DEVICE',
        drawerId: 'drawer-1',
        temperature: 27,
        humidity: 50,
        fireDetected: false,
      }),
    ).rejects.toThrow(NotFoundError);
    try {
      await uc.execute({
        deviceId: 'NO-SUCH-DEVICE',
        drawerId: 'drawer-1',
        temperature: 27,
        humidity: 50,
        fireDetected: false,
      });
    } catch (e) {
      expect((e as Error).message).toBe('Device not found');
    }
    expect(sensorRepo.upsert).not.toHaveBeenCalled();
  });

  it('T5 — Drawer belongs to another MedicineBox → ForbiddenError 403', async () => {
    const foreignDrawer = makeDrawer({
      id: 'drawer-foreign',
      medicineBoxId: 'box-OTHER-OWNER',
    });
    const { uc, sensorRepo } = makeRecordRepos({ drawer: foreignDrawer });
    await expect(
      uc.execute({
        deviceId: 'PI-DEV-001',
        drawerId: 'drawer-foreign',
        temperature: 27,
        humidity: 50,
        fireDetected: false,
      }),
    ).rejects.toThrow(ForbiddenError);
    try {
      await uc.execute({
        deviceId: 'PI-DEV-001',
        drawerId: 'drawer-foreign',
        temperature: 27,
        humidity: 50,
        fireDetected: false,
      });
    } catch (e) {
      expect((e as Error).message).toMatch(/does not belong|another.*box/i);
    }
    expect(sensorRepo.upsert).not.toHaveBeenCalled();
  });

  it('T6 — Mobile GET medicine-box sensors → EVERY drawer present (incl. no-row = null temp/hum, fire=false)', async () => {
    const box = makeBox({ id: 'box-1', userId: 'user-own' });
    const drawer1 = makeDrawer({ id: 'drawer-1', medicineBoxId: 'box-1', drawerNumber: 1 });
    const drawer2 = makeDrawer({ id: 'drawer-2', medicineBoxId: 'box-1', drawerNumber: 2 });
    const s1 = makeSensorState({
      id: 's1',
      drawerId: 'drawer-1',
      temperature: 27.4,
      humidity: 58.2,
      fireDetected: false,
      updatedAt: now(),
    });
    const boxRepo = {
      findByDeviceId: mk(),
      findByIdAndUserId: mk().mockResolvedValue(box),
    } as unknown as Repos['boxRepo'];
    const drawerRepo = {
      findById: mk(),
      findByIdAndUserId: mk(),
      findAllByMedicineBoxId: mk().mockResolvedValue([drawer1, drawer2]),
    } as unknown as Repos['drawerRepo'];
    const sensorRepo = {
      upsert: mk(),
      findByDrawerId: mk(),
      findManyByDrawerIds: mk().mockResolvedValue([s1]),
    } as unknown as Repos['sensorRepo'];
    const uc = new GetMedicineBoxSensorReadings(boxRepo, drawerRepo, sensorRepo);
    const result = await uc.execute('user-own', 'box-1');
    expect(boxRepo.findByIdAndUserId).toHaveBeenCalledWith('box-1', 'user-own');
    expect(drawerRepo.findAllByMedicineBoxId).toHaveBeenCalledWith('box-1');
    expect(sensorRepo.findManyByDrawerIds).toHaveBeenCalledWith(['drawer-1', 'drawer-2']);
    expect(result.medicineBoxId).toBe('box-1');
    expect(result.drawers).toHaveLength(2);
    const d1 = result.drawers.find((d) => d.drawerId === 'drawer-1')!;
    const d2 = result.drawers.find((d) => d.drawerId === 'drawer-2')!;
    expect(d1.temperature).toBe(27.4);
    expect(d1.humidity).toBe(58.2);
    expect(d1.fireDetected).toBe(false);
    expect(d1.updatedAt).toBeInstanceOf(Date);
    expect(d2.temperature).toBeNull();
    expect(d2.humidity).toBeNull();
    expect(d2.fireDetected).toBe(false);
    expect(d2.updatedAt).toBeNull();
  });

  it('T7 — Mobile GET other user\'s medicine box → NotFoundError 404', async () => {
    const boxRepo = {
      findByDeviceId: mk(),
      findByIdAndUserId: mk().mockResolvedValue(null),
    } as unknown as Repos['boxRepo'];
    const drawerRepo = {
      findById: mk(),
      findByIdAndUserId: mk(),
      findAllByMedicineBoxId: mk(),
    } as unknown as Repos['drawerRepo'];
    const sensorRepo = {
      upsert: mk(),
      findByDrawerId: mk(),
      findManyByDrawerIds: mk(),
    } as unknown as Repos['sensorRepo'];
    const uc = new GetMedicineBoxSensorReadings(boxRepo, drawerRepo, sensorRepo);
    await expect(
      uc.execute('user-ATTACKER', 'box-1'),
    ).rejects.toThrow(NotFoundError);
    try {
      await uc.execute('user-ATTACKER', 'box-1');
    } catch (e) {
      expect((e as Error).message).toBe('Medicine box not found');
    }
    expect(drawerRepo.findAllByMedicineBoxId).not.toHaveBeenCalled();
  });

  it('Bonus A — temperature=Infinity → zod strict finite check fails 400', () => {
    const bad = drawerSensorReadingSchema.safeParse({
      deviceId: 'PI-DEV-001',
      drawerId: 'drawer-1',
      temperature: Infinity,
      humidity: 50,
      fireDetected: false,
    });
    expect(bad.success).toBe(false);
    if (!bad.success) {
      const firstPath = bad.error.issues[0]?.path?.[0];
      expect(firstPath).toBe('temperature');
    }
  });

  it('Bonus B — fireDetected="false" string (coercion forbidden) → zod strict boolean fails 400', () => {
    const bad = drawerSensorReadingSchema.safeParse({
      deviceId: 'PI-DEV-001',
      drawerId: 'drawer-1',
      temperature: 27,
      humidity: 50,
      fireDetected: 'false' as unknown as boolean,
    });
    expect(bad.success).toBe(false);
    if (!bad.success) {
      const firstPath = bad.error.issues[0]?.path?.[0];
      expect(firstPath).toBe('fireDetected');
    }
  });
});
